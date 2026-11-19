## Enemy navigation (Enemy.get_chase_direction / can_see / nav_mask) and the chase states
## that use it. Rooms are Factory.nav_room() fixtures; the enemy sits under the room's
## EnemiesSpawn node, as room.gd spawns it.
extends "res://tests/helpers/tw_test_suite.gd"

const WalkerChase := preload("res://Test/Scripts/States/Walker/chase.gd")
const FlyingChase := preload("res://Test/Scripts/States/FlyingEnemy/FlyingChase.gd")

const ORIGIN := Vector2(30000, 30000)
const PLAYER_LAYER := 2
const ENEMY_LAYER := 4
const GROUND := 32
const OBJECTS := 64
const WALKER_MASK := 97

var room: Node2D
var nav: RoomNav
var target: Node2D


func before_test() -> void:
	super.before_test()
	room = auto_free(Factory.nav_room(Vector2i(10, 6)))
	add_child(room)
	room.global_position = ORIGIN
	nav = room.get_node("RoomNav")
	target = auto_free(Node2D.new())
	add_child(target)


func _at(cell: Vector2i) -> Vector2:
	return room.global_position + Factory.nav_cell(cell)


func _enemy_in_room(cell: Vector2i, states := {}, stats: EnemyStats = null) -> Enemy:
	var enemy: Enemy = Factory.enemy(stats, states)
	room.get_node("EnemiesSpawn").add_child(enemy)
	enemy.global_position = _at(cell)
	enemy.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func _settle() -> void:
	await wait_physics_frames(2)


# --- nav_mask and body measurement -------------------------------------------------

func test_nav_mask_ignores_the_player_and_other_enemies() -> void:
	var enemy: Enemy = auto_free(Factory.enemy())
	enemy.collision_mask = 1 | PLAYER_LAYER | ENEMY_LAYER | GROUND | OBJECTS
	assert_int(enemy.nav_mask()).is_equal(1 | GROUND | OBJECTS)
	enemy.collision_mask = WALKER_MASK
	assert_int(enemy.nav_mask()).is_equal(WALKER_MASK)


func test_body_radius_is_measured_from_the_collision_shape() -> void:
	var enemy: Enemy = auto_free(Factory.enemy())
	add_child(enemy)
	var node: CollisionShape2D = enemy.get_node("CollisionShape2D")
	for case: Array in [[_circle(12.0), 12.0], [_rectangle(Vector2(40, 20)), 20.0], [_capsule(10.0, 60.0), 30.0]]:
		node.shape = case[0]
		enemy._measure_body()
		assert_object(enemy._body_shape).is_same(case[0])
		assert_float(enemy._radius).override_failure_message(case[0].get_class()).is_equal(case[1])


func _circle(radius: float) -> CircleShape2D:
	var shape := CircleShape2D.new()
	shape.radius = radius
	return shape


func _rectangle(size: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	return shape


func _capsule(radius: float, height: float) -> CapsuleShape2D:
	var shape := CapsuleShape2D.new()
	shape.radius = radius
	shape.height = height
	return shape


func test_body_shape_offset_is_measured_from_the_enemy_origin() -> void:
	var enemy: Enemy = auto_free(Factory.enemy())
	add_child(enemy)
	enemy.get_node("CollisionShape2D").position = Vector2(0, -8)
	enemy._measure_body()
	assert_vector(enemy._shape_offset).is_equal_approx(Vector2(0, -8), Vector2.ONE * 0.01)


# --- Without a room ----------------------------------------------------------------

func test_enemy_outside_any_room_chases_in_a_straight_line() -> void:
	var enemy: Enemy = auto_free(Factory.enemy())
	add_child(enemy)
	enemy.global_position = Vector2(100, 100)
	assert_vector(enemy.get_chase_direction(Vector2(100, 300), 0.016)).is_equal_approx(Vector2.DOWN, Vector2.ONE * 0.001)
	assert_object(enemy._nav).is_null()
	assert_bool(enemy.can_see(Vector2(100, 300))).is_true()


# --- Inside a room -----------------------------------------------------------------

func test_enemy_finds_the_navigation_of_the_room_it_is_in() -> void:
	var enemy := _enemy_in_room(Vector2i(1, 1))
	await _settle()
	enemy.get_chase_direction(_at(Vector2i(8, 1)), 0.016)
	assert_object(enemy._nav).is_same(nav)


func test_clear_line_goes_straight_without_a_path() -> void:
	var enemy := _enemy_in_room(Vector2i(1, 1))
	await _settle()
	var dir := enemy.get_chase_direction(_at(Vector2i(8, 1)), 0.016)
	assert_vector(dir).is_equal_approx(Vector2.RIGHT, Vector2.ONE * 0.001)
	assert_array(Array(enemy._path)).is_empty()
	assert_bool(enemy.can_see(_at(Vector2i(8, 1)))).is_true()


func test_wall_in_the_way_makes_the_enemy_head_for_the_gap() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3))   # gap in rows 4 and 5
	var enemy := _enemy_in_room(Vector2i(1, 1))
	await _settle()
	var dir := enemy.get_chase_direction(_at(Vector2i(8, 1)), 0.016)
	assert_array(Array(enemy._path)).is_not_empty()
	assert_float(dir.y).override_failure_message("expected to head down to the gap, got %s" % dir).is_greater(0.3)
	var waypoint: Vector2 = enemy._path[enemy._path_index]
	assert_bool(nav.line_clear(enemy._body_shape, enemy._shape_offset, enemy.global_position, waypoint, enemy.nav_mask())) \
		.override_failure_message("the chosen waypoint must be in a clear line").is_true()
	assert_bool(enemy.can_see(_at(Vector2i(8, 1)))).is_false()


