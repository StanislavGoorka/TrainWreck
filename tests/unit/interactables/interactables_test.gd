## Interactable (base), NPC (dialogue), CharacterStation and TrainDoor.
extends "res://tests/helpers/tw_test_suite.gd"

const RecordingInteractable := preload("res://tests/helpers/recording_interactable.gd")

var player: Player


func before_test() -> void:
	super.before_test()
	player = auto_free(Factory.player())
	add_child(player)


func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"Interact"
	event.pressed = true
	return event


# --- Interactable ------------------------------------------------------------------

func _interactable() -> Interactable:
	var thing: Interactable = auto_free(RecordingInteractable.new())
	thing.prompt_text = "Use"
	thing.add_child(Factory.circle_shape(32.0))
	add_child(thing)
	return thing


func test_interactable_only_detects_the_player_layer() -> void:
	var thing := _interactable()
	assert_int(thing.collision_layer).is_zero()
	assert_int(thing.collision_mask).is_equal(1 << 1)


func test_interactable_creates_its_prompt() -> void:
	var thing := _interactable()
	assert_object(thing.prompt).is_not_null()
	assert_object(thing.prompt.get_parent()).is_same(thing)
	assert_str(thing.prompt.label.text).contains("Use")
	assert_bool(thing.prompt.visible).is_false()


func test_player_walking_in_shows_the_prompt() -> void:
	var thing := _interactable()
	thing._on_body_entered(player)
	assert_object(thing.player_inside).is_same(player)
	assert_bool(thing.prompt.visible).is_true()


func test_other_bodies_are_ignored() -> void:
	var thing := _interactable()
	thing._on_body_entered(auto_free(CharacterBody2D.new()))
	assert_object(thing.player_inside).is_null()
	assert_bool(thing.prompt.visible).is_false()


func test_player_walking_out_hides_the_prompt() -> void:
	var thing := _interactable()
	thing._on_body_entered(player)
	thing._on_body_exited(player)
	assert_object(thing.player_inside).is_null()
	thing.prompt.tween.custom_step(1.0)
	assert_bool(thing.prompt.visible).is_false()


func test_overlap_is_detected_by_physics() -> void:
	var thing := _interactable()
	player.global_position = thing.global_position
	await wait_physics_frames(3)
	assert_object(thing.player_inside).is_same(player)


func test_interact_key_triggers_the_interaction() -> void:
	var thing := _interactable()
	thing._on_body_entered(player)
	thing._unhandled_input(_interact_event())
	assert_array(thing.interactions).contains_exactly(player)


func test_interact_key_does_nothing_when_nobody_is_inside() -> void:
	var thing := _interactable()
	thing._unhandled_input(_interact_event())
	assert_array(thing.interactions).is_empty()


func test_disabled_interactable_hides_its_prompt_and_ignores_the_key() -> void:
	var thing := _interactable()
	thing.enabled = false
	thing._on_body_entered(player)
	assert_bool(thing.prompt.visible).is_false()
	thing._unhandled_input(_interact_event())
	assert_array(thing.interactions).is_empty()


func test_base_interactable_is_always_usable() -> void:
	var base: Interactable = auto_free(Interactable.new())
	add_child(base)
	assert_bool(base.can_interact()).is_true()
	base.interact(player)   # no-op


# --- NPC ---------------------------------------------------------------------------

func _npc(lines: Array[String] = ["Hello", "Again?", "Go away"], dialogue_id := "TestNpc", persist := false) -> NPC:
	var npc: NPC = auto_free(NPC.new())
	npc.npc_name = "Bob"
	npc.persist_progress = persist
	if not lines.is_empty():
		var dialogue := DialogueData.new()
		dialogue.id = dialogue_id
		dialogue.lines = lines
		npc.dialogue = dialogue
	add_child(npc)
	return npc


func test_npc_owns_a_speech_label() -> void:
	var npc := _npc()
	assert_object(npc.dialogue_text).is_not_null()
	assert_object(npc.dialogue_text.get_parent()).is_same(npc)
	assert_vector(npc.dialogue_text.anchor).is_equal(npc.text_offset)


func test_npc_says_its_lines_in_order_then_repeats_the_last() -> void:
	var npc := _npc()
	assert_array([npc._next_line(), npc._next_line(), npc._next_line(), npc._next_line()]) \
		.is_equal(["Hello", "Again?", "Go away", "Go away"])


