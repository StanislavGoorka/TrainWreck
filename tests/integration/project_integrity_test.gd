## Whole-project checks: every script compiles, every scene and resource loads, every
## res:// reference points to an existing file, scene signal connections reach real
## methods, input actions used in code exist, autoloads and project settings match what
## the code expects.
##
## Problems that already exist are listed in the KNOWN_* tables so the scans still
## guard everything else. Each table has a skipped test that checks the entries are
## fixed: once a problem is fixed, remove it from its table and drop that test's skip.
extends "res://tests/helpers/tw_test_suite.gd"

const ErrorCapture := preload("res://tests/helpers/error_capture.gd")

const EXCLUDED_DIRS: Array[String] = ["res://addons", "res://tests", "res://reports", "res://.godot"]

const KNOWN_BROKEN_SCRIPTS := {
	"res://Placeholders/Scripts/enemy_shoot.gd": "preloads res://Placeholders/Scenes/Enemies/laser_bullet.tscn, which does not exist",
}
const KNOWN_BROKEN_SCENES := {
	"res://Placeholders/Scenes/Rooms/testing_room.tscn": "instances Placeholders/Scenes/Enemies/*.tscn and Placeholders/Scenes/Items/coin.tscn, which do not exist",
}
const KNOWN_BAD_CONNECTIONS := {
	"res://Placeholders/Scenes/Characters/character_1.tscn": "DashTimer.timeout -> _on_dash_timer_timeout, which character.gd does not define",
}
const KNOWN_MISSING_PATHS := {
	"res://Placeholders/Scenes/UI/main_menu.tscn": "credits.gd sends the player to a main menu that does not exist (the credits Back button breaks)",
}


# --- File discovery ----------------------------------------------------------------

static func project_files(extensions: Array[String], dir := "res://") -> PackedStringArray:
	var result := PackedStringArray()
	for excluded in EXCLUDED_DIRS:
		if dir.trim_suffix("/") == excluded:
			return result
	for file_name in DirAccess.get_files_at(dir):
		if extensions.has(file_name.get_extension()):
			result.append(dir.path_join(file_name))
	for sub_dir in DirAccess.get_directories_at(dir):
		if not sub_dir.begins_with("."):
			result.append_array(project_files(extensions, dir.path_join(sub_dir)))
	return result


static func _report(problems: Array) -> String:
	return "\n  - " + "\n  - ".join(problems)


func test_project_contains_game_code() -> void:
	assert_int(project_files(["gd"]).size()).is_greater(50)
	assert_int(project_files(["tscn"]).size()).is_greater(20)


# --- Scripts -----------------------------------------------------------------------

func test_all_game_scripts_compile() -> void:
	var broken := []
	for path in project_files(["gd"]):
		if KNOWN_BROKEN_SCRIPTS.has(path):
			continue
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			broken.append(path)
	assert_array(broken).override_failure_message("Scripts that do not compile:" + _report(broken)).is_empty()


func test_known_broken_scripts_compile(
		do_skip := true,
		skip_reason := "KNOWN BUG: see KNOWN_BROKEN_SCRIPTS (enemy_shoot.gd preloads a missing scene)") -> void:
	for path: String in KNOWN_BROKEN_SCRIPTS:
		var script := load(path) as GDScript
		assert_bool(script != null and script.can_instantiate()).override_failure_message(path).is_true()


# --- Scenes and resources ----------------------------------------------------------

func test_all_scenes_load_and_instantiate() -> void:
	var broken := []
	for path in project_files(["tscn"]):
		if KNOWN_BROKEN_SCENES.has(path):
			continue
		var scene := load_pinned(path) as PackedScene
		if scene == null or not scene.can_instantiate():
			broken.append(path)
			continue
		var node := scene.instantiate()
		if node == null:
			broken.append(path + " (instantiate() failed)")
		else:
			node.free()
	assert_array(broken).override_failure_message("Scenes that cannot be loaded:" + _report(broken)).is_empty()


func test_known_broken_scenes_are_fixed(
		do_skip := true,
		skip_reason := "KNOWN BUG: see KNOWN_BROKEN_SCENES (testing_room.tscn depends on deleted scenes)") -> void:
	# Godot still loads a scene whose sub-scenes are gone, so check the dependencies.
	var missing := []
	for path: String in KNOWN_BROKEN_SCENES:
		missing.append_array(_missing_dependencies(path))
	assert_array(missing).override_failure_message("Missing dependencies:" + _report(missing)).is_empty()


