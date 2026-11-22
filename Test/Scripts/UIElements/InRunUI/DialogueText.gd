class_name DialogueText
extends Label

signal line_finished   # typing is done
signal closed          # fully faded out

@export var chars_per_second: float = 30.0
@export var hold_time: float = 2.0          # seconds the line stays after it finishes typing
@export var fade_time: float = 0.25
@export var max_width: float = 360.0
@export var sound: AudioStream
@export var sound_volume_db: float = 0.0
@export var sound_pitch_variation: float = 0.06

const MAX_SOUNDS_PER_FRAME := 2   # protects against stacked sounds at very high speeds

var anchor := Vector2(0, -80)   # bottom-center of the text, relative to the owner
var text_size := Vector2.ZERO   # the measured size of the current line, used for positioning
var typing := false
var shown_f := 0.0
var last_count := 0
var serial := 0                 # identifies the current line, so a late correction can't hit a newer one
var hold_tween: Tween
var fade_tween: Tween

func _init() -> void:
	# Style it in your Theme with a "DialogueLabel" type (base type Label).
	theme_type_variation = &"DialogueLabel"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 101
	visible = false
	set_process(false)

func show_line(line: String) -> void:
	_kill_tweens()
	serial += 1
	text = line
	_fit_size()
	visible_characters = 0
	modulate.a = 1.0
	visible = true
	shown_f = 0.0
	last_count = 0
	typing = true
	set_process(true)
	_reposition()
	_refine_size(serial)   # corrects the height once the label has laid itself out

func is_typing() -> bool:
	return typing

# Finishes the current line instantly.
func skip() -> void:
	if typing:
		_finish_typing()

func close() -> void:
	_kill_tweens()
	typing = false
	set_process(false)
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	fade_tween.tween_callback(_on_faded)

func _process(delta: float) -> void:
	if not typing:
		return
	shown_f += chars_per_second * delta
	var total := get_total_character_count()
	var count := mini(int(shown_f), total)

	# One sound per character that appeared this frame.
	if count > last_count:
		var played := 0
		for i in range(last_count, count):
			if text[i] != " " and played < MAX_SOUNDS_PER_FRAME:
				Audio.play_sfx(sound, sound_volume_db, sound_pitch_variation)
				played += 1
		last_count = count

	visible_characters = count
	if count >= total:
		_finish_typing()

func _finish_typing() -> void:
	typing = false
	set_process(false)
	visible_characters = -1   # show everything
	line_finished.emit()
	hold_tween = create_tween()
	hold_tween.tween_interval(hold_time)
	hold_tween.tween_callback(close)

func _on_faded() -> void:
	visible = false
	closed.emit()

func _kill_tweens() -> void:
	for t in [hold_tween, fade_tween]:
		if t:
			t.kill()

# Estimates the wrapped size with the real font, so the first frame is already close.
func _fit_size() -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var single_line := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var width := minf(single_line.x + 16.0, max_width)
	var wrapped := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size)
	text_size = Vector2(width, wrapped.y + font_size * 0.5)
	custom_minimum_size = Vector2(width, 0.0)   # no stale height left over from an earlier line
	size = Vector2(width, text_size.y)          # the width is what the wrapping uses

# One frame later the label has wrapped at the right width, so its own minimum height is exact.
func _refine_size(id: int) -> void:
	await get_tree().process_frame
	if id != serial or not visible:
		return
	var natural := get_minimum_size().y
	if natural > 0.0:
		text_size.y = natural
		_reposition()

# The bottom of the text sits at the anchor. This uses the measured height, never the
# label's own size, which can stay stale from a previous line.
func _reposition() -> void:
	position = anchor - Vector2(text_size.x / 2.0, text_size.y)
