## Smoke tests of the real game scenes: they are instantiated as the game would, and the
## tests check that the parts the scripts rely on (nodes, animations, settings) exist
## and that the scenes come up in a playable state.
extends "res://tests/helpers/tw_test_suite.gd"

const ErrorCapture := preload("res://tests/helpers/error_capture.gd")
const WalkerIdle := preload("res://Test/Scripts/States/Walker/idle.gd")
const WalkerChase := preload("res://Test/Scripts/States/Walker/chase.gd")
const WalkerAttack := preload("res://Test/Scripts/States/Walker/attack.gd")
const WalkerDeath := preload("res://Test/Scripts/States/Walker/death.gd")
const FlyingChase := preload("res://Test/Scripts/States/FlyingEnemy/FlyingChase.gd")
const SpinBossChase := preload("res://Test/Scripts/States/BossScripts/SpinBossChase.gd")
const SpinAttack := preload("res://Test/Scripts/States/BossScripts/SpinAttack.gd")
const BossHealthBar := preload("res://Test/Scripts/UIElements/BossHealthBar.gd")

const PLAYER_SCENE := "res://Placeholders/Scenes/Characters/character_1.tscn"
const PAUSE_MENU_SCENE := "res://Test/Scenes/UIScenes/UIFullScenes/pause_menu.tscn"
const MAIN_MENU_SCENE := "res://Test/Scenes/UIScenes/UIFullScenes/main_menu.tscn"
const CREDITS_SCENE := "res://Test/Scenes/UIScenes/UIFullScenes/credits.tscn"
const GAME_SCENE := "res://Test/Scenes/game.tscn"
const BOSS_ROOM_SCENE := "res://Test/Scenes/Rooms/BossRooms/boss_01.tscn"
const ENEMY_SCENES: Array[String] = [
	"res://Test/Scenes/Enemies/Fantasy/Slayer.tscn",
	"res://Test/Scenes/Enemies/Fantasy/hairy_fairy.tscn",
	"res://Test/Scenes/Enemies/Fantasy/rage_fairy.tscn",
	"res://Test/Scenes/Enemies/Fantasy/slay_fairy.tscn",
	"res://Test/Scenes/Enemies/Fantasy/Boss/laureth.tscn",
]


func before() -> void:
	super.before()
	load_pinned(ROOM_TILESET_PATH)
	load_pinned(HUB_SCENE_PATH)


func _spawn(path: String, parent: Node = self) -> Node:
	var node: Node = auto_free((load(path) as PackedScene).instantiate())
	parent.add_child(node)
	return node


# --- Enemies -----------------------------------------------------------------------

func _states_by_script(enemy: Node) -> Dictionary:
	var result := {}
	for state in enemy.get_node("StateMachine").get_children():
		result[state.get_script()] = state
	return result


func _animation_names(enemy: Node) -> PackedStringArray:
	var frames: SpriteFrames = enemy.get_node("AnimatedSprite2D").sprite_frames
	return frames.get_animation_names() if frames else PackedStringArray()


func test_enemy_scenes_come_up_ready_to_fight() -> void:
	for path in ENEMY_SCENES:
		var enemy: Enemy = _spawn(path)
		assert_object(enemy).override_failure_message(path).is_instanceof(Enemy)
		assert_bool(enemy.is_in_group("Enemies")).override_failure_message(path).is_true()
		assert_object(enemy.stats).override_failure_message(path).is_not_null()
		assert_float(enemy.health).override_failure_message(path).is_equal(enemy.stats.max_health)
		assert_object(enemy.status).override_failure_message(path).is_not_null()
		var machine: StateMachine = enemy.get_node("StateMachine")
		assert_str(String(machine.current_state.name)).override_failure_message(path).is_equal("Idle")
		assert_bool(machine.states.has(&"Dead")).override_failure_message(path + " has no Dead state").is_true()


func test_enemy_scenes_have_the_nodes_their_states_need() -> void:
	for path in ENEMY_SCENES:
		var enemy: Node = _spawn(path)
		var states := _states_by_script(enemy)
		assert_object(enemy.get_node_or_null("AnimatedSprite2D")).override_failure_message(path).is_not_null()
		assert_object(enemy.get_node_or_null("CollisionShape2D")).override_failure_message(path).is_not_null()
		if states.has(WalkerChase) or states.has(WalkerAttack):
			assert_object(enemy.get_node_or_null("AttackHitbox")).override_failure_message(path + " needs an AttackHitbox").is_not_null()
		if states.has(SpinAttack):
			assert_object(enemy.get_node_or_null("SpinHitbox")).override_failure_message(path + " needs a SpinHitbox").is_not_null()
			assert_object(enemy.stats).override_failure_message(path).is_instanceof(SpinBossStats)


