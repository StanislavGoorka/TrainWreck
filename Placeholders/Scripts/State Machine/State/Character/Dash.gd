extends PlayerState

@export var dash_duration: float = 0.15
const ENEMY_LAYER := 3   # "enemies" in your layer names

var dash_direction := Vector2.RIGHT
var elapsed := 0.0
var saved_layer := 0
var saved_mask := 0

func enter(msg := {}) -> void:
	var requested: Vector2 = msg.get("direction", Vector2.ZERO)
	dash_direction = requested.normalized() if requested != Vector2.ZERO else player.last_move_direction
	elapsed = 0.0

	player.invulnerable = true
	saved_layer = player.collision_layer
	saved_mask = player.collision_mask
	player.collision_layer = 0
	player.set_collision_mask_value(ENEMY_LAYER, false)

	var body := player.get_node("Body") as AnimatedSprite2D
	if body.sprite_frames and body.sprite_frames.has_animation("Dash"):
		body.play("Dash")
	if dash_direction.x != 0:
		body.flip_h = dash_direction.x < 0

func exit() -> void:
	player.invulnerable = false
	player.collision_layer = saved_layer
	player.collision_mask = saved_mask
	# Don't carry dash speed into the slide
	player.velocity = player.velocity.limit_length(player.current_stats.speed)

func physics_update(delta: float) -> void:
	elapsed += delta
	var dash_speed: float = player.current_stats.dash_distance / dash_duration
	player.velocity = dash_direction * dash_speed
	player.move_and_slide()

	if elapsed >= dash_duration:
		var direction := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
		transition_requested.emit(&"Move" if direction != Vector2.ZERO else &"Idle")
