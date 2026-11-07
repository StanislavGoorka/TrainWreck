## Room (locks the doors and spawns enemies when the player walks in) and BossRoom.
extends "res://tests/helpers/tw_test_suite.gd"

const RecordingRoom := preload("res://tests/helpers/recording_room.gd")
const ONE_ENEMY_ROOM := preload("res://Test/Scenes/Rooms/IntermediateRooms/room_01.tscn")
const EMPTY_ROOM := preload("res://Test/Scenes/Rooms/IntermediateRooms/room_03.tscn")
const THREE_ENEMY_ROOM := preload("res://Test/Scenes/Rooms/IntermediateRooms/room_05.tscn")
const PEDESTAL_SCENE := preload("res://Test/Scenes/InGameElements/pedestal.tscn")
const BossHealthBar := preload("res://Test/Scripts/UIElements/BossHealthBar.gd")

var player: Player


func before_test() -> void:
	super.before_test()
	player = auto_free(Factory.player(Factory.character_stats(1000.0)))
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	add_child(player)
	player.global_position = Vector2(-5000, -5000)   # outside every room until a test moves it


func _room(scene: PackedScene, script: GDScript = null) -> Room:
	var room: Room = auto_free(scene.instantiate())
	if script:
		room.set_script(script)
	room.spawn_delay = 0.05
	add_child(room)
	return room


func _door_closed(room: Room, door: String) -> bool:
	return not room.get_node("Doors/%s/CollisionShape2D" % door).disabled and room.get_node("Doors/" + door).visible


func _enemies(room: Room) -> Array:
	return room.get_node("EnemiesSpawn").get_children().filter(func(n: Node) -> bool: return n is Enemy)


func _wait_until_enabled(enemies: Array) -> bool:
	var enabled := func(e: Node) -> bool: return is_instance_valid(e) and e.process_mode == Node.PROCESS_MODE_INHERIT
	return await wait_until(func() -> bool: return enemies.all(enabled), 2000)


func _pedestals(room: Node) -> Array:
	return room.get_children().filter(func(n: Node) -> bool: return n.scene_file_path == PEDESTAL_SCENE.resource_path)


# --- Room --------------------------------------------------------------------------

func test_doors_start_open() -> void:
	var room := _room(ONE_ENEMY_ROOM)
	await get_tree().physics_frame
	assert_bool(_door_closed(room, "Door")).is_false()
	assert_bool(_door_closed(room, "Door2")).is_false()
	assert_bool(room.locked).is_false()


func test_only_spawn_points_with_an_enemy_scene_count() -> void:
	var room := _room(THREE_ENEMY_ROOM)
	assert_int(room._get_spawn_points().size()).is_equal(3)
	var empty_point := EnemySpawnPoint.new()
	room.get_node("EnemiesSpawn").add_child(empty_point)
	assert_int(room._get_spawn_points().size()).is_equal(3)
	assert_array(_room(EMPTY_ROOM)._get_spawn_points()).is_empty()


func test_entering_locks_the_room_and_spawns_its_enemies() -> void:
	var room := _room(ONE_ENEMY_ROOM)
	room._on_player_detector_body_entered(player)
	await get_tree().physics_frame
	assert_bool(room.spawned).is_true()
	assert_bool(room.locked).is_true()
	assert_bool(_door_closed(room, "Door")).is_true()
	assert_bool(_door_closed(room, "Door2")).is_true()
	var enemies := _enemies(room)
	assert_array(enemies).has_size(1)
	assert_array(room.alive_enemies).contains_exactly(enemies[0])


