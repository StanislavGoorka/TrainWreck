extends "res://tests/helpers/tw_test_suite.gd"


func test_defaults_describe_a_neutral_item() -> void:
	var item := ItemData.new()
	assert_int(item.pools).is_equal(ItemData.POOL_ITEM_ROOM)
	assert_int(item.rarity).is_equal(ItemData.Rarity.COMMON)
	assert_float(item.damage_mult).is_equal(1.0)
	assert_float(item.fire_rate_mult).is_equal(1.0)
	assert_float(item.bullet_speed_mult).is_equal(1.0)
	assert_float(item.speed_mult).is_equal(1.0)
	assert_int(item.status_effect).is_equal(StatusEffect.Type.NONE)
	assert_int(item.status_stacks_per_hit).is_equal(1)
	assert_float(item.status_chance).is_equal(100.0)
	assert_str(String(item.special_effect)).is_empty()
	assert_array(item.get_stat_lines()).is_empty()


func test_pool_flags_are_distinct_bits() -> void:
	assert_int(ItemData.POOL_ITEM_ROOM & ItemData.POOL_BOSS).is_zero()


func test_rarity_tables_cover_every_rarity() -> void:
	assert_int(ItemData.RARITY_NAMES.size()).is_equal(ItemData.Rarity.size())
	assert_int(ItemData.RARITY_COLORS.size()).is_equal(ItemData.Rarity.size())


func test_rarity_name_and_color(rarity: int, expected_name: String, test_parameters := [
	[ItemData.Rarity.COMMON, "Common"],
	[ItemData.Rarity.UNCOMMON, "Uncommon"],
	[ItemData.Rarity.RARE, "Rare"],
	[ItemData.Rarity.EPIC, "Epic"],
	[ItemData.Rarity.LEGENDARY, "Legendary"],
]) -> void:
	var item := Factory.item({"rarity": rarity})
	assert_str(item.get_rarity_name()).is_equal(expected_name)
	assert_that(item.get_rarity_color()).is_equal(ItemData.RARITY_COLORS[rarity])


# --- Icons -------------------------------------------------------------------------

func test_get_icon_without_any_texture_is_null() -> void:
	assert_object(ItemData.new().get_icon()).is_null()
	assert_object(ItemData.new().get_icon_ui()).is_null()


func test_get_icon_uses_the_manual_icon_when_there_is_no_sheet() -> void:
	var icon := Factory.texture()
	var item := Factory.item({"icon": icon})
	assert_object(item.get_icon()).is_same(icon)


func test_get_icon_slices_the_32px_sheet_at_the_grid_position() -> void:
	var sheet := Factory.texture(Vector2(128, 128))
	var item := Factory.item({"icon_sheet": sheet, "icon_grid_pos": Vector2i(3, 2)})
	var icon := item.get_icon() as AtlasTexture
	assert_object(icon).is_not_null()
	assert_object(icon.atlas).is_same(sheet)
	assert_that(icon.region).is_equal(Rect2(96, 64, 32, 32))


func test_get_icon_ui_slices_the_16px_sheet_at_the_same_grid_position() -> void:
	var sheet := Factory.texture(Vector2(128, 128))
	var ui_sheet := Factory.texture(Vector2(64, 64))
	var item := Factory.item({"icon_sheet": sheet, "icon_sheet_ui": ui_sheet, "icon_grid_pos": Vector2i(1, 2)})
	var icon := item.get_icon_ui() as AtlasTexture
	assert_object(icon.atlas).is_same(ui_sheet)
	assert_that(icon.region).is_equal(Rect2(16, 32, 16, 16))


func test_get_icon_ui_falls_back_to_the_32px_icon() -> void:
	var sheet := Factory.texture(Vector2(128, 128))
	var item := Factory.item({"icon_sheet": sheet, "icon_grid_pos": Vector2i(1, 0)})
	var icon := item.get_icon_ui() as AtlasTexture
	assert_object(icon.atlas).is_same(sheet)
	assert_that(icon.region).is_equal(Rect2(32, 0, 32, 32))