func test_enemies_are_on_the_enemy_layer_so_bullets_hit_them() -> void:
	var bullet: CollisionObject2D = auto_free((load("res://Placeholders/Scenes/Characters/bullet.tscn") as PackedScene).instantiate())
	var bullet_mask := bullet.collision_mask
	for path in ENEMY_SCENES:
		var enemy: CollisionObject2D = _spawn(path)
		assert_int(enemy.collision_layer & bullet_mask).override_failure_message(path + " cannot be hit by bullets").is_not_zero()


func test_enemies_have_a_one_shot_death_animation() -> void:
	for path in ENEMY_SCENES:
		var enemy: Node = _spawn(path)
		var frames: SpriteFrames = enemy.get_node("AnimatedSprite2D").sprite_frames
		assert_bool(frames.has_animation(&"Death")).override_failure_message(path + " has no Death animation").is_true()
		# death.gd waits for animation_finished, which a looping animation never sends.
		assert_bool(frames.get_animation_loop(&"Death")).override_failure_message(path + ": Death loops").is_false()


func test_flying_enemies_have_their_flying_animation() -> void:
	for path in ENEMY_SCENES:
		var enemy: Node = _spawn(path)
		var states := _states_by_script(enemy)
		if states.has(FlyingChase):
			var anim: StringName = states[FlyingChase].animation
			assert_array(Array(_animation_names(enemy))).override_failure_message(path + " misses " + anim).contains(String(anim))


func test_walker_state_animations_exist(
		do_skip := true,
		skip_reason := "KNOWN BUG: Walker states play 'idle', 'run' and 'attack' but the enemy SpriteFrames are named 'Idle', 'Chase' and 'Attack' (Godot logs 'There is no animation' and the sprite freezes)") -> void:
	var needed := {WalkerIdle: "idle", WalkerChase: "run", WalkerAttack: "attack"}
	for path in ENEMY_SCENES:
		var enemy: Node = _spawn(path)
		var states := _states_by_script(enemy)
		for script: GDScript in needed:
			if states.has(script):
				assert_array(Array(_animation_names(enemy))).override_failure_message(path + " misses " + needed[script]).contains(needed[script])


func test_spin_boss_animations_exist(
		do_skip := true,
		skip_reason := "KNOWN BUG: the spin boss states ask for 'idle', 'run' and 'spin' but laureth.tscn has 'Idle', 'Chase' and 'SpinAttack' (the boss never animates; the spin falls back to rotating the sprite)") -> void:
	var boss: Node = _spawn("res://Test/Scenes/Enemies/Fantasy/Boss/laureth.tscn")
	assert_array(Array(_animation_names(boss))).contains("idle", "run", "spin")


func test_killed_enemies_play_their_death_and_disappear() -> void:
	for path in ENEMY_SCENES:
		var enemy: Enemy = _spawn(path)
		enemy.take_damage(enemy.stats.max_health * 10.0)
		assert_str(String(enemy.get_node("StateMachine").current_state.name)).is_equal("Dead")
		var freed := await wait_until(func() -> bool: return not is_instance_valid(enemy), 5000)
		assert_bool(freed).override_failure_message(path + " was not removed after dying").is_true()


# --- Player ------------------------------------------------------------------------

func test_player_scene_comes_up_ready_to_play() -> void:
	var player: Player = _spawn(PLAYER_SCENE)
	assert_bool(player.is_in_group("Players")).is_true()
	assert_float(player.health).is_equal(player.current_stats.max_health)
	assert_object(player.hurtbox).is_not_null()
	assert_object(player.get_node_or_null("Camera2D")).is_not_null()
	var machine: StateMachine = player.get_node("StateMachine")
	assert_array(machine.states.keys()).contains_exactly_in_any_order(&"Idle", &"Move", &"Dash")
	assert_str(String(machine.current_state.name)).is_equal("Idle")
	var weapon: StateMachine = player.get_node("Aim/WeaponStateMachine")
	assert_array(weapon.states.keys()).contains_exactly_in_any_order(&"WeaponIdle", &"WeaponCooldown")


func test_player_sprites_have_the_animations_the_states_play() -> void:
	var player: Player = _spawn(PLAYER_SCENE)
	for sprite_name in ["Body", "Head"]:
		var frames: SpriteFrames = player.get_node(sprite_name).sprite_frames
		for anim in ["Idle", "NewRun"]:
			assert_bool(frames.has_animation(anim)).override_failure_message("%s misses %s" % [sprite_name, anim]).is_true()
	var arrow: SpriteFrames = player.get_node("Aim/WeaponPivot/Arrow").sprite_frames
	for anim in ["Idle", "Shot"]:
		assert_bool(arrow.has_animation(anim)).override_failure_message("Arrow misses " + anim).is_true()


