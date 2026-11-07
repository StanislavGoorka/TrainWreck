extends PlayerState

func physics_update(_delta: float) -> void:
	var direction := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")

	if direction == Vector2.ZERO:
		transition_requested.emit(&"Idle")
		return
	if Input.is_action_just_pressed("Dash") and player.can_dash():
		transition_requested.emit(&"Dash", {"direction": direction})
		return

	player.last_move_direction = direction.normalized()
	player.velocity = direction * player.current_stats.speed
	player.move_and_slide()

	var body := player.get_node("Body") as AnimatedSprite2D
	var head := player.get_node("Head") as AnimatedSprite2D
	body.play("NewRun")
	head.play("NewRun")
	if direction.x != 0:
		body.flip_h = direction.x < 0
