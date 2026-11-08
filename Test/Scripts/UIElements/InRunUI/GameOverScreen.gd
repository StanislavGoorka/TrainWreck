class_name GameOverScreen
extends CanvasLayer

var won := false
var summary := {}

func setup(run_won: bool, run_summary: Dictionary) -> void:
	won = run_won
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
	dim.color = Color(0, 0, 0, 0.8)
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
	title.text = "RUN COMPLETE" if won else "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	box.add_child(title)

	var info := Label.new()
	info.text = "Coins collected: %d" % int(summary.get("coins", 0))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)

	var new_run := _add_button(box, "New Run", _on_new_run)
	_add_button(box, "Get Back To Hub", _on_hub)

	new_run.grab_focus()   # keyboard and gamepad work right away
	create_tween().tween_property(holder, "modulate:a", 1.0, 0.5)

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
