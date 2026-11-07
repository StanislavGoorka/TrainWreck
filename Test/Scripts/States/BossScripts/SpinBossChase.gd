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
	var to_target: Vector2 = target.global_position - actor.global_position
	actor.velocity = to_target.normalized() * s.speed
	actor.move_and_slide()
	actor.face_direction(to_target.x)

	cooldown_left -= delta
	if cooldown_left <= 0.0 and to_target.length() <= s.spin_trigger_range:
		transition_requested.emit(&"SpinAttack")
