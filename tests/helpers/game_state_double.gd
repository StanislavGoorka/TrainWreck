## The real game_state.gd with two seams for tests:
## - characters come from [member injected_characters] instead of the characters folder,
## - go_to_hub() is recorded instead of changing the scene (a scene change would
##   replace the test runner).
extends "res://Test/Scripts/Miscellaneous/game_state.gd"

var injected_characters: Dictionary = {}
var hub_requests := 0


func _load_characters() -> void:
	characters = injected_characters.duplicate()


func go_to_hub() -> void:
	hub_requests += 1
	game_over = false
	run_active = false
	get_tree().paused = false
