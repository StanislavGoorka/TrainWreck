extends "res://tests/helpers/tw_test_suite.gd"


# --- DialogueData ------------------------------------------------------------------

func test_dialogue_lines_play_in_order() -> void:
	var dialogue := DialogueData.new()
	dialogue.lines = ["one", "two", "three"]
	assert_str(dialogue.get_line(0)).is_equal("one")
	assert_str(dialogue.get_line(1)).is_equal("two")
	assert_str(dialogue.get_line(2)).is_equal("three")


func test_dialogue_repeats_the_last_line_forever() -> void:
	var dialogue := DialogueData.new()
	dialogue.lines = ["one", "two"]
	assert_str(dialogue.get_line(2)).is_equal("two")
	assert_str(dialogue.get_line(100)).is_equal("two")


func test_dialogue_without_lines_returns_ellipsis() -> void:
	assert_str(DialogueData.new().get_line(0)).is_equal("...")


# --- Stat resources ----------------------------------------------------------------

func test_character_stats_defaults() -> void:
	var stats := CharacterStats.new()
	assert_float(stats.max_health).is_equal(10.0)
	assert_float(stats.speed).is_equal(300.0)
	assert_float(stats.dash_distance).is_equal(300.0)
	assert_float(stats.luck).is_equal(1.0)
	assert_float(stats.special_chance).is_equal(0.0)


func test_weapon_stats_defaults() -> void:
	var stats := WeaponStats.new()
	assert_float(stats.damage).is_equal(1.0)
	assert_float(stats.fire_rate).is_equal(1.0)
	assert_float(stats.bullet_speed).is_equal(800.0)
	assert_float(stats.shoot_range).is_equal(600.0)


func test_enemy_stats_defaults() -> void:
	var stats := EnemyStats.new()
	assert_float(stats.max_health).is_equal(5.0)
	assert_float(stats.speed).is_equal(350.0)
	assert_float(stats.damage).is_equal(1.0)
	assert_float(stats.attack_cooldown).is_equal(0.5)
	assert_int(stats.status_immunities).is_zero()


func test_boss_stats_hierarchy() -> void:
	var stats := SpinBossStats.new()
	assert_object(stats).is_instanceof(BossStats)
	assert_object(stats).is_instanceof(EnemyStats)
	assert_str(stats.boss_name).is_equal("Boss")


func test_spin_boss_defaults_form_a_valid_attack_cycle() -> void:
	var stats := SpinBossStats.new()
	assert_float(stats.spin_trigger_range).is_greater(0.0)
	assert_float(stats.spin_windup).is_greater(0.0)
	assert_float(stats.spin_duration).is_greater(0.0)
	assert_float(stats.spin_recovery).is_greater(0.0)
	assert_float(stats.spin_cooldown).is_greater(0.0)
	assert_float(stats.spin_move_speed_mult).is_between(0.0, 1.0)


func test_pickup_defaults() -> void:
	var pickup := PickupData.new()
	assert_int(pickup.type).is_equal(PickupData.PickupType.COIN)
	assert_int(pickup.rarity).is_equal(PickupData.Rarity.COMMON)
	assert_int(pickup.value).is_equal(1)
	assert_float(pickup.base_weight).is_greater(0.0)


func test_character_definition_is_locked_and_free_by_default() -> void:
	var def := CharacterDefinition.new()
	assert_bool(def.unlocked_by_default).is_false()
	assert_int(def.unlock_cost).is_zero()
	assert_array(def.starting_items).is_empty()
	assert_object(def.body_frames).is_null()
	assert_object(def.head_frames).is_null()


func test_ui_style_constants() -> void:
	assert_int(UIStyle.SPACING_SMALL).is_less(UIStyle.SPACING)
	assert_int(UIStyle.FONT_SIZE).is_less(UIStyle.FONT_SIZE_TITLE)
	assert_vector(UIStyle.ICON_SIZE).is_equal(Vector2(32, 32))
