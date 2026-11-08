class_name BookMenu
extends Control

signal tab_changed(index: int)

@export_group("Sprites")
@export var background_texture: Texture2D     # 1260x650, drawn first
@export var front_texture: Texture2D          # 1260x650, drawn above the tabs
@export var tab_texture: Texture2D            # 120x50
@export_range(0.5, 4.0, 0.05) var book_scale: float = 1.4
@export var smooth_scaling: bool = false      # off = sharp pixels, on = smoother edges at decimal scales

@export_group("Layout (sprite pixels)")
@export var front_offset: Vector2 = Vector2.ZERO
@export var content_left: int = 100    # book edge to the inside edge of the left page
@export var content_top: int = 70
@export var content_right: int = 100
@export var content_bottom: int = 70
@export var gutter: int = 30           # gap between the two pages (the spine)
@export var page_padding: int = 24     # space between a page's edge and its content

@export_group("Tabs")
@export var tab_start_x: int = 80
@export var tab_top_edge: int = 0      # y in the sprite where the front's visible top edge starts
@export var tab_overlap: int = 16      # how many pixels of each tab hide under the front
@export var tab_spacing: int = 6
@export var tab_raise: int = 6         # how far the selected tab lifts
@export var tab_font_size: int = UIStyle.FONT_SIZE
@export var fade_time: float = 0.1

@export_group("Debug")
@export var show_layout_guides: bool = false   # tints the two page areas for tuning

const DEFAULT_TAB_SIZE := Vector2(120, 50)

var spreads: Array[BookSpread] = []
var tab_buttons: Array[TextureButton] = []
var tab_holder: Control
var tab_rest_y := 0.0
var current: int = -1
var book_size := Vector2.ZERO
var fade_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		if child is BookSpread:
			spreads.append(child)

	var native := Vector2.ZERO
	if background_texture:
		native = background_texture.get_size()
	elif front_texture:
		native = front_texture.get_size()
	if native == Vector2.ZERO:
		push_warning("BookMenu has no Background Texture assigned, using a placeholder size.")
		native = Vector2(1260, 650)
	book_size = native * book_scale

	custom_minimum_size = book_size
	size = book_size
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	_build_layers()
	_setup_spreads()
	select_tab(0, true)

func _filter() -> CanvasItem.TextureFilter:
	return CanvasItem.TEXTURE_FILTER_LINEAR if smooth_scaling else CanvasItem.TEXTURE_FILTER_NEAREST

func _build_layers() -> void:
	# Order: background, tabs, front. The spreads follow, so they draw on top of all three.
	var index := 0
	index = _add_layer(background_texture, Vector2.ZERO, index)

	tab_holder = Control.new()
	tab_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tab_holder)
	move_child(tab_holder, index)
	index += 1
	_build_tabs()

	_add_layer(front_texture, front_offset, index)

func _add_layer(texture: Texture2D, offset: Vector2, index: int) -> int:
	if not texture:
		return index
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = _filter()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE   # clicks pass through to the tabs below
	rect.position = offset * book_scale
	rect.size = texture.get_size() * book_scale
	add_child(rect)
	move_child(rect, index)
	return index + 1

func _build_tabs() -> void:
	var native: Vector2 = tab_texture.get_size() if tab_texture else DEFAULT_TAB_SIZE
	var tab_size: Vector2 = native * book_scale
	var visible_height: float = tab_size.y - tab_overlap * book_scale
	# The tab's top sits above the book edge. The overlapping part stays under the front.
	tab_rest_y = (tab_top_edge - (native.y - tab_overlap)) * book_scale

	for i in spreads.size():
		var button := TextureButton.new()
		button.texture_normal = tab_texture
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.texture_filter = _filter()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = tab_size
		button.size = tab_size
		button.position = Vector2((tab_start_x + i * (native.x + tab_spacing)) * book_scale, tab_rest_y)

		# The label is centered in the part of the tab that stays visible.
		var label := Label.new()
		label.text = spreads[i].get_title()
		label.add_theme_font_size_override("font_size", tab_font_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2.ZERO
		label.size = Vector2(tab_size.x, visible_height)
		button.add_child(label)

		button.pressed.connect(select_tab.bind(i))
		tab_holder.add_child(button)
		tab_buttons.append(button)

func _setup_spreads() -> void:
	var area_pos: Vector2 = Vector2(content_left, content_top) * book_scale
	var area_size: Vector2 = book_size - Vector2(content_left + content_right, content_top + content_bottom) * book_scale
	for spread in spreads:
		spread.position = area_pos
		spread.custom_minimum_size = area_size
		spread.size = area_size
		spread.add_theme_constant_override("separation", roundi(gutter * book_scale))
		spread.visible = false
		for page in spread.get_children():
			if page is Control:
				page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				page.size_flags_vertical = Control.SIZE_EXPAND_FILL
				page.size_flags_stretch_ratio = 1.0
			if page is MarginContainer:
				for side in ["left", "top", "right", "bottom"]:
					page.add_theme_constant_override("margin_" + side, roundi(page_padding * book_scale))

	if show_layout_guides:
		var gap: float = gutter * book_scale
		var page_w: float = (area_size.x - gap) / 2.0
		for i in 2:
			var guide := ColorRect.new()
			guide.color = Color(1, 0, 1, 0.25) if i == 0 else Color(0, 1, 1, 0.25)
			guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
			guide.position = area_pos + Vector2(i * (page_w + gap), 0)
			guide.size = Vector2(page_w, area_size.y)
			add_child(guide)

func select_tab(index: int, instant: bool = false) -> void:
	if spreads.is_empty():
		return
	index = clampi(index, 0, spreads.size() - 1)
	var changed := index != current
	current = index

	for i in spreads.size():
		spreads[i].visible = i == index
	_update_tabs(instant)

	var spread := spreads[index]
	spread.opened()
	if fade_tween:
		fade_tween.kill()
	if changed and not instant and fade_time > 0.0:
		spread.modulate.a = 0.0
		fade_tween = create_tween()
		fade_tween.tween_property(spread, "modulate:a", 1.0, fade_time)
	else:
		spread.modulate.a = 1.0
	if changed:
		tab_changed.emit(index)

func _update_tabs(instant: bool) -> void:
	for i in tab_buttons.size():
		var selected := i == current
		var button := tab_buttons[i]
		var tint := spreads[i].tab_tint
		button.self_modulate = tint if selected else tint.darkened(0.3)
		var raise: float = tab_raise * book_scale if selected else 0.0
		var target_y: float = tab_rest_y - raise
		if instant:
			button.position.y = target_y
		else:
			create_tween().tween_property(button, "position:y", target_y, 0.08)

func _unhandled_input(event: InputEvent) -> void:
	if spreads.is_empty() or not get_tree().paused or not is_visible_in_tree() or GameState.game_over:
		return
	if event.is_action_pressed("ui_page_down"):
		select_tab((current + 1) % spreads.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_up"):
		select_tab((current - 1 + spreads.size()) % spreads.size())
		get_viewport().set_input_as_handled()
