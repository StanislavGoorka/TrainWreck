extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - global_position
	var max_rad = deg_to_rad(30)
	var facing_right = to_mouse.x >= 1
	var base_angle = 0.0 if facing_right else PI
	
	$".".flip_v = not facing_right
	var delta_angle = wrapf(to_mouse.angle() - base_angle, -PI, PI)
	delta_angle = clampf(delta_angle, -max_rad, max_rad)
	rotation = base_angle + delta_angle
