extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_setup_zone($TopLeft, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	_setup_zone($MiddleLeft, Control.PRESET_CENTER_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BOTH)
	_setup_zone($TopRight, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	_setup_zone($BottomRight, Control.PRESET_BOTTOM_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	_setup_zone($BottomCenter, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)

	for stack in [$TopLeft/Stack, $TopRight/Stack]:
		stack.add_theme_constant_override("separation", UIStyle.SPACING)

	# Everything in the top-right stack hugs the right edge.
	for child in $TopRight/Stack.get_children():
		if child is Control:
			child.size_flags_horizontal = Control.SIZE_SHRINK_END
	# The map keeps its own size and sits in the middle. The labels fill the stack's width,
	# which is the width of the map, and center their text under it.
	for child in $TopRight/Stack.get_children():
		if child is Label:
			child.size_flags_horizontal = Control.SIZE_FILL
		elif child is Control:
			child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _setup_zone(zone: MarginContainer, preset: Control.LayoutPreset, grow_h: Control.GrowDirection, grow_v: Control.GrowDirection) -> void:
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		zone.add_theme_constant_override("margin_" + side, UIStyle.MARGIN)
	zone.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	zone.grow_horizontal = grow_h
	zone.grow_vertical = grow_v