func test_all_resources_load() -> void:
	var broken := []
	for path in project_files(["tres"]):
		if load_pinned(path) == null:
			broken.append(path)
	assert_array(broken).override_failure_message("Resources that cannot be loaded:" + _report(broken)).is_empty()


func test_scene_and_resource_dependencies_exist() -> void:
	var missing := []
	for path in project_files(["tscn", "tres"]):
		if not KNOWN_BROKEN_SCENES.has(path):
			missing.append_array(_missing_dependencies(path))
	assert_array(missing).override_failure_message("Missing dependencies:" + _report(missing)).is_empty()


static func _missing_dependencies(path: String) -> Array:
	var regex := RegEx.create_from_string('\\[ext_resource[^\\]]*path="([^"]+)"')
	var missing := []
	for match in regex.search_all(FileAccess.get_file_as_string(path)):
		var dependency := match.get_string(1)
		if not ResourceLoader.exists(dependency) and not FileAccess.file_exists(dependency):
			missing.append("%s -> %s" % [path, dependency])
	return missing


func test_scene_signal_connections_reach_existing_methods() -> void:
	var problems := []
	for path in project_files(["tscn"]):
		if KNOWN_BROKEN_SCENES.has(path) or KNOWN_BAD_CONNECTIONS.has(path):
			continue
		problems.append_array(_connection_problems(path))
	assert_array(problems).override_failure_message("Broken signal connections:" + _report(problems)).is_empty()


func test_known_bad_connections_are_fixed(
		do_skip := true,
		skip_reason := "KNOWN BUG: see KNOWN_BAD_CONNECTIONS (player DashTimer)") -> void:
	var problems := []
	for path: String in KNOWN_BAD_CONNECTIONS:
		problems.append_array(_connection_problems(path))
	assert_array(problems).override_failure_message(_report(problems)).is_empty()


func _connection_problems(path: String) -> Array:
	var problems := []
	var scene := load_pinned(path) as PackedScene
	var state := scene.get_state()
	if state.get_connection_count() == 0:
		return problems
	var capture := ErrorCapture.new()
	capture.start()   # instantiating prints an error for each broken connection
	var root := scene.instantiate()
	capture.stop()
	for i in state.get_connection_count():
		var source := root.get_node_or_null(state.get_connection_source(i))
		var target := root.get_node_or_null(state.get_connection_target(i))
		var signal_name := state.get_connection_signal(i)
		var method := state.get_connection_method(i)
		if source == null or target == null:
			problems.append("%s: %s -> %s (node missing)" % [path, state.get_connection_source(i), state.get_connection_target(i)])
		elif not source.has_signal(signal_name):
			problems.append("%s: %s has no signal '%s'" % [path, source.name, signal_name])
		elif not target.has_method(method):
			problems.append("%s: %s.%s -> %s.%s() does not exist" % [path, source.name, signal_name, target.name, method])
	root.free()
	return problems


# --- References inside scripts -----------------------------------------------------

func _script_paths() -> Array:
	var regex := RegEx.create_from_string('"(res://[^"]+)"')
	var found := []
	for path in project_files(["gd"]):
		if KNOWN_BROKEN_SCRIPTS.has(path):
			continue
		var line_number := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			line_number += 1
			if line.strip_edges().begins_with("#"):
				continue
			for match in regex.search_all(line):
				found.append({"file": path, "line": line_number, "path": match.get_string(1)})
	return found


static func _path_exists(path: String) -> bool:
	if path.ends_with("/"):
		return DirAccess.dir_exists_absolute(path)
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func test_res_paths_in_scripts_exist() -> void:
	var missing := []
	for ref: Dictionary in _script_paths():
		if KNOWN_MISSING_PATHS.has(ref["path"]):
			continue
		if not _path_exists(ref["path"]):
			missing.append("%s:%d -> %s" % [ref["file"], ref["line"], ref["path"]])
	assert_array(missing).override_failure_message("Paths that do not exist:" + _report(missing)).is_empty()


func test_known_missing_paths_exist(
		do_skip := true,
		skip_reason := "KNOWN BUG: see KNOWN_MISSING_PATHS (credits.gd main menu path)") -> void:
	for path: String in KNOWN_MISSING_PATHS:
		assert_bool(_path_exists(path)).override_failure_message(path).is_true()


