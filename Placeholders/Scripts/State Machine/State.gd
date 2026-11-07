class_name State
extends Node

signal transition_requested(state_name: StringName)

var actor: Node  # set by the StateMachine on _ready

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
