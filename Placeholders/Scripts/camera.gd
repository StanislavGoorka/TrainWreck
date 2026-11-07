extends Camera2D

@onready var player_node = get_parent().get_node("Character1")

const ROOM_WIDTH: float = 1920.0 
const ROOM_HEIGHT: float = 1080.0 

# Top left corner it 0,0 so room origin is 0,0
const ROOM_ORIGIN: Vector2 = Vector2(0.0, 0.0)

func _ready():
	position_smoothing_enabled = false
	set_screen_position()
	await get_tree().process_frame
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	print("Player start position: ", player_node.global_position)

func _process(_delta: float) -> void:
	set_screen_position()
	queue_redraw()

func set_screen_position():
	var player_pos = player_node.global_position

	# Player starting position
	var rel_x = player_pos.x - ROOM_ORIGIN.x
	var rel_y = player_pos.y - ROOM_ORIGIN.y

	var room_x = ROOM_ORIGIN.x + floor(rel_x / ROOM_WIDTH) * ROOM_WIDTH + ROOM_WIDTH / 2.0
	var room_y = ROOM_ORIGIN.y + floor(rel_y / ROOM_HEIGHT) * ROOM_HEIGHT + ROOM_HEIGHT / 2.0

	global_position = Vector2(room_x, room_y)

func _draw():
	# Debug frame to show where is camera
	var rel_x = player_node.global_position.x - ROOM_ORIGIN.x
	var rel_y = player_node.global_position.y - ROOM_ORIGIN.y
	var room_left = ROOM_ORIGIN.x + floor(rel_x / ROOM_WIDTH) * ROOM_WIDTH
	var room_top = ROOM_ORIGIN.y + floor(rel_y / ROOM_HEIGHT) * ROOM_HEIGHT
	draw_rect(Rect2(Vector2(room_left, room_top) - global_position, Vector2(ROOM_WIDTH, ROOM_HEIGHT)), Color.RED, false, 4.0)



#extends Camera2D
#
#@onready var screen_size: Vector2 = get_viewport_rect().size
#@onready var player_node = get_parent().get_node("Character1")
#
#func _ready():
	#set_screen_position()
	#await get_tree().process_frame
	#position_smoothing_enabled = true
	#position_smoothing_speed = 10.0
#
#func _process(delta: float) -> void:
	#set_screen_position()
#
#func set_screen_position():
	#var player_pos = player_node.global_position
	#var x = floor(player_pos.x / screen_size.x) * screen_size.x + screen_size.x / 2
	#var y = floor(player_pos.y / screen_size.y) * screen_size.y + screen_size.y / 2
	#global_position = Vector2(x, y)


#extends Camera2D
#
#@onready var screen_size: Vector2 = get_viewport_rect().size
#var player_node: Node2D = null
#var initialized := false
#
#func _ready() -> void:
	#await _wait_for_player()
	#await get_tree().process_frame
	#center_on_player()
#
	#position_smoothing_enabled = true
	#position_smoothing_speed = 10.0
	#initialized = true
#
#
#func _process(_delta: float) -> void:
	#if initialized and player_node:
		#set_screen_position()
#
#
#func _wait_for_player() -> void:
	## Try to get the player node until it appears in the tree
	#while player_node == null:
		#player_node = get_node_or_null("/root/Game/Character1")
		#if player_node == null:
			#await get_tree().process_frame
#
#
#func set_screen_position() -> void:
	#if player_node == null:
		#return
	#var player_pos = player_node.global_position
	#var x = floor(player_pos.x / screen_size.x) * screen_size.x + screen_size.x / 2
	#var y = floor(player_pos.y / screen_size.y) * screen_size.y + screen_size.y / 2
	#global_position = Vector2(x, y)


#func center_on_player() -> void:
	#if player_node:
		#global_position = player_node.global_position
