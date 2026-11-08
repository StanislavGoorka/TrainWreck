class_name Portal
extends Interactable

var used := false

func can_interact() -> bool:
	return not used

func interact(_player: Player) -> void:
	used = true             # stops a second press during the fade
	refresh_prompt()
	GameState.advance_floor()
