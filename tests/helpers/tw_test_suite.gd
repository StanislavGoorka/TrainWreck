## Base class for every TrainWreck test suite.
##
## The game keeps state in autoload singletons (GameState, Audio, GameSettings), in
## engine singletons (pause, Input, AudioServer, the global RNG) and in user:// files.
## This class snapshots all of it before each test and restores it afterwards (floor
## progress and run clock included), so
## tests cannot leak into each other and never overwrite the developer's real save.
##
## Suites that override a hook must call super(), e.g. [code]super.before_test()[/code]
## ([code]await super.after_test()[/code] for after_test, which is a coroutine).
extends GdUnitTestSuite

const Factory := preload("res://tests/helpers/factory.gd")

const ROOM_TILESET_PATH := "res://Placeholders/Scenes/Rooms/testing_room.tres"
const HUB_SCENE_PATH := "res://Test/Scenes/Hub/hub.tscn"

# Resources kept alive for the whole test run, see load_pinned().
static var _pinned := {}

const USER_FILES: Array[String] = ["user://save.json", "user://settings.cfg"]
const GAME_STATE_FIELDS: Array[String] = [
	"characters", "selected_character", "selected_id", "unlocked_characters",
	"meta_currency", "unlocks", "lifetime_stats", "dialogue_progress",
	"game_over", "run_active", "last_run",
	"current_floor", "total_floors", "run_time", "floor_time", "floor_times", "clock_paused",
]

var _user_files := {}
var _game_state := {}
var _audio := {}
var _buses: Array[Dictionary] = []
var _fullscreen := false
var _current_scene: Node


func before() -> void:
	_user_files = backup_user_files()


func after() -> void:
	restore_user_files(_user_files)


func before_test() -> void:
	_game_state = _snapshot_game_state()
	_audio = _snapshot_audio()
	_buses = _snapshot_buses()
	_fullscreen = GameSettings.fullscreen
	_current_scene = get_tree().current_scene
	# Player fixtures must use the stats they were built with, not the selected character.
	GameState.selected_character = null
	GameState.run_active = false
	GameState.game_over = false
	# Every test starts on floor 1 of a run of unknown length (rooms.gd sets total_floors).
	GameState.current_floor = 1
	GameState.total_floors = 0
	GameState.run_time = 0.0
	GameState.floor_time = 0.0
	GameState.floor_times.clear()
	GameState.clock_paused = false


func after_test() -> void:
	var input_used := false
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action) or Input.is_action_just_pressed(action):
			input_used = true
		Input.action_release(action)
	get_tree().paused = false
	if get_tree().current_scene != _current_scene:
		get_tree().current_scene = _current_scene if is_instance_valid(_current_scene) else null
	_free_game_over_screens()
	_restore_game_state(_game_state)
	_restore_audio(_audio)
	_restore_buses(_buses)
	GameSettings.fullscreen = _fullscreen
	randomize()
	if input_used:
		# is_action_just_pressed() stays true until the frame ends, even after
		# action_release(), so the next test must start in a fresh frame.
		await get_tree().process_frame


# --- Helpers available to every suite --------------------------------------------

## Makes [param node] the tree's current_scene (restored after the test). Game code
## such as CharacterStation or WeaponIdle adds nodes to the current scene.
func use_as_current_scene(node: Node) -> void:
	if node.get_parent() != get_tree().root:
		get_tree().root.add_child(node)
	get_tree().current_scene = node


## Waits until [param condition] returns true or [param timeout_ms] passes.
## Returns true if the condition was met in time.
func wait_until(condition: Callable, timeout_ms := 2000) -> bool:
	var end := Time.get_ticks_msec() + timeout_ms
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true


func wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Loads [param path] once per test run and keeps it in the resource cache.
## The room TileSet and the TileSet embedded in hub.tscn log thousands of tile errors
## when loaded (see project_integrity_test); printing them takes from seconds to over
## a minute, so suites that need rooms or the hub load them through this function.
static func load_pinned(path: String) -> Resource:
	if not _pinned.has(path):
		_pinned[path] = load(path)
	return _pinned[path]


static func remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func write_user_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


static func backup_user_files() -> Dictionary:
	var backup := {}
	for path in USER_FILES:
		backup[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return backup


static func restore_user_files(backup: Dictionary) -> void:
	for path: String in backup:
		var data: Variant = backup[path]
		if data == null:
			remove_user_file(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(data)
			file.close()


# --- Snapshots ---------------------------------------------------------------------

func _snapshot_game_state() -> Dictionary:
	var snapshot := {}
	for field in GAME_STATE_FIELDS:
		var value: Variant = GameState.get(field)
		snapshot[field] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return snapshot


func _restore_game_state(snapshot: Dictionary) -> void:
	for field: String in snapshot:
		GameState.set(field, snapshot[field])


func _snapshot_audio() -> Dictionary:
	var players := []
	for player: AudioStreamPlayer in Audio._players:
		players.append({"stream": player.stream, "volume_db": player.volume_db, "playing": player.playing})
	return {
		"volumes": Audio.volumes.duplicate(),
		"current": Audio._current_stream,
		"active": Audio._active,
		"players": players,
	}


func _restore_audio(snapshot: Dictionary) -> void:
	if Audio._fade_tween:
		Audio._fade_tween.kill()
	Audio._save_timer.stop()   # no delayed write of user://settings.cfg after the test
	for i in Audio._players.size():
		var player: AudioStreamPlayer = Audio._players[i]
		var state: Dictionary = snapshot["players"][i]
		player.stop()
		player.stream = state["stream"]
		player.volume_db = state["volume_db"]
		if state["playing"]:
			player.play()
	Audio.volumes = snapshot["volumes"]
	Audio._current_stream = snapshot["current"]
	Audio._active = snapshot["active"]
	for child in Audio.get_children():
		if child is AudioStreamPlayer and not Audio._players.has(child):
			child.queue_free()   # one-shot SFX players


func _snapshot_buses() -> Array[Dictionary]:
	var buses: Array[Dictionary] = []
	for i in AudioServer.bus_count:
		buses.append({"volume_db": AudioServer.get_bus_volume_db(i), "mute": AudioServer.is_bus_mute(i)})
	return buses


func _restore_buses(buses: Array[Dictionary]) -> void:
	for i in mini(buses.size(), AudioServer.bus_count):
		AudioServer.set_bus_volume_db(i, buses[i]["volume_db"])
		AudioServer.set_bus_mute(i, buses[i]["mute"])


func _free_game_over_screens() -> void:
	for child in get_tree().root.get_children():
		if child is GameOverScreen or child is VictoryScreen:
			get_tree().root.remove_child(child)
			child.free()
