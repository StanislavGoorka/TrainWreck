## Boss node plus the spin boss states (SpinBossChase, SpinAttack).
extends "res://tests/helpers/tw_test_suite.gd"

const SpinBossChase := preload("res://Test/Scripts/States/BossScripts/SpinBossChase.gd")
const SpinAttack := preload("res://Test/Scripts/States/BossScripts/SpinAttack.gd")

var boss: Boss
var stats: SpinBossStats
var player: Player
var requests: Array = []


func before_test() -> void:
	super.before_test()
	requests = []
	stats = Factory.spin_boss_stats({
		"boss_name": "Test Boss", "speed": 200.0, "spin_trigger_range": 160.0,
		"spin_windup": 0.5, "spin_duration": 1.0, "spin_recovery": 0.5,
		"spin_cooldown": 2.0, "spin_damage": 1.0, "spin_move_speed_mult": 0.5,
	})
	boss = _make_boss(stats)
	add_child(boss)
	var machine: StateMachine = boss.get_node("StateMachine")
	machine.process_mode = Node.PROCESS_MODE_DISABLED
	for state: State in machine.states.values():
		state.transition_requested.connect(func(state_name: StringName, _msg := {}) -> void: requests.append(state_name))

	player = auto_free(Factory.player(Factory.character_stats(100.0)))
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(1000, 0)


func _make_boss(boss_stats: EnemyStats) -> Boss:
	var result: Boss = auto_free(Factory.enemy(boss_stats, {
		"Idle": Factory.RecordingState, "Chase": SpinBossChase,
		"SpinAttack": SpinAttack, "Dead": Factory.RecordingState,
	}, Boss))
	result.remove_from_group("Enemies")   # Boss must add its groups itself
	result.add_child(Factory.area("SpinHitbox", 0, 2, 48.0))
	return result


func _state(state_name: String) -> State:
	return boss.get_node("StateMachine/" + state_name)


func _sprite() -> AnimatedSprite2D:
	return boss.get_node("AnimatedSprite2D")


# --- Boss --------------------------------------------------------------------------

func test_boss_joins_the_enemy_and_boss_groups() -> void:
	assert_bool(boss.is_in_group("Enemies")).is_true()
	assert_bool(boss.is_in_group("Bosses")).is_true()
	assert_float(boss.health).is_equal(stats.max_health)


func test_boss_with_plain_enemy_stats_still_works() -> void:
	var weak := _make_boss(Factory.enemy_stats(7.0))
	add_child(weak)
	assert_float(weak.health).is_equal(7.0)
	assert_bool(weak.is_in_group("Bosses")).is_true()


# --- SpinBossChase -----------------------------------------------------------------

func test_chase_starts_the_spin_cooldown_and_runs() -> void:
	var chase := _state("Chase")
	chase.enter()
	assert_float(chase.cooldown_left).is_equal(2.0)
	assert_str(String(_sprite().animation)).is_equal("run")


func test_chase_goes_idle_without_a_target() -> void:
	var chase := _state("Chase")
	chase.enter()
	chase.physics_update(0.1)
	assert_array(requests).contains_exactly(&"Idle")


func test_chase_moves_toward_the_target() -> void:
	var chase := _state("Chase")
	chase.enter()
	boss.target = player
	chase.physics_update(0.1)
	assert_vector(boss.velocity).is_equal_approx(Vector2(200, 0), Vector2.ONE * 0.01)


func test_chase_does_not_spin_before_the_cooldown_ends() -> void:
	var chase := _state("Chase")
	chase.enter()
	boss.target = player
	player.global_position = boss.global_position + Vector2(50, 0)
	chase.physics_update(1.0)
	assert_array(requests).is_empty()


func test_chase_spins_when_close_enough_after_the_cooldown() -> void:
	var chase := _state("Chase")
	chase.enter()
	boss.target = player
	player.global_position = boss.global_position + Vector2(100, 0)
	chase.physics_update(2.0)
	assert_array(requests).contains_exactly(&"SpinAttack")


func test_chase_keeps_chasing_when_too_far_to_spin() -> void:
	var chase := _state("Chase")
	chase.enter()
	boss.target = player
	player.global_position = boss.global_position + Vector2(800, 0)
	chase.physics_update(3.0)
	assert_array(requests).is_empty()


# --- SpinAttack --------------------------------------------------------------------

