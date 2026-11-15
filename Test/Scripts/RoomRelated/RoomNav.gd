class_name RoomNav
extends Node2D

const CELL := 64.0   # keep this equal to your TileSet's tile size

var debug_draw := false

var room: Node2D
var anchor := Vector2.ZERO      # where the tile grid starts, so cells line up with tiles
var rect := Rect2()
var rect_room_pos := Vector2.INF
var grids := {}                 # "mask_extra" -> NavGrid
var warned := false

class NavGrid:
	var astar := AStarGrid2D.new()
	var origin := Vector2.ZERO
	var cell := 64.0
	var cols := 0
	var rows := 0

	func world_to_cell(p: Vector2) -> Vector2i:
		var local_pos: Vector2 = (p - origin) / cell
		return Vector2i(floori(local_pos.x), floori(local_pos.y))

	func cell_center(c: Vector2i) -> Vector2:
		return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell

	func is_solid(c: Vector2i) -> bool:
		return not astar.is_in_boundsv(c) or astar.is_point_solid(c)

	# The closest open cell, because the start or the target can sit in a blocked cell next to a wall.
	func nearest_open(c: Vector2i, max_ring: int = 4) -> Vector2i:
		if not is_solid(c):
			return c
		for r in range(1, max_ring + 1):
			var best := Vector2i(-1, -1)
			var best_d := INF
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var n := c + Vector2i(dx, dy)
					if not is_solid(n) and float(dx * dx + dy * dy) < best_d:
						best_d = float(dx * dx + dy * dy)
						best = n
			if best != Vector2i(-1, -1):
				return best
		return Vector2i(-1, -1)

func _ready() -> void:
	room = get_parent() as Node2D
	add_to_group("RoomNav")
	z_index = 200

static func find_for(tree: SceneTree, pos: Vector2) -> RoomNav:
	for nav in tree.get_nodes_in_group("RoomNav"):
		if nav.contains(pos):
			return nav
	return null

func contains(pos: Vector2) -> bool:
	return _update_rect() and rect.has_point(pos)

# The room's bounds come from the same markers the camera uses.
func _update_rect() -> bool:
	if room == null:
		return false
	if room.global_position == rect_room_pos:
		return rect.has_area()

	rect = _tile_bounds()
	if not rect.has_area():
		rect = _marker_bounds()
	if not rect.has_area():
		if not warned:
			warned = true
			push_warning("RoomNav: %s has no painted tiles and no Connector/Top/Bottom markers, so it has no bounds." % room.name)
		return false
	rect_room_pos = room.global_position

	# Align the cells with the tiles, using the tile layer's own position.
	anchor = room.global_position
	for child in room.get_children():
		if child.is_class("TileMapLayer") or child.is_class("TileMap"):
			anchor = (child as Node2D).global_position
			break

	grids.clear()   # the room moved, so any old grid is stale
	return true

# The area covered by every painted tile in the room (works for TileMapLayer and TileMap).
func _tile_bounds() -> Rect2:
	var result := Rect2()
	var found := false
	for child in room.get_children():
		if not (child.is_class("TileMapLayer") or child.is_class("TileMap")):
			continue
		var tm = child   # untyped on purpose, both node types have these methods
		if tm.tile_set == null:
			continue
		var used: Rect2i = tm.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var tile_size := Vector2(tm.tile_set.tile_size)
		var top_left: Vector2 = tm.to_global(tm.map_to_local(used.position) - tile_size * 0.5)
		var area := Rect2(top_left, Vector2(used.size) * tile_size)
		result = area if not found else result.merge(area)
		found = true
	return result

func _marker_bounds() -> Rect2:
	var left := room.get_node_or_null("Connector/Left") as Node2D
	var right := room.get_node_or_null("Connector/Right") as Node2D
	var top := room.get_node_or_null("Top") as Node2D
	var bottom := room.get_node_or_null("Bottom") as Node2D
	if left == null or right == null or top == null or bottom == null:
		return Rect2()
	var x1 := minf(left.global_position.x, right.global_position.x)
	var x2 := maxf(left.global_position.x, right.global_position.x)
	var y1 := minf(top.global_position.y, bottom.global_position.y)
	var y2 := maxf(top.global_position.y, bottom.global_position.y)
	return Rect2(x1, y1, x2 - x1, y2 - y1)

func _grid(mask: int, extra: int) -> NavGrid:
	var key := "%d_%d" % [mask, extra]
	if not grids.has(key):
		grids[key] = _build(mask, extra)
	return grids[key]

