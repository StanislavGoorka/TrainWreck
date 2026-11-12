## HUD widgets that follow the player: hearts, stats, coins and keys, run timer,
## item icons, item pickup popup, map placeholder, boss health bar and HUD layout.
extends "res://tests/helpers/tw_test_suite.gd"

const HealthUI := preload("res://Test/Scripts/UIElements/HealthUI.gd")
const StatsUI := preload("res://Test/Scripts/UIElements/InRunUI/StatsUI.gd")
const CurrencyUI := preload("res://Test/Scripts/UIElements/InRunUI/CurrencyUI.gd")
const TimerUI := preload("res://Test/Scripts/UIElements/InRunUI/TimerUI.gd")
const ActiveItemsUI := preload("res://Test/Scripts/UIElements/InRunUI/ActiveItemsUI.gd")
const ItemPopup := preload("res://Test/Scripts/UIElements/ItemPopup.gd")
const MapUI := preload("res://Test/Scripts/UIElements/InRunUI/MapUI.gd")
const BossHealthBar := preload("res://Test/Scripts/UIElements/InRunUI/BossHealthBar.gd")
const HUD := preload("res://Test/Scripts/UIElements/HUD.gd")
const COUNTDOWN_SCENE := preload("res://Test/Scenes/UIScenes/UIElements/timer.tscn")

var player: Player


func before_test() -> void:
	super.before_test()
	player = auto_free(Factory.player(Factory.character_stats(10.0, 300.0, 300.0, 1.0, 0.0),
		Factory.weapon_stats(2.0, 0.5, 800.0, 600.0)))
	add_child(player)


func _widget(script: GDScript) -> Control:
	var widget: Control = auto_free(script.new())
	add_child(widget)
	return widget


# --- HealthUI ----------------------------------------------------------------------

func _health_ui() -> HBoxContainer:
	var ui: HBoxContainer = auto_free(HealthUI.new())
	ui.full_heart = Factory.texture()
	ui.half_heart = Factory.texture()
	ui.empty_heart = Factory.texture()
	add_child(ui)
	ui._initial_draw()
	return ui


func _hearts(ui: HBoxContainer) -> Array:
	var result := []
	for icon: TextureRect in ui.get_children():
		if icon.texture == ui.full_heart:
			result.append("full")
		elif icon.texture == ui.half_heart:
			result.append("half")
		else:
			result.append("empty")
	return result


func test_hearts_show_full_health() -> void:
	var ui := _health_ui()
	assert_array(_hearts(ui)).is_equal(["full", "full", "full", "full", "full"])


func test_hearts_show_halves_and_empty_containers() -> void:
	var ui := _health_ui()
	player.take_damage(3.0)   # 7 of 10
	assert_array(_hearts(ui)).is_equal(["full", "full", "full", "half", "empty"])


func test_odd_max_health_rounds_up_to_a_whole_container() -> void:
	var ui := _health_ui()
	player.add_item(Factory.item({"max_health_add": 1.0}), true)   # 11 HP
	assert_array(_hearts(ui)).has_size(6)
	assert_str(_hearts(ui)[5]).is_equal("half")


func test_hearts_play_a_hurt_animation_only_when_damaged() -> void:
	var ui := _health_ui()
	player.add_pickup(Factory.pickup(PickupData.PickupType.HEART, 1))
	assert_object(ui.hurt_tween).is_null()
	player.take_damage(1.0)
	assert_bool(ui.hurt_tween.is_running()).is_true()
	ui.hurt_tween.custom_step(1.0)
	assert_that(ui.modulate).is_equal(Color.WHITE)
	assert_vector(ui.scale).is_equal_approx(Vector2.ONE, Vector2.ONE * 0.001)


func test_health_ui_without_player_stays_empty() -> void:
	player.remove_from_group("Players")
	var ui := _health_ui()
	assert_int(ui.get_child_count()).is_zero()


# --- StatsUI -----------------------------------------------------------------------

func _stats_ui() -> VBoxContainer:
	var ui: VBoxContainer = _widget(StatsUI)
	ui._refresh()
	return ui


func test_stats_ui_has_a_row_per_stat() -> void:
	var ui := _stats_ui()
	assert_array(ui.value_labels.keys()).contains_exactly_in_any_order(
		"speed", "dash", "damage", "fire_rate", "bullet_speed", "range", "luck", "special")
	assert_int(ui.get_child_count()).is_equal(8)


func test_stats_ui_formats_values() -> void:
	var ui := _stats_ui()
	assert_str(ui.value_labels["speed"].text).is_equal("300.00")
	assert_str(ui.value_labels["dash"].text).is_equal("300.00")
	assert_str(ui.value_labels["damage"].text).is_equal("2.00")
	assert_str(ui.value_labels["fire_rate"].text).is_equal("2.00")   # 0.5 s per shot = 2 shots/s
	assert_str(ui.value_labels["bullet_speed"].text).is_equal("800.00")
	assert_str(ui.value_labels["range"].text).is_equal("600.00")
	assert_str(ui.value_labels["luck"].text).is_equal("1.00")
	assert_str(ui.value_labels["special"].text).is_equal("0%")


