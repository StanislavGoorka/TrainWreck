## Tests a private instance of audio_manager.gd. The base suite restores the
## AudioServer bus volumes and user://settings.cfg afterwards.
extends "res://tests/helpers/tw_test_suite.gd"

const AudioManager := preload("res://Test/Scripts/Miscellaneous/Audio Related/audio_manager.gd")
const SETTINGS_PATH := "user://settings.cfg"

var audio: Node


func before_test() -> void:
	super.before_test()
	remove_user_file(SETTINGS_PATH)
	audio = auto_free(AudioManager.new())
	add_child(audio)


func _stream() -> AudioStream:
	return AudioStreamGenerator.new()   # plays until stopped, no asset file needed


func _bus(bus_name: StringName) -> int:
	return AudioServer.get_bus_index(bus_name)


# --- Setup -------------------------------------------------------------------------

func test_ready_keeps_running_while_the_game_is_paused() -> void:
	assert_int(audio.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_ready_creates_two_silent_music_players_for_crossfades() -> void:
	assert_array(audio._players).has_size(2)
	for player: AudioStreamPlayer in audio._players:
		assert_str(String(player.bus)).is_equal(String(AudioManager.BUS_MUSIC))
		assert_float(player.volume_db).is_equal(AudioManager.SILENT_DB)
		assert_bool(player.playing).is_false()


func test_buses_used_by_the_game_exist() -> void:
	for bus_name in AudioManager.BUSES:
		assert_int(_bus(bus_name)).override_failure_message("missing audio bus " + bus_name).is_greater_equal(0)


func test_without_settings_every_bus_is_at_full_volume() -> void:
	for bus_name in AudioManager.BUSES:
		assert_float(audio.get_volume(bus_name)).is_equal(1.0)
		assert_float(AudioServer.get_bus_volume_db(_bus(bus_name))).is_equal_approx(0.0, 0.001)
		assert_bool(AudioServer.is_bus_mute(_bus(bus_name))).is_false()


func test_saved_volumes_are_applied_on_startup() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "Music", 0.5)
	cfg.set_value("audio", "SFX", 0.0)
	cfg.save(SETTINGS_PATH)
	var fresh: Node = auto_free(AudioManager.new())
	add_child(fresh)
	assert_float(fresh.get_volume(&"Music")).is_equal(0.5)
	assert_float(fresh.get_volume(&"Master")).is_equal(1.0)
	assert_float(AudioServer.get_bus_volume_db(_bus(&"Music"))).is_equal_approx(linear_to_db(0.5), 0.001)
	assert_bool(AudioServer.is_bus_mute(_bus(&"SFX"))).is_true()


# --- Volumes -----------------------------------------------------------------------

func test_set_volume_converts_to_decibels() -> void:
	audio.set_volume(&"Music", 0.25)
	assert_float(audio.get_volume(&"Music")).is_equal(0.25)
	assert_float(AudioServer.get_bus_volume_db(_bus(&"Music"))).is_equal_approx(linear_to_db(0.25), 0.001)
	assert_bool(AudioServer.is_bus_mute(_bus(&"Music"))).is_false()


func test_zero_volume_mutes_the_bus() -> void:
	audio.set_volume(&"SFX", 0.0)
	assert_bool(AudioServer.is_bus_mute(_bus(&"SFX"))).is_true()
	audio.set_volume(&"SFX", 0.3)
	assert_bool(AudioServer.is_bus_mute(_bus(&"SFX"))).is_false()


func test_set_volume_is_clamped(value: float, expected: float, test_parameters := [
	[-1.0, 0.0], [2.5, 1.0], [0.4, 0.4],
]) -> void:
	audio.set_volume(&"Master", value)
	assert_float(audio.get_volume(&"Master")).is_equal(expected)


func test_unknown_bus_is_ignored() -> void:
	audio.set_volume(&"NoSuchBus", 0.3)
	assert_bool(audio.volumes.has(&"NoSuchBus")).is_false()
	assert_float(audio.get_volume(&"NoSuchBus")).is_equal(1.0)


func test_volume_changes_are_saved_after_a_short_delay() -> void:
	audio.set_volume(&"Music", 0.6)
	assert_bool(audio._save_timer.is_stopped()).is_false()
	audio._save_timer.timeout.emit()   # skip the wait
	var cfg := ConfigFile.new()
	assert_int(cfg.load(SETTINGS_PATH)).is_equal(OK)
	assert_float(cfg.get_value("audio", "Music")).is_equal(0.6)


