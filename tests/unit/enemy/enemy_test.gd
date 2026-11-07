extends "res://tests/helpers/tw_test_suite.gd"

const BURN_FLAG := 1
const POISON_FLAG := 2
const FREEZE_FLAG := 4
const BLEED_FLAG := 8


func _spawn(stats: EnemyStats = null) -> Enemy:
	var enemy: Enemy = auto_free(Factory.enemy(stats))
	add_child(enemy)
	return enemy


# --- Setup -------------------------------------------------------------------------

func test_ready_creates_a_status_component_when_missing() -> void:
	var enemy := _spawn()
	assert_object(enemy.status).is_not_null()
	assert_object(enemy.get_node("StatusComponent")).is_same(enemy.status)
	assert_object(enemy.status.enemy).is_same(enemy)


func test_ready_reuses_an_existing_status_component() -> void:
	var enemy: Enemy = auto_free(Factory.enemy())
	var component := StatusComponent.new()
	component.name = "StatusComponent"
	enemy.add_child(component)
	add_child(enemy)
	assert_object(enemy.status).is_same(component)
	assert_int(enemy.get_children().filter(func(n: Node) -> bool: return n is StatusComponent).size()).is_equal(1)


func test_ready_starts_at_full_health_and_announces_it() -> void:
	var enemy: Enemy = auto_free(Factory.enemy(Factory.enemy_stats(6.0)))
	var events := []
	enemy.health_changed.connect(func(current: float, max_value: float) -> void: events.append([current, max_value]))
	add_child(enemy)
	assert_float(enemy.health).is_equal(6.0)
	assert_array(events).is_equal([[6.0, 6.0]])


func test_enemy_without_stats_does_not_crash() -> void:
	var enemy: Enemy = auto_free(Factory.enemy())
	enemy.stats = null
	add_child(enemy)
	assert_bool(enemy.is_dead).is_false()
	assert_bool(enemy.is_immune_to(StatusEffect.Type.BURN)).is_false()


# --- Damage ------------------------------------------------------------------------

func test_take_damage_reduces_health_and_announces_it() -> void:
	var enemy := _spawn(Factory.enemy_stats(5.0))
	var events := []
	enemy.health_changed.connect(func(current: float, max_value: float) -> void: events.append([current, max_value]))
	enemy.take_damage(2.0)
	assert_float(enemy.health).is_equal(3.0)
	assert_array(events).is_equal([[3.0, 5.0]])


func test_lethal_damage_kills_once_and_switches_to_the_dead_state() -> void:
	var enemy := _spawn(Factory.enemy_stats(3.0))
	var deaths := []
	var events := []
	enemy.died.connect(func(who: Enemy) -> void: deaths.append(who))
	enemy.health_changed.connect(func(current: float, _max: float) -> void: events.append(current))
	enemy.take_damage(10.0)
	enemy.take_damage(1.0)
	assert_bool(enemy.is_dead).is_true()
	assert_array(deaths).contains_exactly(enemy)
	assert_array(events).is_equal([0.0])   # never reports negative health
	assert_str(String(enemy.get_node("StateMachine").current_state.name)).is_equal("Dead")


func test_death_clears_all_statuses() -> void:
	var enemy := _spawn(Factory.enemy_stats(3.0))
	enemy.apply_statuses({StatusEffect.Type.BURN: 2, StatusEffect.Type.POISON: 1})
	enemy.take_damage(10.0)
	assert_int(enemy.status.burn_stacks).is_zero()
	assert_int(enemy.status.poison_stacks).is_zero()


func test_bleed_boosts_the_next_direct_hit_only() -> void:
	var enemy := _spawn(Factory.enemy_stats(20.0))
	enemy.apply_statuses({StatusEffect.Type.BLEED: 1})
	enemy.take_damage(2.0)
	assert_float(enemy.health).is_equal(20.0 - 2.0 * StatusEffect.BLEED_MULTIPLIER)
	enemy.take_damage(2.0)
	assert_float(enemy.health).is_equal(20.0 - 2.0 * StatusEffect.BLEED_MULTIPLIER - 2.0)


func test_status_damage_does_not_consume_bleed() -> void:
	var enemy := _spawn(Factory.enemy_stats(20.0))
	enemy.apply_statuses({StatusEffect.Type.BLEED: 1})
	enemy.take_status_damage(1.0)
	assert_float(enemy.health).is_equal(19.0)
	assert_bool(enemy.status.bleeding).is_true()


