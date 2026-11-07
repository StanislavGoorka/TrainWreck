extends ParallaxBackground

# Base speed multiplier (everything scales from this)
@export var base_speed: float = 50.0

# Independent speed multipliers per layer (you can tweak in Inspector)
@export var far_speed: float = 0.0
@export var mid_speed: float = 0.5
@export var near_speed: float = 0.8
@export var mountains_speed: float = 1.0

# Internal offset tracking
var offset_x: float = 0.0

func _process(delta: float) -> void:
	# Increment global offset (moves continuously, even if player is still)
	offset_x -= base_speed * delta
	
	# Apply custom offsets for each layer
	for layer in get_children():
		if layer is ParallaxLayer:
			match layer.name:
				"CloudsFar":
					layer.motion_offset.x = offset_x * far_speed
				"CloudsMid":
					layer.motion_offset.x = offset_x * mid_speed
				"CloudsNear":
					layer.motion_offset.x = offset_x * near_speed
				"Mountains":
					layer.motion_offset.x = offset_x * mountains_speed
