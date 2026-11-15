extends State

@export var acceleration: float = 500.0   # lower = more ice-like sliding
@export var animation: StringName = &"Fly"

func enter(_msg := {}) -> void:
	print("[Chase] ", actor.name, " entered Chase, has get_chase_direction: ", actor.has_method("get_chase_direction"))
	actor.get_node("AnimatedSprite2D").play(animation)

func physics_update(delta: float) -> void:
	var target: Node2D = actor.target
	if not is_instance_valid(target):
		transition_requested.emit(&"Idle")
		return

	# Steer toward the way around, instead of snapping to full speed, so it still slides like on ice.
	var dir: Vector2 = actor.get_chase_direction(target.global_position, delta)
	var desired: Vector2 = dir * actor.stats.speed * actor.speed_mult
	actor.velocity = actor.velocity.move_toward(desired, acceleration * delta)
	actor.move_and_slide()

	if absf(actor.velocity.x) > 5.0:
		actor.face_direction(actor.velocity.x)