func test_saving_keeps_other_settings_in_the_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "fullscreen", true)
	cfg.save(SETTINGS_PATH)
	audio.set_volume(&"SFX", 0.2)
	audio.save_settings()
	cfg = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	assert_bool(cfg.get_value("graphics", "fullscreen")).is_true()
	for bus_name in AudioManager.BUSES:
		assert_bool(cfg.has_section_key("audio", String(bus_name))).is_true()
	assert_float(cfg.get_value("audio", "SFX")).is_equal(0.2)


# --- Music -------------------------------------------------------------------------

func test_play_music_fades_in_the_new_track() -> void:
	var track := _stream()
	audio.play_music(track, 0.5)
	var incoming: AudioStreamPlayer = audio._players[audio._active]
	assert_object(incoming.stream).is_same(track)
	assert_bool(incoming.playing).is_true()
	assert_float(incoming.volume_db).is_equal(AudioManager.SILENT_DB)
	audio._fade_tween.custom_step(0.5)
	assert_float(incoming.volume_db).is_equal_approx(0.0, 0.01)


func test_requesting_the_playing_track_again_does_not_restart_it() -> void:
	var track := _stream()
	audio.play_music(track, 0.1)
	var active: int = audio._active
	audio.play_music(track, 0.1)
	assert_int(audio._active).is_equal(active)


func test_switching_tracks_crossfades_and_stops_the_old_one() -> void:
	var first := _stream()
	var second := _stream()
	audio.play_music(first, 0.2)
	audio._fade_tween.custom_step(0.2)
	var old_player: AudioStreamPlayer = audio._players[audio._active]
	audio.play_music(second, 0.2)
	var new_player: AudioStreamPlayer = audio._players[audio._active]
	assert_object(new_player).is_not_same(old_player)
	assert_object(new_player.stream).is_same(second)
	audio._fade_tween.custom_step(0.25)
	assert_float(new_player.volume_db).is_equal_approx(0.0, 0.01)
	assert_bool(old_player.playing).is_false()


func test_stop_music_fades_out() -> void:
	audio.play_music(_stream(), 0.1)
	audio._fade_tween.custom_step(0.1)
	var player: AudioStreamPlayer = audio._players[audio._active]
	audio.stop_music(0.2)
	assert_object(audio._current_stream).is_null()
	audio._fade_tween.custom_step(0.25)
	assert_bool(player.playing).is_false()


func test_stopping_when_nothing_plays_does_nothing() -> void:
	audio.stop_music(0.2)
	for player: AudioStreamPlayer in audio._players:
		assert_bool(player.playing).is_false()


# --- SFX ---------------------------------------------------------------------------

func _sfx_players() -> Array:
	return audio.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer and not audio._players.has(n))


func test_play_sfx_without_a_stream_does_nothing() -> void:
	audio.play_sfx(null)
	assert_array(_sfx_players()).is_empty()


func test_play_sfx_uses_a_one_shot_player_on_the_sfx_bus() -> void:
	audio.play_sfx(_stream(), -6.0)
	var players := _sfx_players()
	assert_array(players).has_size(1)
	var player: AudioStreamPlayer = players[0]
	assert_str(String(player.bus)).is_equal("SFX")
	assert_float(player.volume_db).is_equal(-6.0)
	assert_float(player.pitch_scale).is_equal(1.0)
	assert_bool(player.playing).is_true()
	assert_bool(player.finished.is_connected(player.queue_free)).is_true()


func test_play_sfx_pitch_variation_stays_in_range() -> void:
	for i in 20:
		audio.play_sfx(_stream(), 0.0, 0.1)
	for player: AudioStreamPlayer in _sfx_players():
		assert_float(player.pitch_scale).is_between(0.9, 1.1)


# --- MusicTrigger ------------------------------------------------------------------

func test_music_trigger_asks_the_audio_autoload_for_its_track() -> void:
	var trigger: MusicTrigger = auto_free(MusicTrigger.new())
	trigger.track = _stream()
	trigger.fade_time = 0.1
	add_child(trigger)
	assert_object(Audio._current_stream).is_same(trigger.track)
