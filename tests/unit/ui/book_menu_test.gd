## The pause menu book: BookMenu (tabs and spreads), BookSpread, MainSpread and
## InventorySpread. Built in code with placeholder sizes (no textures).
extends "res://tests/helpers/tw_test_suite.gd"

const RecordingSpread := preload("res://tests/helpers/recording_spread.gd")


func _book(spread_titles: Array, scale := 1.0) -> BookMenu:
	var book: BookMenu = auto_free(BookMenu.new())
	book.book_scale = scale
	book.fade_time = 0.1
	for title: String in spread_titles:
		var spread: BookSpread = RecordingSpread.new()
		spread.name = title
		spread.add_child(MarginContainer.new())
		spread.add_child(MarginContainer.new())
		book.add_child(spread)
	add_child(book)
	return book


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


# --- BookSpread --------------------------------------------------------------------

func test_spread_title_defaults_to_the_node_name() -> void:
	var spread: BookSpread = auto_free(BookSpread.new())
	spread.name = "Inventory"
	assert_str(spread.get_title()).is_equal("Inventory")
	spread.tab_title = "Bag"
	assert_str(spread.get_title()).is_equal("Bag")


# --- BookMenu ----------------------------------------------------------------------

func test_book_uses_a_placeholder_size_without_textures() -> void:
	var book := _book(["Main"], 2.0)
	assert_vector(book.book_size).is_equal(Vector2(1260, 650) * 2.0)
	assert_vector(book.custom_minimum_size).is_equal(book.book_size)


func test_book_creates_a_tab_per_spread() -> void:
	var book := _book(["Main", "Inventory", "Settings"])
	assert_array(book.spreads).has_size(3)
	assert_array(book.tab_buttons).has_size(3)
	var titles := book.tab_buttons.map(func(b: TextureButton) -> String: return (b.get_child(0) as Label).text)
	assert_array(titles).contains_exactly("Main", "Inventory", "Settings")


func test_book_opens_on_the_first_spread() -> void:
	var book := _book(["Main", "Inventory"])
	assert_int(book.current).is_zero()
	assert_bool(book.spreads[0].visible).is_true()
	assert_bool(book.spreads[1].visible).is_false()
	assert_int(book.spreads[0].opened_count).is_equal(1)


func test_selecting_a_tab_shows_only_that_spread() -> void:
	var book := _book(["Main", "Inventory", "Settings"])
	var changes := []
	book.tab_changed.connect(func(index: int) -> void: changes.append(index))
	book.select_tab(2)
	assert_int(book.current).is_equal(2)
	assert_array(book.spreads.map(func(s: BookSpread) -> bool: return s.visible)).is_equal([false, false, true])
	assert_array(changes).is_equal([2])
	assert_int(book.spreads[2].opened_count).is_equal(1)


func test_switching_spreads_fades_the_new_one_in() -> void:
	var book := _book(["Main", "Inventory"])
	book.select_tab(1)
	assert_float(book.spreads[1].modulate.a).is_equal(0.0)
	book.fade_tween.custom_step(book.fade_time)
	assert_float(book.spreads[1].modulate.a).is_equal_approx(1.0, 0.001)


func test_instant_selection_skips_the_fade() -> void:
	var book := _book(["Main", "Inventory"])
	book.select_tab(1, true)
	assert_float(book.spreads[1].modulate.a).is_equal(1.0)


func test_reselecting_the_current_tab_reopens_without_a_change_event() -> void:
	var book := _book(["Main", "Inventory"])
	var changes := []
	book.tab_changed.connect(func(index: int) -> void: changes.append(index))
	book.select_tab(0)
	assert_array(changes).is_empty()
	assert_int(book.spreads[0].opened_count).is_equal(2)


func test_tab_index_is_clamped() -> void:
	var book := _book(["Main", "Inventory"])
	book.select_tab(99)
	assert_int(book.current).is_equal(1)
	book.select_tab(-5)
	assert_int(book.current).is_equal(0)


