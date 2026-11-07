extends Node

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUSES: Array[StringName] = [BUS_MASTER, BUS_MUSIC, BUS_SFX]
const SETTINGS_PATH := "user://settings.cfg"
const SILENT_DB := -80.0

var volumes: Dictionary = {}          # bus name -> linear volume 0.0 to 1.0
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current_stream: AudioStream
var _fade_tween: Tween
var _save_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # music keeps playing while paused

	for i in 2:   # two players, so tracks can crossfade
		var player := AudioStreamPlayer.new()
		player.bus = BUS_MUSIC
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)

	_load_settings()

# --- Music ---------------------------------------------------------------

func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
	# Asking for the track that is already playing does nothing,
	# so reloading a scene doesn't restart the song.
	if stream == _current_stream and (stream == null or _players[_active].playing):
		return
	_current_stream = stream

	var old := _players[_active]
	_active = 1 - _active
	var incoming := _players[_active]

	if _fade_tween:
		_fade_tween.kill()
	if stream == null and not old.playing:
		return

	_fade_tween = create_tween().set_parallel(true)
	if stream:
		incoming.stream = stream
		incoming.volume_db = SILENT_DB
		incoming.play()
		_fade_tween.tween_property(incoming, "volume_db", 0.0, fade_time)
	if old.playing:
		_fade_tween.tween_property(old, "volume_db", SILENT_DB, fade_time)
		_fade_tween.chain().tween_callback(old.stop)

func stop_music(fade_time: float = 1.0) -> void:
	play_music(null, fade_time)

# --- SFX -----------------------------------------------------------------

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_variation: float = 0.0) -> void:
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.volume_db = volume_db
	if pitch_variation > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

# --- Volumes -------------------------------------------------------------

func set_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		push_warning("Audio bus '%s' does not exist." % bus)
		return
	linear = clampf(linear, 0.0, 1.0)
	volumes[bus] = linear
	AudioServer.set_bus_mute(idx, linear <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	_save_timer.start()   # saves shortly after the last change, not on every slider tick

func get_volume(bus: StringName) -> float:
	return volumes.get(bus, 1.0)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep any other settings stored in the same file
	for bus in BUSES:
		cfg.set_value("audio", String(bus), get_volume(bus))
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # a missing file just leaves the defaults
	for bus in BUSES:
		set_volume(bus, float(cfg.get_value("audio", String(bus), 1.0)))
		
		
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()
