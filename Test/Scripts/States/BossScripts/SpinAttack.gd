extends State

enum Phase { WINDUP, SPIN, RECOVER }

@export var fallback_turns: int = 2   # sprite rotations if there is no "spin" animation

var phase: Phase = Phase.WINDUP
var phase_time := 0.0
var hit_landed := false
var hitbox: Area2D
var flash_tween: Tween
var spin_tween: Tween

func enter(_msg := {}) -> void:
	if not hitbox:
		hitbox = actor.get_node("SpinHitbox")
	hitbox.monitoring = false
	phase = Phase.WINDUP
	phase_time = 0.0
	hit_landed = false
	actor.velocity = Vector2.ZERO
	actor.play_anim(&"idle")

	# Red blink as the telegraph.
	var s := actor.stats as SpinBossStats
	var sprite := _sprite()
	flash_tween = create_tween().set_loops()
	flash_tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3), s.spin_windup * 0.25)
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, s.spin_windup * 0.25)

func exit() -> void:
	_stop_flash()
	_stop_spin_visual()
	if hitbox:
		hitbox.monitoring = false

func physics_update(delta: float) -> void:
	var s := actor.stats as SpinBossStats
	phase_time += delta

	match phase:
		Phase.WINDUP:
			if phase_time >= s.spin_windup:
				_start_spin(s)
		Phase.SPIN:
			_move_toward_target(s.speed * s.spin_move_speed_mult)
			_check_hit(s)
			if phase_time >= s.spin_duration:
				_start_recover()
		Phase.RECOVER:
			actor.velocity = Vector2.ZERO
			if phase_time >= s.spin_recovery:
				transition_requested.emit(&"Chase")

func _start_spin(s: SpinBossStats) -> void:
	phase = Phase.SPIN
	phase_time = 0.0
	_stop_flash()
	hitbox.monitoring = true

	var sprite := _sprite()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"spin"):
		sprite.play(&"spin")
	else:
		# Placeholder spin until the real animation exists.
		spin_tween = create_tween()
		spin_tween.tween_property(sprite, "rotation", TAU * fallback_turns, s.spin_duration)

func _start_recover() -> void:
	phase = Phase.RECOVER
	phase_time = 0.0
	hitbox.monitoring = false
	_stop_spin_visual()
	actor.play_anim(&"idle")

func _move_toward_target(move_speed: float) -> void:
	var target: Node2D = actor.target
	if is_instance_valid(target):
		var dir: Vector2 = (target.global_position - actor.global_position).normalized()
		actor.velocity = dir * move_speed
	else:
		actor.velocity = Vector2.ZERO
	actor.move_and_slide()

func _check_hit(s: SpinBossStats) -> void:
	if hit_landed:
		return
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("Players") and body.has_method("take_damage"):
			body.take_damage(s.spin_damage)
			hit_landed = true   # one hit per spin
			return

func _stop_flash() -> void:
	if flash_tween:
		flash_tween.kill()
		flash_tween = null
	_sprite().modulate = Color.WHITE

func _stop_spin_visual() -> void:
	if spin_tween:
		spin_tween.kill()
		spin_tween = null
	_sprite().rotation = 0.0

func _sprite() -> AnimatedSprite2D:
	return actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
