class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)
signal health_changed(current: float, max_value: float)

@export var stats: EnemyStats
@export var sprite_faces_left: bool = true

var health: float
var is_dead: bool = false
var target: Node2D = null

var _probed := false

# Driven by StatusComponent. States read the two multipliers.
var status: StatusComponent
var speed_mult: float = 1.0
var attack_speed_mult: float = 1.0
var is_frozen: bool = false

@export_group("Navigation")
@export var nav_radius: float = 0.0       # 0 = measured from this enemy's own CollisionShape2D
@export var repath_interval: float = 0.3
@export var waypoint_reach: float = 24.0
@export var debug_navigation: bool = false   # prints one line a second and draws the path

var _nav: RoomNav
var _path := PackedVector2Array()
var _path_index := 0
var _repath_left := 0.0
var _clear := true
var _clear_left := 0.0
var _body_shape: Shape2D
var _shape_offset := Vector2.ZERO
var _radius := 20.0
var _mode := ""
var _debug_left := 0.0

# What blocks this enemy is whatever it collides with, minus the bodies of the player and other enemies.
func nav_mask() -> int:
	return collision_mask & ~((1 << 1) | (1 << 2))

func _measure_body() -> void:
	var node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if node == null or node.shape == null:
		return
	_body_shape = node.shape
	_shape_offset = node.global_position - global_position
	var s := node.shape
	if s is CircleShape2D:
		_radius = s.radius
	elif s is RectangleShape2D:
		_radius = maxf(s.size.x, s.size.y) * 0.5
	elif s is CapsuleShape2D:
		_radius = maxf(s.radius, s.height * 0.5)

func _find_nav() -> void:
	if _nav != null and is_instance_valid(_nav):
		return
	# Every enemy is spawned inside its room, so the room's RoomNav is on one of its ancestors.
	var node: Node = get_parent()
	while node != null:
		var found := node.get_node_or_null("RoomNav") as RoomNav
		if found:
			_nav = found
			return
		node = node.get_parent()

func get_chase_direction(target_pos: Vector2, delta: float) -> Vector2:
	var straight := (target_pos - global_position).normalized()
	if _body_shape == null:
		_measure_body()
	_find_nav()

	if not _probed:
		_probed = true
		print("[Probe] %s | room nav found: %s | body shape found: %s | rooms with nav in the tree: %d | position %s" % [
			name, _nav != null, _body_shape != null, get_tree().get_nodes_in_group("RoomNav").size(), global_position])
		if _nav != null and _body_shape != null:
			_nav.prepare(nav_mask(), nav_radius if nav_radius > 0.0 else _radius)

	if _nav == null or _body_shape == null:
		_report("NO NAV (rooms with navigation in the tree: %d)" % get_tree().get_nodes_in_group("RoomNav").size())
		return straight

	var mask := nav_mask()
	var radius := nav_radius if nav_radius > 0.0 else _radius

	# Is the player in a clear line for this enemy's real body? Checked 10 times a second.
	_clear_left -= delta
	if _clear_left <= 0.0:
		_clear_left = 0.1
		_clear = _nav.line_clear(_body_shape, _shape_offset, global_position, target_pos, mask)
	if _clear:
		_path = PackedVector2Array()
		_report("STRAIGHT")
		return straight

	# Touching a wall while following a path: plan again right away.
	if get_slide_collision_count() > 0:
		_repath_left = 0.0

	_repath_left -= delta
	if _path.is_empty() or _repath_left <= 0.0:
		_repath_left = repath_interval
		_path = _nav.find_path(global_position, target_pos, mask, radius)
		_path_index = mini(1, maxi(_path.size() - 1, 0))
		# Head for the farthest of the next few waypoints that is really in a clear line.
		for i in range(mini(_path.size() - 1, 4), _path_index, -1):
			if _nav.line_clear(_body_shape, _shape_offset, global_position, _path[i], mask):
				_path_index = i
				break
	if _path.is_empty():
		_report("NO PATH (falling back to a straight line)")
		return straight

	while _path_index < _path.size() - 1 and global_position.distance_to(_path[_path_index]) < waypoint_reach:
		_path_index += 1
	_report("PATH")
	return (_path[_path_index] - global_position).normalized()

func can_see(target_pos: Vector2) -> bool:
	if _body_shape == null:
		_measure_body()
	_find_nav()
	if _nav == null or _body_shape == null:
		return true
	return _nav.line_clear(_body_shape, _shape_offset, global_position, target_pos, nav_mask())

func _report(mode: String) -> void:
	if not debug_navigation:
		return
	_mode = mode
	queue_redraw()
	_debug_left -= get_physics_process_delta_time()
	if _debug_left <= 0.0:
		_debug_left = 1.0
		print("[Nav] %s | %s | radius %.0f | path points %d | mask %d" % [name, mode, nav_radius if nav_radius > 0.0 else _radius, _path.size(), nav_mask()])

func _draw() -> void:
	if not debug_navigation or _path.size() < 2:
		return
	for i in range(_path_index, _path.size() - 1):
		draw_line(to_local(_path[i]), to_local(_path[i + 1]), Color.YELLOW, 2.0)
	draw_line(Vector2.ZERO, to_local(_path[_path_index]), Color.GREEN, 2.0)

func _ready() -> void:
	status = get_node_or_null("StatusComponent") as StatusComponent
	if not status:
		status = StatusComponent.new()
		status.name = "StatusComponent"
		add_child(status)
	status.enemy = self

	if not stats:
		push_error("%s has no EnemyStats assigned!" % name)
		return
	health = stats.max_health
	health_changed.emit(health, stats.max_health)

func take_damage(amount: float, from_status: bool = false) -> void:
	if is_dead:
		return
	if not from_status:
		amount *= status.consume_bleed()   # bleed only affects direct hits, not burn or poison ticks
	health -= amount
	health_changed.emit(maxf(health, 0.0), stats.max_health)
	if health <= 0:
		is_dead = true
		status.clear_all()   # also thaws, so the death animation can play
		died.emit(self)
		$StateMachine.transition_to(&"Dead")

func take_status_damage(amount: float) -> void:
	take_damage(amount, true)

func apply_statuses(statuses: Dictionary) -> void:
	if is_dead:
		return
	for type in statuses:
		status.apply(type, statuses[type])

func is_immune_to(type: int) -> bool:
	return stats != null and (stats.status_immunities & (1 << (type - 1))) != 0

# Frozen solid: the AI stops and the animation holds. The body stays in physics,
# so bullets still hit it.
func set_frozen(value: bool) -> void:
	is_frozen = value
	velocity = Vector2.ZERO
	for node_name in ["StateMachine", "EnemyAim"]:
		var node := get_node_or_null(node_name)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		if value:
			sprite.pause()
		else:
			sprite.play()

func play_anim(anim_name: StringName) -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func face_direction(dir_x: float) -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and absf(dir_x) > 0.1:
		var moving_right := dir_x > 0.0
		sprite.flip_h = moving_right if sprite_faces_left else not moving_right
