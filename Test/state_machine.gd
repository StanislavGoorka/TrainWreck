class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

# StateMachine.gd — only the property name changes
func _ready() -> void:
	var actor_ref := get_parent()
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.actor = actor_ref
			child.transition_requested.connect(transition_to)

	current_state = initial_state if initial_state else get_children()[0]
	current_state.enter()

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if get_parent().get("is_frozen"):
		return
	if not states.has(state_name):
		push_warning("State machine has no state named %s" % state_name)
		return
	if state_name == current_state.name:
		return
	current_state.exit()
	current_state = states[state_name]
	current_state.enter(msg)
