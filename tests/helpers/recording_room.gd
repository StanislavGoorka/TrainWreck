## A Room that counts calls to its hook methods.
extends Room

var spawned_calls: Array[Array] = []
var cleared_calls := 0


func _on_enemies_spawned(enemies: Array) -> void:
	spawned_calls.append(enemies.duplicate())


func _on_room_cleared() -> void:
	cleared_calls += 1