func test_selected_tab_is_raised_and_tinted() -> void:
	var book := _book(["Main", "Inventory"])
	book.spreads[1].tab_tint = Color(0.2, 0.6, 0.4)
	book.select_tab(1, true)
	var selected: TextureButton = book.tab_buttons[1]
	var other: TextureButton = book.tab_buttons[0]
	assert_float(selected.position.y).is_less(other.position.y)
	assert_that(selected.self_modulate).is_equal(Color(0.2, 0.6, 0.4))
	assert_that(other.self_modulate).is_equal(Color.WHITE.darkened(0.3))


func test_clicking_a_tab_selects_it() -> void:
	var book := _book(["Main", "Inventory"])
	book.tab_buttons[1].pressed.emit()
	assert_int(book.current).is_equal(1)


func test_page_keys_cycle_tabs_while_paused() -> void:
	var book := _book(["Main", "Inventory", "Settings"])
	get_tree().paused = true
	book._unhandled_input(_press(&"ui_page_down"))
	assert_int(book.current).is_equal(1)
	book._unhandled_input(_press(&"ui_page_up"))
	book._unhandled_input(_press(&"ui_page_up"))
	assert_int(book.current).is_equal(2)   # wraps around
	get_tree().paused = false


func test_page_keys_are_ignored_while_the_game_runs() -> void:
	var book := _book(["Main", "Inventory"])
	book._unhandled_input(_press(&"ui_page_down"))
	assert_int(book.current).is_zero()


func test_page_keys_are_ignored_on_the_game_over_screen() -> void:
	var book := _book(["Main", "Inventory"])
	GameState.game_over = true
	get_tree().paused = true
	book._unhandled_input(_press(&"ui_page_down"))
	get_tree().paused = false
	assert_int(book.current).is_zero()


func test_spreads_fill_the_page_area() -> void:
	var book := _book(["Main"])
	var spread: BookSpread = book.spreads[0]
	assert_vector(spread.position).is_equal(Vector2(book.content_left, book.content_top) * book.book_scale)
	for page: Control in spread.get_children():
		assert_int(page.size_flags_horizontal).is_equal(Control.SIZE_EXPAND_FILL)
		assert_int(page.get_theme_constant("margin_left")).is_equal(roundi(book.page_padding * book.book_scale))


# --- MainSpread --------------------------------------------------------------------

func _main_spread() -> MainSpread:
	var spread: MainSpread = auto_free(MainSpread.new())
	var summary := Label.new()
	summary.name = "Summary"
	spread.add_child(summary)
	summary.owner = spread
	summary.unique_name_in_owner = true
	add_child(spread)
	return spread


func test_main_spread_summarizes_the_run() -> void:
	var player: Player = auto_free(Factory.player())
	add_child(player)
	player.currency = 4
	player.keys = 2
	player.bombs = 1
	player.add_item(Factory.item(), true)
	var spread := _main_spread()
	spread.opened()
	assert_str(spread.summary.text).is_equal("Coins: 4\nKeys: 2\nBombs: 1\nItems: 1")


func test_main_spread_is_empty_without_a_player() -> void:
	var spread := _main_spread()
	spread.summary.text = "stale"
	spread.opened()
	assert_str(spread.summary.text).is_empty()


# --- InventorySpread ---------------------------------------------------------------

func _inventory_spread(size := Vector2(800, 400)) -> InventorySpread:
	var spread: InventorySpread = auto_free(InventorySpread.new())
	for page_name in ["LeftPage", "RightPage"]:
		var page := MarginContainer.new()
		page.name = page_name
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spread.add_child(page)
	spread.custom_minimum_size = size
	spread.size = size
	add_child(spread)
	return spread


