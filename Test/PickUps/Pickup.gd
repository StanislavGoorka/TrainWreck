extends Area2D

@export var pickup_data: PickupData

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if pickup_data:
		sprite.texture = pickup_data.icon
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Players") or not pickup_data:
		return
	if body.has_method("add_pickup"):
		body.add_pickup(pickup_data)
	queue_free()
