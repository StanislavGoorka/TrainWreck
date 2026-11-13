## Exercise real asynchronous loading against a disposable current scene.
extends "res://tests/helpers/tw_test_suite.gd"

const LoaderScript := preload("res://Test/Scripts/UIElements/scene_loader.gd")
const ErrorCapture := preload("res://tests/helpers/error_capture.gd")
const TARGET := "res://tests/fixtures/loader_target.tscn"
const MISSING := "res://tests/fixtures/missing_scene.tscn"

var loader: CanvasLayer
var previous_scene: Node
var capture: Logger


func before_test() -> void:
	super.before_test()
	previous_scene = get_tree().current_scene
	var old_scene: Node = auto_free(Node.new())
	use_as_current_scene(old_scene)
	loader = auto_free(LoaderScript.new())
	add_child(loader)
	capture = ErrorCapture.new()


func after_test() -> void:
	if is_instance_valid(loader) and loader.busy:
		await wait_until(func() -> bool: return not loader.busy, 5000)
	# Failed loads also leave a task in ResourceLoader's global cache until consumed.
	if ResourceLoader.load_threaded_get_status(MISSING) == ResourceLoader.THREAD_LOAD_FAILED:
		ResourceLoader.load_threaded_get(MISSING)
	capture.stop()
	var scene := get_tree().current_scene
	get_tree().current_scene = previous_scene if is_instance_valid(previous_scene) else null
	if is_instance_valid(scene) and scene != previous_scene:
		scene.free()
	await super.after_test()


func test_loader_starts_idle_and_hidden() -> void:
	assert_bool(loader.busy).is_false()
	assert_bool(loader.root.visible).is_false()
	assert_int(loader.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_loading_pauses_the_old_scene_and_blocks_repeat_requests() -> void:
	var old_scene := get_tree().current_scene
	loader.change_scene(TARGET)
	assert_bool(loader.busy).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(loader.root.visible).is_true()
	loader.change_scene(MISSING)
	assert_bool(await wait_until(func() -> bool: return not loader.busy, 5000)).is_true()
	assert_bool(is_instance_valid(old_scene)).is_false()
	assert_str(get_tree().current_scene.scene_file_path).is_equal(TARGET)
	assert_bool(get_tree().paused).is_false()
	assert_bool(loader.root.visible).is_false()
	assert_float(loader.bar.value).is_equal(1.0)


func test_loading_failure_restores_the_old_scene_and_unpauses() -> void:
	var old_scene := get_tree().current_scene
	capture.start()
	loader.change_scene(MISSING)
	assert_bool(await wait_until(func() -> bool: return not loader.busy, 5000)).is_true()
	var errors: PackedStringArray = capture.stop()
	assert_str("\n".join(errors)).contains(MISSING)
	assert_object(get_tree().current_scene).is_same(old_scene)
	assert_bool(get_tree().paused).is_false()
	assert_bool(loader.root.visible).is_false()


func test_loader_can_be_used_again_after_a_failed_request() -> void:
	capture.start()
	loader.change_scene(MISSING)
	assert_bool(await wait_until(func() -> bool: return not loader.busy, 5000)).is_true()
	capture.stop()
	loader.change_scene(TARGET)
	assert_bool(await wait_until(func() -> bool: return not loader.busy, 5000)).is_true()
	assert_str(get_tree().current_scene.scene_file_path).is_equal(TARGET)
	assert_bool(get_tree().paused).is_false()
