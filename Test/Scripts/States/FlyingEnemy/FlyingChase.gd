extends State

@export var acceleration: float = 500.0   # lower = more ice-like sliding
@export var animation: StringName = &"Fly"

func enter(_msg := {}) -> void:
	actor.get_node("AnimatedSprite2D").play(animation)

func physics_update(delta: float) -> void:
	var target: Node2D = actor.target
	if not is_instance_valid(target):
		transition_requested.emit(&"Idle")
		return

	# Steer toward the target instead of snapping to full speed. After
	# overshooting, the enemy has to brake and turn, so it slides past.
	var desired: Vector2 = (target.global_position - actor.global_position).normalized() * actor.stats.speed
	actor.velocity = actor.velocity.move_toward(desired, acceleration * delta)
	actor.move_and_slide()

	if absf(actor.velocity.x) > 5.0:
		actor.face_direction(actor.velocity.x)
