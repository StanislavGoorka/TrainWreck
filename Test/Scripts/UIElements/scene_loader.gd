extends CanvasLayer

const BACKGROUND_PATH := "res://Placeholders/Assets/Backgrounds/Steampunk/1.png"   # optional, skipped if missing
const TIPS: Array[String] = []   # optional hints, one random one is shown per load
const MIN_TIME := 0.5            # shortest time the screen stays up, so it never flashes
const FADE_TIME := 0.3

var busy := false

var root: Control
var bar: ProgressBar
var title_label: Label
var tip_label: Label

func _ready() -> void:
	layer = 200   # above the HUD, the fade and the game over screens
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	root.visible = false

func _build_ui() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # blocks clicks while loading
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var back := ColorRect.new()
	back.color = Color.BLACK
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if ResourceLoader.exists(BACKGROUND_PATH):
		var picture := TextureRect.new()
		picture.texture = load(BACKGROUND_PATH)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UIStyle.MARGIN * 2)
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN   # grows upward, not off-screen

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", UIStyle.SPACING)
	margin.add_child(box)

	tip_label = Label.new()
	tip_label.theme_type_variation = &"LoadingTip"
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tip_label)

	title_label = Label.new()
	title_label.theme_type_variation = &"LoadingLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_label)

	bar = ProgressBar.new()
	bar.theme_type_variation = &"LoadingBar"
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(600, 20)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)

func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	get_tree().paused = true   # freezes the old scene while it fades out (this node keeps running)

	bar.value = 0.0
	title_label.text = "Loading"
	tip_label.text = TIPS.pick_random() if not TIPS.is_empty() else ""
	tip_label.visible = not TIPS.is_empty()
	root.modulate.a = 0.0
	root.visible = true
	await _fade(1.0)

	if ResourceLoader.load_threaded_request(path) != OK:
		push_error("Could not start loading " + path)
		await _abort()
		return

	var start := Time.get_ticks_msec()
	while true:
		var info: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, info)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to load scene: " + path)
			await _abort()
			return

		var elapsed: float = (Time.get_ticks_msec() - start) / 1000.0
		var real: float = info[0] if not info.is_empty() else 0.0
		bar.value = minf(real, elapsed / MIN_TIME)
		title_label.text = "Loading" + ".".repeat(int(elapsed * 3.0) % 4)

		if status == ResourceLoader.THREAD_LOAD_LOADED and elapsed >= MIN_TIME:
			break
		await get_tree().process_frame

	bar.value = 1.0
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	get_tree().change_scene_to_packed(packed)
	# The new scene's _ready() runs inside this swap, so any generation hitch stays behind the screen.
	await get_tree().process_frame
	await get_tree().process_frame

	get_tree().paused = false
	await _fade(0.0)
	root.visible = false
	busy = false

func _abort() -> void:
	await _fade(0.0)
	root.visible = false
	get_tree().paused = false
	busy = false

func _fade(to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", to_alpha, FADE_TIME)
	await tween.finished
