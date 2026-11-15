extends State

var cooldown_left := 0.0

func enter(_msg := {}) -> void:
	var s := actor.stats as SpinBossStats
	cooldown_left = s.spin_cooldown
	actor.play_anim(&"run")

func physics_update(delta: float) -> void:
	var target: Node2D = actor.target
	if not is_instance_valid(target):
		transition_requested.emit(&"Idle")
		return

	var s := actor.stats as SpinBossStats
	var dir: Vector2 = actor.get_chase_direction(target.global_position, delta)
	actor.velocity = dir * s.speed * actor.speed_mult
	actor.move_and_slide()
	actor.face_direction(dir.x)

	cooldown_left -= delta
	var distance: float = actor.global_position.distance_to(target.global_position)
	if cooldown_left <= 0.0 and distance <= s.spin_trigger_range and actor.can_see(target.global_position):
		transition_requested.emit(&"SpinAttack")