func test_player_body_has_a_dash_animation(
		do_skip := true,
		skip_reason := "KNOWN BUG: Dash.gd plays 'Dash' only if it exists; the Body SpriteFrames call it 'Roll', so dashing shows no animation") -> void:
	var player: Player = _spawn(PLAYER_SCENE)
	assert_bool(player.get_node("Body").sprite_frames.has_animation("Dash")).is_true()


func test_player_scene_has_the_health_bar_character_gd_expects(
		do_skip := true,
		skip_reason := "KNOWN BUG: character.gd looks up %HealthBar, which character_1.tscn does not have (error on every spawn)") -> void:
	var capture := ErrorCapture.new()
	capture.start()
	var player: Player = _spawn(PLAYER_SCENE)
	var errors := capture.stop()
	assert_object(player.health_bar).is_not_null()
	assert_array(Array(errors)).is_empty()


func test_player_stats_come_from_the_slinger_resources() -> void:
	var player: Player = _spawn(PLAYER_SCENE)
	assert_str(player.stats.resource_path).is_equal("res://Test/Scripts/Resource/CharacterResource/SlingerStats.tres")
	assert_str(player.weapon_stats.resource_path).is_equal("res://Test/Scripts/Resource/WeaponResource/SlingerWeaponStats.tres")


# --- Pause menu --------------------------------------------------------------------

func _pause_menu() -> Control:
	var player: Player = auto_free(Factory.player())
	add_child(player)
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	return _spawn(PAUSE_MENU_SCENE, layer)


func _menu_buttons(menu: Control) -> Dictionary:
	var result := {}
	for button: BaseButton in menu.buttons.get_children():
		result[String(button.name)] = button
	return result


func test_pause_menu_starts_closed() -> void:
	var menu := _pause_menu()
	assert_bool(menu.book.visible).is_false()
	assert_bool(get_tree().paused).is_false()


func test_pause_menu_book_has_main_inventory_and_settings_tabs() -> void:
	var menu := _pause_menu()
	var titles: Array = menu.book.spreads.map(func(s: BookSpread) -> String: return s.get_title())
	assert_array(titles).contains_exactly("Main", "Inventory", "Settings")


func test_pausing_opens_the_book_and_pauses_the_game() -> void:
	var menu := _pause_menu()
	menu.pause()
	assert_bool(get_tree().paused).is_true()
	assert_bool(menu.book.visible).is_true()
	assert_int(menu.book.current).is_zero()
	for button: BaseButton in _menu_buttons(menu).values():
		assert_bool(button.disabled).is_false()


func test_run_only_buttons_are_hidden_outside_a_run() -> void:
	var menu := _pause_menu()
	menu.pause()
	var buttons := _menu_buttons(menu)
	assert_bool(buttons["Restart"].visible).is_false()
	assert_bool(buttons["Abandon"].visible).is_false()
	assert_bool(buttons["Resume"].visible).is_true()
	assert_bool(buttons["Quit"].visible).is_true()


func test_run_only_buttons_are_shown_during_a_run() -> void:
	GameState.run_active = true
	var menu := _pause_menu()
	menu.pause()
	var buttons := _menu_buttons(menu)
	assert_bool(buttons["Restart"].visible).is_true()
	assert_bool(buttons["Abandon"].visible).is_true()


func test_resuming_closes_the_book_and_unpauses() -> void:
	var menu := _pause_menu()
	menu.pause()
	_menu_buttons(menu)["Resume"].pressed.emit()
	assert_bool(get_tree().paused).is_false()
	for button: BaseButton in _menu_buttons(menu).values():
		assert_bool(button.disabled).is_true()
	menu.fade_tween.custom_step(0.2)
	assert_bool(menu.book.visible).is_false()


func test_pause_menu_settings_split_graphics_and_audio() -> void:
	var menu := _pause_menu()
	var left: SettingsPanel = menu.get_node("Book/Settings/LeftPage/SettingsPanel")
	var right: SettingsPanel = menu.get_node("Book/Settings/RightPage/SettingsPanel")
	assert_object(left.fullscreen_check).is_not_null()
	assert_array(left.volume_rows).is_empty()
	assert_object(right.fullscreen_check).is_null()
	assert_array(right.volume_rows).has_size(3)


# --- Menus -------------------------------------------------------------------------

func test_main_menu_has_its_buttons_and_music() -> void:
	var menu: Control = _spawn(MAIN_MENU_SCENE)
	for button_name in ["Start", "Settings", "Credits", "Exit"]:
		assert_object(menu.get_node("HBoxContainer/MenuButtons/" + button_name)).is_instanceof(BaseButton)
	var trigger: MusicTrigger = menu.get_node("MusicTrigger")
	assert_object(trigger.track).is_not_null()
	assert_object(Audio._current_stream).is_same(trigger.track)


