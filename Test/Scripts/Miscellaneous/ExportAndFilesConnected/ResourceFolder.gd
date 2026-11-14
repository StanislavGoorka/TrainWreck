class_name ResourceFolder
extends RefCounted

# Lists resource files of one type in a folder. Works in the editor and in exported builds,
# where files are renamed to "name.tscn.remap".
static func list(folder: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("Failed to open folder: " + folder)
		return result
	for file in dir.get_files():
		var clean := file.trim_suffix(".remap")
		var full := folder.path_join(clean)
		if clean.ends_with("." + extension) and not result.has(full):
			result.append(full)
	return result
