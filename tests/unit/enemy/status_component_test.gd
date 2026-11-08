## StatusComponent is driven by calling _physics_process(delta) by hand. The tests stay
## synchronous (no frames pass), so the engine never ticks the component on its own.
extends "res://tests/helpers/tw_test_suite.gd"

var enemy: Enemy
var status: StatusComponent


func before_test() -> void:
	super.before_test()
	enemy = auto_free(Factory.enemy(Factory.enemy_stats(1000.0)))
	add_child(enemy)
	status = enemy.status


## 0.125 is exact in binary floating point, so timers reach exactly zero on their
## interval boundaries (ten steps of 0.1 would add up to slightly less than 1.0).
func _tick(seconds: float, step := 0.125) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		status._physics_process(step)
		elapsed += step


func _damage_taken() -> float:
	return enemy.stats.max_health - enemy.health


# --- Guards ------------------------------------------------------------------------

func test_apply_without_enemy_is_ignored() -> void:
	var lonely: StatusComponent = auto_free(StatusComponent.new())
	lonely.apply(StatusEffect.Type.BURN, 3)
	assert_int(lonely.burn_stacks).is_zero()


func test_apply_emits_changed() -> void:
	var events := []
	status.changed.connect(func() -> void: events.append(true))
	status.apply(StatusEffect.Type.POISON)
	assert_array(events).has_size(1)


# --- Burn --------------------------------------------------------------------------

func test_burn_stacks_add_up_to_the_cap() -> void:
	status.apply(StatusEffect.Type.BURN, 4)
	status.apply(StatusEffect.Type.BURN, 4)
	assert_int(status.burn_stacks).is_equal(8)
	status.apply(StatusEffect.Type.BURN, 5)
	assert_int(status.burn_stacks).is_equal(StatusEffect.MAX_STACKS)
	assert_int(status.burn_ticks_left).is_equal(StatusEffect.BURN_TICKS)


func test_burn_ticks_once_per_interval_scaled_by_stacks() -> void:
	status.apply(StatusEffect.Type.BURN, 4)   # 0.5 x 4 = 2 per tick
	_tick(StatusEffect.BURN_INTERVAL * 0.5)
	assert_float(_damage_taken()).is_equal(0.0)
	_tick(StatusEffect.BURN_INTERVAL * 0.5)
	assert_float(_damage_taken()).is_equal_approx(2.0, 0.001)


func test_burn_deals_at_least_the_minimum_damage() -> void:
	status.apply(StatusEffect.Type.BURN, 1)   # 0.5 x 1 < 1
	_tick(StatusEffect.BURN_INTERVAL)
	assert_float(_damage_taken()).is_equal_approx(StatusEffect.BURN_MIN_DAMAGE, 0.001)


func test_burn_runs_out_after_its_ticks() -> void:
	status.apply(StatusEffect.Type.BURN, 4)
	_tick(StatusEffect.BURN_INTERVAL * StatusEffect.BURN_TICKS)
	assert_float(_damage_taken()).is_equal_approx(2.0 * StatusEffect.BURN_TICKS, 0.001)
	assert_int(status.burn_stacks).is_zero()
	_tick(5.0)
	assert_float(_damage_taken()).is_equal_approx(2.0 * StatusEffect.BURN_TICKS, 0.001)


func test_reapplying_burn_refreshes_ticks_without_resetting_the_clock() -> void:
	status.apply(StatusEffect.Type.BURN, 2)
	_tick(StatusEffect.BURN_INTERVAL * 0.5)
	status.apply(StatusEffect.Type.BURN, 2)
	assert_int(status.burn_ticks_left).is_equal(StatusEffect.BURN_TICKS)
	_tick(StatusEffect.BURN_INTERVAL * 0.5)   # first tick still lands on time
	assert_float(_damage_taken()).is_equal_approx(2.0, 0.001)


# --- Poison ------------------------------------------------------------------------

func test_poison_deals_flat_damage_every_interval_for_its_duration() -> void:
	status.apply(StatusEffect.Type.POISON, 5)
	_tick(StatusEffect.POISON_DURATION + 3.0)
	var ticks := int(StatusEffect.POISON_DURATION / StatusEffect.POISON_INTERVAL)
	assert_float(_damage_taken()).is_equal_approx(StatusEffect.POISON_DAMAGE * ticks, 0.001)
	assert_int(status.poison_stacks).is_zero()


func test_poison_stacks_are_capped() -> void:
	status.apply(StatusEffect.Type.POISON, 8)
	status.apply(StatusEffect.Type.POISON, 8)
	assert_int(status.poison_stacks).is_equal(StatusEffect.MAX_STACKS)


func test_reapplying_poison_extends_it() -> void:
	status.apply(StatusEffect.Type.POISON)
	_tick(StatusEffect.POISON_DURATION - 1.0)
	status.apply(StatusEffect.Type.POISON)
	assert_float(status.poison_left).is_equal(StatusEffect.POISON_DURATION)


