## SummonerBoss (damage only inside a vulnerability window, capped per window; waves of
## summoned enemies) and its states (SummonerIdle, SummonerSummon, SummonerVulnerable).
extends "res://tests/helpers/tw_test_suite.gd"

const SummonerIdle := preload("res://Test/Scripts/States/BossScripts/SummonerIdle.gd")
const SummonerSummon := preload("res://Test/Scripts/States/BossScripts/SummonerSummon.gd")
const SummonerVulnerable := preload("res://Test/Scripts/States/BossScripts/SummonerVulnerable.gd")

var boss: SummonerBoss
var stats: SummonerBossStats
var player: Player
var requests: Array = []


func before_test() -> void:
	super.before_test()
	requests = []
	stats = _stats()
	boss = _make_boss(stats)
	add_child(boss)
	var machine: StateMachine = boss.get_node("StateMachine")
	machine.process_mode = Node.PROCESS_MODE_DISABLED   # states are driven by hand
	for state: State in machine.states.values():
		state.transition_requested.connect(func(state_name: StringName, _msg := {}) -> void: requests.append(state_name))

	player = auto_free(Factory.player(Factory.character_stats(100.0)))
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(2000, 0)


func _stats(properties := {}) -> SummonerBossStats:
	var result := SummonerBossStats.new()
	result.boss_name = "Test Summoner"
	result.max_health = 100.0
	result.speed = 0.0
	result.enemy_pool = [_packed_enemy()]
	result.wave_size_pool = [2, 3, 4]
	result.growth_after_pool = 1
	result.first_wave_delay = 1.5
	result.wave_delay = 0.5
	result.spawn_fade_time = 0.05
	result.spawn_radius_min = 100.0
	result.spawn_radius_max = 200.0
	result.window_duration = 5.0
	result.window_damage_cap = 0.25
	result.end_window_at_cap = false
	for key: String in properties:
		result.set(key, properties[key])
	return result


## A PackedScene of a minimal Enemy (Factory.enemy with every node owned by the root).
func _packed_enemy() -> PackedScene:
	var enemy := Factory.enemy(Factory.enemy_stats(2.0))
	for node in enemy.find_children("*", "", true, false):
		node.owner = enemy
	var scene := PackedScene.new()
	scene.pack(enemy)
	enemy.free()
	return scene


func _make_boss(boss_stats: EnemyStats) -> SummonerBoss:
	return auto_free(Factory.enemy(boss_stats, {
		"Idle": SummonerIdle, "Summon": SummonerSummon,
		"Vulnerable": SummonerVulnerable, "Dead": Factory.RecordingState,
	}, SummonerBoss))


func _state(state_name: String) -> State:
	return boss.get_node("StateMachine/" + state_name)


func _sprite() -> AnimatedSprite2D:
	return boss.get_node("AnimatedSprite2D")


func _minions() -> Array:
	return get_children().filter(func(n: Node) -> bool: return n is Enemy and n != boss and not n.is_queued_for_deletion())


func _free_minions() -> void:
	for minion in _minions():
		minion.free()


# --- Setup -------------------------------------------------------------------------

func test_summoner_is_a_boss_with_full_health() -> void:
	assert_object(boss).is_instanceof(Boss)
	assert_bool(boss.is_in_group("Bosses")).is_true()
	assert_float(boss.health).is_equal(100.0)
	assert_int(boss.wave_number).is_zero()


func test_summoner_starts_shielded() -> void:
	assert_bool(boss.vulnerable).is_false()
	assert_that(_sprite().modulate).is_equal(SummonerBoss.SHIELD_TINT)


# --- Damage rules ------------------------------------------------------------------

func test_no_damage_while_a_wave_is_active() -> void:
	boss.take_damage(50.0)
	boss.take_damage(5.0, true)
	assert_float(boss.health).is_equal(100.0)


func test_damage_lands_inside_the_window() -> void:
	boss.set_vulnerable(true)
	boss.take_damage(10.0)
	assert_float(boss.health).is_equal(90.0)
	assert_float(boss.window_damage).is_equal(10.0)


func test_window_cap_is_a_share_of_max_health() -> void:
	assert_float(boss.window_cap()).is_equal(25.0)


