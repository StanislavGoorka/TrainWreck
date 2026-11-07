class_name SettingsOverlay
extends CanvasLayer

signal closed

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	# The dim background also blocks clicks on the menu buttons behind it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UIStyle.MARGIN)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIStyle.SPACING * 2)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	var settings := SettingsPanel.new()
	settings.margin = 0   # the overlay already adds its own margin
	box.add_child(settings)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	box.add_child(back)

	settings.focus_first.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	closed.emit()
	queue_free()