func test_dead_enemy_ignores_statuses() -> void:
	var enemy := _spawn(Factory.enemy_stats(1.0))
	enemy.take_damage(5.0)
	enemy.apply_statuses({StatusEffect.Type.POISON: 1})
	assert_int(enemy.status.poison_stacks).is_zero()


# --- Immunities --------------------------------------------------------------------

func test_immunity_flags(flags: int, burn: bool, poison: bool, freeze: bool, bleed: bool, test_parameters := [
	[0, false, false, false, false],
	[BURN_FLAG, true, false, false, false],
	[POISON_FLAG, false, true, false, false],
	[FREEZE_FLAG, false, false, true, false],
	[BLEED_FLAG, false, false, false, true],
	[BURN_FLAG | BLEED_FLAG, true, false, false, true],
]) -> void:
	var enemy := _spawn(Factory.enemy_stats(5.0, 100.0, 1.0, 0.5, flags))
	assert_bool(enemy.is_immune_to(StatusEffect.Type.BURN)).is_equal(burn)
	assert_bool(enemy.is_immune_to(StatusEffect.Type.POISON)).is_equal(poison)
	assert_bool(enemy.is_immune_to(StatusEffect.Type.FREEZE)).is_equal(freeze)
	assert_bool(enemy.is_immune_to(StatusEffect.Type.BLEED)).is_equal(bleed)


func test_immune_enemy_ignores_that_status() -> void:
	var enemy := _spawn(Factory.enemy_stats(5.0, 100.0, 1.0, 0.5, POISON_FLAG))
	enemy.apply_statuses({StatusEffect.Type.POISON: 2, StatusEffect.Type.BURN: 1})
	assert_int(enemy.status.poison_stacks).is_zero()
	assert_int(enemy.status.burn_stacks).is_equal(1)


# --- Freeze ------------------------------------------------------------------------

func test_set_frozen_stops_ai_movement_and_animation() -> void:
	var enemy := _spawn()
	var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
	sprite.play(&"idle")
	enemy.velocity = Vector2(50, 50)
	enemy.set_frozen(true)
	assert_bool(enemy.is_frozen).is_true()
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	assert_int(enemy.get_node("StateMachine").process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_bool(sprite.is_playing()).is_false()


func test_unfreezing_resumes_ai_and_animation() -> void:
	var enemy := _spawn()
	var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
	sprite.play(&"idle")
	enemy.set_frozen(true)
	enemy.set_frozen(false)
	assert_bool(enemy.is_frozen).is_false()
	assert_int(enemy.get_node("StateMachine").process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_bool(sprite.is_playing()).is_true()


func test_set_frozen_also_stops_an_enemy_aim_node() -> void:
	var enemy: Enemy = auto_free(Factory.enemy())
	var aim := Node2D.new()
	aim.name = "EnemyAim"
	enemy.add_child(aim)
	add_child(enemy)
	enemy.set_frozen(true)
	assert_int(aim.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)


# --- Visuals -----------------------------------------------------------------------

func test_play_anim_only_plays_existing_animations() -> void:
	var enemy := _spawn()
	var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
	enemy.play_anim(&"run")
	assert_str(String(sprite.animation)).is_equal("run")
	enemy.play_anim(&"missing")
	assert_str(String(sprite.animation)).is_equal("run")


func test_face_direction(faces_left: bool, dir_x: float, expected_flip: bool, test_parameters := [
	[true, 10.0, true],
	[true, -10.0, false],
	[false, 10.0, false],
	[false, -10.0, true],
]) -> void:
	var enemy := _spawn()
	enemy.sprite_faces_left = faces_left
	enemy.face_direction(dir_x)
	assert_bool(enemy.get_node("AnimatedSprite2D").flip_h).is_equal(expected_flip)


func test_face_direction_ignores_tiny_movements() -> void:
	var enemy := _spawn()
	var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
	enemy.face_direction(10.0)
	var flip := sprite.flip_h
	enemy.face_direction(-0.05)
	assert_bool(sprite.flip_h).is_equal(flip)


# --- Subclasses --------------------------------------------------------------------

func test_melee_grunt_is_an_enemy() -> void:
	var grunt: Enemy = auto_free(Factory.enemy(null, {}, MeleeGrunt))
	add_child(grunt)
	assert_object(grunt).is_instanceof(MeleeGrunt)
	assert_float(grunt.health).is_equal(grunt.stats.max_health)
