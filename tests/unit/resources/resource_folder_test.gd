## ResourceFolder.list(): lists resource files of one type in a folder, also in exported
## builds where Godot renames them to "name.ext.remap". GameState (characters), the room
## generator (room scenes) and pedestals (items) load their content through it.
extends "res://tests/helpers/tw_test_suite.gd"

const ErrorCapture := preload("res://tests/helpers/error_capture.gd")
const FOLDER := "user://tw_resource_folder_test"


func before_test() -> void:
	super.before_test()
	_clear_folder()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))


func after_test() -> void:
	_clear_folder()
	await super.after_test()


func _clear_folder() -> void:
	if not DirAccess.dir_exists_absolute(FOLDER):
		return
	for file_name in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER.path_join(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER))


func _touch(file_name: String) -> void:
	write_user_file(FOLDER.path_join(file_name), "")


func test_lists_only_files_with_the_requested_extension() -> void:
	for file_name in ["a.tres", "b.tres", "c.tscn", "notes.txt", "d.tres.import"]:
		_touch(file_name)
	var listed := ResourceFolder.list(FOLDER, "tres")
	assert_array(listed).contains_exactly_in_any_order([FOLDER.path_join("a.tres"), FOLDER.path_join("b.tres")])


func test_exported_remap_files_are_listed_under_their_original_name() -> void:
	_touch("room_01.tscn.remap")
	_touch("room_02.tscn.remap")
	var listed := ResourceFolder.list(FOLDER, "tscn")
	assert_array(listed).contains_exactly_in_any_order([FOLDER.path_join("room_01.tscn"), FOLDER.path_join("room_02.tscn")])


func test_a_file_and_its_remap_are_listed_once() -> void:
	_touch("item.tres")
	_touch("item.tres.remap")
	assert_array(ResourceFolder.list(FOLDER, "tres")).contains_exactly([FOLDER.path_join("item.tres")])


func test_a_missing_folder_gives_an_empty_list_and_reports_an_error() -> void:
	var capture := ErrorCapture.new()
	capture.start()
	var listed := ResourceFolder.list(FOLDER.path_join("does_not_exist"), "tres")
	var errors := capture.stop()
	assert_array(listed).is_empty()
	assert_array(Array(errors).filter(func(e: String) -> bool: return e.contains("Failed to open folder"))).has_size(1)


func test_the_game_folders_list_their_resources() -> void:
	assert_array(ResourceFolder.list("res://Test/Scenes/Rooms/IntermediateRooms/", "tscn")).is_not_empty()
	assert_array(ResourceFolder.list("res://Test/Scripts/Resource/ItemResource/", "tres")).is_not_empty()
