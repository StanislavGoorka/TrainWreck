extends "res://tests/helpers/tw_test_suite.gd"

const AIM_SCENE := preload("res://Placeholders/Scenes/Characters/aim.tscn")

var player: Player
var aim: Area2D
var world: Node2D
var idle: WeaponState
var cooldown: WeaponState
var requests: Array = []


func before_test() -> void:
	super.before_test()
	requests = []
	world = auto_free(Node2D.new())
	world.name = "TestWorld"
	use_as_current_scene(world)   # WeaponIdle adds bullets to the current scene

	player = Factory.player(null, Factory.weapon_stats(2.5, 0.25, 900.0))
	aim = AIM_SCENE.instantiate()
	aim.name = "Aim"
	player.add_child(aim)
	world.add_child(player)

	# The tests drive the states by hand, so the scene's own state machine stays off.
	var machine := aim.get_node("WeaponStateMachine")
	machine.process_mode = Node.PROCESS_MODE_DISABLED
	idle = machine.get_node("WeaponIdle")
	cooldown = machine.get_node("WeaponCooldown")
	idle.transition_requested.connect(func(state_name: StringName, _msg := {}) -> void: requests.append(state_name))
	cooldown.transition_requested.connect(func(state_name: StringName, _msg := {}) -> void: requests.append(state_name))


func _bullets() -> Array:
	return world.get_children().filter(func(n: Node) -> bool: return n != player)


func test_weapon_state_exposes_the_aim_node() -> void:
	assert_object(idle.aim).is_same(aim)


func test_idle_does_not_shoot_without_input() -> void:
	idle.physics_update(0.016)
	assert_array(_bullets()).is_empty()
	assert_array(requests).is_empty()


func test_shooting_spawns_a_bullet_with_the_current_weapon_stats() -> void:
	Input.action_press("Shoot")
	idle.physics_update(0.016)

	var bullets := _bullets()
	assert_array(bullets).has_size(1)
	var bullet: Node = bullets[0]
	assert_float(bullet.damage).is_equal(2.5)
	assert_float(bullet.speed).is_equal(900.0)
	assert_vector(bullet.global_position).is_equal_approx(
		aim.get_node("%ShootingPoint").global_position, Vector2.ONE * 0.01)
	assert_array(requests).contains_exactly(&"WeaponCooldown")


func test_bullets_carry_the_rolled_statuses() -> void:
	player.add_item(Factory.item({"status_effect": StatusEffect.Type.BURN, "status_stacks_per_hit": 2}), true)
	Input.action_press("Shoot")
	idle.physics_update(0.016)
	assert_dict(_bullets()[0].statuses).is_equal({StatusEffect.Type.BURN: 2})


func test_cannot_shoot_right_after_picking_up_an_item() -> void:
	player.add_item(Factory.item())
	Input.action_press("Shoot")
	idle.physics_update(0.016)
	assert_array(_bullets()).is_empty()


func test_shooting_kicks_the_gun_back_and_it_settles() -> void:
	var pivot: Node2D = aim.get_node("WeaponPivot")
	var rest := pivot.position
	Input.action_press("Shoot")
	idle.physics_update(0.016)
	var tween: Tween = aim.recoil_tween
	assert_bool(tween.is_valid()).is_true()
	# Tweens are stepped by hand: in headless runs a single frame can be longer than the recoil.
	tween.custom_step(aim.recoil_out_time)
	assert_vector(pivot.position).is_equal_approx(rest + Vector2(-aim.recoil_distance, 0), Vector2.ONE * 0.01)
	tween.custom_step(aim.recoil_return_time)
	assert_vector(pivot.position).is_equal_approx(rest, Vector2.ONE * 0.01)


func test_recoil_restarts_from_the_rest_position() -> void:
	var pivot: Node2D = aim.get_node("WeaponPivot")
	var rest := pivot.position
	aim.recoil()
	aim.recoil_tween.custom_step(aim.recoil_out_time * 0.5)
	aim.recoil()   # a second shot mid-recoil must not drift the gun
	aim.recoil_tween.custom_step(aim.recoil_out_time + aim.recoil_return_time)
	assert_vector(pivot.position).is_equal_approx(rest, Vector2.ONE * 0.01)
	assert_vector(aim.rest_position).is_equal(rest)


func test_cooldown_waits_for_the_fire_rate_then_returns_to_idle() -> void:
	cooldown.enter()
	var timer: Timer = aim.get_node("Cooldown")
	assert_float(timer.wait_time).is_equal(0.25)
	assert_bool(timer.is_stopped()).is_false()
	assert_array(requests).is_empty()
	await wait_until(func() -> bool: return not requests.is_empty(), 1000)
	assert_array(requests).contains_exactly(&"WeaponIdle")


func test_cooldown_can_be_entered_repeatedly() -> void:
	for i in 2:
		requests.clear()
		cooldown.enter()
		await wait_until(func() -> bool: return not requests.is_empty(), 1000)
		assert_array(requests).contains_exactly(&"WeaponIdle")
