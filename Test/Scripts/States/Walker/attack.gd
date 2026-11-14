extends State

var cooldown_timer: float = 0.0
var hitbox: Area2D
var anim: AnimatedSprite2D

func enter(_msg := {}) -> void:
	if not hitbox:
		hitbox = actor.get_node("AttackHitbox")
		anim = actor.get_node("AnimatedSprite2D")
	actor.velocity = Vector2.ZERO
	_swing()

func physics_update(delta: float) -> void:
	if not is_instance_valid(actor.target):
		transition_requested.emit(&"Idle")
		return

	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		if _player_in_range():
			_swing()
		else:
			transition_requested.emit(&"Chase")

func _player_in_range() -> bool:
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("Players"):
			return true
	return false

func _swing() -> void:
	cooldown_timer = actor.stats.attack_cooldown
	anim.play("Attack")
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("Players") and body.has_method("take_damage"):
			body.take_damage(actor.stats.damage)
