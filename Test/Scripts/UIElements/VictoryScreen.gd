class_name VictoryScreen
extends CanvasLayer

var summary := {}

func setup(run_summary: Dictionary) -> void:
	summary = run_summary

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # works while the tree is paused

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.modulate.a = 0.0

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	holder.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIStyle.SPACING * 2)
	center.add_child(box)

	var title := Label.new()
	title.text = "VICTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIStyle.SPACING * 6)
	grid.add_theme_constant_override("v_separation", UIStyle.SPACING_SMALL)
	box.add_child(grid)

	_add_row(grid, "Items collected", str(int(summary.get("items", 0))))
	_add_row(grid, "Total time", GameState.format_time(float(summary.get("run_time", 0.0))))
	_add_spacer(grid)

	var floor_times: Array = summary.get("floor_times", [])
	for i in floor_times.size():
		_add_row(grid, GameState.floor_title(i + 1), GameState.format_time(float(floor_times[i])))

	var new_run := _add_button(box, "New Run", _on_new_run)
	_add_button(box, "Get Back To Hub", _on_hub)

	new_run.grab_focus()   # keyboard and gamepad work right away
	create_tween().tween_property(holder, "modulate:a", 1.0, 0.5)

func _add_row(grid: GridContainer, left_text: String, right_text: String) -> void:
	var left := Label.new()
	left.text = left_text
	grid.add_child(left)
	var right := Label.new()
	right.text = right_text
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(right)

func _add_spacer(grid: GridContainer) -> void:
	for i in 2:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, UIStyle.SPACING)
		grid.add_child(spacer)

func _add_button(parent: Control, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 56)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button

func _on_new_run() -> void:
	queue_free()
	GameState.start_run()

func _on_hub() -> void:
	queue_free()
	GameState.go_to_hub()
