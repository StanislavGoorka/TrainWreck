## Walker AI states (Idle, Chase, Attack, Death). The state machine's own processing is
## switched off, so the tests call the states directly and control every step.
extends "res://tests/helpers/tw_test_suite.gd"

const IdleState := preload("res://Test/Scripts/States/Walker/idle.gd")
const ChaseState := preload("res://Test/Scripts/States/Walker/chase.gd")
const AttackState := preload("res://Test/Scripts/States/Walker/attack.gd")
const DeathState := preload("res://Test/Scripts/States/Walker/death.gd")

var enemy: Enemy
var player: Player
var requests: Array = []


func before_test() -> void:
	super.before_test()
	requests = []
	enemy = auto_free(Factory.enemy(Factory.enemy_stats(10.0, 120.0, 1.5, 0.5), {
		"Idle": IdleState, "Chase": ChaseState, "Attack": AttackState, "Dead": DeathState,
	}))
	add_child(enemy)
	var machine: StateMachine = enemy.get_node("StateMachine")
	machine.process_mode = Node.PROCESS_MODE_DISABLED
	for state: State in machine.states.values():
		state.transition_requested.connect(func(state_name: StringName, _msg := {}) -> void: requests.append(state_name))

	player = auto_free(Factory.player(Factory.character_stats(100.0)))
	add_child(player)
	player.set_physics_process(false)   # no contact damage, so health only changes through attacks
	player.global_position = Vector2(1000, 0)


func _state(state_name: String) -> State:
	return enemy.get_node("StateMachine/" + state_name)


func _put_player_in_attack_range() -> void:
	player.global_position = enemy.global_position
	await wait_physics_frames(3)


# --- Idle --------------------------------------------------------------------------

func test_idle_stands_still_and_plays_idle() -> void:
	enemy.velocity = Vector2(30, 0)
	_state("Idle").enter()
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	assert_str(String(enemy.get_node("AnimatedSprite2D").animation)).is_equal("idle")


func test_idle_waits_without_a_target() -> void:
	_state("Idle").physics_update(0.016)
	assert_array(requests).is_empty()


func test_idle_starts_chasing_a_target() -> void:
	enemy.target = player
	_state("Idle").physics_update(0.016)
	assert_array(requests).contains_exactly(&"Chase")


# --- Chase -------------------------------------------------------------------------

func test_chase_plays_run_and_listens_to_its_attack_range_once() -> void:
	var chase := _state("Chase")
	chase.enter()
	chase.enter()
	var hitbox: Area2D = enemy.get_node("AttackHitbox")
	assert_str(String(enemy.get_node("AnimatedSprite2D").animation)).is_equal("run")
	assert_bool(hitbox.body_entered.is_connected(chase._on_attack_range_entered)).is_true()
	chase.exit()
	assert_bool(hitbox.body_entered.is_connected(chase._on_attack_range_entered)).is_false()


func test_chase_gives_up_without_a_target() -> void:
	var chase := _state("Chase")
	chase.enter()
	chase.physics_update(0.016)
	assert_array(requests).contains_exactly(&"Idle")


func test_chase_runs_toward_the_target_at_full_speed() -> void:
	var chase := _state("Chase")
	chase.enter()
	enemy.target = player
	chase.physics_update(0.016)
	assert_vector(enemy.velocity).is_equal_approx(Vector2(120, 0), Vector2.ONE * 0.01)
	assert_bool(enemy.get_node("AnimatedSprite2D").flip_h).is_true()   # sprite faces left
	assert_array(requests).is_empty()


func test_chase_attacks_when_the_player_is_in_range() -> void:
	var chase := _state("Chase")
	chase.enter()
	enemy.target = player
	await _put_player_in_attack_range()
	requests.clear()
	chase.physics_update(0.016)
	assert_array(requests).contains_exactly(&"Attack")


func test_entering_the_attack_range_triggers_an_attack() -> void:
	var chase := _state("Chase")
	chase._on_attack_range_entered(player)
	chase._on_attack_range_entered(auto_free(Node2D.new()))
	assert_array(requests).contains_exactly(&"Attack")


# --- Attack ------------------------------------------------------------------------

func test_attack_swings_immediately_and_hits_players_in_range() -> void:
	enemy.target = player
	await _put_player_in_attack_range()
	enemy.velocity = Vector2(50, 0)
	var attack := _state("Attack")
	attack.enter()
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	assert_str(String(enemy.get_node("AnimatedSprite2D").animation)).is_equal("attack")
	assert_float(player.health).is_equal(100.0 - 1.5)
	assert_float(attack.cooldown_timer).is_equal(0.5)


func test_attack_swings_again_after_the_cooldown() -> void:
	enemy.target = player
	await _put_player_in_attack_range()
	var attack := _state("Attack")
	attack.enter()
	attack.physics_update(0.25)
	assert_float(player.health).is_equal(100.0 - 1.5)
	attack.physics_update(0.25)
	assert_float(player.health).is_equal(100.0 - 3.0)
	assert_array(requests).is_empty()


func test_attack_resumes_the_chase_when_the_player_escapes() -> void:
	enemy.target = player
	var attack := _state("Attack")
	attack.enter()   # player is far away: the swing hits nothing
	assert_float(player.health).is_equal(100.0)
	attack.physics_update(0.5)
	assert_array(requests).contains_exactly(&"Chase")


func test_attack_goes_idle_when_the_target_disappears() -> void:
	var attack := _state("Attack")
	attack.enter()
	attack.physics_update(0.016)
	assert_array(requests).contains_exactly(&"Idle")


# --- Death -------------------------------------------------------------------------

func test_death_stops_the_body_and_frees_it_after_a_fallback_delay() -> void:
	enemy.velocity = Vector2(10, 10)
	_state("Dead").enter()
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	assert_bool(enemy.is_physics_processing()).is_false()
	await get_tree().process_frame
	assert_bool(enemy.get_node("CollisionShape2D").disabled).is_true()
	var freed := await wait_until(func() -> bool: return not is_instance_valid(enemy), 2000)
	assert_bool(freed).override_failure_message("enemy was not freed after dying").is_true()


func test_death_waits_for_the_death_animation_when_there_is_one() -> void:
	var frames: SpriteFrames = enemy.get_node("AnimatedSprite2D").sprite_frames
	frames.add_animation(&"Death")
	frames.set_animation_loop(&"Death", false)
	frames.set_animation_speed(&"Death", 60.0)
	for i in 3:
		frames.add_frame(&"Death", Factory.texture(Vector2(8, 8)))
	_state("Dead").enter()
	assert_str(String(enemy.get_node("AnimatedSprite2D").animation)).is_equal("Death")
	var freed := await wait_until(func() -> bool: return not is_instance_valid(enemy), 2000)
	assert_bool(freed).is_true()


func test_killing_an_enemy_runs_the_death_state_end_to_end() -> void:
	enemy.get_node("StateMachine").process_mode = Node.PROCESS_MODE_INHERIT
	enemy.take_damage(1000.0)
	assert_str(String(enemy.get_node("StateMachine").current_state.name)).is_equal("Dead")
	var freed := await wait_until(func() -> bool: return not is_instance_valid(enemy), 2000)
	assert_bool(freed).is_true()
