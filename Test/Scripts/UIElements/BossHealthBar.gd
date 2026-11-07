extends VBoxContainer

@export var frame_texture: Texture2D                 # outline with background fill
@export var fill_texture: Texture2D                  # the red HP sprite
@export var fill_offset: Vector2 = Vector2.ZERO      # where the fill starts inside the frame, in sprite pixels
@export_range(1, 8) var pixel_scale: int = 3         # whole-number scale keeps the pixels sharp
@export var fill_direction: TextureProgressBar.FillMode = TextureProgressBar.FILL_LEFT_TO_RIGHT
@export var smooth_time: float = 0.15                # how fast the fill drains, 0 = instant
@export var name_font_size: int = UIStyle.FONT_SIZE

var name_label: Label
var bar: TextureProgressBar
var boss: Enemy
var value_tween: Tween

func _ready() -> void:
	add_to_group("BossHealthBar")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", UIStyle.SPACING_SMALL)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	if not frame_texture or not fill_texture:
		push_warning("BossHealthBar needs both Frame Texture and Fill Texture assigned.")

	# The holder reserves the scaled size in the layout. TextureProgressBar draws its
	# textures at their native size, so the bar itself is scaled inside the holder.
	var native_size := Vector2.ZERO
	if frame_texture:
		native_size = frame_texture.get_size()
	elif fill_texture:
		native_size = fill_texture.get_size()

	var holder := Control.new()
	holder.custom_minimum_size = native_size * pixel_scale
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(holder)

	bar = TextureProgressBar.new()
	bar.texture_under = frame_texture
	bar.texture_progress = fill_texture
	bar.texture_progress_offset = fill_offset
	bar.fill_mode = fill_direction
	bar.step = 0.01
	bar.scale = Vector2(pixel_scale, pixel_scale)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)

	visible = false

func show_for(target: Enemy) -> void:
	if is_instance_valid(boss) and boss.health_changed.is_connected(_on_health_changed):
		boss.health_changed.disconnect(_on_health_changed)

	boss = target
	var boss_stats := boss.stats as BossStats
	name_label.text = boss_stats.boss_name if boss_stats else String(boss.name)

	boss.health_changed.connect(_on_health_changed)
	boss.died.connect(_on_boss_died)
	_set_health(boss.health, boss.stats.max_health, true)
	visible = true

func _on_health_changed(current: float, max_value: float) -> void:
	_set_health(current, max_value, false)

func _set_health(current: float, max_value: float, instant: bool) -> void:
	bar.max_value = max_value
	if value_tween:
		value_tween.kill()
	if instant or smooth_time <= 0.0:
		bar.value = current
	else:
		value_tween = create_tween()
		value_tween.tween_property(bar, "value", current, smooth_time)

func _on_boss_died(_enemy) -> void:
	visible = false
