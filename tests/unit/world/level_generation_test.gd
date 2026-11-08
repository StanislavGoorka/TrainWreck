## The run's level generator (rooms.gd: floors, room order, floor transitions) and the
## room-snapping camera (camera.gd).
## rooms.gd looks the player up at the absolute path /root/Game/Character1, so the
## fixture builds exactly that under the tree root.
extends "res://tests/helpers/tw_test_suite.gd"

const RoomsScript := preload("res://Test/Scripts/RoomRelated/rooms.gd")
const CameraScript := preload("res://Placeholders/Scripts/camera.gd")

var game: Node
var player: Player


func before() -> void:
	super.before()
	load_pinned(ROOM_TILESET_PATH)   # every generated room loads it


func before_test() -> void:
	super.before_test()
	game = auto_free(Node.new())
	game.name = "Game"
	player = Factory.player(Factory.character_stats(1000.0))
	player.name = "Character1"
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	game.add_child(player)
	get_tree().root.add_child(game)


func _generate(levels: int) -> Node2D:
	var rooms: Node2D = Node2D.new()
	rooms.name = "Rooms"
	rooms.set_script(RoomsScript)
	rooms.num_levels = levels
	game.add_child(rooms)
	return rooms


func _rooms(generator: Node2D) -> Array:
	return generator.get_children().filter(func(n: Node) -> bool: return n is Node2D and not n.is_queued_for_deletion())


func _folder(room: Node) -> String:
	return room.scene_file_path.get_base_dir() + "/"


# --- Generation --------------------------------------------------------------------

func test_level_has_the_requested_number_of_rooms() -> void:
	var generator := _generate(6)
	assert_array(_rooms(generator)).has_size(6)


func test_level_starts_and_ends_with_the_right_room_types() -> void:
	var rooms := _rooms(_generate(6))
	assert_str(_folder(rooms[0])).is_equal(RoomsScript.STARTING_ROOMS_FOLDER)
	assert_str(_folder(rooms[5])).is_equal(RoomsScript.ENDING_ROOMS_FOLDER)


func test_boss_room_comes_right_before_the_end() -> void:
	var rooms := _rooms(_generate(6))
	assert_str(_folder(rooms[4])).is_equal(RoomsScript.BOSS_ROOMS_FOLDER)


func test_every_level_has_exactly_one_item_room() -> void:
	for attempt in 5:
		var generator := _generate(7)
		var rooms := _rooms(generator)
		var special := rooms.filter(func(r: Node) -> bool: return _folder(r) == RoomsScript.SPECIAL_ROOMS_FOLDER)
		assert_array(special).has_size(1)
		var index := rooms.find(special[0])
		assert_int(index).is_between(1, 4)   # never the start, boss or end slot
		generator.free()


func test_middle_rooms_are_intermediate_rooms() -> void:
	var rooms := _rooms(_generate(8))
	for i in range(1, 6):
		assert_array([RoomsScript.INTERMEDIATE_ROOMS_FOLDER, RoomsScript.SPECIAL_ROOMS_FOLDER]) \
			.contains(_folder(rooms[i]))


func test_rooms_are_chained_door_to_door() -> void:
	var rooms := _rooms(_generate(6))
	for i in range(1, rooms.size()):
		var previous_right: Vector2 = rooms[i - 1].get_node("Connector/Right").global_position
		var left: Vector2 = rooms[i].get_node("Connector/Left").global_position
		assert_vector(left).override_failure_message("room %d is not attached to room %d" % [i, i - 1]) \
			.is_equal_approx(previous_right, Vector2.ONE * 0.01)


func test_player_starts_at_the_spawn_point_of_the_first_room() -> void:
	var rooms := _rooms(_generate(5))
	var spawn: Node2D = rooms[0].get_node("PlayerSpawnPos")
	assert_vector(player.global_position).is_equal_approx(spawn.global_position, Vector2.ONE * 0.01)


func test_room_folders_contain_rooms() -> void:
	var generator := _generate(5)
	for list_name in ["START_ROOMS", "INTERMEDIATE_ROOMS", "END_ROOMS", "SPECIAL_ROOMS", "BOSS_ROOMS"]:
		var scenes: Array = generator.get(list_name)
		assert_array(scenes).override_failure_message(list_name + " is empty").is_not_empty()
		for scene in scenes:
			assert_object(scene).is_instanceof(PackedScene)


func test_without_the_player_nothing_is_generated() -> void:
	player.name = "SomebodyElse"
	var generator := _generate(5)
	assert_array(_rooms(generator)).is_empty()


func test_generation_seed_is_recorded() -> void:
	var generator := _generate(4)
	assert_int(generator.generation_seed).is_not_zero()


# --- Floors ------------------------------------------------------------------------

func test_too_few_levels_still_build_every_required_room() -> void:
	var rooms := _rooms(_generate(3))
	assert_array(rooms).has_size(GameState.MIN_FLOOR_ROOMS)
	assert_str(_folder(rooms[0])).is_equal(RoomsScript.STARTING_ROOMS_FOLDER)
	assert_str(_folder(rooms[-2])).is_equal(RoomsScript.BOSS_ROOMS_FOLDER)
	assert_str(_folder(rooms[-1])).is_equal(RoomsScript.ENDING_ROOMS_FOLDER)


