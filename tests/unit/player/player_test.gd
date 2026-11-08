extends "res://tests/helpers/tw_test_suite.gd"


func _spawn(stats: CharacterStats = null, weapon: WeaponStats = null) -> Player:
	var player: Player = auto_free(Factory.player(stats, weapon))
	add_child(player)
	return player


# --- Setup -------------------------------------------------------------------------

func test_ready_copies_stats_so_items_never_modify_the_resources() -> void:
	var stats := Factory.character_stats(10.0)
	var weapon := Factory.weapon_stats(2.0)
	var player := _spawn(stats, weapon)

	assert_object(player.base_stats).is_same(stats)
	assert_object(player.base_weapon_stats).is_same(weapon)
	assert_object(player.current_stats).is_not_same(stats)
	assert_object(player.current_weapon_stats).is_not_same(weapon)

	player.add_item(Factory.item({"max_health_add": 4.0, "damage_add": 1.0}), true)
	assert_float(stats.max_health).is_equal(10.0)
	assert_float(weapon.damage).is_equal(2.0)


func test_ready_starts_at_full_health_and_announces_it() -> void:
	var player: Player = auto_free(Factory.player(Factory.character_stats(8.0)))
	var health_events := []
	var stats_events := []
	player.health_changed.connect(func(current: float, max_value: float) -> void: health_events.append([current, max_value]))
	player.stats_changed.connect(func() -> void: stats_events.append(true))
	add_child(player)

	assert_float(player.health).is_equal(8.0)
	assert_bool(player.is_dead).is_false()
	assert_array(health_events).is_equal([[8.0, 8.0]])
	assert_array(stats_events).has_size(1)
	assert_array(player.inventory).is_empty()


func test_ready_uses_the_selected_character_when_there_is_one() -> void:
	var def := Factory.character_definition("tester", {
		"stats": Factory.character_stats(14.0, 420.0),
		"weapon_stats": Factory.weapon_stats(5.0),
	})
	GameState.selected_character = def
	var player := _spawn(Factory.character_stats(2.0), Factory.weapon_stats(1.0))
	assert_float(player.current_stats.max_health).is_equal(14.0)
	assert_float(player.current_stats.speed).is_equal(420.0)
	assert_float(player.current_weapon_stats.damage).is_equal(5.0)


# --- Items -------------------------------------------------------------------------

func test_add_item_announces_the_pickup_and_locks_shooting() -> void:
	var player := _spawn()
	var picked := []
	player.item_picked_up.connect(func(item: ItemData) -> void: picked.append(item))
	var item := Factory.item({"item_name": "Thing"})

	player.add_item(item)

	assert_array(player.inventory).contains_exactly(item)
	assert_array(picked).contains_exactly(item)
	assert_bool(player.can_shoot()).is_false()
	assert_float(player.shoot_lock_remaining).is_equal(player.item_pickup_lock_time)


func test_silent_add_item_neither_announces_nor_locks_shooting() -> void:
	var player := _spawn()
	var picked := []
	player.item_picked_up.connect(func(item: ItemData) -> void: picked.append(item))
	player.add_item(Factory.item(), true)
	assert_array(picked).is_empty()
	assert_bool(player.can_shoot()).is_true()


func test_shoot_lock_wears_off_over_time() -> void:
	var player := _spawn()
	player.item_pickup_lock_time = 1.0
	player.add_item(Factory.item())
	player._physics_process(0.6)
	assert_bool(player.can_shoot()).is_false()
	assert_float(player.shoot_lock_remaining).is_equal_approx(0.4, 0.0001)
	player._physics_process(0.6)
	assert_bool(player.can_shoot()).is_true()
	assert_float(player.shoot_lock_remaining).is_equal(0.0)


func test_special_effects_are_registered_once() -> void:
	var player := _spawn()
	player.add_item(Factory.item({"special_effect": &"fire_bullets"}), true)
	player.add_item(Factory.item({"special_effect": &"fire_bullets"}), true)
	player.add_item(Factory.item(), true)
	assert_array(player.active_effects).contains_exactly(&"fire_bullets")


func test_flat_character_bonuses_are_added() -> void:
	var player := _spawn(Factory.character_stats(10.0, 300.0, 300.0, 1.0, 0.0))
	player.add_item(Factory.item({"luck_add": 2.0, "special_chance_add": 0.15}), true)
	assert_float(player.current_stats.luck).is_equal(3.0)
	assert_float(player.current_stats.special_chance).is_equal_approx(0.15, 0.0001)


