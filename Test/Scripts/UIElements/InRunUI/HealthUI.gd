extends GridContainer

@export var full_heart: Texture2D
@export var half_heart: Texture2D
@export var empty_heart: Texture2D
@export var hearts_per_row: int = 6
@export var hurt_flash_color: Color = Color(1, 0.3, 0.3)
@export var hurt_pop_scale: float = 1.12

var player: Player
var last_health: float = -1.0
var hurt_tween: Tween

func _ready() -> void:
	columns = hearts_per_row
	add_theme_constant_override("h_separation", UIStyle.SPACING_SMALL)
	add_theme_constant_override("v_separation", UIStyle.SPACING_SMALL)

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

	var max_hearts := mini(ceili(max_health / StatLimits.HP_PER_HEART), StatLimits.MAX_HEARTS)
	var remaining := current_health

	for i in max_hearts:
		var icon := TextureRect.new()
		icon.custom_minimum_size = UIStyle.HEART_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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
