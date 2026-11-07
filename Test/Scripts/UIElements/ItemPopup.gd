extends Control

@export var display_time: float = 2.5     # seconds fully visible
@export var fade_time: float = 0.3
@export var top_margin: int = UIStyle.MARGIN
@export var side_margin: int = 200   # clears the map (160 px) plus its margin
@export var name_font_size: int = 28
@export var desc_font_size: int = 16

var name_label: Label
var desc_label: Label
var tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	modulate.a = 0.0

	var player := get_tree().get_first_node_in_group("Players") as Player
	if player:
		player.item_picked_up.connect(_on_item_picked_up)
	else:
		push_warning("ItemPopup couldn't find Player.")

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", top_margin)
	margin.add_theme_constant_override("margin_left", side_margin)
	margin.add_theme_constant_override("margin_right", side_margin)
	add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	desc_label = Label.new()
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", desc_font_size)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc_label)

func _on_item_picked_up(item: ItemData) -> void:
	name_label.text = item.item_name
	name_label.add_theme_color_override("font_color", item.get_rarity_color())
	desc_label.text = item.description

	# A new pickup replaces whatever is still on screen.
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_time)
	tween.tween_interval(display_time)
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