# --- Stat lines --------------------------------------------------------------------

# Note: Godot 4.7 String.num() keeps ".0" on whole numbers ("+1.0 Heart").
func test_stat_line_for_single_property(property: String, value: Variant, expected: String, test_parameters := [
	["max_health_add", 2.0, "+1.0 Heart"],
	["max_health_add", -2.0, "-1.0 Heart"],
	["max_health_add", 1.0, "+0.5 Heart"],
	["speed_add", 50.0, "+50.0 Speed"],
	["speed_add", -150.0, "-150.0 Speed"],
	["speed_mult", 1.5, "Speed x1.5"],
	["dash_distance_add", 25.0, "+25.0 Dash Distance"],
	["damage_add", 0.4, "+0.4 Damage"],
	["damage_mult", 2.0, "Damage x2.0"],
	["bullet_speed_add", 100.0, "+100.0 Bullet Speed"],
	["bullet_speed_mult", 0.75, "Bullet Speed x0.75"],
	["shoot_range_add", -50.0, "-50.0 Range"],
	["luck_add", 1.0, "+1.0 Luck"],
	["special_chance_add", 0.1, "+10.0% Special Chance"],
]) -> void:
	var item := Factory.item({property: value})
	assert_array(item.get_stat_lines()).contains_exactly(expected)


func test_fire_rate_line_is_shown_in_shots_per_second() -> void:
	# 0.8 s -> 0.6 s between shots: 1/0.6 - 1/0.8 = +0.42 shots per second
	var item := Factory.item({"fire_rate_add": -0.2})
	var lines := item.get_stat_lines(Factory.weapon_stats(1.0, 0.8))
	assert_array(lines).contains_exactly("+0.42 Fire Rate")


func test_fire_rate_multiplier_slower_shots_is_negative() -> void:
	var item := Factory.item({"fire_rate_mult": 2.0})
	var lines := item.get_stat_lines(Factory.weapon_stats(1.0, 1.0))
	assert_array(lines).contains_exactly("-0.5 Fire Rate")


func test_fire_rate_line_reports_max_when_interval_reaches_zero() -> void:
	var item := Factory.item({"fire_rate_add": -1.0})
	assert_array(item.get_stat_lines(Factory.weapon_stats(1.0, 0.8))).contains_exactly("Fire Rate MAX")


func test_fire_rate_line_without_base_weapon_is_generic() -> void:
	var item := Factory.item({"fire_rate_add": -0.2})
	assert_array(item.get_stat_lines()).contains_exactly("Fire Rate changed")
	assert_array(item.get_stat_lines(Factory.weapon_stats(1.0, 0.0))).contains_exactly("Fire Rate changed")


func test_status_line_with_guaranteed_chance() -> void:
	var item := Factory.item({"status_effect": StatusEffect.Type.POISON, "status_stacks_per_hit": 2})
	assert_array(item.get_stat_lines()).contains_exactly("Shots apply Poison x2")


func test_status_line_with_partial_chance() -> void:
	var item := Factory.item({"status_effect": StatusEffect.Type.BLEED, "status_chance": 50.5})
	assert_array(item.get_stat_lines()).contains_exactly("50.5% chance: Shots apply Bleed x1")


func test_stat_lines_keep_a_stable_order() -> void:
	var item := Factory.item({
		"max_health_add": 2.0, "speed_add": 10.0, "damage_add": 1.0,
		"luck_add": 1.0, "status_effect": StatusEffect.Type.BURN,
	})
	assert_array(item.get_stat_lines()).contains_exactly(
		"+1.0 Heart", "+10.0 Speed", "+1.0 Damage", "+1.0 Luck", "Shots apply Burn x1")


func test_signed_formatting() -> void:
	assert_str(ItemData._signed(1.0)).is_equal("+1.0")
	assert_str(ItemData._signed(-0.25)).is_equal("-0.25")
	assert_str(ItemData._signed(0.0)).is_equal("0.0")
	assert_str(ItemData._signed(1.239)).is_equal("+1.24")
