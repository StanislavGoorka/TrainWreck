class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)
signal health_changed(current: float, max_value: float)

@export var stats: EnemyStats
@export var sprite_faces_left: bool = true

var health: float
var is_dead: bool = false
var target: Node2D = null

# Driven by StatusComponent. States read the two multipliers.
var status: StatusComponent
var speed_mult: float = 1.0
var attack_speed_mult: float = 1.0
var is_frozen: bool = false

func _ready() -> void:
	status = get_node_or_null("StatusComponent") as StatusComponent
	if not status:
		status = StatusComponent.new()
		status.name = "StatusComponent"
		add_child(status)
	status.enemy = self

	if not stats:
		push_error("%s has no EnemyStats assigned!" % name)
		return
	health = stats.max_health
	health_changed.emit(health, stats.max_health)

func take_damage(amount: float, from_status: bool = false) -> void:
	if is_dead:
		return
	if not from_status:
		amount *= status.consume_bleed()   # bleed only affects direct hits, not burn or poison ticks
	health -= amount
	health_changed.emit(maxf(health, 0.0), stats.max_health)
	if health <= 0:
		is_dead = true
		status.clear_all()   # also thaws, so the death animation can play
		died.emit(self)
		$StateMachine.transition_to(&"Dead")

func take_status_damage(amount: float) -> void:
	take_damage(amount, true)

func apply_statuses(statuses: Dictionary) -> void:
	if is_dead:
		return
	for type in statuses:
		status.apply(type, statuses[type])

func is_immune_to(type: int) -> bool:
	return stats != null and (stats.status_immunities & (1 << (type - 1))) != 0

# Frozen solid: the AI stops and the animation holds. The body stays in physics,
# so bullets still hit it.
func set_frozen(value: bool) -> void:
	is_frozen = value
	velocity = Vector2.ZERO
	for node_name in ["StateMachine", "EnemyAim"]:
		var node := get_node_or_null(node_name)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		if value:
			sprite.pause()
		else:
			sprite.play()

func play_anim(anim_name: StringName) -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func face_direction(dir_x: float) -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and absf(dir_x) > 0.1:
		var moving_right := dir_x > 0.0
		sprite.flip_h = moving_right if sprite_faces_left else not moving_right