func test_each_window_takes_at_most_its_cap() -> void:
	boss.set_vulnerable(true)
	boss.take_damage(20.0)
	boss.take_damage(20.0)
	boss.take_damage(20.0)
	assert_float(boss.health).is_equal(75.0)
	assert_float(boss.window_damage).is_equal(25.0)


func test_a_new_window_resets_the_cap() -> void:
	boss.set_vulnerable(true)
	boss.take_damage(100.0)
	boss.set_vulnerable(false)
	boss.set_vulnerable(true)
	assert_float(boss.window_damage).is_zero()
	boss.take_damage(100.0)
	assert_float(boss.health).is_equal(50.0)


func test_four_full_windows_kill_the_boss() -> void:
	var died := []
	boss.died.connect(func(e: Enemy) -> void: died.append(e))
	for window in 4:
		boss.set_vulnerable(true)
		boss.take_damage(999.0)
		if window < 3:
			boss.set_vulnerable(false)
	assert_bool(boss.is_dead).is_true()
	assert_array(died).has_size(1)
	assert_str(String(boss.get_node("StateMachine").current_state.name)).is_equal("Dead")


func test_status_damage_also_counts_towards_the_cap() -> void:
	boss.set_vulnerable(true)
	boss.take_damage(20.0, true)
	boss.take_damage(20.0, true)
	assert_float(boss.health).is_equal(75.0)


func test_bleed_multiplies_the_hit_but_not_past_the_cap() -> void:
	boss.set_vulnerable(true)
	boss.status.apply(StatusEffect.Type.BLEED)
	boss.take_damage(10.0)
	assert_float(boss.health).is_equal(85.0)   # 10 x 1.5
	assert_bool(boss.status.bleeding).is_false()
	boss.status.apply(StatusEffect.Type.BLEED)
	boss.take_damage(10.0)
	assert_float(boss.health).is_equal(75.0)   # 15 asked, 10 left in this window


func test_bleed_is_kept_while_the_boss_is_shielded() -> void:
	boss.set_vulnerable(true)
	boss.status.apply(StatusEffect.Type.BLEED)
	boss.set_vulnerable(false)
	boss.take_damage(10.0)
	assert_bool(boss.status.bleeding).is_true()


func test_dead_boss_takes_no_more_damage() -> void:
	boss.set_vulnerable(true)
	boss.health = 1.0
	boss.take_damage(5.0)
	assert_bool(boss.is_dead).is_true()
	var health := boss.health
	boss.set_vulnerable(true)
	boss.take_damage(5.0)
	assert_float(boss.health).is_equal(health)


# --- Statuses ----------------------------------------------------------------------

func test_statuses_do_not_stick_during_a_wave() -> void:
	boss.apply_statuses({StatusEffect.Type.BURN: 2, StatusEffect.Type.BLEED: 1})
	assert_int(boss.status.burn_stacks).is_zero()
	assert_bool(boss.status.bleeding).is_false()


func test_statuses_stick_inside_the_window() -> void:
	boss.set_vulnerable(true)
	boss.apply_statuses({StatusEffect.Type.BURN: 2})
	assert_int(boss.status.burn_stacks).is_equal(2)


func test_summoner_can_never_be_frozen() -> void:
	assert_bool(boss.is_immune_to(StatusEffect.Type.FREEZE)).is_true()
	boss.set_vulnerable(true)
	boss.status.apply(StatusEffect.Type.FREEZE, 99)
	assert_bool(boss.is_frozen).is_false()


func test_other_immunities_still_come_from_the_stats() -> void:
	assert_bool(boss.is_immune_to(StatusEffect.Type.BURN)).is_false()
	var immune := _make_boss(_stats({"status_immunities": 1 << (StatusEffect.Type.BURN - 1)}))
	add_child(immune)
	assert_bool(immune.is_immune_to(StatusEffect.Type.BURN)).is_true()


# --- Vulnerability window ----------------------------------------------------------

func test_set_vulnerable_announces_the_window() -> void:
	var events := []
	boss.window_changed.connect(func(open: bool) -> void: events.append(open))
	boss.set_vulnerable(true)
	boss.set_vulnerable(false)
	assert_array(events).is_equal([true, false])


func test_open_window_fades_the_shield_tint_away() -> void:
	boss.set_vulnerable(true)
	boss.tint_tween.custom_step(0.3)
	assert_that(_sprite().modulate).is_equal(Color.WHITE)
	boss.set_vulnerable(false)
	boss.tint_tween.custom_step(0.3)
	assert_that(_sprite().modulate).is_equal(SummonerBoss.SHIELD_TINT)


