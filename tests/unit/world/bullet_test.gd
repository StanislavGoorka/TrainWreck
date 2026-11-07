extends "res://tests/helpers/tw_test_suite.gd"

const BULLET_SCENE := preload("res://Placeholders/Scenes/Characters/bullet.tscn")


func _bullet(properties := {}) -> CharacterBody2D:
	var bullet: CharacterBody2D = auto_free(BULLET_SCENE.instantiate())
	for key: String in properties:
		bullet.set(key, properties[key])
	add_child(bullet)
	return bullet


func _particles(bullet: Node) -> Array:
	return bullet.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)


func test_bullet_flies_in_the_direction_it_faces() -> void:
	var bullet := _bullet({"speed": 500.0, "rotation": PI / 2.0})
	assert_vector(bullet.velocity).is_equal_approx(Vector2(0, 500), Vector2.ONE * 0.01)


func test_plain_bullet_has_no_status_visuals() -> void:
	var bullet := _bullet()
	assert_array(_particles(bullet)).is_empty()
	assert_that(bullet.get_node("Sprite2D").self_modulate).is_equal(Color.WHITE)


func test_status_bullet_is_tinted_bigger_and_leaves_a_trail() -> void:
	var plain := _bullet()
	var statuses := {StatusEffect.Type.POISON: 1}
	var bullet := _bullet({"statuses": statuses})
	var sprite: Sprite2D = bullet.get_node("Sprite2D")
	assert_that(sprite.self_modulate).is_equal(StatusEffect.bullet_color(statuses))
	assert_vector(sprite.scale).is_equal_approx(plain.get_node("Sprite2D").scale * bullet.status_scale, Vector2.ONE * 0.001)
	var trails := _particles(bullet)
	assert_array(trails).has_size(1)
	assert_that(trails[0].color).is_equal(sprite.self_modulate)


func test_hitting_an_enemy_deals_damage_and_frees_the_bullet() -> void:
	var enemy: Enemy = auto_free(Factory.enemy(Factory.enemy_stats(10.0)))
	add_child(enemy)
	var bullet := _bullet({"damage": 3.0})
	bullet._on_hit(enemy)
	assert_float(enemy.health).is_equal(7.0)
	assert_bool(bullet.is_queued_for_deletion()).is_true()


func test_statuses_are_applied_after_the_damage() -> void:
	var enemy: Enemy = auto_free(Factory.enemy(Factory.enemy_stats(10.0)))
	add_child(enemy)
	var bullet := _bullet({"damage": 2.0, "statuses": {StatusEffect.Type.BLEED: 1}})
	bullet._on_hit(enemy)
	assert_float(enemy.health).is_equal(8.0)   # this hit is not boosted by its own bleed
	assert_bool(enemy.status.bleeding).is_true()


func test_hitting_a_wall_only_frees_the_bullet() -> void:
	var wall: StaticBody2D = auto_free(StaticBody2D.new())
	add_child(wall)
	var bullet := _bullet()
	bullet._on_hit(wall)
	assert_bool(bullet.is_queued_for_deletion()).is_true()


func test_bullet_disappears_after_its_lifetime() -> void:
	var bullet := _bullet({"lifetime": 0.05})
	var freed := await wait_until(func() -> bool: return not is_instance_valid(bullet), 1000)
	assert_bool(freed).is_true()


func test_bullet_collides_with_enemies_in_flight() -> void:
	var enemy: Enemy = auto_free(Factory.enemy(Factory.enemy_stats(10.0)))
	add_child(enemy)
	enemy.global_position = Vector2(60, 0)
	var bullet := _bullet({"damage": 4.0, "speed": 600.0})
	var freed := await wait_until(func() -> bool: return not is_instance_valid(bullet), 2000)
	assert_bool(freed).is_true()
	assert_float(enemy.health).is_equal(6.0)
