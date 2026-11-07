extends Node2D

@onready var spawn: Marker2D = $PlayerSpawnPos
@onready var cam_top_left: Marker2D = $CameraTopLeft
@onready var cam_bottom_right: Marker2D = $CameraBottomRight

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("Players") as Player
	if not player:
		push_error("Hub has no player instance!")
		return
	player.global_position = spawn.global_position
	_apply_camera_limits(player.get_node("Camera2D") as Camera2D)

	# UI that only makes sense during a run (map, timer).
	for node in get_tree().get_nodes_in_group("RunOnlyUI"):
		node.hide()

func _apply_camera_limits(cam: Camera2D) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size / cam.zoom
	var rect := Rect2(cam_top_left.global_position, cam_bottom_right.global_position - cam_top_left.global_position).abs()
	var center := rect.get_center()
	var half := Vector2(maxf(rect.size.x, view.x), maxf(rect.size.y, view.y)) / 2.0
	cam.limit_left = int(center.x - half.x)
	cam.limit_right = int(center.x + half.x)
	cam.limit_top = int(center.y - half.y)
	cam.limit_bottom = int(center.y + half.y)
