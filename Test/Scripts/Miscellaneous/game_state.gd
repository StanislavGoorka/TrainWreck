extends Node

signal meta_currency_changed(amount: int)

const SAVE_PATH := "user://save.json"
const MENU_SCENE := "res://Test/Scenes/UIScenes/UIFullScenes/main_menu.tscn"   # adjust paths
const HUB_SCENE := "res://Test/Scenes/Hub/hub.tscn"
const RUN_SCENE := "res://Test/Scenes/game.tscn"
const CHARACTER_FOLDER := "res://Test/Scripts/Character/"
const DEFAULT_CHARACTER_ID := "slinger"
const DEATH_SCREEN_TIME := 1.5

var characters: Dictionary = {}                 # id -> CharacterDefinition
var selected_character: CharacterDefinition
var selected_id: String = ""
var unlocked_characters: Array[String] = []
var meta_currency: int = 0
var unlocks: Dictionary = {}                    # generic flags for future unlocks
var lifetime_stats: Dictionary = {"runs": 0, "wins": 0, "deaths": 0, "abandoned": 0}
var dialogue_progress: Dictionary = {}   # speaker id -> number of lines already said

var game_over: bool = false
var run_active: bool = false
var last_run: Dictionary = {}                   # summary of the run that just ended

signal floor_changed(floor_number: int)

const MIN_FLOOR_ROOMS := 5     # start, special, boss, end, and at least one more
const FLOOR_NAMES: Array[String] = []   # optional, e.g. ["Depot", "Cargo Car"]. Empty = "Floor N"

var current_floor: int = 1
var total_floors: int = 0      # set by rooms.gd when it builds the run, 0 = unknown

var run_time: float = 0.0
var floor_time: float = 0.0
var floor_times: Array[float] = []
var clock_paused: bool = false


func _ready() -> void:
	_load_characters()
	load_game()
	for def in characters.values():
		if def.unlocked_by_default and not unlocked_characters.has(def.id):
			unlocked_characters.append(def.id)
	# Safety net: the default character is always available.
	if characters.has(DEFAULT_CHARACTER_ID) and not unlocked_characters.has(DEFAULT_CHARACTER_ID):
		unlocked_characters.append(DEFAULT_CHARACTER_ID)
	if not characters.has(selected_id) or not is_unlocked(selected_id):
		selected_id = DEFAULT_CHARACTER_ID if characters.has(DEFAULT_CHARACTER_ID) else ""
	selected_character = characters.get(selected_id)

func _load_characters() -> void:
	var dir := DirAccess.open(CHARACTER_FOLDER)
	if dir == null:
		push_error("❌ Failed to open folder: " + CHARACTER_FOLDER)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and not dir.current_is_dir():
			var def := load(CHARACTER_FOLDER + file_name) as CharacterDefinition
			if def:
				characters[def.id] = def
		file_name = dir.get_next()
	dir.list_dir_end()

# --- Progression ---------------------------------------------------------

func is_unlocked(id: String) -> bool:
	return unlocked_characters.has(id)

func unlock_character(id: String) -> bool:
	var def: CharacterDefinition = characters.get(id)
	if not def or is_unlocked(id) or meta_currency < def.unlock_cost:
		return false
	meta_currency -= def.unlock_cost
	unlocked_characters.append(id)
	meta_currency_changed.emit(meta_currency)
	save_game()
	return true

func select_character(id: String) -> void:
	if not characters.has(id) or not is_unlocked(id):
		return
	selected_id = id
	selected_character = characters[id]
	save_game()

func add_meta_currency(amount: int) -> void:
	meta_currency += amount
	meta_currency_changed.emit(meta_currency)

# --- Scene flow ----------------------------------------------------------

func go_to_hub() -> void:
	game_over = false
	run_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE)

func start_run() -> void:
	game_over = false
	run_active = true
	current_floor = 1
	run_time = 0.0
	floor_time = 0.0
	floor_times.clear()
	clock_paused = false
	lifetime_stats["runs"] += 1
	save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(RUN_SCENE)

func advance_floor() -> void:
	if is_final_floor():
		end_run(true)
		return
	floor_times.append(floor_time)
	floor_time = 0.0
	current_floor += 1
	floor_changed.emit(current_floor)

func end_run(won: bool, abandoned: bool = false) -> void:
	if not run_active:
		return   # also stops repeated death signals from firing this twice
	run_active = false

	floor_times.append(floor_time)   # the floor the run ended on

	var player := get_tree().get_first_node_in_group("Players") as Player
	var earned: int = player.currency if player else 0
	add_meta_currency(earned)

	var result_key := "wins" if won else ("abandoned" if abandoned else "deaths")
	lifetime_stats[result_key] += 1
	last_run = {
		"won": won,
		"abandoned": abandoned,
		"coins": earned,
		"items": player.inventory.size() if player else 0,
		"run_time": run_time,
		"floor_times": floor_times.duplicate(),
	}
	save_game()

	if abandoned:
		go_to_hub()
		return

	game_over = true
	get_tree().paused = true
	if won:
		var victory := VictoryScreen.new()
		victory.setup(last_run)
		get_tree().root.add_child(victory)
	else:
		var screen := GameOverScreen.new()
		screen.setup(false, last_run)
		get_tree().root.add_child(screen)

func _process(delta: float) -> void:
	if run_active and not game_over and not clock_paused:
		run_time += delta
		floor_time += delta

func is_final_floor() -> bool:
	return total_floors > 0 and current_floor >= total_floors

func floor_title(n: int) -> String:
	var title := "Floor %d" % n
	if n - 1 < FLOOR_NAMES.size() and FLOOR_NAMES[n - 1] != "":
		title += ": " + FLOOR_NAMES[n - 1]
	return title

func format_time(seconds: float) -> String:
	var hours := floori(seconds / 3600.0)
	var minutes := floori(fmod(seconds, 3600.0) / 60.0)
	var secs := floori(fmod(seconds, 60.0))
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]


func go_to_menu() -> void:
	game_over = false
	run_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

# --- Save / load ---------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": 1,
		"meta_currency": meta_currency,
		"selected_id": selected_id,
		"unlocked_characters": unlocked_characters,
		"unlocks": unlocks,
		"lifetime_stats": lifetime_stats,
		"dialogue_progress": dialogue_progress,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	meta_currency = int(parsed.get("meta_currency", 0))
	selected_id = str(parsed.get("selected_id", ""))
	unlocked_characters.clear()
	for id in parsed.get("unlocked_characters", []):
		unlocked_characters.append(str(id))
	unlocks = parsed.get("unlocks", {})
	lifetime_stats.merge(parsed.get("lifetime_stats", {}), true)
	dialogue_progress = parsed.get("dialogue_progress", {})
