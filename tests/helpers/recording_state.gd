## A State that records every call the StateMachine makes on it.
extends State

var entered: Array[Dictionary] = []
var exit_count := 0
var updates: Array[float] = []
var inputs: Array[InputEvent] = []


func enter(msg: Dictionary = {}) -> void:
	entered.append(msg)


func exit() -> void:
	exit_count += 1


func physics_update(delta: float) -> void:
	updates.append(delta)


func handle_input(event: InputEvent) -> void:
	inputs.append(event)
