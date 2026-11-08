## GameSettings (graphics settings) and the settings UI (VolumeSlider, SettingsPanel,
## SettingsOverlay). Window mode changes are avoided: the tests only toggle values that
## leave the window windowed, and the base suite restores user://settings.cfg.
extends "res://tests/helpers/tw_test_suite.gd"

const GameSettingsScript := preload("res://Test/Scripts/Settings/game_settings.gd")
const SETTINGS_PATH := "user://settings.cfg"


func before_test() -> void:
	super.before_test()
	remove_user_file(SETTINGS_PATH)


func _load_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	return cfg


# --- GameSettings ------------------------------------------------------------------

func test_game_settings_keeps_running_while_paused() -> void:
	assert_int(GameSettings.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_game_settings_reads_windowed_mode_from_the_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "fullscreen", false)
	cfg.save(SETTINGS_PATH)
	var settings: Node = auto_free(GameSettingsScript.new())
	add_child(settings)
	assert_bool(settings.fullscreen).is_false()


func test_game_settings_defaults_to_windowed_without_a_file() -> void:
	var settings: Node = auto_free(GameSettingsScript.new())
	add_child(settings)
	assert_bool(settings.fullscreen).is_false()
	# The project window is borderless and 1920x1080. On a 1920x1080 screen the OS reports
	# such a window as fullscreen even in windowed mode, so the real window state can only
	# be checked when the window is smaller than the screen.
	var window_size := DisplayServer.window_get_size()
	var screen_size := DisplayServer.screen_get_size()
	var borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	if not (borderless and window_size.x >= screen_size.x and window_size.y >= screen_size.y):
		assert_bool(settings.is_fullscreen()).is_false()


func test_set_fullscreen_saves_the_choice() -> void:
	var settings: Node = auto_free(GameSettingsScript.new())
	add_child(settings)
	settings.set_fullscreen(false)
	assert_bool(_load_cfg().get_value("graphics", "fullscreen", true)).is_false()


func test_saving_graphics_keeps_the_audio_section() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "Music", 0.3)
	cfg.save(SETTINGS_PATH)
	var settings: Node = auto_free(GameSettingsScript.new())
	add_child(settings)
	settings.fullscreen = true   # value only, the window is not touched
	settings.save_settings()
	cfg = _load_cfg()
	assert_float(cfg.get_value("audio", "Music")).is_equal(0.3)
	assert_bool(cfg.get_value("graphics", "fullscreen")).is_true()


func test_cursor_image_is_only_built_once_set_up() -> void:
	var settings: Node = auto_free(GameSettingsScript.new())
	add_child(settings)
	assert_object(settings.cursor_image).is_null()
	settings._update_cursor()   # safe without an image
	assert_bool(ResourceLoader.exists(GameSettingsScript.CURSOR_PATH)) \
		.override_failure_message("cursor sprite missing: " + GameSettingsScript.CURSOR_PATH).is_true()


# --- VolumeSlider ------------------------------------------------------------------

func test_volume_slider_shows_the_bus_volume() -> void:
	Audio.set_volume(&"Music", 0.35)
	var slider: VolumeSlider = auto_free(VolumeSlider.new())
	slider.bus = &"Music"
	add_child(slider)
	assert_float(slider.min_value).is_equal(0.0)
	assert_float(slider.max_value).is_equal(1.0)
	assert_float(slider.step).is_equal(0.05)
	assert_float(slider.value).is_equal_approx(0.35, 0.026)


func test_moving_the_slider_changes_the_bus_volume() -> void:
	var slider: VolumeSlider = auto_free(VolumeSlider.new())
	slider.bus = &"SFX"
	add_child(slider)
	slider.value = 0.5
	assert_float(Audio.get_volume(&"SFX")).is_equal(0.5)


# --- SettingsPanel -----------------------------------------------------------------

