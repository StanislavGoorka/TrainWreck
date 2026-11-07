extends CharacterBody2D

var statuses: Dictionary = {}

@export var damage: float = 1.0
@export var speed: float = 800.0
@export var lifetime: float = 3.0

@export var status_scale: float = 1.3

func _ready() -> void:
	velocity = Vector2.RIGHT.rotated(rotation) * speed
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	if not statuses.is_empty():
		_apply_status_visual()

func _apply_status_visual() -> void:
	var color := StatusEffect.bullet_color(statuses)

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.self_modulate = color
		sprite.scale *= status_scale

	# Trail of small squares in the effect's color.
	var trail := CPUParticles2D.new()
	trail.amount = 14
	trail.lifetime = 0.25
	trail.local_coords = false          # particles stay where they were emitted
	trail.spread = 180.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 25.0
	trail.scale_amount_min = 1.5
	trail.scale_amount_max = 3.0
	trail.color = color
	add_child(trail)

func _physics_process(_delta: float) -> void:
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		_on_hit(collision.get_collider())
		break



func _on_hit(collider: Node) -> void:
	if collider.is_in_group("Enemies") and collider.has_method("take_damage"):
		collider.take_damage(damage)
		if not statuses.is_empty() and collider.has_method("apply_statuses"):
			collider.apply_statuses(statuses)   # applied after the damage, so Bleed counts on the next hit
	queue_free()
