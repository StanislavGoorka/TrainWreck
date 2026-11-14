class_name InteractPrompt
extends PanelContainer

# Used when an interactable has no icon of its own. Adjust the path.
const DEFAULT_ICON_PATH := "res://Test/Assets/UI Elements/Tiles (Black)/tile_0087.png"

@export var icon_size: Vector2 = Vector2(32, 32)
@export var fade_time: float = 0.12

var icon_rect: TextureRect
var label: Label
var anchor_offset := Vector2(0, -48)   # where the bottom-center of the prompt sits
var tween: Tween

func _init() -> void:
	# Type variations let your Theme style this panel and its label
	# without touching every other PanelContainer and Label.
	theme_type_variation = &"InteractPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false
	modulate.a = 0.0

	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UIStyle.SPACING_SMALL)
	add_child(box)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = icon_size
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_rect)

	label = Label.new()
	label.theme_type_variation = &"InteractPromptLabel"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	resized.connect(_reposition)

func setup(text: String, icon: Texture2D, prompt_theme: Theme, offset: Vector2) -> void:
	if prompt_theme:
		theme = prompt_theme
	anchor_offset = offset

	var texture := icon if icon else _default_icon()
	icon_rect.texture = texture
	icon_rect.visible = texture != null
	# No icon at all: fall back to the key name, e.g. "[E] Talk".
	label.text = text if texture else "[%s] %s" % [_key_name(), text]

	reset_size()
	_reposition()

func set_text(text: String) -> void:
	label.text = text if icon_rect.visible else "[%s] %s" % [_key_name(), text]
	reset_size()

func show_prompt() -> void:
	if tween:
		tween.kill()
	visible = true
	scale = Vector2(0.85, 0.85)
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, fade_time)
	tween.tween_property(self, "scale", Vector2.ONE, fade_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_prompt() -> void:
	if not visible:
		return
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(func(): visible = false)

# Keeps the prompt centered above its anchor however wide the text makes it.
func _reposition() -> void:
	pivot_offset = size / 2.0
	position = anchor_offset - Vector2(size.x / 2.0, size.y)

static func _default_icon() -> Texture2D:
	if ResourceLoader.exists(DEFAULT_ICON_PATH):
		return load(DEFAULT_ICON_PATH) as Texture2D
	return null

static func _key_name() -> String:
	var events := InputMap.action_get_events("Interact")
	if events.is_empty():
		return "?"
	return events[0].as_text().get_slice(" (", 0)