func test_input_actions_used_in_code_exist() -> void:
	var single := RegEx.create_from_string(
		'(?:is_action_pressed|is_action_just_pressed|is_action_just_released|is_action_released|get_action_strength|action_get_events)\\(\\s*"([^"]+)"')
	var vector := RegEx.create_from_string('get_vector\\(\\s*"([^"]+)"\\s*,\\s*"([^"]+)"\\s*,\\s*"([^"]+)"\\s*,\\s*"([^"]+)"')
	var used := {}
	for path in project_files(["gd"]):
		var source := FileAccess.get_file_as_string(path)
		for match in single.search_all(source):
			used[match.get_string(1)] = path
		for match in vector.search_all(source):
			for group in range(1, 5):
				used[match.get_string(group)] = path
	assert_int(used.size()).is_greater(5)
	var missing := []
	for action: String in used:
		if not InputMap.has_action(action):
			missing.append("%s (used in %s)" % [action, used[action]])
	assert_array(missing).override_failure_message("Input actions missing from the Input Map:" + _report(missing)).is_empty()


func test_every_custom_input_action_has_a_binding() -> void:
	var unbound := []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_") and InputMap.action_get_events(action).is_empty():
			unbound.append(action)
	assert_array(unbound).is_empty()


# --- Project settings --------------------------------------------------------------

func test_autoloads_are_running_the_expected_scripts() -> void:
	var expected := {
		"GameState": "res://Test/Scripts/Miscellaneous/game_state.gd",
		"Audio": "res://Test/Scripts/Miscellaneous/Audio Related/audio_manager.gd",
		"GameSettings": "res://Test/Scripts/Settings/game_settings.gd",
	}
	for autoload_name: String in expected:
		var node := get_tree().root.get_node_or_null(autoload_name)
		assert_object(node).override_failure_message("autoload %s is not running" % autoload_name).is_not_null()
		assert_str(node.get_script().resource_path).is_equal(expected[autoload_name])


func test_main_scene_is_the_main_menu() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	if main_scene.begins_with("uid://"):
		main_scene = ResourceUID.get_id_path(ResourceUID.text_to_id(main_scene))
	assert_str(main_scene).is_equal("res://Test/Scenes/UIScenes/UIFullScenes/main_menu.tscn")
	assert_object(load(main_scene)).is_instanceof(PackedScene)


func test_physics_layers_match_the_layers_used_in_code() -> void:
	# Interactable and character_1.tscn use layer 2 for the player; Dash.gd uses
	# layer 3 for enemies; enemy scenes use layer value 4 (= layer 3).
	assert_str(ProjectSettings.get_setting("layer_names/2d_physics/layer_2")).is_equal("player")
	assert_str(ProjectSettings.get_setting("layer_names/2d_physics/layer_3")).is_equal("enemies")


func test_audio_bus_layout_has_the_buses_the_game_uses() -> void:
	for bus_name in Audio.BUSES:
		assert_int(AudioServer.get_bus_index(bus_name)).override_failure_message("missing bus " + bus_name).is_greater_equal(0)


func _tile_errors(path: String) -> Array:
	var capture := ErrorCapture.new()
	capture.start()
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	return Array(capture.stop()).filter(func(e: String) -> bool: return e.contains("tile"))


func test_room_tileset_fits_inside_its_texture() -> void:
	# Fixed with clean_tilesets.gd; this keeps the room TileSet clean.
	var errors := _tile_errors(ROOM_TILESET_PATH)
	assert_array(errors).override_failure_message("%s: %d tile errors" % [ROOM_TILESET_PATH, errors.size()]).is_empty()


func test_hub_tileset_fits_inside_its_texture(
		do_skip := true,
		skip_reason := "KNOWN BUG: the TileSet embedded in hub.tscn defines tiles outside its atlas texture; Godot logs thousands of 'Cannot create tile' / 'no tile at' errors (clean_tilesets.gd only cleans it when hub.tscn is open in the editor)") -> void:
	var errors := _tile_errors(HUB_SCENE_PATH)
	assert_array(errors).override_failure_message("%s: %d tile errors" % [HUB_SCENE_PATH, errors.size()]).is_empty()