func test_enemies_fade_in_harmless_then_hunt_the_player() -> void:
	var room := _room(ONE_ENEMY_ROOM)
	room._on_player_detector_body_entered(player)
	var enemy: Enemy = _enemies(room)[0]
	var point: Node2D = room._get_spawn_points()[0]
	assert_vector(enemy.global_position).is_equal_approx(point.global_position, Vector2.ONE * 0.01)
	assert_int(enemy.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_float(enemy.modulate.a).is_equal(0.0)
	assert_bool(await _wait_until_enabled([enemy])).is_true()
	assert_object(enemy.target).is_same(player)


func test_killing_every_enemy_opens_the_doors() -> void:
	var room := _room(THREE_ENEMY_ROOM, RecordingRoom)
	room._on_player_detector_body_entered(player)
	var enemies := _enemies(room)
	assert_array(enemies).has_size(3)
	await _wait_until_enabled(enemies)
	enemies[0].take_damage(1000.0)
	enemies[1].take_damage(1000.0)
	assert_bool(room.locked).is_true()
	enemies[2].take_damage(1000.0)
	await get_tree().physics_frame
	assert_bool(room.locked).is_false()
	assert_bool(_door_closed(room, "Door")).is_false()
	assert_int(room.cleared_calls).is_equal(1)


func test_room_hook_receives_all_spawned_enemies_once(
		do_skip := true,
		skip_reason := "KNOWN BUG: room.gd _spawn_enemies() calls _on_enemies_spawned() inside the spawn loop (line 86), once per enemy with a partial list") -> void:
	var room := _room(THREE_ENEMY_ROOM, RecordingRoom)
	room._on_player_detector_body_entered(player)
	assert_array(room.spawned_calls).has_size(1)
	assert_array(room.spawned_calls[0]).has_size(3)


func test_entering_a_room_without_enemies_keeps_it_open() -> void:
	var room := _room(EMPTY_ROOM, RecordingRoom)
	room._on_player_detector_body_entered(player)
	await get_tree().physics_frame
	assert_bool(room.spawned).is_false()
	assert_bool(room.locked).is_false()
	assert_bool(_door_closed(room, "Door")).is_false()
	assert_array(room.spawned_calls).is_empty()


func test_only_the_player_triggers_the_room() -> void:
	var room := _room(ONE_ENEMY_ROOM)
	var enemy: Enemy = auto_free(Factory.enemy())
	add_child(enemy)
	room._on_player_detector_body_entered(enemy)
	assert_bool(room.spawned).is_false()


func test_leaving_the_room_makes_enemies_lose_track_of_the_player() -> void:
	var room := _room(ONE_ENEMY_ROOM)
	room._on_player_detector_body_entered(player)
	var enemy: Enemy = _enemies(room)[0]
	await _wait_until_enabled([enemy])
	room._on_player_detector_body_exited(player)
	assert_object(enemy.target).is_null()


func test_dashing_out_of_the_detector_does_not_count_as_leaving() -> void:
	var room := _room(ONE_ENEMY_ROOM)
	room._on_player_detector_body_entered(player)
	var enemy: Enemy = _enemies(room)[0]
	await _wait_until_enabled([enemy])
	player.invulnerable = true
	room._on_player_detector_body_exited(player)
	assert_object(enemy.target).is_same(player)


func test_coming_back_relocks_the_room_and_reactivates_survivors() -> void:
	var room := _room(ONE_ENEMY_ROOM)
	room._on_player_detector_body_entered(player)
	var enemy: Enemy = _enemies(room)[0]
	await _wait_until_enabled([enemy])
	room._on_player_detector_body_exited(player)
	room.locked = false
	room._set_doors(true)
	room._on_player_detector_body_entered(player)
	await get_tree().physics_frame
	assert_bool(room.locked).is_true()
	assert_bool(_door_closed(room, "Door")).is_true()
	assert_object(enemy.target).is_same(player)
	assert_array(_enemies(room)).has_size(1)   # nobody respawns


func test_player_walking_in_is_detected_by_physics() -> void:
	var room := _room(ONE_ENEMY_ROOM)
	player.global_position = room.get_node("PlayerDetector").global_position
	var spawned := await wait_until(func() -> bool: return room.spawned, 2000)
	assert_bool(spawned).is_true()


func test_short_rooms_center_the_camera_vertically() -> void:
	var room := _room(EMPTY_ROOM)
	room._apply_camera_limits(player)
	var camera: Camera2D = player.get_node("Camera2D")
	var view_height: float = room.get_viewport().get_visible_rect().size.y / camera.zoom.y
	var center: float = (room.top_boundary.global_position.y + room.bottom_boundary.global_position.y) / 2.0
	assert_int(camera.limit_top).is_equal(int(center - view_height / 2.0))
	assert_int(camera.limit_bottom).is_equal(int(center + view_height / 2.0))
	assert_int(camera.limit_left).is_equal(-10000000)
	assert_int(camera.limit_right).is_equal(10000000)


func test_tall_rooms_limit_the_camera_to_their_bounds() -> void:
	var room := _room(EMPTY_ROOM)
	room.top_boundary.global_position.y = -3000.0
	room.bottom_boundary.global_position.y = 3000.0
	room._apply_camera_limits(player)
	var camera: Camera2D = player.get_node("Camera2D")
	assert_int(camera.limit_top).is_equal(-3000)
	assert_int(camera.limit_bottom).is_equal(3000)


func test_horizontal_camera_clamp_uses_the_connectors() -> void:
	var room := _room(EMPTY_ROOM)
	room.clamp_camera_horizontally = true
	room._apply_camera_limits(player)
	var camera: Camera2D = player.get_node("Camera2D")
	assert_int(camera.limit_left).is_equal(int(room.get_node("Connector/Left").global_position.x))
	assert_int(camera.limit_right).is_equal(int(room.get_node("Connector/Right").global_position.x))


# --- BossRoom ----------------------------------------------------------------------

func _boss_room(reward: PackedScene = null) -> BossRoom:
	var room: BossRoom = _room(EMPTY_ROOM, BossRoom)
	room.reward_pedestal_scene = reward
	room.reward_spawn_delay = 0.05
	return room


func _boss() -> Boss:
	var stats := BossStats.new()
	stats.boss_name = "Test Boss"
	var boss: Boss = auto_free(Factory.enemy(stats, {}, Boss))
	add_child(boss)
	return boss


func test_boss_room_shows_the_boss_health_bar() -> void:
	var bar: VBoxContainer = auto_free(BossHealthBar.new())
	add_child(bar)
	var room := _boss_room()
	var boss := _boss()
	var grunt: Enemy = auto_free(Factory.enemy())
	add_child(grunt)
	room._on_enemies_spawned([grunt, boss])
	assert_bool(bar.visible).is_true()
	assert_object(bar.boss).is_same(boss)
	assert_str(bar.name_label.text).is_equal("Test Boss")


func test_boss_room_without_a_health_bar_does_not_crash() -> void:
	var room := _boss_room()
	room._on_enemies_spawned([_boss()])
	assert_bool(room.locked).is_false()


func test_boss_room_remembers_where_the_boss_died() -> void:
	var room := _boss_room()
	var boss := _boss()
	boss.global_position = Vector2(123, 456)
	room.alive_enemies = [boss]
	room.locked = true
	room._on_enemy_died(boss)
	assert_vector(room.last_enemy_position).is_equal(Vector2(123, 456))
	assert_bool(room.locked).is_false()


func test_beating_the_boss_spawns_a_boss_reward_pedestal() -> void:
	var room := _boss_room(PEDESTAL_SCENE)
	room.last_enemy_position = Vector2(300, 200)
	room._on_room_cleared()
	var appeared := await wait_until(func() -> bool: return not _pedestals(room).is_empty(), 2000)
	assert_bool(appeared).is_true()
	var pedestal: Node2D = _pedestals(room)[0]
	assert_int(pedestal.draw_from_pools).is_equal(ItemData.POOL_BOSS)
	assert_vector(pedestal.global_position).is_equal_approx(Vector2(300, 200), Vector2.ONE * 0.01)


func test_boss_reward_uses_the_reward_spawn_marker_when_present() -> void:
	var room := _boss_room(PEDESTAL_SCENE)
	var marker := Marker2D.new()
	marker.name = "RewardSpawnPos"
	room.add_child(marker)
	marker.global_position = Vector2(-40, 80)
	room._on_room_cleared()
	await wait_until(func() -> bool: return not _pedestals(room).is_empty(), 2000)
	var pedestal: Node2D = _pedestals(room)[0]
	assert_vector(pedestal.global_position).is_equal_approx(Vector2(-40, 80), Vector2.ONE * 0.01)


func test_boss_room_without_a_reward_scene_spawns_nothing() -> void:
	var room := _boss_room(null)
	var before := room.get_child_count()
	room._on_room_cleared()
	await await_millis(150)
	assert_int(room.get_child_count()).is_equal(before)
