extends Node2D

@onready var player: CharacterBody2D = get_node_or_null("/root/Game/Character1")

const STARTING_ROOMS_FOLDER := "res://Test/Scenes/Rooms/StartingRooms/"
const INTERMEDIATE_ROOMS_FOLDER := "res://Test/Scenes/Rooms/IntermediateRooms/"
const ENDING_ROOMS_FOLDER := "res://Test/Scenes/Rooms/EndingRooms/"
const SPECIAL_ROOMS_FOLDER := "res://Test/Scenes/Rooms/SpecialRooms/"
const BOSS_ROOMS_FOLDER := "res://Test/Scenes/Rooms/BossRooms/"

var START_ROOMS: Array = []
var INTERMEDIATE_ROOMS: Array = []
var END_ROOMS: Array = []
var SPECIAL_ROOMS: Array = []
var BOSS_ROOMS: Array = []

@export var num_levels: int = 10   # rooms on FLOOR 1. Every later floor has one room less.
var generation_seed: int = 0

var current_rooms: Array[Node2D] = []
var transitioning := false
var fade_layer: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	if player == null:
		push_error("❌ Could not find the Player node! Make sure Character1 exists under /root/Game/")
		return

	_load_room_scenes(STARTING_ROOMS_FOLDER, START_ROOMS)
	_load_room_scenes(INTERMEDIATE_ROOMS_FOLDER, INTERMEDIATE_ROOMS)
	_load_room_scenes(ENDING_ROOMS_FOLDER, END_ROOMS)
	_load_room_scenes(SPECIAL_ROOMS_FOLDER, SPECIAL_ROOMS)
	_load_room_scenes(BOSS_ROOMS_FOLDER, BOSS_ROOMS)

	if START_ROOMS.is_empty() or END_ROOMS.is_empty() or INTERMEDIATE_ROOMS.is_empty():
		push_error("❌ Missing start, intermediate or ending rooms! Check folder paths.")
		return
	if SPECIAL_ROOMS.is_empty():
		push_warning("⚠️ No special rooms loaded, floors will have none.")
	if BOSS_ROOMS.is_empty():
		push_warning("⚠️ No boss rooms loaded, floors will have none.")

	# One seed per run. Floors continue the same random sequence.
	generation_seed = randi()
	seed(generation_seed)
	print("🔁 Generation Seed:", generation_seed)
	
	var first_floor: int = maxi(num_levels, GameState.MIN_FLOOR_ROOMS)
	GameState.total_floors = first_floor - GameState.MIN_FLOOR_ROOMS + 1
	
	_build_fade()
	GameState.floor_changed.connect(_on_floor_changed)
	_spawn_floor(GameState.current_floor)

func _load_room_scenes(folder_path: String, target_array: Array) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("❌ Failed to open folder: " + folder_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn") and not dir.current_is_dir():
			var scene = load(folder_path + file_name)
			if scene:
				target_array.append(scene)
			else:
				push_warning("⚠️ Failed to load room scene: " + folder_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

# --- Floors --------------------------------------------------------------

func _floor_room_count(floor_number: int) -> int:
	var first_floor: int = maxi(num_levels, GameState.MIN_FLOOR_ROOMS)
	return maxi(first_floor - (floor_number - 1), GameState.MIN_FLOOR_ROOMS)

func _spawn_floor(floor_number: int) -> void:
	var count: int = _floor_room_count(floor_number)
	var boss_index: int = count - 2
	print("🚂 Floor %d: %d rooms" % [floor_number, count])

	# One slot for the special room: anywhere except the start, the boss and the end.
	var special_index := -1
	if not SPECIAL_ROOMS.is_empty():
		var valid_indices: Array[int] = []
		for i in range(1, count - 1):
			if i != boss_index:
				valid_indices.append(i)
		if not valid_indices.is_empty():
			special_index = valid_indices[randi() % valid_indices.size()]

	var previous_right_door_global := global_position
	for i in range(count):
		var room_scene: PackedScene
		if i == 0:
			room_scene = START_ROOMS[randi() % START_ROOMS.size()]
		elif i == count - 1:
			room_scene = END_ROOMS[randi() % END_ROOMS.size()]
		elif i == boss_index and not BOSS_ROOMS.is_empty():
			room_scene = BOSS_ROOMS[randi() % BOSS_ROOMS.size()]
		elif i == special_index:
			room_scene = SPECIAL_ROOMS[randi() % SPECIAL_ROOMS.size()]
		else:
			room_scene = INTERMEDIATE_ROOMS[randi() % INTERMEDIATE_ROOMS.size()]

		var room: Node2D = room_scene.instantiate()
		add_child(room)

		var left_door = room.get_node_or_null("Connector/Left")
		if left_door == null:
			push_error("❌ Room #" + str(i) + " is missing Connector/Left.")
			room.queue_free()
			continue

		var left_door_local_offset = left_door.global_position - room.global_position
		room.global_position = previous_right_door_global - left_door_local_offset
		current_rooms.append(room)

		var right_door = room.get_node_or_null("Connector/Right")
		if right_door:
			previous_right_door_global = right_door.global_position
		else:
			push_warning("⚠️ Room #" + str(i) + " missing Connector/Right, using fallback offset.")
			previous_right_door_global += Vector2(256, 0)

		if i == 0:
			var spawn_pos = room.get_node_or_null("PlayerSpawnPos")
			if spawn_pos:
				_place_player(spawn_pos.global_position)
			else:
				push_error("❌ Start room missing PlayerSpawnPos")

func _place_player(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()   # the camera jumps with the player instead of gliding

func _clear_rooms() -> void:
	for room in current_rooms:
		if is_instance_valid(room):
			remove_child(room)   # out of the tree at once, so old rooms never overlap the new ones
			room.queue_free()
	current_rooms.clear()

func _on_floor_changed(floor_number: int) -> void:
	if transitioning:
		return
	transitioning = true
	GameState.clock_paused = true   # the fade is not counted in the floor time
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _fade(1.0, 0.5)

	_clear_rooms()
	_spawn_floor(floor_number)
	await get_tree().process_frame

	player.process_mode = Node.PROCESS_MODE_INHERIT
	await _fade(0.0, 0.5)
	GameState.clock_paused = false
	transitioning = false

# --- Fade ----------------------------------------------------------------

func _build_fade() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 90   # above the HUD, below the game over screen
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	add_child(fade_layer)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _fade(to_alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", to_alpha, time)
	await tween.finished

# --- Debug reset ---------------------------------------------------------

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Reset"):
		restart_game()

func restart_game() -> void:
	print("🔄 Restarting game...")
	GameState.current_floor = 1
	get_tree().reload_current_scene()
