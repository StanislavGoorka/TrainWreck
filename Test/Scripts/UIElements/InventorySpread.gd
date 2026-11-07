class_name InventorySpread
extends BookSpread

const OUTLINE_PAD := 8   # keep this at least as big as the outline size in your Theme
const ITEM_GAP := 18

@export_range(1, 4) var icon_scale: int = 2     # 32x32 art shown at 2x
@export var prev_icon: Texture2D                # optional, text is used when empty
@export var next_icon: Texture2D



var player: Player
var spread_index: int = 0
var pages: Array = []          # each page is an Array of entry Controls
var build_id: int = 0          # cancels a build if the tab is reopened mid-way

var left_items: VBoxContainer
var right_items: VBoxContainer
var left_number: Label
var right_number: Label
var prev_button: Button
var next_button: Button

func _ready() -> void:
	var left := _build_page($LeftPage, true)
	left_items = left["items"]
	left_number = left["number"]
	prev_button = left["button"]

	var right := _build_page($RightPage, false)
	right_items = right["items"]
	right_number = right["number"]
	next_button = right["button"]

func _build_page(page: Control, is_left: bool) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIStyle.SPACING)
	page.add_child(root)

	# The clipping happens here, with a margin, so text outlines are not cut at the edges.
	var clip := MarginContainer.new()
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.clip_contents = true
	for side in ["left", "top", "right", "bottom"]:
		clip.add_theme_constant_override("margin_" + side, OUTLINE_PAD)
	root.add_child(clip)

	var items := VBoxContainer.new()
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items.add_theme_constant_override("separation", ITEM_GAP)
	clip.add_child(items)

	var footer := HBoxContainer.new()
	root.add_child(footer)

	var number := Label.new()
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	if is_left:
		button.text = "" if prev_icon else "< Prev"
		button.icon = prev_icon
		button.pressed.connect(_go.bind(-1))
		footer.add_child(button)
		footer.add_child(number)
	else:
		button.text = "" if next_icon else "Next >"
		button.icon = next_icon
		button.pressed.connect(_go.bind(1))
		footer.add_child(number)
		footer.add_child(button)
	button.visible = false

	return {"items": items, "number": number, "button": button}

func opened() -> void:
	build_id += 1
	var id := build_id
	player = get_tree().get_first_node_in_group("Players") as Player
	_clear_pages()

	if not player or player.inventory.is_empty():
		var empty := Label.new()
		empty.text = "No items yet."
		left_items.add_child(empty)
		_update_footer()
		return

	# Wait for the page layout, so the available height is real.
	for i in 3:
		await get_tree().process_frame
		if id != build_id:
			return
		if left_items.size.y > 100.0:
			break
	var avail_h: float = left_items.size.y
	var width: float = left_items.size.x

	# Measure every entry at the real page width, in a hidden box that sits outside the layout.
	var measure := VBoxContainer.new()
	measure.top_level = true
	measure.position = Vector2(-10000, -10000)
	measure.size = Vector2(width, 0)
	measure.modulate.a = 0.0
	measure.add_theme_constant_override("separation", ITEM_GAP)
	add_child(measure)

	var entries: Array[Control] = []
	for item in player.inventory:
		var entry := _build_entry(item)
		measure.add_child(entry)
		entries.append(entry)

	await get_tree().process_frame
	await get_tree().process_frame
	if id != build_id:
		measure.queue_free()   # the entries go with it
		return

	# Pack: items go on the current page until the next one would not fit.
	var current: Array = []
	var used: float = 0.0
	for entry in entries:
		var h: float = entry.size.y
		var gap: float = float(ITEM_GAP) if not current.is_empty() else 0.0
		if not current.is_empty() and used + gap + h > avail_h:
			pages.append(current)
			current = []
			used = 0.0
			gap = 0.0
		current.append(entry)
		used += gap + h
	if not current.is_empty():
		pages.append(current)

	for entry in entries:
		measure.remove_child(entry)
	measure.queue_free()

	_show_spread(0)

func _clear_pages() -> void:
	for container in [left_items, right_items]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for page in pages:
		for entry in page:
			if is_instance_valid(entry) and entry.get_parent() == null:
				entry.free()   # entries of pages that were not on screen
	pages.clear()
	spread_index = 0

func _show_spread(index: int) -> void:
	spread_index = index
	# Detach without freeing, so going back keeps the same entries.
	for container in [left_items, right_items]:
		for child in container.get_children():
			container.remove_child(child)

	_fill(left_items, index * 2)
	_fill(right_items, index * 2 + 1)
	_update_footer()

func _fill(container: VBoxContainer, page_index: int) -> void:
	if page_index >= pages.size():
		return
	var page: Array = pages[page_index]
	for entry in page:
		container.add_child(entry)
	# The last item on a page doesn't need a divider under it.
	var last: Control = page[page.size() - 1]
	last.get_child(last.get_child_count() - 1).visible = false

func _update_footer() -> void:
	var left_page: int = spread_index * 2
	#left_number.text = str(left_page + 1) if left_page < pages.size() else ""
	#right_number.text = str(left_page + 2) if left_page + 1 < pages.size() else ""
	prev_button.visible = spread_index > 0
	next_button.visible = (spread_index + 1) * 2 < pages.size()

func _go(direction: int) -> void:
	var count: int = ceili(pages.size() / 2.0)
	var target: int = clampi(spread_index + direction, 0, maxi(count - 1, 0))
	if target != spread_index:
		_show_spread(target)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not get_tree().paused or pages.is_empty():
		return
	if event.is_action_pressed("ui_right"):
		_go(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_go(-1)
		get_viewport().set_input_as_handled()

func _build_entry(item: ItemData) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", UIStyle.SPACING_SMALL)

	# Icon and name
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIStyle.SPACING)
	entry.add_child(header)

	var icon := TextureRect.new()
	icon.texture = item.get_icon()
	icon.custom_minimum_size = Vector2(32, 32) * icon_scale
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(icon)

	var title := Label.new()
	title.text = "%s (%s)" % [item.item_name, item.get_rarity_name()]
	title.add_theme_color_override("font_color", item.get_rarity_color())
	title.add_theme_font_size_override("font_size", UIStyle.FONT_SIZE_TITLE)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Description
	var desc := Label.new()
	desc.text = item.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(desc)

	# Stats
	var lines := item.get_stat_lines(player.base_weapon_stats if player else null)
	if not lines.is_empty():
		var stats := Label.new()
		stats.text = "\n".join(lines)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		entry.add_child(stats)

	# Divider. It must stay the last child, because _fill() hides the last one on a page.
	entry.add_child(HSeparator.new())
	return entry
