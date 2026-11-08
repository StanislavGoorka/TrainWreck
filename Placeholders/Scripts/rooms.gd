extends Node2D

@onready var player: CharacterBody2D = get_node_or_null("/root/Game/Character1")

# Folders relative to your current project
const STARTING_ROOMS_FOLDER := "res://Test/Scenes/Rooms/StartingRooms/"
const INTERMEDIATE_ROOMS_FOLDER := "res://Test/Scenes/Rooms/IntermediateRooms/"
const ENDING_ROOMS_FOLDER := "res://Test/Scenes/Rooms/EndingRooms/"
const SPECIAL_ROOMS_FOLDER := "res://Test/Scenes/Rooms/SpecialRooms/"
const BOSS_ROOMS_FOLDER := "res://Test/Scenes/Rooms/BossRooms/"
# These will store the loaded scenes
var START_ROOMS: Array = []
var INTERMEDIATE_ROOMS: Array = []
var END_ROOMS: Array = []
var SPECIAL_ROOMS: Array = []
var BOSS_ROOMS: Array = []

@export var num_levels: int = 10
var generation_seed: int = 0

func _ready():
	if player == null:
		push_error("❌ Could not find the Player node! Make sure Character1 exists under /root/Game/")
		return

	# Load all room scenes dynamically
	_load_room_scenes(STARTING_ROOMS_FOLDER, START_ROOMS)
	_load_room_scenes(INTERMEDIATE_ROOMS_FOLDER, INTERMEDIATE_ROOMS)
	_load_room_scenes(ENDING_ROOMS_FOLDER, END_ROOMS)
	_load_room_scenes(SPECIAL_ROOMS_FOLDER, SPECIAL_ROOMS)
	_load_room_scenes(BOSS_ROOMS_FOLDER, BOSS_ROOMS)

	if INTERMEDIATE_ROOMS.is_empty():
		push_error("❌ No intermediate rooms loaded! Check folder paths.")
		return

	# Seed RNG for consistent generation
	generation_seed = randi()
	seed(generation_seed)
	print("🔁 Generation Seed:", generation_seed)

	_spawn_rooms()

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
				print("✅ Loaded room:", folder_path + file_name)
			else:
				push_warning("⚠️ Failed to load room scene: " + folder_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _spawn_rooms() -> void:
	var previous_right_door_global := global_position # startowy punkt = pozycja generatora
	var boss_index := num_levels - 2

	# Pick exactly one slot for the special/item room — any intermediate
	# slot except the boss room. Guarantees exactly one per floor.
	var special_index := -1
	if not SPECIAL_ROOMS.is_empty():
		var valid_indices: Array[int] = []
		for i in range(1, num_levels - 1):
			if i != boss_index:
				valid_indices.append(i)
		if not valid_indices.is_empty():
			special_index = valid_indices[randi() % valid_indices.size()]

	for i in range(num_levels):
		var room_scene: PackedScene
		if i == 0:
			room_scene = START_ROOMS[randi() % START_ROOMS.size()]
		elif i == num_levels - 1:
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

		# Lokalny offset drzwi względem korzenia pokoju (uwzględnia Connector!)
		var left_door_local_offset = left_door.global_position - room.global_position

		# Ustawiamy pokój tak, by jego lewe drzwi trafiły dokładnie
		# w prawe drzwi poprzedniego pokoju
		room.global_position = previous_right_door_global - left_door_local_offset

		var right_door = room.get_node_or_null("Connector/Right")
		if right_door:
			previous_right_door_global = right_door.global_position
		else:
			push_warning("⚠️ Room #" + str(i) + " missing Connector/Right, using fallback offset.")
			previous_right_door_global += Vector2(256, 0)

		# Player spawn w pierwszym pokoju
		if i == 0:
			var spawn_pos = room.get_node_or_null("PlayerSpawnPos")
			if spawn_pos:
				player.global_position = spawn_pos.global_position
			else:
				push_error("❌ Start room missing PlayerSpawnPos")

func _process(_delta):
	if Input.is_action_just_pressed("Reset"):
		restart_game()

func restart_game():
	print("🔄 Restarting game...")
	for child in get_children():
		if child != player:
			remove_child(child)
			child.queue_free()
	get_tree().reload_current_scene()