func _panel(graphics := true, audio := true) -> SettingsPanel:
	var panel: SettingsPanel = auto_free(SettingsPanel.new())
	panel.show_graphics = graphics
	panel.show_audio = audio
	add_child(panel)
	return panel


func test_panel_builds_a_row_per_audio_bus() -> void:
	var panel := _panel()
	assert_object(panel.fullscreen_check).is_not_null()
	var buses := panel.volume_rows.map(func(row: Dictionary) -> StringName: return row["bus"])
	assert_array(buses).contains_exactly(Audio.BUS_MASTER, Audio.BUS_MUSIC, Audio.BUS_SFX)


func test_panel_sections_can_be_hidden() -> void:
	var audio_only := _panel(false, true)
	assert_object(audio_only.fullscreen_check).is_null()
	assert_array(audio_only.volume_rows).has_size(3)
	var graphics_only := _panel(true, false)
	assert_object(graphics_only.fullscreen_check).is_not_null()
	assert_array(graphics_only.volume_rows).is_empty()


func test_panel_shows_current_volumes_as_percent() -> void:
	Audio.set_volume(&"Master", 0.5)
	var panel := _panel()
	var master: Dictionary = panel.volume_rows[0]
	assert_float(master["slider"].value).is_equal_approx(0.5, 0.001)
	assert_str(master["percent"].text).is_equal("50%")


func test_panel_percent_follows_the_slider() -> void:
	var panel := _panel()
	var music: Dictionary = panel.volume_rows[1]
	music["slider"].value = 0.25
	assert_str(music["percent"].text).is_equal("25%")
	assert_float(Audio.get_volume(&"Music")).is_equal(0.25)


func test_panel_resyncs_when_shown_again() -> void:
	var panel := _panel()
	panel.hide()
	Audio.set_volume(&"SFX", 0.75)
	panel.show()
	var sfx: Dictionary = panel.volume_rows[2]
	assert_str(sfx["percent"].text).is_equal("75%")


func test_panel_fullscreen_toggle_reflects_the_window() -> void:
	var panel := _panel()
	assert_bool(panel.fullscreen_check.button_pressed).is_equal(GameSettings.is_fullscreen())
	assert_bool(panel.fullscreen_check.toggled.is_connected(GameSettings.set_fullscreen)).is_true()


func test_panel_margin_is_applied_on_every_side() -> void:
	var panel: SettingsPanel = auto_free(SettingsPanel.new())
	panel.margin = 7
	add_child(panel)
	for side in ["left", "top", "right", "bottom"]:
		assert_int(panel.get_theme_constant("margin_" + side)).is_equal(7)


# --- SettingsOverlay ---------------------------------------------------------------

func test_overlay_sits_above_the_menu_and_works_while_paused() -> void:
	var overlay: SettingsOverlay = auto_free(SettingsOverlay.new())
	add_child(overlay)
	assert_int(overlay.layer).is_equal(50)
	assert_int(overlay.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	var panels := overlay.find_children("*", "SettingsPanel", true, false)
	assert_array(panels).has_size(1)
	assert_int(panels[0].margin).is_zero()


func test_overlay_back_button_closes_it() -> void:
	var overlay: SettingsOverlay = auto_free(SettingsOverlay.new())
	add_child(overlay)
	var closed := []
	overlay.closed.connect(func() -> void: closed.append(true))
	var back: Button = overlay.find_children("*", "Button", true, false) \
		.filter(func(b: Button) -> bool: return b.text == "Back")[0]
	back.pressed.emit()
	assert_array(closed).has_size(1)
	assert_bool(overlay.is_queued_for_deletion()).is_true()


func test_overlay_closes_on_cancel() -> void:
	var overlay: SettingsOverlay = auto_free(SettingsOverlay.new())
	add_child(overlay)
	var closed := []
	overlay.closed.connect(func() -> void: closed.append(true))
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	overlay._unhandled_input(event)
	assert_array(closed).has_size(1)
