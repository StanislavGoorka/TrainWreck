extends Area2D

const ITEM_RESOURCE_FOLDER := "res://Test/Scripts/Resource/ItemResource/"

const RARITY_WEIGHTS := {
	ItemData.Rarity.COMMON: 0.30,
	ItemData.Rarity.UNCOMMON: 0.25,
	ItemData.Rarity.RARE: 0.20,
	ItemData.Rarity.EPIC: 0.15,
	ItemData.Rarity.LEGENDARY: 0.10,
}

@export var item_data: ItemData   # optional manual override — leave empty for random pool pick

@onready var item_sprite: Sprite2D = $ItemSprite2D

@export_flags("Item Room", "Boss") var draw_from_pools: int = 1

func _ready() -> void:
	if not item_data:
		item_data = _pick_random_item()

	if item_data:
		item_sprite.texture = item_data.get_icon()   # ← changed from item_data.icon
	body_entered.connect(_on_body_entered)

func _pick_random_item() -> ItemData:
	var pool := _load_eligible_items()
	
	if pool.is_empty():
		push_warning("No eligible items found in " + ITEM_RESOURCE_FOLDER)
		return null

	# Group eligible items by rarity tier.
	var by_rarity: Dictionary = {}
	for item in pool:
		if not by_rarity.has(item.rarity):
			by_rarity[item.rarity] = []
		by_rarity[item.rarity].append(item)

	# Only tiers that actually have at least one eligible item count toward
	# the roll — their weights get renormalized so odds still sum to 100%.
	var total_weight := 0.0
	for rarity in by_rarity.keys():
		total_weight += RARITY_WEIGHTS.get(rarity, 0.0)

	if total_weight <= 0.0:
		# Fallback: no known weights matched, just pick uniformly from the pool.
		return pool[randi() % pool.size()]

	var roll := randf() * total_weight
	var cumulative := 0.0
	for rarity in by_rarity.keys():
		cumulative += RARITY_WEIGHTS.get(rarity, 0.0)
		if roll <= cumulative:
			var tier_items: Array = by_rarity[rarity]
			return tier_items[randi() % tier_items.size()]

	# Shouldn't be reached, but just in case of float rounding at the edge.
	return pool[randi() % pool.size()]

func _load_eligible_items() -> Array[ItemData]:
	var pool: Array[ItemData] = []
	var player := get_tree().get_first_node_in_group("Players") as Player
	var owned_names: Array[String] = []
	if player:
		for owned in player.inventory:
			owned_names.append(owned.item_name)

	for path in ResourceFolder.list(ITEM_RESOURCE_FOLDER, "tres"):
		var item := load(path) as ItemData
		if item and not owned_names.has(item.item_name) and (item.pools & draw_from_pools) != 0:
			pool.append(item)
	return pool

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Players"):
		return
	if not item_data:
		return
	if body.has_method("add_item"):
		body.add_item(item_data)
	queue_free()