# --- Freeze ------------------------------------------------------------------------

func test_freeze_slows_movement_and_attacks() -> void:
	status.apply(StatusEffect.Type.FREEZE, 1)
	assert_float(enemy.speed_mult).is_equal(StatusEffect.FREEZE_SLOW)
	assert_float(enemy.attack_speed_mult).is_equal(StatusEffect.FREEZE_SLOW)
	assert_bool(status.frozen).is_false()


func test_freeze_slow_wears_off_without_new_stacks() -> void:
	status.apply(StatusEffect.Type.FREEZE, 3)
	_tick(StatusEffect.FREEZE_DURATION + 0.2)
	assert_int(status.freeze_stacks).is_zero()
	assert_float(enemy.speed_mult).is_equal(1.0)


func test_max_freeze_stacks_freeze_the_enemy_solid() -> void:
	status.apply(StatusEffect.Type.FREEZE, StatusEffect.MAX_STACKS)
	assert_bool(status.frozen).is_true()
	assert_bool(enemy.is_frozen).is_true()


func test_frozen_enemy_thaws_and_loses_all_stacks() -> void:
	status.apply(StatusEffect.Type.FREEZE, StatusEffect.MAX_STACKS)
	_tick(StatusEffect.FROZEN_DURATION + 0.2)
	assert_bool(status.frozen).is_false()
	assert_bool(enemy.is_frozen).is_false()
	assert_int(status.freeze_stacks).is_zero()
	assert_float(enemy.speed_mult).is_equal(1.0)


func test_freeze_cannot_be_stacked_while_frozen() -> void:
	status.apply(StatusEffect.Type.FREEZE, StatusEffect.MAX_STACKS)
	var left := status.frozen_left
	_tick(0.5)
	status.apply(StatusEffect.Type.FREEZE, 5)
	assert_float(status.frozen_left).is_equal_approx(left - 0.5, 0.001)


# --- Bleed -------------------------------------------------------------------------

func test_bleed_is_consumed_by_the_next_hit() -> void:
	status.apply(StatusEffect.Type.BLEED)
	assert_float(status.consume_bleed()).is_equal(StatusEffect.BLEED_MULTIPLIER)
	assert_float(status.consume_bleed()).is_equal(1.0)


func test_bleed_expires() -> void:
	status.apply(StatusEffect.Type.BLEED)
	_tick(StatusEffect.BLEED_DURATION + 0.2)
	assert_bool(status.bleeding).is_false()


# --- Clearing and tint -------------------------------------------------------------

func test_clear_all_resets_every_effect_and_thaws() -> void:
	status.apply(StatusEffect.Type.BURN, 3)
	status.apply(StatusEffect.Type.POISON, 3)
	status.apply(StatusEffect.Type.BLEED)
	status.apply(StatusEffect.Type.FREEZE, StatusEffect.MAX_STACKS)
	status.clear_all()
	assert_int(status.burn_stacks + status.burn_ticks_left + status.poison_stacks + status.freeze_stacks).is_zero()
	assert_bool(status.bleeding or status.frozen or enemy.is_frozen).is_false()
	assert_float(enemy.speed_mult).is_equal(1.0)


func test_ticks_stop_once_the_enemy_dies() -> void:
	enemy.health = 1.0
	status.apply(StatusEffect.Type.BURN, 2)
	status.apply(StatusEffect.Type.POISON, 2)
	_tick(StatusEffect.BURN_INTERVAL)
	assert_bool(enemy.is_dead).is_true()
	var health := enemy.health
	_tick(3.0)
	assert_float(enemy.health).is_equal(health)


func test_sprite_tint_reflects_the_strongest_effect() -> void:
	var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
	assert_that(sprite.self_modulate).is_equal(Color.WHITE)
	status.apply(StatusEffect.Type.BLEED)
	var bleed_tint := sprite.self_modulate
	status.apply(StatusEffect.Type.POISON)
	var poison_tint := sprite.self_modulate
	status.apply(StatusEffect.Type.BURN)
	var burn_tint := sprite.self_modulate
	status.apply(StatusEffect.Type.FREEZE)
	var freeze_tint := sprite.self_modulate
	status.apply(StatusEffect.Type.FREEZE, StatusEffect.MAX_STACKS)
	var frozen_tint := sprite.self_modulate
	var tints := [bleed_tint, poison_tint, burn_tint, freeze_tint, frozen_tint]
	for i in tints.size():
		assert_bool(tints[i] == Color.WHITE).is_false()
		for j in range(i + 1, tints.size()):
			assert_bool(tints[i] == tints[j]).override_failure_message("tint %d equals tint %d" % [i, j]).is_false()
	status.clear_all()
	assert_that(sprite.self_modulate).is_equal(Color.WHITE)
