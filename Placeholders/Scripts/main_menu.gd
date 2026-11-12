extends Control

@export var base_speed: float = 30.0
@export var far_speed: float = 100.0
@export var mid_speed: float = 0.5
var offset_x: float = 50.0

func _ready() -> void:
	var settings_button := find_child("Settings", true, false) as BaseButton
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	else:
		push_warning("Settings button not found in the main menu.")

func _on_settings_pressed() -> void:
	add_child(SettingsOverlay.new())

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

func _on_start_pressed() -> void:
	GameState.go_to_hub()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_credits_pressed() -> void:
	GameState.go_to_credits()
