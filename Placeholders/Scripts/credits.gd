class_name CreditsScreen
extends Control

signal finished

@export var data: CreditsData
@export var music: AudioStream                # optional, leave empty to keep the current music
@export var scroll_speed: float = 60.0        # pixels per second
@export var fast_multiplier: float = 4.0      # while holding "ui_down"
@export var content_width: float = 800.0
@export var start_delay: float = 0.8
@export var end_delay: float = 1.5
@export var fade_time: float = 0.6

var clip: Control
var content: VBoxContainer
var skip_button: Button
var scrolling := false
var leaving := false
var scroll_y := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0

	_setup_skip_button()

	clip = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(clip, skip_button.get_index())   # the text draws under the skip button

	content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(content)
	_build_content()

	if music:
		Audio.play_music(music)

	# Wait for the layout to measure the content, then park it just below the screen.
	content.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	content.reset_size()
	scroll_y = clip.size.y
	_place_content()
	content.visible = true

	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)
	await get_tree().create_timer(start_delay).timeout
	scrolling = true

func _place_content() -> void:
	content.position = Vector2((clip.size.x - content.size.x) / 2.0, scroll_y)

func _process(delta: float) -> void:
	if not scrolling or leaving:
		return
	var speed := scroll_speed * (fast_multiplier if Input.is_action_pressed("ui_down") else 1.0)
	scroll_y -= speed * delta
	_place_content()
	if scroll_y + content.size.y < 0.0:   # the last line has left the screen
		scrolling = false
		await get_tree().create_timer(end_delay).timeout
		_leave()

func _setup_skip_button() -> void:
	skip_button = find_child("SkipButton", false, false) as Button
	if skip_button == null:   # the scene has no button, so create a default one
		skip_button = Button.new()
		skip_button.name = "SkipButton"
		skip_button.text = "Skip"
		add_child(skip_button)
		skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		skip_button.position -= Vector2(UIStyle.MARGIN, UIStyle.MARGIN) + skip_button.size
	skip_button.pressed.connect(_leave)
	skip_button.grab_focus.call_deferred()   # keyboard and gamepad work right away

func _build_content() -> void:
	if data == null:
		push_warning("CreditsScreen has no Data assigned.")
		return
	content.add_theme_constant_override("separation", UIStyle.SPACING)

	if data.game_logo:
		content.add_child(_make_image(data.game_logo))
	if data.game_title != "":
		content.add_child(_make_label(data.game_title, &"CreditsTitle"))
	content.add_child(_make_spacer(96))

	for section in data.sections:
		if section.heading != "":
			content.add_child(_make_label(section.heading, &"CreditsHeading"))
		if section.image:
			content.add_child(_make_image(section.image))
		for line in section.lines:
			content.add_child(_make_label(line, &"CreditsLine"))
		content.add_child(_make_spacer(section.space_after))

	if data.closing_text != "":
		content.add_child(_make_label(data.closing_text, &"CreditsFooter"))

func _make_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation   # styled by your Theme
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = content_width
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_image(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = Vector2(content_width, texture.get_height())
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()

func _leave() -> void:
	if leaving:
		return
	leaving = true
	scrolling = false
	finished.emit()
	GameState.go_to_menu()