func test_no_way_through_falls_back_to_a_straight_line() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 5))
	var enemy := _enemy_in_room(Vector2i(1, 1))
	await _settle()
	var dir := enemy.get_chase_direction(_at(Vector2i(8, 1)), 0.016)
	assert_vector(dir).is_equal_approx(Vector2.RIGHT, Vector2.ONE * 0.001)
	assert_array(Array(enemy._path)).is_empty()


func test_nav_radius_overrides_the_measured_body() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 2))
	Factory.nav_block(room, Vector2i(4, 4), Vector2i(4, 5))   # one-cell gap at (4, 3)
	var small := _enemy_in_room(Vector2i(1, 1))
	var big := _enemy_in_room(Vector2i(1, 1))
	big.nav_radius = 80.0   # needs a wider gap than the 12 px body would
	await _settle()
	small.get_chase_direction(_at(Vector2i(8, 1)), 0.016)
	assert_array(Array(small._path)).is_not_empty()
	var dir := big.get_chase_direction(_at(Vector2i(8, 1)), 0.016)
	assert_array(Array(big._path)).is_empty()
	assert_vector(dir).is_equal_approx(Vector2.RIGHT, Vector2.ONE * 0.001)


func test_holes_stop_walkers_but_flyers_go_straight_over_them() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3), GROUND)   # hole with a way round below
	var walker := _enemy_in_room(Vector2i(1, 1))
	walker.collision_mask = WALKER_MASK
	var flyer := _enemy_in_room(Vector2i(1, 1))   # mask 1, like the fairy scenes
	await _settle()
	var walker_dir := walker.get_chase_direction(_at(Vector2i(8, 1)), 0.016)
	var flyer_dir := flyer.get_chase_direction(_at(Vector2i(8, 1)), 0.016)
	assert_float(walker_dir.y).override_failure_message("walker should go round the hole, got %s" % walker_dir).is_greater(0.3)
	assert_vector(flyer_dir).is_equal_approx(Vector2.RIGHT, Vector2.ONE * 0.001)


# --- Chase states in a room --------------------------------------------------------

func test_walker_chase_walks_around_a_wall() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3))
	var enemy := _enemy_in_room(Vector2i(1, 1), {"Idle": Factory.RecordingState, "Chase": WalkerChase}, Factory.enemy_stats(10.0, 120.0))
	await _settle()
	target.global_position = _at(Vector2i(8, 1))
	enemy.target = target
	var chase: State = enemy.get_node("StateMachine/Chase")
	chase.enter()
	chase.physics_update(0.016)
	assert_float(enemy.velocity.length()).is_equal_approx(120.0, 0.01)
	assert_float(enemy.velocity.y).override_failure_message("walker walks straight into the wall: %s" % enemy.velocity).is_greater(0.0)


func test_flying_chase_steers_toward_the_way_around() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3))
	var enemy := _enemy_in_room(Vector2i(1, 1), {"Idle": Factory.RecordingState, "Chase": FlyingChase}, Factory.enemy_stats(10.0, 100.0))
	await _settle()
	target.global_position = _at(Vector2i(8, 1))
	enemy.target = target
	var chase: State = enemy.get_node("StateMachine/Chase")
	chase.acceleration = 500.0
	chase.physics_update(0.1)
	assert_float(enemy.velocity.y).override_failure_message("flyer heads straight into the wall: %s" % enemy.velocity).is_greater(0.0)
