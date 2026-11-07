extends "res://tests/helpers/tw_test_suite.gd"


func test_display_name(type: int, expected: String, test_parameters := [
	[StatusEffect.Type.NONE, "None"],
	[StatusEffect.Type.BURN, "Burn"],
	[StatusEffect.Type.POISON, "Poison"],
	[StatusEffect.Type.FREEZE, "Freeze"],
	[StatusEffect.Type.BLEED, "Bleed"],
]) -> void:
	assert_str(StatusEffect.display_name(type)).is_equal(expected)


func test_every_effect_has_its_own_color() -> void:
	var colors := []
	for type in [StatusEffect.Type.BURN, StatusEffect.Type.POISON, StatusEffect.Type.FREEZE, StatusEffect.Type.BLEED]:
		var color := StatusEffect.color(type)
		assert_bool(color == Color.WHITE).override_failure_message("%s uses the fallback color" % type).is_false()
		assert_array(colors).not_contains(color)
		colors.append(color)


func test_none_and_unknown_types_fall_back_to_white() -> void:
	assert_that(StatusEffect.color(StatusEffect.Type.NONE)).is_equal(Color.WHITE)
	assert_that(StatusEffect.color(99)).is_equal(Color.WHITE)


func test_bullet_color_without_effects_is_black() -> void:
	var color := StatusEffect.bullet_color({})
	assert_vector(Vector3(color.r, color.g, color.b)).is_equal(Vector3.ZERO)


func test_bullet_color_with_one_effect_matches_that_effect() -> void:
	var expected := StatusEffect.color(StatusEffect.Type.BURN)
	var color := StatusEffect.bullet_color({StatusEffect.Type.BURN: 3})
	assert_vector(Vector3(color.r, color.g, color.b)).is_equal_approx(
		Vector3(expected.r, expected.g, expected.b), Vector3.ONE * 0.001)


func test_bullet_color_with_two_effects_is_the_average() -> void:
	var a := StatusEffect.color(StatusEffect.Type.POISON)
	var b := StatusEffect.color(StatusEffect.Type.FREEZE)
	var color := StatusEffect.bullet_color({StatusEffect.Type.POISON: 1, StatusEffect.Type.FREEZE: 1})
	assert_vector(Vector3(color.r, color.g, color.b)).is_equal_approx(
		Vector3((a.r + b.r) / 2.0, (a.g + b.g) / 2.0, (a.b + b.b) / 2.0), Vector3.ONE * 0.001)


func test_bullet_color_stays_opaque() -> void:
	for statuses in [{}, {StatusEffect.Type.BURN: 1}, {StatusEffect.Type.BURN: 1, StatusEffect.Type.BLEED: 2}]:
		assert_float(StatusEffect.bullet_color(statuses).a).is_greater_equal(1.0)


func test_balance_constants_are_sane() -> void:
	assert_int(StatusEffect.MAX_STACKS).is_greater(0)
	assert_int(StatusEffect.BURN_TICKS).is_greater(0)
	assert_float(StatusEffect.BURN_INTERVAL).is_greater(0.0)
	assert_float(StatusEffect.POISON_INTERVAL).is_greater(0.0)
	assert_float(StatusEffect.POISON_DURATION).is_greater_equal(StatusEffect.POISON_INTERVAL)
	assert_float(StatusEffect.FREEZE_SLOW).is_between(0.0, 1.0)
	assert_float(StatusEffect.FROZEN_DURATION).is_greater(0.0)
	assert_float(StatusEffect.BLEED_MULTIPLIER).is_greater(1.0)
