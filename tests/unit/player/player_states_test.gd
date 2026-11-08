extends "res://tests/helpers/tw_test_suite.gd"

const IdleState := preload("res://Placeholders/Scripts/State Machine/State/Character/Idle.gd")
const MoveState := preload("res://Placeholders/Scripts/State Machine/State/Character/Move.gd")
const DashState := preload("res://Placeholders/Scripts/State Machine/State/Character/Dash.gd")

var player: Player
var requests: Array = []


func before_test() -> void:
	super.before_test()
	requests = []
	player = auto_free(Factory.player(Factory.character_stats(10.0, 300.0, 300.0)))
	add_child(player)


func _state(script: GDScript) -> PlayerState:
	var state: PlayerState = auto_free(script.new())
	state.actor = player
	state.transition_requested.connect(func(state_name: StringName, msg := {}) -> void: requests.append([state_name, msg]))
	return state


func _requested_names() -> Array:
	return requests.map(func(r: Array) -> StringName: return r[0])


# --- Idle --------------------------------------------------------------------------

func test_idle_plays_the_idle_animations() -> void:
	_state(IdleState).enter()
	assert_str(String(player.get_node("Body").animation)).is_equal("Idle")
	assert_str(String(player.get_node("Head").animation)).is_equal("Idle")
	assert_bool(player.get_node("Body").is_playing()).is_true()


func test_idle_slides_to_a_stop_without_input() -> void:
	var idle := _state(IdleState)
	player.velocity = Vector2(300, 0)
	idle.physics_update(0.05)   # friction = 300 / 0.1 s = 3000 px/s^2 -> loses 150 px/s
	assert_float(player.velocity.x).is_equal_approx(150.0, 0.5)
	idle.physics_update(1.0)
	assert_vector(player.velocity).is_equal(Vector2.ZERO)
	assert_array(requests).is_empty()


func test_idle_switches_to_move_on_movement_input() -> void:
	var idle := _state(IdleState)
	Input.action_press("MoveRight")
	idle.physics_update(0.016)
	assert_array(_requested_names()).contains_exactly(&"Move")


func test_idle_dashes_in_the_last_move_direction() -> void:
	var idle := _state(IdleState)
	player.last_move_direction = Vector2.UP
	Input.action_press("Dash")
	idle.physics_update(0.016)
	assert_array(requests).is_equal([[&"Dash", {"direction": Vector2.UP}]])


func test_idle_does_not_dash_while_on_cooldown() -> void:
	var idle := _state(IdleState)
	player.dash_cooldown_remaining = 1.0
	Input.action_press("Dash")
	idle.physics_update(0.016)
	assert_array(_requested_names()).not_contains(&"Dash")


# --- Move --------------------------------------------------------------------------

func test_move_goes_idle_without_input() -> void:
	_state(MoveState).physics_update(0.016)
	assert_array(_requested_names()).contains_exactly(&"Idle")


func test_move_walks_at_character_speed() -> void:
	var move := _state(MoveState)
	Input.action_press("MoveRight")
	move.physics_update(0.016)
	assert_vector(player.velocity).is_equal_approx(Vector2(300, 0), Vector2.ONE * 0.01)
	assert_vector(player.last_move_direction).is_equal(Vector2.RIGHT)
	assert_str(String(player.get_node("Body").animation)).is_equal("NewRun")
	assert_str(String(player.get_node("Head").animation)).is_equal("NewRun")


func test_move_flips_the_body_when_walking_left() -> void:
	var move := _state(MoveState)
	Input.action_press("MoveLeft")
	move.physics_update(0.016)
	assert_bool(player.get_node("Body").flip_h).is_true()
	Input.action_release("MoveLeft")
	Input.action_press("MoveRight")
	move.physics_update(0.016)
	assert_bool(player.get_node("Body").flip_h).is_false()


func test_move_diagonal_input_is_normalized() -> void:
	var move := _state(MoveState)
	Input.action_press("MoveRight")
	Input.action_press("MoveDown")
	move.physics_update(0.016)
	assert_float(player.velocity.length()).is_equal_approx(300.0, 0.5)
	assert_float(player.last_move_direction.length()).is_equal_approx(1.0, 0.001)


func test_move_dashes_in_the_input_direction() -> void:
	var move := _state(MoveState)
	Input.action_press("MoveDown")
	Input.action_press("Dash")
	move.physics_update(0.016)
	assert_array(requests).is_equal([[&"Dash", {"direction": Vector2.DOWN}]])


# --- Dash --------------------------------------------------------------------------

func test_dash_makes_the_player_invulnerable_and_ghost_through_enemies() -> void:
	player.collision_layer = 2
	player.collision_mask = 1 | 4
	_state(DashState).enter({"direction": Vector2.RIGHT})
	assert_bool(player.invulnerable).is_true()
	assert_int(player.collision_layer).is_zero()
	assert_bool(player.get_collision_mask_value(DashState.ENEMY_LAYER)).is_false()
	assert_bool(player.get_collision_mask_value(1)).is_true()


func test_dash_moves_dash_distance_over_its_duration() -> void:
	var dash := _state(DashState)
	dash.enter({"direction": Vector2(0, -2)})
	dash.physics_update(0.01)
	var expected_speed: float = player.current_stats.dash_distance / dash.dash_duration
	assert_vector(player.velocity).is_equal_approx(Vector2(0, -expected_speed), Vector2.ONE * 0.01)


func test_dash_without_direction_uses_the_last_move_direction() -> void:
	player.last_move_direction = Vector2.LEFT
	var dash := _state(DashState)
	dash.enter({})
	assert_vector(dash.dash_direction).is_equal(Vector2.LEFT)
	assert_bool(player.get_node("Body").flip_h).is_true()


func test_dash_ends_in_idle_or_move(input_action: String, expected: StringName, test_parameters := [
	["", &"Idle"],
	["MoveUp", &"Move"],
]) -> void:
	var dash := _state(DashState)
	dash.enter({"direction": Vector2.RIGHT})
	if input_action != "":
		Input.action_press(input_action)
	dash.physics_update(dash.dash_duration * 0.5)
	assert_array(requests).is_empty()
	dash.physics_update(dash.dash_duration * 0.6)
	assert_array(_requested_names()).contains_exactly(expected)


func test_dash_exit_restores_collision_and_caps_speed() -> void:
	player.collision_layer = 2
	player.collision_mask = 1 | 4
	var dash := _state(DashState)
	dash.enter({"direction": Vector2.RIGHT})
	dash.physics_update(0.01)
	dash.exit()
	assert_bool(player.invulnerable).is_false()
	assert_int(player.collision_layer).is_equal(2)
	assert_int(player.collision_mask).is_equal(1 | 4)
	assert_float(player.velocity.length()).is_less_equal(player.current_stats.speed + 0.01)


func test_player_state_exposes_the_actor_as_player() -> void:
	var state := _state(IdleState)
	assert_object(state.player).is_same(player)
