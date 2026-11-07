extends Node


const CURSOR_PATH := "res://Test/Assets/UI Elements/CharacterRelated/SPRITE-UI-CROSSHAIR2.png"   # adjust to your cursor sprite
const CURSOR_BASE_SCALE := 1    # extra whole-number scale on top of the automatic one

var cursor_image: Image

const SETTINGS_PATH := "user://settings.cfg"

var fullscreen: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # a missing file just leaves the defaults
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", false))
	_apply_fullscreen()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	save_settings()

# Reads the real window state, so toggling it outside the game (Alt+Enter) stays in sync.
func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep the audio section written by Audio
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()
		
func _setup_cursor() -> void:
	if not ResourceLoader.exists(CURSOR_PATH):
		push_warning("Cursor sprite not found at " + CURSOR_PATH)
		return
	var texture := load(CURSOR_PATH) as Texture2D
	cursor_image = texture.get_image()
	_update_cursor()
	# The OS cursor ignores the game's stretch scaling, so redo it when the window changes.
	get_window().size_changed.connect(_update_cursor)

func _update_cursor() -> void:
	if cursor_image == null:
		return
	# 1x at 1080p, 2x at 4K. Whole numbers keep the pixels sharp.
	var window_scale: int = maxi(roundi(float(DisplayServer.window_get_size().y) / 1080.0), 1)
	var factor: int = window_scale * CURSOR_BASE_SCALE

	var image: Image = cursor_image.duplicate()
	if factor > 1:
		image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)

	var cursor := ImageTexture.create_from_image(image)
	var hotspot := Vector2(cursor.get_width(), cursor.get_height()) / 2.0
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, hotspot)
