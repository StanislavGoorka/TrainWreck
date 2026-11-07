extends Area2D

@export var recoil_distance: float = 6.0    # pixels the gun kicks back
@export var recoil_out_time: float = 0.03   # seconds to kick back
@export var recoil_return_time: float = 0.07   # seconds to settle (about 4 frames at 60 FPS)

@onready var pivot: Node2D = $WeaponPivot

var rest_position: Vector2
var recoil_tween: Tween

func _ready() -> void:
	# Saved once, never from a mid-recoil position, so it can't drift.
	rest_position = pivot.position

func _physics_process(_delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var to_mouse := mouse_pos - global_position
	var max_rad := deg_to_rad(90)
	var facing_right := to_mouse.x >= 0
	var base_angle := 0.0 if facing_right else PI

	%Arrow.flip_v = not facing_right
	%Arrow.flip_h = true
	var delta_angle := clampf(wrapf(to_mouse.angle() - base_angle, -PI, PI), -max_rad, max_rad)
	rotation = base_angle + delta_angle

func recoil() -> void:
	if recoil_tween:
		recoil_tween.kill()
	pivot.position = rest_position

	recoil_tween = create_tween()
	recoil_tween.tween_property(pivot, "position", rest_position + Vector2(-recoil_distance, 0), recoil_out_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recoil_tween.tween_property(pivot, "position", rest_position, recoil_return_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