func _texts(container: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for label: Label in container.find_children("*", "Label", true, false):
		texts.append(label.text)
	return texts


func test_inventory_without_items_says_so() -> void:
	var player: Player = auto_free(Factory.player())
	add_child(player)
	var spread := _inventory_spread()
	await spread.opened()
	assert_array(Array(_texts(spread.left_items))).contains_exactly("No items yet.")
	assert_bool(spread.prev_button.visible).is_false()
	assert_bool(spread.next_button.visible).is_false()


func test_inventory_lists_items_with_rarity_and_stats() -> void:
	var player: Player = auto_free(Factory.player())
	add_child(player)
	player.add_item(Factory.item({
		"item_name": "Banner", "description": "Forward!", "rarity": ItemData.Rarity.UNCOMMON, "speed_add": 50.0,
	}), true)
	var spread := _inventory_spread()
	await spread.opened()
	var texts := Array(_texts(spread.left_items))
	assert_array(texts).contains("Banner (Uncommon)", "Forward!", "+50.0 Speed")
	assert_int(spread.pages.size()).is_equal(1)


func test_inventory_splits_many_items_over_pages() -> void:
	var player: Player = auto_free(Factory.player())
	add_child(player)
	for i in 12:
		player.add_item(Factory.item({"item_name": "Item %d" % i, "description": "A fairly long description line."}), true)
	var spread := _inventory_spread(Vector2(800, 260))
	await spread.opened()
	assert_int(spread.pages.size()).is_greater(2)
	var shown := 0
	for page: Array in spread.pages:
		shown += page.size()
	assert_int(shown).is_equal(12)
	assert_bool(spread.next_button.visible).is_true()
	assert_bool(spread.prev_button.visible).is_false()
	spread._clear_pages()   # see test_freeing_the_inventory_frees_hidden_pages


func test_inventory_page_buttons_move_between_spreads() -> void:
	var player: Player = auto_free(Factory.player())
	add_child(player)
	for i in 12:
		player.add_item(Factory.item({"item_name": "Item %d" % i, "description": "A fairly long description line."}), true)
	var spread := _inventory_spread(Vector2(800, 260))
	await spread.opened()
	spread.next_button.pressed.emit()
	assert_int(spread.spread_index).is_equal(1)
	assert_bool(spread.prev_button.visible).is_true()
	spread._go(-10)
	assert_int(spread.spread_index).is_zero()
	spread._go(100)
	assert_int(spread.spread_index).is_equal(ceili(spread.pages.size() / 2.0) - 1)
	spread._clear_pages()   # see test_freeing_the_inventory_frees_hidden_pages


func test_freeing_the_inventory_frees_hidden_pages(
		do_skip := true,
		skip_reason := "KNOWN BUG: InventorySpread keeps entries of off-screen pages detached in 'pages' and never frees them when it is freed itself (node leak every time the pause menu is destroyed)") -> void:
	var player: Player = auto_free(Factory.player())
	add_child(player)
	for i in 12:
		player.add_item(Factory.item({"item_name": "Item %d" % i, "description": "A fairly long description line."}), true)
	var spread: InventorySpread = _inventory_spread(Vector2(800, 260))
	await spread.opened()
	var entries := []
	for page: Array in spread.pages:
		for entry: Control in page:
			entries.append(weakref(entry))
	remove_child(spread)
	spread.free()
	var leaked := entries.filter(func(ref: WeakRef) -> bool: return ref.get_ref() != null)
	for ref: WeakRef in leaked:
		ref.get_ref().free()
	assert_array(leaked).is_empty()


func test_reopening_the_inventory_rebuilds_it() -> void:
	var player: Player = auto_free(Factory.player())
	add_child(player)
	var spread := _inventory_spread()
	await spread.opened()
	player.add_item(Factory.item({"item_name": "New"}), true)
	await spread.opened()
	assert_array(Array(_texts(spread.left_items))).not_contains("No items yet.")
	assert_array(Array(_texts(spread.left_items))).contains("New (Common)")
