## Checks the game data in .tres files: every saved property still exists on its
## script (renamed fields are silently dropped by Godot), and the values make sense.
extends "res://tests/helpers/tw_test_suite.gd"

const Integrity := preload("res://tests/integration/project_integrity_test.gd")

const ITEM_FOLDER := "res://Test/Scripts/Resource/ItemResource/"
const ENEMY_FOLDER := "res://Test/Scripts/Resource/EnemyResource/"
const WEAPON_FOLDER := "res://Test/Scripts/Resource/WeaponResource/"
const CHARACTER_FOLDER := "res://Test/Scripts/Resource/CharacterResource/"
const DIALOGUE_FOLDER := "res://Test/Scripts/Resource/DialogueResource/"
const BOSS_FOLDER := "res://Test/Scripts/Resource/BossResource/"
const ENEMY_SCENE_FOLDERS: Array[String] = ["res://Test/Scenes/Enemies/"]

const KNOWN_STALE_PROPERTIES := {
	"res://Test/Scripts/Resource/CharacterResource/SlingerStats.tres": "uses old field names (name, health, dash_speed, damage, fire_rate, bullet_speed, shoot_range, special_chances); only speed and luck reach CharacterStats",
}


static func _resources_in(folder: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(".tres"):
			result.append(load(folder + file_name))
	return result


## Keys saved in the [resource] section of a .tres file.
static func _saved_keys(path: String) -> PackedStringArray:
	var keys := PackedStringArray()
	var in_resource := false
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("["):
			in_resource = line.begins_with("[resource]")
			continue
		if in_resource and " = " in line and not line.begins_with(" ") and not line.begins_with("\t"):
			keys.append(line.get_slice(" = ", 0))
	return keys


static func _stale_keys(path: String) -> PackedStringArray:
	var resource := load(path)
	if resource == null or resource.get_script() == null:
		return PackedStringArray()
	var known := {}
	for property in resource.get_property_list():
		known[property["name"]] = true
	var stale := PackedStringArray()
	for key in _saved_keys(path):
		if key == "script" or key.begins_with("metadata/") or key.begins_with("resource_"):
			continue
		if not known.has(key):
			stale.append(key)
	return stale


# --- Schema ------------------------------------------------------------------------

func test_saved_properties_exist_on_their_scripts() -> void:
	var problems := []
	for path in Integrity.project_files(["tres"]):
		if KNOWN_STALE_PROPERTIES.has(path):
			continue
		var stale := _stale_keys(path)
		if not stale.is_empty():
			problems.append("%s: %s" % [path, ", ".join(stale)])
	assert_array(problems).override_failure_message(
		"Saved values that no script property receives:\n  - " + "\n  - ".join(problems)).is_empty()


func test_known_stale_resources_are_fixed(
		do_skip := true,
		skip_reason := "KNOWN BUG: SlingerStats.tres uses old CharacterStats field names, so the Gunslinger's health, dash and weapon values are ignored") -> void:
	for path: String in KNOWN_STALE_PROPERTIES:
		assert_array(Array(_stale_keys(path))).override_failure_message(path).is_empty()


# --- Items -------------------------------------------------------------------------

func test_item_folder_is_not_empty() -> void:
	assert_array(_resources_in(ITEM_FOLDER)).is_not_empty()


func test_items_are_complete() -> void:
	for item: ItemData in _resources_in(ITEM_FOLDER):
		var where := item.resource_path
		assert_object(item).override_failure_message(where + " is not an ItemData").is_instanceof(ItemData)
		assert_str(item.item_name.strip_edges()).override_failure_message(where + " has no name").is_not_empty()
		assert_str(item.description).override_failure_message(where + " has no description").is_not_empty()
		assert_int(item.rarity).override_failure_message(where).is_between(0, ItemData.Rarity.size() - 1)
		assert_int(item.pools).override_failure_message(where + " is in no pool and can never drop").is_not_zero()
		assert_float(item.status_chance).override_failure_message(where).is_between(0.0, 100.0)
		assert_object(item.get_icon()).override_failure_message(where + " has no icon").is_not_null()


func test_item_names_are_unique() -> void:
	# Pedestals skip items by name, so two items with one name would hide each other.
	var seen := {}
	for item: ItemData in _resources_in(ITEM_FOLDER):
		var key := item.item_name.strip_edges().to_lower()
		assert_bool(seen.has(key)).override_failure_message(
			"%s and %s share the name '%s'" % [seen.get(key, ""), item.resource_path, item.item_name]).is_false()
		seen[key] = item.resource_path


func test_every_pool_has_items() -> void:
	for pool in [ItemData.POOL_ITEM_ROOM, ItemData.POOL_BOSS]:
		var items := _resources_in(ITEM_FOLDER).filter(func(i: ItemData) -> bool: return i.pools & pool)
		assert_array(items).override_failure_message("no items in pool %d" % pool).is_not_empty()


func test_status_items_have_a_status_chance() -> void:
	for item: ItemData in _resources_in(ITEM_FOLDER):
		if item.status_effect != StatusEffect.Type.NONE:
			assert_float(item.status_chance).override_failure_message(item.resource_path).is_greater(0.0)


# --- Enemies and bosses ------------------------------------------------------------

func test_enemy_stats_are_playable() -> void:
	var all: Array[Resource] = _resources_in(ENEMY_FOLDER)
	all.append_array(_resources_in(BOSS_FOLDER))
	assert_array(all).is_not_empty()
	for stats: EnemyStats in all:
		var where := stats.resource_path
		assert_float(stats.max_health).override_failure_message(where).is_greater(0.0)
		assert_float(stats.speed).override_failure_message(where).is_greater(0.0)
		assert_float(stats.damage).override_failure_message(where).is_greater_equal(0.0)
		assert_float(stats.attack_cooldown).override_failure_message(where).is_greater(0.0)


func test_bosses_have_names_and_a_valid_spin_cycle() -> void:
	for stats: Resource in _resources_in(BOSS_FOLDER):
		assert_object(stats).is_instanceof(BossStats)
		assert_str(stats.boss_name).is_not_empty()
		if stats is SpinBossStats:
			for property in ["spin_trigger_range", "spin_windup", "spin_duration", "spin_recovery", "spin_cooldown"]:
				assert_float(stats.get(property)).override_failure_message(property).is_greater(0.0)


## Enemy scene path -> path of the stats resource its root node uses ("" if none).
func _enemy_scene_stats() -> Dictionary:
	var result := {}
	for path in Integrity.project_files(["tscn"]):
		if not path.begins_with(ENEMY_SCENE_FOLDERS[0]):
			continue
		result[path] = ""
		var state := (load(path) as PackedScene).get_state()
		for property in state.get_node_property_count(0):
			if state.get_node_property_name(0, property) == "stats":
				var stats: Resource = state.get_node_property_value(0, property)
				result[path] = stats.resource_path if stats else ""
	return result


func _stats_used_by_enemy_scenes() -> Dictionary:
	var used := {}
	var scene_stats := _enemy_scene_stats()
	for scene: String in scene_stats:
		used[scene_stats[scene]] = scene
	return used


func test_every_enemy_scene_has_stats() -> void:
	var scene_stats := _enemy_scene_stats()
	assert_int(scene_stats.size()).is_greater(0)
	for scene: String in scene_stats:
		assert_str(scene_stats[scene]).override_failure_message(scene + " has no stats").is_not_empty()


func test_every_enemy_stats_resource_is_used(
		do_skip := true,
		skip_reason := "KNOWN BUG: SlayFairy.tres is unused because slay_fairy.tscn uses RageyFairy.tres (probably a copy-paste mistake)") -> void:
	var used := _stats_used_by_enemy_scenes()
	for stats: Resource in _resources_in(ENEMY_FOLDER) + _resources_in(BOSS_FOLDER):
		assert_bool(used.has(stats.resource_path)).override_failure_message(stats.resource_path + " is not used by any enemy scene").is_true()


# --- Weapons, characters, dialogue -------------------------------------------------

func test_weapon_stats_are_playable() -> void:
	for stats: WeaponStats in _resources_in(WEAPON_FOLDER):
		var where := stats.resource_path
		assert_float(stats.damage).override_failure_message(where).is_greater(0.0)
		assert_float(stats.fire_rate).override_failure_message(where).is_greater(0.0)
		assert_float(stats.bullet_speed).override_failure_message(where).is_greater(0.0)
		assert_float(stats.shoot_range).override_failure_message(where).is_greater(0.0)


func test_character_definitions_are_complete() -> void:
	var definitions := _resources_in(CHARACTER_FOLDER).filter(func(r: Resource) -> bool: return r is CharacterDefinition)
	assert_array(definitions).is_not_empty()
	var ids := {}
	for def: CharacterDefinition in definitions:
		var where := def.resource_path
		assert_str(def.id).override_failure_message(where + " has no id").is_not_empty()
		assert_bool(ids.has(def.id)).override_failure_message("duplicate character id " + def.id).is_false()
		ids[def.id] = true
		assert_str(def.display_name).override_failure_message(where).is_not_empty()
		assert_object(def.stats).override_failure_message(where + " has no stats").is_not_null()
		assert_object(def.weapon_stats).override_failure_message(where + " has no weapon stats").is_not_null()
		assert_int(def.unlock_cost).is_greater_equal(0)


func _default_character() -> CharacterDefinition:
	for def in _resources_in(CHARACTER_FOLDER):
		if def is CharacterDefinition and def.id == GameState.DEFAULT_CHARACTER_ID:
			return def
	return null


func test_default_character_exists() -> void:
	assert_object(_default_character()).override_failure_message(
		"no CharacterDefinition with id '%s' in %s" % [GameState.DEFAULT_CHARACTER_ID, CHARACTER_FOLDER]).is_not_null()


func test_default_character_is_unlocked_from_the_start(
		do_skip := true,
		skip_reason := "KNOWN BUG: slinger.tres does not set unlocked_by_default, so a new save owns no character (hidden today because GameState loads no characters at all)") -> void:
	assert_bool(_default_character().unlocked_by_default).is_true()


func test_dialogues_have_an_id_and_lines() -> void:
	for dialogue: DialogueData in _resources_in(DIALOGUE_FOLDER):
		assert_str(dialogue.id).override_failure_message(dialogue.resource_path).is_not_empty()
		assert_array(dialogue.lines).override_failure_message(dialogue.resource_path).is_not_empty()
