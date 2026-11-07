class_name MainSpread
extends BookSpread

@onready var summary: Label = %Summary

func opened() -> void:
	var player := get_tree().get_first_node_in_group("Players") as Player
	if not player:
		summary.text = ""
		return
	summary.text = "Coins: %d\nKeys: %d\nBombs: %d\nItems: %d" % [
		player.currency, player.keys, player.bombs, player.inventory.size()
	]