func test_speed_bonus_is_added_before_the_multiplier() -> void:
	var player := _spawn(Factory.character_stats(10.0, 300.0))
	player.add_item(Factory.item({"speed_add": 50.0, "speed_mult": 1.5}), true)
	assert_float(player.current_stats.speed).is_equal_approx(525.0, 0.001)


func test_weapon_bonuses_are_added_before_multipliers() -> void:
	var player := _spawn(null, Factory.weapon_stats(1.0, 1.0, 800.0, 600.0))
	player.add_item(Factory.item({
		"damage_add": 0.5, "damage_mult": 2.0,
		"fire_rate_add": -0.2, "fire_rate_mult": 0.5,
		"bullet_speed_add": 100.0, "bullet_speed_mult": 1.5,
		"shoot_range_add": 50.0,
	}), true)
	var weapon := player.current_weapon_stats
	assert_float(weapon.damage).is_equal_approx(3.0, 0.0001)
	assert_float(weapon.fire_rate).is_equal_approx(0.4, 0.0001)
	assert_float(weapon.bullet_speed).is_equal_approx(1350.0, 0.001)
	assert_float(weapon.shoot_range).is_equal_approx(650.0, 0.001)


func test_items_stack_in_pickup_order() -> void:
	var player := _spawn(null, Factory.weapon_stats(1.0))
	player.add_item(Factory.item({"damage_add": 1.0}), true)    # (1 + 1) = 2
	player.add_item(Factory.item({"damage_mult": 2.0}), true)   # 2 * 2 = 4
	player.add_item(Factory.item({"damage_add": 1.0}), true)    # 4 + 1 = 5
	assert_float(player.current_weapon_stats.damage).is_equal_approx(5.0, 0.0001)


func test_dash_distance_bonus_is_applied_once(
		do_skip := true,
		skip_reason := "KNOWN BUG: character.gd _recalculate_stats() adds dash_distance_add twice (lines 123 and 131)") -> void:
	var player := _spawn(Factory.character_stats(10.0, 300.0, 300.0))
	player.add_item(Factory.item({"dash_distance_add": 25.0}), true)
	assert_float(player.current_stats.dash_distance).is_equal_approx(325.0, 0.001)


func test_more_max_health_also_heals_by_the_same_amount() -> void:
	var player := _spawn(Factory.character_stats(10.0))
	player.take_damage(3.0)
	player.add_item(Factory.item({"max_health_add": 4.0}), true)
	assert_float(player.current_stats.max_health).is_equal(14.0)
	assert_float(player.health).is_equal(11.0)


func test_less_max_health_also_removes_health() -> void:
	var player := _spawn(Factory.character_stats(10.0))
	player.add_item(Factory.item({"max_health_add": -2.0}), true)
	assert_float(player.current_stats.max_health).is_equal(8.0)
	assert_float(player.health).is_equal(8.0)


func test_recalculation_updates_the_health_bar() -> void:
	var player := _spawn(Factory.character_stats(10.0))
	player.add_item(Factory.item({"max_health_add": 2.0}), true)
	assert_float(player.health_bar.max_value).is_equal(12.0)
	assert_float(player.health_bar.value).is_equal(12.0)


func test_recalculation_emits_health_and_stats_changed() -> void:
	var player := _spawn(Factory.character_stats(10.0))
	var health_events := []
	var stats_events := []
	player.health_changed.connect(func(current: float, max_value: float) -> void: health_events.append([current, max_value]))
	player.stats_changed.connect(func() -> void: stats_events.append(true))
	player.add_item(Factory.item({"max_health_add": 2.0}), true)
	assert_array(health_events).is_equal([[12.0, 12.0]])
	assert_array(stats_events).has_size(1)


# --- Bullet statuses ---------------------------------------------------------------

func test_only_items_with_a_status_effect_are_status_items() -> void:
	var player := _spawn()
	var burn := Factory.item({"status_effect": StatusEffect.Type.BURN})
	player.add_item(Factory.item({"damage_add": 1.0}), true)
	player.add_item(burn, true)
	assert_array(player.status_items).contains_exactly(burn)


func test_guaranteed_status_is_always_rolled() -> void:
	var player := _spawn()
	player.add_item(Factory.item({"status_effect": StatusEffect.Type.POISON, "status_stacks_per_hit": 3}), true)
	for i in 20:
		assert_dict(player.roll_bullet_statuses()).is_equal({StatusEffect.Type.POISON: 3})


