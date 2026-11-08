class_name SummonerBoss
extends Boss

signal window_changed(vulnerable: bool)
signal wave_started(number: int, size: int)

const SOLID_MASK := (1 << 0) | (1 << 6)         # layer 1 (walls) and layer 7 (objects)
const SHIELD_TINT := Color(0.55, 0.65, 1.0)

var wave_number: int = 0        # waves started so far
var vulnerable: bool = false    # only true inside the damage window
var window_damage: float = 0.0
var wave_enemies: Array = []
var tint_tween: Tween

func _ready() -> void:
	super()
	if not stats is SummonerBossStats:
		push_error("%s needs a SummonerBossStats resource assigned to Stats!" % name)
	_set_tint(SHIELD_TINT, 0.0)

# --- Damage rules ------------------------------------------------------

func take_damage(amount: float, from_status: bool = false) -> void:
	if is_dead or not vulnerable:
		return   # a wave is active, so the boss cannot be hurt
	var s := stats as SummonerBossStats
	if not from_status:
		amount *= status.consume_bleed()   # bleed only counts while damage can land
	var allowed := minf(amount, window_cap() - window_damage)
	if allowed <= 0.0:
		return   # this window's 25% is used up
	window_damage += allowed
	# from_status = true here only skips the bleed multiplier, which was applied above.
	super.take_damage(allowed, true)

func window_cap() -> float:
	var s := stats as SummonerBossStats
	return stats.max_health * s.window_damage_cap

func apply_statuses(statuses: Dictionary) -> void:
	if vulnerable:
		super(statuses)   # no status effects stick during a wave

func is_immune_to(type: int) -> bool:
	# A frozen boss would stop its own wave logic (freezing disables the state machine).
	return type == StatusEffect.Type.FREEZE or super(type)

func set_vulnerable(value: bool) -> void:
	vulnerable = value
	if value:
		window_damage = 0.0
	_set_tint(Color.WHITE if value else SHIELD_TINT, 0.2)
	window_changed.emit(value)

func _set_tint(color: Color, time: float) -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not sprite:
		return
	if tint_tween:
		tint_tween.kill()
	if time <= 0.0:
		sprite.modulate = color
	else:
		tint_tween = create_tween()
		tint_tween.tween_property(sprite, "modulate", color, time)

# --- Waves ---------------------------------------------------------------

func wave_cleared() -> bool:
	wave_enemies = wave_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	return wave_enemies.is_empty()

func next_wave_size() -> int:
	var s := stats as SummonerBossStats
	var pool := s.wave_size_pool.duplicate()
	if pool.is_empty():
		return 3
	pool.sort()
	var last := pool.size() - 1
	var lo := mini(wave_number, last)
	var hi := mini(wave_number + 1, last)
	var size: int = pool[randi_range(lo, hi)]
	size += maxi(wave_number - last, 0) * s.growth_after_pool
	return maxi(size, 1)

func spawn_wave() -> void:
	var s := stats as SummonerBossStats
	if s.enemy_pool.is_empty():
		push_error("%s has an empty enemy_pool, so no wave can be spawned." % name)
		return

	var count := next_wave_size()
	var player_ref: Node = target if is_instance_valid(target) else get_tree().get_first_node_in_group("Players")
	var holder := get_parent()

	for i in count:
		var scene: PackedScene = s.enemy_pool.pick_random()
		var enemy := scene.instantiate() as Enemy
		if enemy == null:
			push_warning("An entry of enemy_pool is not an Enemy scene.")
			continue
		# Frozen and invisible until the fade-in ends, like room spawns.
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.modulate.a = 0.0
		holder.add_child(enemy)
		enemy.global_position = _find_spawn_position()
		wave_enemies.append(enemy)

		var tween := create_tween()
		tween.tween_property(enemy, "modulate:a", 1.0, s.spawn_fade_time)
		tween.tween_callback(_enable_minion.bind(enemy, player_ref))

	wave_number += 1
	wave_started.emit(wave_number, count)

func _enable_minion(enemy: Node, player_ref: Node) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	if "target" in enemy:
		enemy.target = player_ref
	if enemy.has_node("EnemyAim"):
		enemy.get_node("EnemyAim").start_shooting()

# A random spot around the boss that is not inside a wall or an object.
func _find_spawn_position() -> Vector2:
	var s := stats as SummonerBossStats
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = SOLID_MASK
	for attempt in 16:
		var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(s.spawn_radius_min, s.spawn_radius_max)
		query.position = pos
		if space.intersect_point(query, 1).is_empty():
			return pos
	return global_position