func test_spin_attack_starts_with_a_harmless_telegraph() -> void:
	boss.velocity = Vector2(40, 0)
	var spin := _state("SpinAttack")
	spin.enter()
	assert_int(spin.phase).is_equal(spin.Phase.WINDUP)
	assert_bool(boss.get_node("SpinHitbox").monitoring).is_false()
	assert_vector(boss.velocity).is_equal(Vector2.ZERO)
	assert_bool(spin.flash_tween.is_running()).is_true()


func test_windup_turns_into_a_spin_with_an_active_hitbox() -> void:
	var spin := _state("SpinAttack")
	spin.enter()
	spin.physics_update(0.25)
	assert_int(spin.phase).is_equal(spin.Phase.WINDUP)
	spin.physics_update(0.25)
	assert_int(spin.phase).is_equal(spin.Phase.SPIN)
	assert_bool(boss.get_node("SpinHitbox").monitoring).is_true()
	assert_object(spin.flash_tween).is_null()
	assert_that(_sprite().modulate).is_equal(Color.WHITE)


func test_spin_without_a_spin_animation_rotates_the_sprite() -> void:
	var spin := _state("SpinAttack")
	spin.enter()
	spin.physics_update(0.5)
	assert_object(spin.spin_tween).is_not_null()
	spin.spin_tween.custom_step(stats.spin_duration)
	assert_float(_sprite().rotation).is_equal_approx(TAU * spin.fallback_turns, 0.001)


func test_spin_uses_the_spin_animation_when_there_is_one() -> void:
	var frames := _sprite().sprite_frames
	frames.add_animation(&"spin")
	frames.add_frame(&"spin", Factory.texture(Vector2(8, 8)))
	var spin := _state("SpinAttack")
	spin.enter()
	spin.physics_update(0.5)
	assert_str(String(_sprite().animation)).is_equal("spin")
	assert_object(spin.spin_tween).is_null()


func test_spinning_boss_drifts_toward_the_target() -> void:
	boss.target = player
	var spin := _state("SpinAttack")
	spin.enter()
	spin.physics_update(0.5)
	spin.physics_update(0.1)
	assert_vector(boss.velocity).is_equal_approx(Vector2(100, 0), Vector2.ONE * 0.01)


func test_spin_hits_the_player_only_once() -> void:
	boss.target = player
	player.global_position = boss.global_position
	var spin := _state("SpinAttack")
	spin.enter()
	spin.physics_update(0.5)   # hitbox switches on
	await wait_physics_frames(3)
	spin.physics_update(0.1)
	spin.physics_update(0.1)
	spin.physics_update(0.1)
	assert_float(player.health).is_equal(100.0 - stats.spin_damage)
	assert_bool(spin.hit_landed).is_true()


func test_spin_ends_in_a_vulnerable_recovery() -> void:
	var spin := _state("SpinAttack")
	spin.enter()
	spin.physics_update(0.5)
	spin.physics_update(1.0)
	assert_int(spin.phase).is_equal(spin.Phase.RECOVER)
	assert_bool(boss.get_node("SpinHitbox").monitoring).is_false()
	assert_float(_sprite().rotation).is_equal(0.0)
	boss.velocity = Vector2(30, 0)
	spin.physics_update(0.1)
	assert_vector(boss.velocity).is_equal(Vector2.ZERO)


func test_recovery_returns_to_the_chase() -> void:
	var spin := _state("SpinAttack")
	spin.enter()
	spin.physics_update(0.5)
	spin.physics_update(1.0)
	spin.physics_update(0.25)
	assert_array(requests).is_empty()
	spin.physics_update(0.25)
	assert_array(requests).contains_exactly(&"Chase")


func test_leaving_the_spin_cleans_up_visuals_and_hitbox() -> void:
	var spin := _state("SpinAttack")
	spin.enter()
	spin.physics_update(0.5)
	spin.spin_tween.custom_step(0.3)
	spin.exit()
	assert_bool(boss.get_node("SpinHitbox").monitoring).is_false()
	assert_float(_sprite().rotation).is_equal(0.0)
	assert_that(_sprite().modulate).is_equal(Color.WHITE)
	assert_object(spin.spin_tween).is_null()


func test_a_new_spin_resets_the_hit() -> void:
	var spin := _state("SpinAttack")
	spin.enter()
	spin.hit_landed = true
	spin.exit()
	spin.enter()
	assert_bool(spin.hit_landed).is_false()
	assert_float(spin.phase_time).is_equal(0.0)