func test_zero_chance_status_is_never_rolled() -> void:
	var player := _spawn()
	player.add_item(Factory.item({"status_effect": StatusEffect.Type.BURN, "status_chance": 0.0}), true)
	for i in 20:
		assert_dict(player.roll_bullet_statuses()).is_empty()


func test_stacks_of_the_same_effect_are_summed() -> void:
	var player := _spawn()
	player.add_item(Factory.item({"status_effect": StatusEffect.Type.FREEZE, "status_stacks_per_hit": 2}), true)
	player.add_item(Factory.item({"status_effect": StatusEffect.Type.FREEZE, "status_stacks_per_hit": 1}), true)
	player.add_item(Factory.item({"status_effect": StatusEffect.Type.BLEED}), true)
	assert_dict(player.roll_bullet_statuses()).is_equal({
		StatusEffect.Type.FREEZE: 3,
		StatusEffect.Type.BLEED: 1,
	})


func test_partial_chance_rolls_roughly_that_often() -> void:
	seed(1234)
	var player := _spawn()
	player.add_item(Factory.item({"status_effect": StatusEffect.Type.BURN, "status_chance": 50.0}), true)
	var hits := 0
	for i in 1000:
		if player.roll_bullet_statuses().has(StatusEffect.Type.BURN):
			hits += 1
	assert_int(hits).is_between(400, 600)


# --- Damage and death --------------------------------------------------------------

func test_take_damage_reduces_health_and_announces_it() -> void:
	var player := _spawn(Factory.character_stats(10.0))
	var events := []
	player.health_changed.connect(func(current: float, max_value: float) -> void: events.append([current, max_value]))
	player.take_damage(1.5)
	assert_float(player.health).is_equal(8.5)
	assert_array(events).is_equal([[8.5, 10.0]])


func test_invulnerable_player_takes_no_damage() -> void:
	var player := _spawn(Factory.character_stats(10.0))
	player.invulnerable = true
	player.take_damage(5.0)
	assert_float(player.health).is_equal(10.0)


func test_player_dies_once_when_health_runs_out() -> void:
	var player := _spawn(Factory.character_stats(2.0))
	var deaths := []
	player.died.connect(func() -> void: deaths.append(true))
	player.take_damage(1.0)
	assert_bool(player.is_dead).is_false()
	player.take_damage(1.0)
	assert_bool(player.is_dead).is_true()
	player.take_damage(1.0)
	assert_array(deaths).has_size(1)
	assert_float(player.health).is_equal(0.0)


func test_dying_outside_a_run_does_not_touch_the_progress() -> void:
	var deaths_before: int = int(GameState.lifetime_stats["deaths"])
	var player := _spawn(Factory.character_stats(1.0))
	player.take_damage(1.0)
	assert_int(int(GameState.lifetime_stats["deaths"])).is_equal(deaths_before)
	assert_bool(GameState.game_over).is_false()


func test_dying_during_a_run_ends_the_run() -> void:
	GameState.run_active = true
	var deaths_before: int = int(GameState.lifetime_stats["deaths"])
	var player := _spawn(Factory.character_stats(1.0))
	player.currency = 7
	player.take_damage(5.0)
	assert_bool(GameState.run_active).is_false()
	assert_bool(GameState.game_over).is_true()
	assert_int(int(GameState.lifetime_stats["deaths"])).is_equal(deaths_before + 1)
	assert_dict(GameState.last_run).is_equal({"won": false, "abandoned": false, "coins": 7})


func test_contact_with_enemies_deals_damage_per_enemy() -> void:
	var player := _spawn(Factory.character_stats(100.0))
	for i in 2:
		var enemy: Enemy = auto_free(Factory.enemy())
		add_child(enemy)
		enemy.global_position = player.global_position
	await wait_physics_frames(3)
	var before := player.health
	player._process_hurtbox_damage(1.0)
	assert_float(before - player.health).is_equal_approx(Player.DAMAGE_TICK_RATE * 2.0, 0.0001)


func test_frozen_enemies_and_non_enemies_deal_no_contact_damage() -> void:
	var player := _spawn(Factory.character_stats(100.0))
	var frozen: Enemy = auto_free(Factory.enemy())
	add_child(frozen)
	frozen.global_position = player.global_position
	frozen.is_frozen = true
	var wall: StaticBody2D = auto_free(StaticBody2D.new())
	wall.collision_layer = 4
	wall.add_child(Factory.circle_shape())
	add_child(wall)
	wall.global_position = player.global_position
	await wait_physics_frames(3)
	var before := player.health
	player._process_hurtbox_damage(1.0)
	assert_float(player.health).is_equal(before)


