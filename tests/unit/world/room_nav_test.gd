## RoomNav: the per-room grid enemies use to find their way around walls and holes.
## The rooms are Factory.nav_room() fixtures (markers + StaticBody2D blocks), placed far
## from the origin so no other physics body can touch them.
extends "res://tests/helpers/tw_test_suite.gd"

const ORIGIN := Vector2(20000, 20000)
const WALLS := 1
const GROUND := 32        # holes
const WALKER_MASK := 97   # walls + ground + objects, as Slayer.tscn and laureth.tscn
const SMALL := 16.0       # fits in one cell: no extra clearance
const BIG := 80.0         # needs one extra cell of clearance around walls

var room: Node2D
var nav: RoomNav


func before_test() -> void:
	super.before_test()
	room = auto_free(Factory.nav_room(Vector2i(10, 6)))
	add_child(room)
	room.global_position = ORIGIN
	nav = room.get_node("RoomNav")


## Global position of the centre of a grid cell.
func _at(cell: Vector2i) -> Vector2:
	return room.global_position + Factory.nav_cell(cell)


## Grid cell of a global position.
func _cell(pos: Vector2) -> Vector2i:
	var local_pos := (pos - room.global_position) / RoomNav.CELL
	return Vector2i(floori(local_pos.x), floori(local_pos.y))


## Physics queries only see bodies once the physics server has stepped.
func _settle() -> void:
	await wait_physics_frames(2)


func _cells(path: PackedVector2Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for point in path:
		result.append(_cell(point))
	return result


# --- Bounds ------------------------------------------------------------------------

func test_bounds_come_from_the_connector_and_top_bottom_markers() -> void:
	assert_bool(nav.contains(ORIGIN + Vector2(10, 10))).is_true()
	assert_bool(nav.contains(ORIGIN + Vector2(630, 374))).is_true()
	assert_bool(nav.contains(ORIGIN + Vector2(-10, 10))).is_false()
	assert_bool(nav.contains(ORIGIN + Vector2(10, 400))).is_false()
	assert_that(nav.rect).is_equal(Rect2(ORIGIN, Vector2(640, 384)))


func test_a_room_without_tiles_or_markers_has_no_bounds_and_no_path() -> void:
	var bare: Node2D = auto_free(Node2D.new())
	var bare_nav := RoomNav.new()
	bare.add_child(bare_nav)
	add_child(bare)
	assert_bool(bare_nav.contains(Vector2.ZERO)).is_false()
	assert_array(Array(bare_nav.find_path(Vector2.ZERO, Vector2(100, 0), WALLS, SMALL))).is_empty()
	assert_bool(bare_nav.warned).is_true()   # warns once instead of every frame


func test_painted_tiles_set_the_bounds_and_align_the_grid() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	var source := TileSetAtlasSource.new()
	source.texture = Factory.texture(Vector2(64, 64))
	source.texture_region_size = Vector2i(64, 64)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.position = Vector2(32, 0)   # the grid must follow the tile layer, not the room origin
	layer.set_cell(Vector2i(2, 1), 0, Vector2i.ZERO)
	layer.set_cell(Vector2i(5, 3), 0, Vector2i.ZERO)
	room.add_child(layer)
	# Painted tiles win over the markers the fixture room also has.
	var expected := Rect2(ORIGIN + Vector2(32 + 128, 64), Vector2(4 * 64, 3 * 64))
	assert_bool(nav.contains(expected.get_center())).is_true()
	assert_that(nav.rect).is_equal(expected)
	assert_vector(nav.anchor).is_equal(layer.global_position)
	nav.prepare(WALLS, SMALL)
	var grid = nav._grid(WALLS, 0)
	assert_vector(grid.origin).is_equal(expected.position)
	assert_int(grid.cols).is_equal(4)
	assert_int(grid.rows).is_equal(3)


# --- Paths -------------------------------------------------------------------------

func test_path_in_an_open_room_runs_from_the_start_cell_to_the_goal_cell() -> void:
	await _settle()
	var path := nav.find_path(_at(Vector2i(1, 1)), _at(Vector2i(8, 1)), WALLS, SMALL)
	assert_int(path.size()).is_greater_equal(8)
	assert_vector(path[0]).is_equal(_at(Vector2i(1, 1)))
	assert_vector(path[path.size() - 1]).is_equal(_at(Vector2i(8, 1)))


func test_path_goes_around_a_wall_through_the_gap() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3))   # gap in rows 4 and 5
	await _settle()
	var cells := _cells(nav.find_path(_at(Vector2i(1, 1)), _at(Vector2i(8, 1)), WALLS, SMALL))
	assert_array(cells).is_not_empty()
	for cell in cells:
		assert_bool(cell.x == 4 and cell.y <= 3).override_failure_message("waypoint inside the wall at %s" % cell).is_false()
	var crossing := cells.filter(func(c: Vector2i) -> bool: return c.x == 4)
	assert_array(crossing).is_not_empty()
	assert_int(crossing[0].y).is_greater_equal(4)


func test_a_sealed_off_goal_gives_no_path() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 5))
	await _settle()
	assert_array(Array(nav.find_path(_at(Vector2i(1, 1)), _at(Vector2i(8, 1)), WALLS, SMALL))).is_empty()


