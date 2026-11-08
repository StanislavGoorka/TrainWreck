@tool
extends EditorScript

# External TileSet files to clean. Adjust the path.
const TILESET_PATHS: Array[String] = [
	"res://Placeholders/Scenes/Rooms/testing_room.tres"
]

func _run() -> void:
	var removed := 0
	for path in TILESET_PATHS:
		var tileset := load(path) as TileSet
		if not tileset:
			push_warning("Could not load " + path)
			continue
		removed += _clean(tileset, path)
		ResourceSaver.save(tileset, path)

	# TileSets embedded in the scene that is open in the editor (for example hub.tscn).
	var root := EditorInterface.get_edited_scene_root()
	if root:
		for tilemap in _find_tilemaps(root):
			var tileset := tilemap.tile_set
			if tileset and tileset.resource_path.find("::") != -1:   # embedded in a scene
				removed += _clean(tileset, String(root.scene_file_path))
		print("Save the open scene (Ctrl+S) to keep changes to its embedded TileSets.")

	print("Done. Tiles removed: ", removed)

func _clean(tileset: TileSet, label: String) -> int:
	var removed := 0
	for i in tileset.get_source_count():
		var source := tileset.get_source(tileset.get_source_id(i)) as TileSetAtlasSource
		if source == null:
			continue
		if source.texture == null:
			# Without a texture every tile counts as outside it, and they would all be deleted.
			push_warning("%s: an atlas source has no texture, skipped." % label)
			continue
		var before := source.get_tiles_count()
		source.clear_tiles_outside_texture()
		removed += before - source.get_tiles_count()
	print(label, ": removed ", removed, " tiles")
	return removed

func _find_tilemaps(node: Node) -> Array[TileMap]:
	var result: Array[TileMap] = []
	if node is TileMap:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_tilemaps(child))
	return result
