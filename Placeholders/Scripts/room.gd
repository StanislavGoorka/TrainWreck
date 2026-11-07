class_name Room
extends Node2D

@export var spawn_delay: float = 0.6   # seconds enemies take to fade in (harmless during this time)
@export var clamp_camera_horizontally: bool = false

@onready var detect_area = $PlayerDetector
@onready var top_boundary: Node2D = $Top
@onready var bottom_boundary: Node2D = $Bottom

var locked: bool = false
var spawned: bool = false
var alive_enemies: Array[Node] = []

func _ready():
	detect_area.body_entered.connect(_on_player_detector_body_entered)
	detect_area.body_exited.connect(_on_player_detector_body_exited)
	_set_doors(true)

func _get_spawn_points() -> Array[EnemySpawnPoint]:
	var points: Array[EnemySpawnPoint] = []
	for child in $EnemiesSpawn.get_children():
		if child is EnemySpawnPoint and child.enemy_scene:
			points.append(child)
	return points

func _on_enemies_spawned(_enemies: Array) -> void:
	pass

func _on_room_cleared() -> void:
	pass

func _apply_camera_limits(player: CharacterBody2D) -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	if not camera:
		push_warning("Player has no Camera2D child; can't set room camera limits.")
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	var region_top: float = top_boundary.global_position.y
	var region_bottom: float = bottom_boundary.global_position.y

	if (region_bottom - region_top) > viewport_size.y:
		camera.limit_top = int(region_top)
		camera.limit_bottom = int(region_bottom)
	else:
		var center_y := (region_top + region_bottom) / 2.0
		camera.limit_top = int(center_y - viewport_size.y / 2.0)
		camera.limit_bottom = int(center_y + viewport_size.y / 2.0)

	if clamp_camera_horizontally:
		camera.limit_left = int($Connector/Left.global_position.x)
		camera.limit_right = int($Connector/Right.global_position.x)
	else:
		camera.limit_left = -10000000
		camera.limit_right = 10000000

func _set_doors(open: bool) -> void:
	$Doors/Door/CollisionShape2D.set_deferred("disabled", open)
	$Doors/Door.visible = not open
	$Doors/Door2/CollisionShape2D.set_deferred("disabled", open)
	$Doors/Door2.visible = not open

func _spawn_enemies(player: CharacterBody2D) -> void:
	for point in _get_spawn_points():
		var enemy: Node2D = point.enemy_scene.instantiate()

		# Frozen and invisible until the spawn delay ends, so the player
		# can't be hit by something that just popped into existence.
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.modulate.a = 0.0

		$EnemiesSpawn.add_child(enemy)
		enemy.global_position = point.global_position   # set after add_child

		alive_enemies.append(enemy)
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died)
		else:
			push_warning("Spawned enemy has no 'died' signal, so the room can't track it.")

		var tween := create_tween()
		tween.tween_property(enemy, "modulate:a", 1.0, spawn_delay)
		tween.tween_callback(_enable_enemy.bind(enemy, player))
	
		_on_enemies_spawned(alive_enemies)

func _enable_enemy(enemy: Node, player: CharacterBody2D) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	_activate_enemy(enemy, player)

func _activate_enemy(enemy: Node, player: CharacterBody2D) -> void:
	if "target" in enemy:
		enemy.target = player
	if enemy.has_node("EnemyAim"):
		enemy.get_node("EnemyAim").start_shooting()

func _deactivate_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if "target" in enemy:
		enemy.target = null
	if enemy.has_node("EnemyAim"):
		enemy.get_node("EnemyAim").stop_shooting()

func _on_enemy_died(enemy) -> void:
	alive_enemies.erase(enemy)
	if locked and alive_enemies.is_empty():
		locked = false
		_set_doors(true)
		# If you added the pickup drop code (_spawn_pickups), call it here.
		print("All enemies defeated, doors opened")
		_on_room_cleared()
	

func _on_player_detector_body_entered(body: CharacterBody2D) -> void:
	if not body.is_in_group("Players"):
		return
	_apply_camera_limits(body)

	var room_file := scene_file_path.get_file()
	print("[Room] ", room_file, " entered | spawned=", spawned, " | spawn points=", _get_spawn_points().size())

	if spawned:
		if not alive_enemies.is_empty():
			locked = true
			_set_doors(false)
			for enemy in alive_enemies:
				if is_instance_valid(enemy) and enemy.process_mode != Node.PROCESS_MODE_DISABLED:
					_activate_enemy(enemy, body)
		return

	if _get_spawn_points().is_empty():
		print("[Room] ", room_file, ": no valid spawn points. Children of EnemiesSpawn:")
		for child in $EnemiesSpawn.get_children():
			print("    ", child.name, " | class: ", child.get_class(), " | is EnemySpawnPoint: ", child is EnemySpawnPoint, " | enemy_scene: ", child.get("enemy_scene"))
		return

	spawned = true
	locked = true
	_set_doors(false)
	_spawn_enemies(body)

func _on_player_detector_body_exited(body: CharacterBody2D) -> void:
	if not body.is_in_group("Players"):
		return
	if body.get("invulnerable"):
		return   # a dash clears the player's collision layer, which looks like leaving
	for enemy in alive_enemies:
		_deactivate_enemy(enemy)
