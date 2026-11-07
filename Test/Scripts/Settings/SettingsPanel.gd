class_name SettingsPanel
extends MarginContainer

@export var show_graphics: bool = true
@export var show_audio: bool = true

const LABEL_WIDTH := 180
const SLIDER_MIN_WIDTH := 140
const PERCENT_WIDTH := 56
const HEADER_SIZE := 28

@export var margin: int = UIStyle.MARGIN   # set to 0 where a parent already adds padding

var content: VBoxContainer
var fullscreen_check: CheckButton
var volume_rows: Array[Dictionary] = []   # each: {bus, slider, percent}

func _ready() -> void:
	for side in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, margin)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", UIStyle.SPACING)
	add_child(content)

	if show_graphics:
		_add_header("Graphics")
		fullscreen_check = CheckButton.new()
		fullscreen_check.text = "Fullscreen"
		fullscreen_check.toggled.connect(GameSettings.set_fullscreen)
		content.add_child(fullscreen_check)

	if show_audio:
		_add_header("Audio")
		_add_volume_row("Master Volume", Audio.BUS_MASTER)
		_add_volume_row("Music Volume", Audio.BUS_MUSIC)
		_add_volume_row("SFX Volume", Audio.BUS_SFX)

	_sync()
	visibility_changed.connect(func(): if is_visible_in_tree(): _sync())
	


func focus_first() -> void:
	if fullscreen_check:
		fullscreen_check.grab_focus()

func _sync() -> void:
	if fullscreen_check:
		fullscreen_check.set_pressed_no_signal(GameSettings.is_fullscreen())
	for row in volume_rows:
		var value: float = Audio.get_volume(row["bus"])
		row["slider"].set_value_no_signal(value)
		row["percent"].text = "%d%%" % roundi(value * 100.0)

func _add_header(title: String) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", HEADER_SIZE)
	content.add_child(header)

func _add_volume_row(title: String, bus: StringName) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", UIStyle.SPACING)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(label)

	var slider := VolumeSlider.new()
	slider.bus = bus   # set before it enters the tree, because VolumeSlider reads it in _ready()
	slider.custom_minimum_size.x = SLIDER_MIN_WIDTH
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var percent := Label.new()
	percent.custom_minimum_size.x = PERCENT_WIDTH
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)

	content.add_child(row)
	slider.value_changed.connect(func(v: float): percent.text = "%d%%" % roundi(v * 100.0))
	volume_rows.append({"bus": bus, "slider": slider, "percent": percent})
