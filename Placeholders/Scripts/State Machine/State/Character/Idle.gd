extends PlayerState

@export var slide_time: float = 0.1   # seconds to come to a stop from full speed

func enter(_msg := {}) -> void:
	# No longer zeroing velocity here, so leftover momentum becomes the slide.
	player.get_node("Body").play("Idle")
	player.get_node("Head").play("Idle")

func physics_update(delta: float) -> void:
	if Input.is_action_just_pressed("Dash") and player.can_dash():
		transition_requested.emit(&"Dash", {"direction": player.last_move_direction})
		return

	var direction := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	if direction != Vector2.ZERO:
		transition_requested.emit(&"Move")
		return

	var friction: float = player.current_stats.speed / slide_time
	player.velocity = player.velocity.move_toward(Vector2.ZERO, friction * delta)
	player.move_and_slide()