func test_holes_block_walking_enemies_but_not_flying_ones() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 5), GROUND)   # a hole across the room
	await _settle()
	var from := _at(Vector2i(1, 2))
	var to := _at(Vector2i(8, 2))
	assert_array(Array(nav.find_path(from, to, WALKER_MASK, SMALL))).override_failure_message("walkers cross holes").is_empty()
	assert_array(Array(nav.find_path(from, to, WALLS, SMALL))).override_failure_message("flyers cannot cross holes").is_not_empty()


func test_big_enemies_do_not_squeeze_through_a_one_cell_gap() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 2))
	Factory.nav_block(room, Vector2i(4, 4), Vector2i(4, 5))   # the only gap is cell (4, 3)
	await _settle()
	var from := _at(Vector2i(1, 3))
	var to := _at(Vector2i(8, 3))
	assert_array(_cells(nav.find_path(from, to, WALLS, SMALL))).contains([Vector2i(4, 3)])
	# The grid of a big enemy grows every blocked cell by one, which closes the gap.
	assert_bool(nav._grid(WALLS, 1).astar.is_point_solid(Vector2i(4, 3))).is_true()
	assert_bool(nav._grid(WALLS, 0).astar.is_point_solid(Vector2i(4, 3))).is_false()
	assert_bool(RoomNav.ALLOW_TIGHT_FALLBACK).is_false()   # with the fallback on, big enemies would retry tighter grids
	assert_array(Array(nav.find_path(from, to, WALLS, BIG))).is_empty()


func test_a_start_inside_a_wall_snaps_to_the_nearest_open_cell() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3))
	await _settle()
	var path := nav.find_path(_at(Vector2i(4, 1)), _at(Vector2i(8, 1)), WALLS, SMALL)
	assert_array(Array(path)).is_not_empty()
	assert_array([Vector2i(3, 1), Vector2i(5, 1)]).contains([_cell(path[0])])


func test_open_cells_next_to_walls_and_the_room_edge_cost_more() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3))
	await _settle()
	nav.prepare(WALLS, SMALL)
	var grid = nav._grid(WALLS, 0)
	assert_bool(grid.astar.is_point_solid(Vector2i(4, 2))).is_true()
	assert_float(grid.astar.get_point_weight_scale(Vector2i(3, 2))).is_equal(RoomNav.WALL_WEIGHT)   # next to the wall
	assert_float(grid.astar.get_point_weight_scale(Vector2i(0, 3))).is_equal(RoomNav.WALL_WEIGHT)   # room edge
	assert_float(grid.astar.get_point_weight_scale(Vector2i(2, 3))).is_equal(1.0)


func test_grids_are_cached_per_mask_and_clearance() -> void:
	await _settle()
	var from := _at(Vector2i(1, 1))
	var to := _at(Vector2i(8, 4))
	nav.find_path(from, to, WALLS, SMALL)
	nav.find_path(from, to, WALLS, SMALL)
	assert_int(nav.grids.size()).is_equal(1)
	nav.find_path(from, to, WALKER_MASK, SMALL)
	assert_int(nav.grids.size()).is_equal(2)
	nav.find_path(from, to, WALLS, BIG)
	assert_int(nav.grids.size()).is_equal(3)


func test_moving_the_room_rebuilds_the_grid_at_the_new_place() -> void:
	# rooms.gd adds a room first and moves it to its slot afterwards.
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3))
	await _settle()
	nav.find_path(_at(Vector2i(1, 1)), _at(Vector2i(8, 1)), WALLS, SMALL)
	room.global_position = ORIGIN + Vector2(1280, 0)
	await _settle()
	assert_bool(nav.contains(ORIGIN + Vector2(10, 10))).is_false()
	assert_bool(nav.contains(ORIGIN + Vector2(1290, 10))).is_true()
	var cells := _cells(nav.find_path(_at(Vector2i(1, 1)), _at(Vector2i(8, 1)), WALLS, SMALL))
	assert_array(cells).is_not_empty()
	assert_vector(nav._grid(WALLS, 0).origin).is_equal(room.global_position)
	for cell in cells:
		assert_bool(cell.x == 4 and cell.y <= 3).override_failure_message("the wall moved but the grid did not: %s" % cell).is_false()


# --- Line of sight -----------------------------------------------------------------

func test_line_clear_checks_the_real_body_shape_against_the_mask() -> void:
	Factory.nav_block(room, Vector2i(4, 0), Vector2i(4, 3))
	var enemy_body := Factory.nav_block(room, Vector2i(6, 4), Vector2i(6, 4), 4)   # on the enemy layer
	await _settle()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	assert_bool(nav.line_clear(circle, Vector2.ZERO, _at(Vector2i(1, 1)), _at(Vector2i(8, 1)), WALLS)).is_false()
	assert_bool(nav.line_clear(circle, Vector2.ZERO, _at(Vector2i(1, 4)), _at(Vector2i(8, 4)), WALLS)).is_true()
	# Other enemies are not obstacles for the line, unless the mask asks for them.
	assert_bool(nav.line_clear(circle, Vector2.ZERO, _at(Vector2i(1, 4)), _at(Vector2i(8, 4)), WALLS | int(enemy_body.collision_layer))).is_false()
	# The shape offset counts: the same line with the body shape 192 px higher runs into the wall.
	assert_bool(nav.line_clear(circle, Vector2(0, -192), _at(Vector2i(1, 4)), _at(Vector2i(8, 4)), WALLS)).is_false()