func test_generator_sets_the_number_of_floors(levels: int, floors: int, test_parameters := [
	[3, 1], [5, 1], [6, 2], [8, 4], [10, 6],
]) -> void:
	_generate(levels)
	assert_int(GameState.total_floors).is_equal(floors)


func test_every_floor_has_one_room_less_down_to_the_minimum() -> void:
	var generator := _generate(8)
	var counts := []
	for floor_number in range(1, 7):
		counts.append(generator._floor_room_count(floor_number))
	assert_array(counts).is_equal([8, 7, 6, 5, 5, 5])


func test_last_floor_has_the_minimum_room_count() -> void:
	var generator := _generate(9)
	assert_int(generator._floor_room_count(GameState.total_floors)).is_equal(GameState.MIN_FLOOR_ROOMS)


func test_generation_starts_on_the_current_floor() -> void:
	GameState.current_floor = 3
	assert_array(_rooms(_generate(8))).has_size(6)


func test_generator_builds_an_invisible_fade_layer() -> void:
	var generator := _generate(5)
	assert_object(generator.fade_layer).is_not_null()
	assert_int(generator.fade_layer.layer).is_equal(90)   # above the HUD, below the game over screen
	assert_int(generator.fade_layer.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_float(generator.fade_rect.modulate.a).is_zero()
	assert_int(generator.fade_rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func _wait_for_transition(generator: Node2D) -> bool:
	return await wait_until(func() -> bool: return not generator.transitioning, 5000)


func test_next_floor_replaces_the_rooms_with_a_smaller_floor() -> void:
	GameState.run_active = true
	var generator := _generate(7)
	var old_rooms := _rooms(generator)
	GameState.advance_floor()
	assert_bool(generator.transitioning).is_true()
	assert_bool(await _wait_for_transition(generator)).is_true()

	var rooms := _rooms(generator)
	assert_array(rooms).has_size(6)
	assert_array(generator.current_rooms).has_size(6)
	for room in old_rooms:
		assert_bool(is_instance_valid(room) and room.is_inside_tree()).is_false()
	assert_str(_folder(rooms[0])).is_equal(RoomsScript.STARTING_ROOMS_FOLDER)
	assert_str(_folder(rooms[4])).is_equal(RoomsScript.BOSS_ROOMS_FOLDER)
	assert_str(_folder(rooms[5])).is_equal(RoomsScript.ENDING_ROOMS_FOLDER)


func test_next_floor_puts_the_player_at_the_new_start() -> void:
	GameState.run_active = true
	var generator := _generate(6)
	player.global_position = Vector2(99999, 99999)
	player.velocity = Vector2(500, 0)
	GameState.advance_floor()
	await _wait_for_transition(generator)
	var spawn: Node2D = _rooms(generator)[0].get_node("PlayerSpawnPos")
	assert_vector(player.global_position).is_equal_approx(spawn.global_position, Vector2.ONE * 0.01)
	assert_vector(player.velocity).is_equal(Vector2.ZERO)


func test_floor_transition_freezes_the_player_and_the_clock_until_it_ends() -> void:
	GameState.run_active = true
	var generator := _generate(6)
	GameState.advance_floor()
	assert_bool(GameState.clock_paused).is_true()
	assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	await _wait_for_transition(generator)
	assert_bool(GameState.clock_paused).is_false()
	assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_float(generator.fade_rect.modulate.a).is_equal_approx(0.0, 0.001)


func test_floor_change_during_a_transition_is_ignored() -> void:
	GameState.run_active = true
	var generator := _generate(8)
	GameState.advance_floor()
	GameState.floor_changed.emit(3)   # e.g. a second portal press slipping through
	await _wait_for_transition(generator)
	assert_array(_rooms(generator)).has_size(7)   # floor 2, not floor 3


# --- Room camera -------------------------------------------------------------------

func _camera(player_position: Vector2) -> Camera2D:
	var world: Node2D = auto_free(Node2D.new())
	var target := Node2D.new()
	target.name = "Character1"
	world.add_child(target)
	target.position = player_position
	var camera := Camera2D.new()
	camera.set_script(CameraScript)
	world.add_child(camera)
	add_child(world)
	return camera


func test_camera_centers_on_the_room_the_player_is_in(player_position: Vector2, expected: Vector2, test_parameters := [
	[Vector2(10, 10), Vector2(960, 540)],
	[Vector2(1919, 1079), Vector2(960, 540)],
	[Vector2(1920, 0), Vector2(2880, 540)],
	[Vector2(4000, 2500), Vector2(4800, 2700)],
	[Vector2(-10, 5), Vector2(-960, 540)],
	[Vector2(5, -1), Vector2(960, -540)],
]) -> void:
	var camera := _camera(player_position)
	assert_vector(camera.global_position).is_equal_approx(expected, Vector2.ONE * 0.01)


func test_camera_follows_the_player_into_the_next_room() -> void:
	var camera := _camera(Vector2(100, 100))
	camera.player_node.position = Vector2(2000, 100)
	camera.set_screen_position()
	assert_vector(camera.global_position).is_equal_approx(Vector2(2880, 540), Vector2.ONE * 0.01)


func test_camera_starts_without_smoothing_and_enables_it_a_frame_later() -> void:
	var camera := _camera(Vector2(100, 100))
	assert_bool(camera.position_smoothing_enabled).is_false()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(camera.position_smoothing_enabled).is_true()
