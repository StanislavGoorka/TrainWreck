extends "res://tests/helpers/tw_test_suite.gd"

const FlyingChase := preload("res://Test/Scripts/States/FlyingEnemy/FlyingChase.gd")

var enemy: Enemy
var chase: State
var target: Node2D
var requests: Array = []


func before_test() -> void:
	super.before_test()
	requests = []
	enemy = auto_free(Factory.enemy(Factory.enemy_stats(5.0, 100.0), {"Idle": Factory.RecordingState, "Chase": FlyingChase}))
	add_child(enemy)
	enemy.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	chase = enemy.get_node("StateMachine/Chase")
	chase.acceleration = 500.0
	chase.transition_requested.connect(func(state_name: StringName, _msg := {}) -> void: requests.append(state_name))
	target = auto_free(Node2D.new())
	add_child(target)
	target.global_position = Vector2(1000, 0)


func test_enter_plays_the_configured_animation() -> void:
	chase.animation = &"Fly"
	chase.enter()
	assert_str(String(enemy.get_node("AnimatedSprite2D").animation)).is_equal("Fly")


func test_gives_up_without_a_target() -> void:
	chase.physics_update(0.1)
	assert_array(requests).contains_exactly(&"Idle")


func test_accelerates_toward_the_target_instead_of_snapping() -> void:
	enemy.target = target
	chase.physics_update(0.1)   # 500 px/s^2 for 0.1 s
	assert_vector(enemy.velocity).is_equal_approx(Vector2(50, 0), Vector2.ONE * 0.01)
	chase.physics_update(0.1)
	assert_vector(enemy.velocity).is_equal_approx(Vector2(100, 0), Vector2.ONE * 0.01)
	chase.physics_update(0.1)   # capped at stats.speed
	assert_vector(enemy.velocity).is_equal_approx(Vector2(100, 0), Vector2.ONE * 0.01)


func test_overshooting_makes_it_brake_and_turn_gradually() -> void:
	enemy.target = target
	enemy.velocity = Vector2(100, 0)
	target.global_position = Vector2(-1000, 0)
	chase.physics_update(0.1)
	assert_vector(enemy.velocity).is_equal_approx(Vector2(50, 0), Vector2.ONE * 0.01)


func test_faces_its_flying_direction() -> void:
	enemy.target = target
	enemy.velocity = Vector2(100, 0)
	chase.physics_update(0.016)
	assert_bool(enemy.get_node("AnimatedSprite2D").flip_h).is_true()


func test_tiny_horizontal_speed_keeps_the_facing() -> void:
	enemy.target = target
	target.global_position = Vector2(0, 1000)   # straight down: almost no x speed
	var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
	sprite.flip_h = true
	chase.physics_update(0.016)
	assert_bool(sprite.flip_h).is_true()