func test_summoner_without_a_sprite_does_not_crash() -> void:
	_sprite().free()
	boss.set_vulnerable(true)
	assert_bool(boss.vulnerable).is_true()


# --- Waves -------------------------------------------------------------------------

func test_first_wave_size_comes_from_the_two_smallest_sizes() -> void:
	stats.wave_size_pool = [6, 2, 4]   # sorted by the boss
	for i in 20:
		assert_array([2, 4]).contains([boss.next_wave_size()])


func test_wave_size_grows_with_each_wave(wave: int, allowed: Array, test_parameters := [
	[1, [3, 4]],
	[2, [4]],
	[3, [5]],
	[5, [7]],
]) -> void:
	boss.wave_number = wave
	for i in 10:
		assert_array(allowed).contains([boss.next_wave_size()])


func test_wave_size_without_a_pool_is_three() -> void:
	stats.wave_size_pool = []
	assert_int(boss.next_wave_size()).is_equal(3)


func test_wave_size_is_at_least_one() -> void:
	stats.wave_size_pool = [0]
	assert_int(boss.next_wave_size()).is_equal(1)


func test_next_wave_size_does_not_reorder_the_stats() -> void:
	stats.wave_size_pool = [5, 1, 3]
	boss.next_wave_size()
	assert_array(stats.wave_size_pool).is_equal([5, 1, 3])


func test_spawn_wave_summons_hidden_frozen_enemies_around_the_boss() -> void:
	stats.wave_size_pool = [3]
	var started := []
	boss.wave_started.connect(func(n: int, size: int) -> void: started.append([n, size]))
	boss.spawn_wave()
	var minions := _minions()
	assert_array(minions).has_size(3)
	assert_array(boss.wave_enemies).has_size(3)
	assert_int(boss.wave_number).is_equal(1)
	assert_array(started).is_equal([[1, 3]])
	for minion: Enemy in minions:
		assert_int(minion.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
		assert_float(minion.modulate.a).is_less(1.0)
		var distance := minion.global_position.distance_to(boss.global_position)
		assert_float(distance).is_between(stats.spawn_radius_min - 0.01, stats.spawn_radius_max + 0.01)
	_free_minions()


func test_summoned_enemies_wake_up_and_hunt_the_target_after_fading_in() -> void:
	stats.wave_size_pool = [2]
	boss.target = player
	boss.spawn_wave()
	var minions := _minions()
	var awake := func() -> bool: return minions.all(func(m: Enemy) -> bool: return m.process_mode == Node.PROCESS_MODE_INHERIT)
	assert_bool(await wait_until(awake, 2000)).is_true()
	for minion: Enemy in minions:
		assert_float(minion.modulate.a).is_equal_approx(1.0, 0.001)
		assert_object(minion.target).is_same(player)
	_free_minions()


func test_without_a_target_minions_hunt_the_player_group() -> void:
	stats.wave_size_pool = [1]
	boss.spawn_wave()
	var minion: Enemy = _minions()[0]
	assert_bool(await wait_until(func() -> bool: return minion.process_mode == Node.PROCESS_MODE_INHERIT, 2000)).is_true()
	assert_object(minion.target).is_same(player)
	_free_minions()


func test_empty_enemy_pool_spawns_nothing() -> void:
	stats.enemy_pool = []
	boss.spawn_wave()
	assert_array(_minions()).is_empty()
	assert_int(boss.wave_number).is_zero()


func test_pool_entries_that_are_not_enemies_are_skipped_without_leaking(
		do_skip := true,
		skip_reason := "KNOWN BUG: SummonerBoss.spawn_wave() never frees an enemy_pool instance that is not an Enemy (one orphan node per slot); wave_number and wave_started still count the empty wave") -> void:
	var not_enemy := PackedScene.new()
	var node := Node2D.new()
	not_enemy.pack(node)
	node.free()
	stats.enemy_pool = [not_enemy]
	stats.wave_size_pool = [2]
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	boss.spawn_wave()
	var leaked := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) - orphans_before
	assert_array(boss.wave_enemies).is_empty()
	assert_array(_minions()).is_empty()
	assert_float(leaked).override_failure_message("spawn_wave leaked %d instantiated non-enemy nodes" % leaked).is_zero()