func test_npc_without_dialogue_mumbles() -> void:
	var lines: Array[String] = []
	var npc := _npc(lines)
	assert_str(npc._next_line()).is_equal("...")


func test_npc_progress_is_saved_in_game_state_when_persistent() -> void:
	GameState.dialogue_progress = {}
	var npc := _npc(["A", "B"], "Emil", true)
	npc._next_line()
	assert_int(int(GameState.dialogue_progress["Emil"])).is_equal(1)
	var again := _npc(["A", "B"], "Emil", true)
	assert_str(again._next_line()).is_equal("B")


func test_npc_progress_stays_local_when_not_persistent() -> void:
	GameState.dialogue_progress = {}
	var npc := _npc(["A", "B"], "Local", false)
	npc._next_line()
	assert_bool(GameState.dialogue_progress.has("Local")).is_false()
	assert_int(int(npc.local_store["Local"])).is_equal(1)


func test_npc_falls_back_to_its_name_as_the_progress_key() -> void:
	var npc := _npc(["A", "B"], "", false)
	npc._next_line()
	assert_bool(npc.local_store.has("Bob")).is_true()


func test_npc_progress_counter_stops_at_the_last_line() -> void:
	var npc := _npc(["A", "B"])
	for i in 5:
		npc._next_line()
	assert_int(int(npc.local_store["TestNpc"])).is_equal(2)


func test_talking_shows_the_line_and_hides_the_prompt() -> void:
	var npc := _npc()
	npc._on_body_entered(player)
	npc._unhandled_input(_interact_event())
	assert_bool(npc.talking).is_true()
	assert_bool(npc.can_interact()).is_false()
	assert_str(npc.dialogue_text.text).is_equal("Hello")
	assert_bool(npc.dialogue_text.is_typing()).is_true()


func test_interact_while_typing_skips_then_closes() -> void:
	var npc := _npc()
	npc._on_body_entered(player)
	npc.interact(player)
	npc._unhandled_input(_interact_event())
	assert_bool(npc.dialogue_text.is_typing()).is_false()
	assert_bool(npc.talking).is_true()
	npc._unhandled_input(_interact_event())
	npc.dialogue_text.fade_tween.custom_step(npc.dialogue_text.fade_time + 0.01)
	assert_bool(npc.talking).is_false()
	assert_bool(npc.can_interact()).is_true()


func test_second_interaction_while_talking_is_ignored() -> void:
	var npc := _npc()
	npc.interact(player)
	npc.interact(player)
	assert_str(npc.dialogue_text.text).is_equal("Hello")
	assert_int(int(npc.local_store["TestNpc"])).is_equal(1)


func test_walking_away_ends_the_conversation() -> void:
	var npc := _npc()
	npc._on_body_entered(player)
	npc.interact(player)
	npc._on_body_exited(player)
	npc.dialogue_text.fade_tween.custom_step(npc.dialogue_text.fade_time + 0.01)
	assert_bool(npc.talking).is_false()


# --- CharacterStation --------------------------------------------------------------

func test_character_station_opens_the_menu_and_freezes_the_player() -> void:
	var world: Node2D = auto_free(Node2D.new())
	use_as_current_scene(world)
	GameState.characters = {"slinger": Factory.character_definition("slinger")}
	var station: CharacterStation = auto_free(CharacterStation.new())
	add_child(station)
	assert_bool(station.can_interact()).is_true()

	station.interact(player)

	assert_object(station.menu).is_not_null()
	assert_object(station.menu.get_parent()).is_same(world)
	assert_object(station.menu.player).is_same(player)
	assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_bool(station.can_interact()).is_false()


func test_closing_the_station_menu_unfreezes_the_player() -> void:
	var world: Node2D = auto_free(Node2D.new())
	use_as_current_scene(world)
	var station: CharacterStation = auto_free(CharacterStation.new())
	add_child(station)
	station.interact(player)
	station.menu.close()
	assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_object(station.menu).is_null()
	assert_bool(station.can_interact()).is_true()


# --- TrainDoor ---------------------------------------------------------------------

func test_train_door_is_an_interactable_that_starts_a_run() -> void:
	var door: TrainDoor = auto_free(TrainDoor.new())
	assert_object(door).is_instanceof(Interactable)
	assert_bool(door.has_method("interact")).is_true()
	# interact() itself changes the scene, which would replace the test runner.