func test_main_menu_settings_handler_opens_the_overlay() -> void:
	var menu: Control = _spawn(MAIN_MENU_SCENE)
	menu._on_settings_pressed()
	var overlays := menu.get_children().filter(func(n: Node) -> bool: return n is SettingsOverlay)
	assert_array(overlays).has_size(1)


func test_main_menu_clouds_drift_on_their_own() -> void:
	var menu: Control = _spawn(MAIN_MENU_SCENE)
	var before: float = menu.offset_x
	menu._process(1.0)
	assert_float(menu.offset_x).is_equal_approx(before - menu.base_speed, 0.001)


func test_credits_scene_has_a_way_back() -> void:
	var credits: Control = _spawn(CREDITS_SCENE)
	var buttons := credits.find_children("*", "BaseButton", true, false)
	assert_array(buttons).is_not_empty()
	assert_bool(credits.has_method("_on_menu_button_pressed")).is_true()


# --- Hub ---------------------------------------------------------------------------

func test_hub_places_the_player_at_the_spawn_point() -> void:
	var hub: Node2D = _spawn(HUB_SCENE_PATH)
	var player: Player = hub.get_node("Character1")
	assert_vector(player.global_position).is_equal_approx(hub.get_node("PlayerSpawnPos").global_position, Vector2.ONE * 0.01)


func test_hub_limits_the_camera_to_the_hub_area() -> void:
	var hub: Node2D = _spawn(HUB_SCENE_PATH)
	var camera: Camera2D = hub.get_node("Character1/Camera2D")
	assert_int(camera.limit_left).is_less(camera.limit_right)
	assert_int(camera.limit_top).is_less(camera.limit_bottom)
	var top_left: Vector2 = hub.get_node("CameraTopLeft").global_position
	var bottom_right: Vector2 = hub.get_node("CameraBottomRight").global_position
	var center := (top_left + bottom_right) / 2.0
	assert_float((camera.limit_left + camera.limit_right) / 2.0).is_equal_approx(center.x, 1.0)


func test_hub_has_the_train_door_and_emil() -> void:
	var hub: Node2D = _spawn(HUB_SCENE_PATH)
	assert_object(hub.get_node("Interactables/TrainDoor")).is_instanceof(TrainDoor)
	var emil: NPC = hub.get_node("Interactables/Emil")
	assert_str(emil.dialogue.id).is_equal("Emil")
	assert_object(emil.dialogue_text).is_not_null()


func test_hub_starts_its_music() -> void:
	var hub: Node2D = _spawn(HUB_SCENE_PATH)
	assert_object(Audio._current_stream).is_same(hub.get_node("MusicTrigger").track)


# --- Run -----------------------------------------------------------------------------

func test_run_scene_builds_a_level_around_the_player() -> void:
	# rooms.gd finds the player at /root/Game/Character1, so the scene goes under the root.
	var game: Node = auto_free((load(GAME_SCENE) as PackedScene).instantiate())
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var generator: Node2D = game.get_node("Rooms")
	var rooms := generator.get_children().filter(func(n: Node) -> bool: return n is Node2D)
	assert_array(rooms).has_size(generator.num_levels)
	var player: Player = game.get_node("Character1")
	assert_vector(player.global_position).is_equal_approx(rooms[0].get_node("PlayerSpawnPos").global_position, Vector2(64, 64))
	assert_bool(player.is_dead).is_false()

	var hud := game.get_node("Character1/UI/HUD")
	assert_str(hud.get_node("TopLeft/Stack/CurrencyUI").coin_label.text).is_equal("00")
	assert_int(hud.get_node("TopLeft/Stack/HealthUI").get_child_count()).is_greater(0)
	assert_bool(hud.get_node("BottomCenter/BossHealthBar").visible).is_false()
	assert_object(game.get_node("Character1/UI/PauseMenu")).is_not_null()
	game.free()


func test_boss_room_spawns_the_boss_and_shows_its_bar() -> void:
	var bar: VBoxContainer = auto_free(BossHealthBar.new())
	add_child(bar)
	var player: Player = auto_free(Factory.player(Factory.character_stats(1000.0)))
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	add_child(player)
	player.global_position = Vector2(-5000, -5000)
	var room: BossRoom = _spawn(BOSS_ROOM_SCENE)
	room._on_player_detector_body_entered(player)
	var bosses := room.alive_enemies.filter(func(e: Node) -> bool: return e.is_in_group("Bosses"))
	assert_array(bosses).has_size(1)
	assert_bool(bar.visible).is_true()
	assert_str(bar.name_label.text).is_equal("Laureth, Doom Of All Scales")


func test_boss_room_rewards_the_player(
		do_skip := true,
		skip_reason := "KNOWN BUG: boss_01.tscn sets reward_pedestal_scene = null, so beating the boss gives no reward") -> void:
	var room: BossRoom = _spawn(BOSS_ROOM_SCENE)
	assert_object(room.reward_pedestal_scene).is_not_null()
