extends "res://tests/helpers/tw_test_suite.gd"

const RecordingState := preload("res://tests/helpers/recording_state.gd")


## Builds actor -> StateMachine -> states. Returns the machine, already in the tree.
func _machine(state_names: Array, initial := "", extra_children: Array[Node] = []) -> StateMachine:
	var actor: Node2D = auto_free(Node2D.new())
	actor.name = "Actor"
	var machine := StateMachine.new()
	machine.name = "StateMachine"
	actor.add_child(machine)
	for child in extra_children:
		machine.add_child(child)
	for state_name: String in state_names:
		var state: State = RecordingState.new()
		state.name = state_name
		machine.add_child(state)
	if initial != "":
		machine.initial_state = machine.get_node(initial)
	add_child(actor)
	return machine


func test_registers_state_children_and_gives_them_the_actor() -> void:
	var machine := _machine(["Idle", "Chase"])
	assert_array(machine.states.keys()).contains_exactly_in_any_order(&"Idle", &"Chase")
	for state: State in machine.states.values():
		assert_object(state.actor).is_same(machine.get_parent())


func test_non_state_children_are_ignored() -> void:
	var helper := Timer.new()
	helper.name = "Helper"
	var machine := _machine(["Idle"], "Idle", [helper])
	assert_array(machine.states.keys()).contains_exactly(&"Idle")


func test_first_child_is_the_initial_state_by_default() -> void:
	var machine := _machine(["Idle", "Chase"])
	assert_str(String(machine.current_state.name)).is_equal("Idle")
	assert_array(machine.current_state.entered).has_size(1)


func test_initial_state_export_wins() -> void:
	var machine := _machine(["Idle", "Chase"], "Chase")
	assert_str(String(machine.current_state.name)).is_equal("Chase")
	assert_array(machine.get_node("Idle").entered).is_empty()


func test_transition_exits_the_old_state_and_enters_the_new_one_with_a_message() -> void:
	var machine := _machine(["Idle", "Chase"])
	var idle: RecordingState = machine.get_node("Idle")
	var chase: RecordingState = machine.get_node("Chase")
	machine.transition_to(&"Chase", {"reason": "test"})
	assert_object(machine.current_state).is_same(chase)
	assert_int(idle.exit_count).is_equal(1)
	assert_array(chase.entered).is_equal([{"reason": "test"}])


func test_transition_to_the_current_state_does_nothing() -> void:
	var machine := _machine(["Idle", "Chase"])
	var idle: RecordingState = machine.get_node("Idle")
	machine.transition_to(&"Idle")
	assert_int(idle.exit_count).is_zero()
	assert_array(idle.entered).has_size(1)


func test_transition_to_an_unknown_state_is_ignored() -> void:
	var machine := _machine(["Idle"])
	machine.transition_to(&"DoesNotExist")
	assert_str(String(machine.current_state.name)).is_equal("Idle")


func test_frozen_actor_cannot_change_state() -> void:
	# StateMachine reads the parent's "is_frozen" property, which Enemy provides.
	var enemy: Enemy = auto_free(Factory.enemy())
	add_child(enemy)
	var machine: StateMachine = enemy.get_node("StateMachine")
	enemy.is_frozen = true
	machine.transition_to(&"Dead")
	assert_str(String(machine.current_state.name)).is_equal("Idle")
	enemy.is_frozen = false
	machine.transition_to(&"Dead")
	assert_str(String(machine.current_state.name)).is_equal("Dead")


func test_states_can_request_transitions_through_their_signal() -> void:
	var machine := _machine(["Idle", "Chase"])
	machine.get_node("Idle").transition_requested.emit(&"Chase")
	assert_str(String(machine.current_state.name)).is_equal("Chase")


func test_physics_frames_are_forwarded_to_the_current_state() -> void:
	var machine := _machine(["Idle", "Chase"])
	machine._physics_process(0.25)
	assert_array(machine.get_node("Idle").updates).is_equal([0.25])
	assert_array(machine.get_node("Chase").updates).is_empty()


func test_unhandled_input_is_forwarded_to_the_current_state() -> void:
	var machine := _machine(["Idle"])
	var event := InputEventAction.new()
	event.action = &"Dash"
	event.pressed = true
	machine._unhandled_input(event)
	assert_array(machine.get_node("Idle").inputs).contains_exactly(event)


func test_base_state_methods_are_safe_no_ops() -> void:
	var state: State = auto_free(State.new())
	state.enter({})
	state.exit()
	state.physics_update(0.1)
	state.handle_input(InputEventAction.new())
	assert_object(state.actor).is_null()
