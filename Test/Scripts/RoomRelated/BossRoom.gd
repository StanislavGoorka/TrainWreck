class_name BossRoom
extends Room

@export var reward_pedestal_scene: PackedScene
@export var reward_spawn_delay: float = 0.8   # lets the death animation finish first

var last_enemy_position := Vector2.ZERO

func _on_enemies_spawned(enemies: Array) -> void:
	var bar := get_tree().get_first_node_in_group("BossHealthBar")
	if not bar:
		push_warning("No BossHealthBar found in the UI.")
		return
	for enemy in enemies:
		if enemy.is_in_group("Bosses"):
			bar.show_for(enemy)
			break

func _on_enemy_died(enemy) -> void:
	last_enemy_position = enemy.global_position
	super(enemy)

func _on_room_cleared() -> void:
	_spawn_reward()

func _spawn_reward() -> void:
	if not reward_pedestal_scene:
		push_warning("BossRoom has no reward_pedestal_scene assigned.")
		return
	await get_tree().create_timer(reward_spawn_delay).timeout
	if not is_inside_tree():
		return

	var pedestal := reward_pedestal_scene.instantiate()
	pedestal.draw_from_pools = ItemData.POOL_BOSS   # set before add_child so _ready sees it
	add_child(pedestal)

	var spot := get_node_or_null("RewardSpawnPos") as Node2D
	pedestal.global_position = spot.global_position if spot else last_enemy_position