# Builds the grid for an enemy type right away, so the report prints on the first chase.
func prepare(mask: int, radius: float) -> void:
	if not _update_rect():
		return
	var extra: int = maxi(ceili((radius - CELL * 0.5) / CELL), 0)
	_grid(mask, extra)

func _build(mask: int, extra: int) -> NavGrid:
	var g := NavGrid.new()
	g.cell = CELL
	var rel: Vector2 = rect.position - anchor
	g.origin = anchor + Vector2(floorf(rel.x / CELL), floorf(rel.y / CELL)) * CELL
	g.cols = ceili((rect.end.x - g.origin.x) / CELL)
	g.rows = ceili((rect.end.y - g.origin.y) / CELL)
	g.astar.region = Rect2i(0, 0, g.cols, g.rows)
	g.astar.cell_size = Vector2(CELL, CELL)
	g.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.astar.update()

	# A cell is blocked if anything touches it. The square is 2 px smaller than the cell,
	# so neighboring walls that only share an edge don't count.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL - 2.0, CELL - 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space: PhysicsDirectSpaceState2D = room.get_world_2d().direct_space_state

	var blocked: Array[Vector2i] = []
	for y in g.rows:
		for x in g.cols:
			query.transform = Transform2D(0.0, g.cell_center(Vector2i(x, y)))
			if not space.intersect_shape(query, 1).is_empty():
				blocked.append(Vector2i(x, y))

	# Bigger enemies need more room around walls, so the blocked area grows by whole cells.
	for c in blocked:
		for dy in range(-extra, extra + 1):
			for dx in range(-extra, extra + 1):
				var n := Vector2i(c.x + dx, c.y + dy)
				if g.astar.is_in_boundsv(n):
					g.astar.set_point_solid(n, true)
	_print_report(g, mask, blocked.size())
	if debug_draw:
		queue_redraw()
	return g

# World-space waypoints (cell centers), or an empty array if there is no way through.
func find_path(from: Vector2, to: Vector2, mask: int, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not _update_rect():
		return result
	var extra: int = maxi(ceili((radius - CELL * 0.5) / CELL), 0)
	var g: NavGrid = _grid(mask, extra)
	var a: Vector2i = g.nearest_open(g.world_to_cell(from))
	var b: Vector2i = g.nearest_open(g.world_to_cell(to))
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return result
	for cell_id in g.astar.get_id_path(a, b):
		result.append(g.cell_center(cell_id))
	return result

func _print_report(g: NavGrid, mask: int, blocked_count: int) -> void:
	print("[RoomNav] %s | grid %dx%d | blocked cells %d | mask %d | origin %s | rect %s" % [room.name, g.cols, g.rows, blocked_count, mask, g.origin, rect])
	for child in room.get_children():
		if child.is_class("TileMapLayer"):
			var layer := child as TileMapLayer
			var set_info := "NO TILESET"
			if layer.tile_set:
				var parts: Array[String] = []
				for i in layer.tile_set.get_physics_layers_count():
					parts.append("physics layer %d -> collision layer bits %d" % [i, layer.tile_set.get_physics_layer_collision_layer(i)])
				set_info = ", ".join(parts)
			print("    %s | enabled %s | collision_enabled %s | %s" % [layer.name, layer.enabled, layer.collision_enabled, set_info])

# True when the enemy's real collision shape can slide from one point to the other without touching anything.
func line_clear(shape: Shape2D, shape_offset: Vector2, from: Vector2, to: Vector2, mask: int) -> bool:
	if shape == null or room == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = mask
	query.collide_with_areas = false
	query.transform = Transform2D(0.0, from + shape_offset)
	query.motion = to - from
	var space: PhysicsDirectSpaceState2D = room.get_world_2d().direct_space_state
	var motion_result: PackedFloat32Array = space.cast_motion(query)
	return motion_result.size() >= 2 and motion_result[0] >= 1.0

func _draw() -> void:
	if not debug_draw or grids.is_empty():
		return
	var g: NavGrid = grids.values()[0]   # only the first grid, so the red doesn't stack
	for y in g.rows:
		for x in g.cols:
			if g.astar.is_point_solid(Vector2i(x, y)):
				var top_left: Vector2 = g.origin + Vector2(x, y) * CELL
				draw_rect(Rect2(to_local(top_left), Vector2(CELL, CELL)), Color(1, 0, 0, 0.25))
