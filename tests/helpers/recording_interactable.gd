## An Interactable that records interactions and can be switched off.
extends Interactable

var interactions: Array[Player] = []
var enabled := true


func can_interact() -> bool:
	return enabled


func interact(player: Player) -> void:
	interactions.append(player)