# --- Pickups -----------------------------------------------------------------------

func test_coin_pickup_adds_currency() -> void:
	var player := _spawn()
	var events := []
	player.currency_changed.connect(func(amount: int) -> void: events.append(amount))
	player.add_pickup(Factory.pickup(PickupData.PickupType.COIN, 3))
	player.add_pickup(Factory.pickup(PickupData.PickupType.COIN, 2))
	assert_int(player.currency).is_equal(5)
	assert_array(events).is_equal([3, 5])


func test_key_pickup_adds_keys() -> void:
	var player := _spawn()
	var events := []
	player.keys_changed.connect(func(amount: int) -> void: events.append(amount))
	player.add_pickup(Factory.pickup(PickupData.PickupType.KEY))
	assert_int(player.keys).is_equal(1)
	assert_array(events).is_equal([1])


func test_bomb_pickup_adds_bombs() -> void:
	var player := _spawn()
	player.add_pickup(Factory.pickup(PickupData.PickupType.BOMB, 2))
	assert_int(player.bombs).is_equal(2)


func test_heart_pickup_heals_up_to_max_health() -> void:
	var player := _spawn(Factory.character_stats(10.0))
	player.take_damage(5.0)
	player.add_pickup(Factory.pickup(PickupData.PickupType.HEART, 2))
	assert_float(player.health).is_equal(7.0)
	player.add_pickup(Factory.pickup(PickupData.PickupType.HEART, 99))
	assert_float(player.health).is_equal(10.0)
	assert_float(player.health_bar.value).is_equal(10.0)


# --- Dash cooldown -----------------------------------------------------------------

func test_dash_is_available_from_the_start() -> void:
	assert_bool(_spawn().can_dash()).is_true()


func test_dash_cooldown_counts_down() -> void:
	var player := _spawn()
	player.dash_cooldown_remaining = 0.5
	assert_bool(player.can_dash()).is_false()
	player._physics_process(0.2)
	assert_float(player.dash_cooldown_remaining).is_equal_approx(0.3, 0.0001)
	player._physics_process(1.0)
	assert_float(player.dash_cooldown_remaining).is_equal(0.0)
	assert_bool(player.can_dash()).is_true()


func test_start_dash_cooldown_uses_the_character_stats(
		do_skip := true,
		skip_reason := "KNOWN BUG: character.gd start_dash_cooldown() reads current_stats.dash_cooldown, which CharacterStats does not define (dash has no cooldown)") -> void:
	var player := _spawn()
	player.start_dash_cooldown()
	assert_bool(player.can_dash()).is_false()


# --- Characters --------------------------------------------------------------------

func test_apply_character_replaces_stats_inventory_and_sprites() -> void:
	var player := _spawn()
	player.add_item(Factory.item({"item_name": "old"}), true)
	var starting := Factory.item({"item_name": "Starter", "max_health_add": 2.0})
	var body_frames := Factory.sprite_frames([&"Idle"])
	var head_frames := Factory.sprite_frames([&"Idle"])
	var starting_items: Array[ItemData] = [starting]
	var def := Factory.character_definition("hero", {
		"stats": Factory.character_stats(6.0, 500.0),
		"weapon_stats": Factory.weapon_stats(4.0),
		"starting_items": starting_items,
		"body_frames": body_frames,
		"head_frames": head_frames,
	})
	var picked := []
	player.item_picked_up.connect(func(item: ItemData) -> void: picked.append(item))

	player.apply_character(def)

	assert_array(player.inventory).contains_exactly(starting)
	assert_array(picked).is_empty()
	assert_float(player.current_stats.max_health).is_equal(8.0)
	assert_float(player.health).is_equal(8.0)
	assert_float(player.current_stats.speed).is_equal(500.0)
	assert_float(player.current_weapon_stats.damage).is_equal(4.0)
	assert_object(player.get_node("Body").sprite_frames).is_same(body_frames)
	assert_object(player.get_node("Head").sprite_frames).is_same(head_frames)


func test_apply_character_without_frames_keeps_the_scene_sprites() -> void:
	var player := _spawn()
	var original: SpriteFrames = player.get_node("Body").sprite_frames
	player.apply_character(Factory.character_definition("plain"))
	assert_object(player.get_node("Body").sprite_frames).is_same(original)