func test_stats_ui_updates_when_an_item_is_picked_up() -> void:
	var ui := _stats_ui()
	player.add_item(Factory.item({"damage_add": 1.0, "special_chance_add": 0.255}), true)
	assert_str(ui.value_labels["damage"].text).is_equal("3.00")
	assert_str(ui.value_labels["special"].text).is_equal("26%")


func test_stats_ui_shows_max_fire_rate_for_instant_shots() -> void:
	var ui := _stats_ui()
	player.add_item(Factory.item({"fire_rate_add": -1.0}), true)
	assert_str(ui.value_labels["fire_rate"].text).is_equal("MAX")


# --- CurrencyUI --------------------------------------------------------------------

func test_currency_ui_shows_two_digit_counters() -> void:
	var ui: VBoxContainer = _widget(CurrencyUI)
	assert_str(ui.coin_label.text).is_equal("00")
	assert_str(ui.key_label.text).is_equal("00")
	player.add_pickup(Factory.pickup(PickupData.PickupType.COIN, 7))
	player.add_pickup(Factory.pickup(PickupData.PickupType.KEY, 12))
	assert_str(ui.coin_label.text).is_equal("07")
	assert_str(ui.key_label.text).is_equal("12")


func test_currency_ui_without_player_still_builds_its_rows() -> void:
	player.remove_from_group("Players")
	var ui: VBoxContainer = _widget(CurrencyUI)
	assert_int(ui.get_child_count()).is_equal(2)
	assert_str(ui.coin_label.text).is_empty()


# --- TimerUI -----------------------------------------------------------------------

func test_run_timer_displays_the_shared_run_clock() -> void:
	var timer: Label = _widget(TimerUI)
	timer.set_process(false)
	timer._process(0.0)
	assert_str(timer.text).is_equal("00:00")
	GameState.run_time = 65.4
	timer._process(0.0)
	assert_str(timer.text).is_equal("01:05")
	GameState.run_time = 665.4
	timer._process(0.0)
	assert_str(timer.text).is_equal("11:05")


func test_run_timer_keeps_the_same_clock_when_the_widget_is_recreated() -> void:
	GameState.run_time = 63.0
	var timer: Label = _widget(TimerUI)
	timer._process(0.0)
	assert_str(timer.text).is_equal("01:03")
	timer.free()
	var replacement: Label = _widget(TimerUI)
	replacement._process(0.0)
	assert_str(replacement.text).is_equal("01:03")


func test_run_timer_does_not_advance_the_shared_clock() -> void:
	var timer: Label = _widget(TimerUI)
	GameState.run_time = 12.0
	timer._process(5.0)
	assert_float(GameState.run_time).is_equal(12.0)
	assert_str(timer.text).is_equal("00:12")


# --- Countdown timer (timer.tscn) --------------------------------------------------

func test_countdown_timer_counts_down_from_ten_minutes() -> void:
	var countdown: Control = auto_free(COUNTDOWN_SCENE.instantiate())
	add_child(countdown)
	countdown.set_process(false)
	countdown._process(1.0)
	assert_str(countdown.get_time_formatted()).is_equal("09:59")
	assert_str(countdown.get_node("%Minutes").text).is_equal("09:")
	assert_str(countdown.get_node("%Seconds").text).is_equal("59")


# --- ActiveItemsUI -----------------------------------------------------------------

func test_active_items_ui_shows_an_icon_per_item() -> void:
	var ui: GridContainer = _widget(ActiveItemsUI)
	var sheet := Factory.texture(Vector2(64, 64))
	player.add_item(Factory.item({"icon_sheet_ui": sheet, "icon_grid_pos": Vector2i(1, 1)}), true)
	player.add_item(Factory.item({"icon": Factory.texture()}), true)
	assert_int(ui.get_child_count()).is_equal(2)
	var first: TextureRect = ui.get_child(0)
	assert_that((first.texture as AtlasTexture).region).is_equal(Rect2(16, 16, 16, 16))
	assert_vector(first.custom_minimum_size).is_equal(ui.icon_size)


func test_active_items_ui_skips_rebuilds_when_nothing_changed() -> void:
	var ui: GridContainer = _widget(ActiveItemsUI)
	player.add_item(Factory.item(), true)
	var icon := ui.get_child(0)
	ui._refresh()
	assert_object(ui.get_child(0)).is_same(icon)


func test_active_items_ui_uses_its_column_setting() -> void:
	var ui: GridContainer = _widget(ActiveItemsUI)
	assert_int(ui.columns).is_equal(ui.max_columns)


# --- ItemPopup ---------------------------------------------------------------------

func test_item_popup_starts_hidden() -> void:
	var popup: Control = _widget(ItemPopup)
	assert_float(popup.modulate.a).is_equal(0.0)