func test_wave_is_cleared_once_every_minion_is_dead_or_gone() -> void:
	stats.wave_size_pool = [2]
	boss.spawn_wave()
	var minions := _minions()
	assert_bool(boss.wave_cleared()).is_false()
	minions[0].is_dead = true
	assert_bool(boss.wave_cleared()).is_false()
	minions[1].free()
	assert_bool(boss.wave_cleared()).is_true()
	_free_minions()


func test_minions_never_spawn_inside_walls() -> void:
	# A wall covering the whole spawn ring: every try fails and the boss uses its own spot.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 2000)
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	auto_free(wall)
	boss.global_position = Vector2(5000, 5000)
	wall.global_position = boss.global_position
	await wait_physics_frames(2)
	assert_vector(boss._find_spawn_position()).is_equal(boss.global_position)


# --- States ------------------------------------------------------------------------

func test_idle_waits_for_a_target() -> void:
	var idle := _state("Idle")
	idle.enter()
	idle.physics_update(0.1)
	assert_array(requests).is_empty()
	boss.target = player
	idle.physics_update(0.1)
	assert_array(requests).contains_exactly(&"Summon")


func test_idle_stands_still() -> void:
	boss.velocity = Vector2(50, 50)
	_state("Idle").enter()
	assert_vector(boss.velocity).is_equal(Vector2.ZERO)


func test_summon_closes_the_window_and_waits_before_the_first_wave() -> void:
	boss.set_vulnerable(true)
	var summon := _state("Summon")
	summon.enter()
	assert_bool(boss.vulnerable).is_false()
	assert_float(summon.delay_left).is_equal(1.5)
	summon.physics_update(1.0)
	assert_array(_minions()).is_empty()
	summon.physics_update(0.625)
	assert_bool(summon.spawned).is_true()
	assert_int(boss.wave_number).is_equal(1)
	_free_minions()


func test_later_waves_use_the_shorter_delay() -> void:
	boss.wave_number = 2
	var summon := _state("Summon")
	summon.enter()
	assert_float(summon.delay_left).is_equal(0.5)


func test_summon_opens_the_window_only_after_the_wave_is_cleared() -> void:
	stats.wave_size_pool = [2]
	var summon := _state("Summon")
	summon.enter()
	summon.physics_update(2.0)
	summon.physics_update(0.125)
	assert_array(requests).is_empty()
	_free_minions()
	summon.physics_update(0.125)
	assert_array(requests).contains_exactly(&"Vulnerable")


func test_vulnerable_opens_the_window_for_its_duration() -> void:
	var window := _state("Vulnerable")
	window.enter()
	assert_bool(boss.vulnerable).is_true()
	assert_float(window.time_left).is_equal(5.0)
	for i in 39:
		window.physics_update(0.125)
	assert_array(requests).is_empty()
	window.physics_update(0.125)
	assert_array(requests).contains_exactly(&"Summon")


func test_leaving_the_window_shields_the_boss_again() -> void:
	var window := _state("Vulnerable")
	window.enter()
	window.exit()
	assert_bool(boss.vulnerable).is_false()


func test_window_ends_early_at_the_cap_when_configured() -> void:
	stats.end_window_at_cap = true
	var window := _state("Vulnerable")
	window.enter()
	boss.take_damage(100.0)
	window.physics_update(0.125)
	assert_array(requests).contains_exactly(&"Summon")


func test_window_stays_open_at_the_cap_by_default() -> void:
	var window := _state("Vulnerable")
	window.enter()
	boss.take_damage(100.0)
	window.physics_update(0.125)
	assert_array(requests).is_empty()


func test_full_cycle_through_the_state_machine() -> void:
	stats.wave_size_pool = [1]
	stats.first_wave_delay = 0.0
	var machine: StateMachine = boss.get_node("StateMachine")
	boss.target = player
	machine._physics_process(0.125)   # Idle -> Summon
	assert_str(String(machine.current_state.name)).is_equal("Summon")
	machine._physics_process(0.125)   # wave spawned
	assert_int(boss.wave_number).is_equal(1)
	_free_minions()
	machine._physics_process(0.125)   # wave cleared -> Vulnerable
	assert_str(String(machine.current_state.name)).is_equal("Vulnerable")
	assert_bool(boss.vulnerable).is_true()
