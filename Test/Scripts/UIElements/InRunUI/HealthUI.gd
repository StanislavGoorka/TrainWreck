extends HBoxContainer

@export var full_heart: Texture2D
@export var half_heart: Texture2D
@export var empty_heart: Texture2D


@export var hurt_flash_color: Color = Color(1, 0.3, 0.3)   # reddish flash
@export var hurt_shake_strength: float = 6.0
@export var hurt_pop_scale: float = 1.12

var player: Player
var last_health: float = -1.0
var base_position: Vector2
var base_position_set: bool = false
var hurt_tween: Tween

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Players") as Player
	if not player:
		push_warning("HealthUI couldn't find Player.")
		return

	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)

	call_deferred("_initial_draw")

func _initial_draw() -> void:
	if player and player.current_stats:
		last_health = player.health
		_redraw(player.health, player.current_stats.max_health)

func _on_health_changed(current: float, max_health: float) -> void:
	var took_damage := current < last_health
	last_health = current
	_redraw(current, max_health)
	if took_damage:
		_play_hurt_animation()

func _redraw(current_health: float, max_health: float) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var max_hearts := ceili(max_health / 2.0)
	var remaining := current_health

	for i in max_hearts:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		if remaining >= 2:
			icon.texture = full_heart
			remaining -= 2
		elif remaining >= 1:
			icon.texture = half_heart
			remaining -= 1
		else:
			icon.texture = empty_heart

		add_child(icon)

func _play_hurt_animation() -> void:
	if hurt_tween and hurt_tween.is_running():
		return
	hurt_tween = create_tween()
	hurt_tween.tween_property(self, "modulate", hurt_flash_color, 0.07)
	hurt_tween.parallel().tween_property(self, "scale", Vector2.ONE * hurt_pop_scale, 0.07)
	hurt_tween.tween_property(self, "modulate", Color.WHITE, 0.18)
	hurt_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)