func test_item_popup_shows_the_picked_up_item() -> void:
	var popup: Control = _widget(ItemPopup)
	var item := Factory.item({"item_name": "Lucky Coin", "description": "Shiny.", "rarity": ItemData.Rarity.EPIC})
	player.add_item(item)
	assert_str(popup.name_label.text).is_equal("Lucky Coin")
	assert_str(popup.desc_label.text).is_equal("Shiny.")
	assert_that(popup.name_label.get_theme_color("font_color")).is_equal(item.get_rarity_color())
	popup.tween.custom_step(popup.fade_time)
	assert_float(popup.modulate.a).is_equal_approx(1.0, 0.001)
	popup.tween.custom_step(popup.display_time + popup.fade_time)
	assert_float(popup.modulate.a).is_equal_approx(0.0, 0.001)


func test_item_popup_ignores_silent_pickups() -> void:
	var popup: Control = _widget(ItemPopup)
	player.add_item(Factory.item({"item_name": "Starter"}), true)
	assert_str(popup.name_label.text).is_empty()


# --- MapUI -------------------------------------------------------------------------

func test_map_placeholder() -> void:
	var map: PanelContainer = _widget(MapUI)
	assert_vector(map.custom_minimum_size).is_equal(map.map_size)
	assert_str((map.get_child(0) as Label).text).is_equal("MAP")


# --- BossHealthBar -----------------------------------------------------------------

func _boss(boss_name := "Big Bad", max_health := 40.0) -> Enemy:
	var stats := BossStats.new()
	stats.boss_name = boss_name
	stats.max_health = max_health
	var boss: Enemy = auto_free(Factory.enemy(stats))
	add_child(boss)
	return boss


func _boss_bar() -> VBoxContainer:
	var bar: VBoxContainer = auto_free(BossHealthBar.new())
	bar.smooth_time = 0.1
	add_child(bar)
	return bar


func test_boss_bar_registers_itself_and_starts_hidden() -> void:
	var bar := _boss_bar()
	assert_bool(bar.is_in_group("BossHealthBar")).is_true()
	assert_bool(bar.visible).is_false()


func test_boss_bar_shows_the_boss_name_and_health() -> void:
	var bar := _boss_bar()
	var boss := _boss("Laureth", 40.0)
	bar.show_for(boss)
	assert_bool(bar.visible).is_true()
	assert_str(bar.name_label.text).is_equal("Laureth")
	assert_float(bar.bar.max_value).is_equal(40.0)
	assert_float(bar.bar.value).is_equal(40.0)


func test_boss_bar_falls_back_to_the_node_name() -> void:
	var bar := _boss_bar()
	var enemy: Enemy = auto_free(Factory.enemy())
	enemy.name = "Grunt"
	add_child(enemy)
	bar.show_for(enemy)
	assert_str(bar.name_label.text).is_equal("Grunt")


func test_boss_bar_drains_smoothly_on_damage() -> void:
	var bar := _boss_bar()
	var boss := _boss("Laureth", 40.0)
	bar.show_for(boss)
	boss.take_damage(10.0)
	assert_float(bar.bar.value).is_equal(40.0)
	bar.value_tween.custom_step(bar.smooth_time)
	assert_float(bar.bar.value).is_equal_approx(30.0, 0.01)


func test_boss_bar_hides_when_the_boss_dies() -> void:
	var bar := _boss_bar()
	var boss := _boss()
	bar.show_for(boss)
	boss.take_damage(1000.0)
	assert_bool(bar.visible).is_false()


func test_boss_bar_follows_only_the_latest_boss() -> void:
	var bar := _boss_bar()
	var first := _boss("First", 40.0)
	var second := _boss("Second", 20.0)
	bar.show_for(first)
	bar.show_for(second)
	bar.smooth_time = 0.0
	first.take_damage(30.0)
	assert_float(bar.bar.value).is_equal(20.0)
	assert_str(bar.name_label.text).is_equal("Second")


# --- HUD layout --------------------------------------------------------------------

func test_hud_anchors_every_zone_with_the_standard_margin() -> void:
	var hud: Control = auto_free(Control.new())
	for zone_name in ["TopLeft", "MiddleLeft", "TopRight", "BottomRight", "BottomCenter"]:
		var zone := MarginContainer.new()
		zone.name = zone_name
		hud.add_child(zone)
	for zone_name in ["TopLeft", "TopRight"]:
		var stack := VBoxContainer.new()
		stack.name = "Stack"
		hud.get_node(zone_name).add_child(stack)
	var right_widget := Label.new()
	hud.get_node("TopRight/Stack").add_child(right_widget)
	var map_widget := PanelContainer.new()
	hud.get_node("TopRight/Stack").add_child(map_widget)
	hud.set_script(HUD)
	add_child(hud)

	assert_int(hud.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for zone: MarginContainer in hud.get_children():
		assert_int(zone.get_theme_constant("margin_left")).is_equal(UIStyle.MARGIN)
		assert_int(zone.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(right_widget.size_flags_horizontal).is_equal(Control.SIZE_FILL)
	assert_int(map_widget.size_flags_horizontal).is_equal(Control.SIZE_SHRINK_CENTER)
	assert_int(hud.get_node("TopRight").grow_horizontal).is_equal(Control.GROW_DIRECTION_BEGIN)
