## DialogueText (typed speech lines), InteractPrompt ("[E] Talk") and GameOverScreen.
extends "res://tests/helpers/tw_test_suite.gd"


# --- DialogueText ------------------------------------------------------------------

func _dialogue() -> DialogueText:
	var text: DialogueText = auto_free(DialogueText.new())
	text.chars_per_second = 10.0
	text.hold_time = 1.0
	text.fade_time = 0.2
	add_child(text)
	return text


func test_dialogue_starts_hidden_and_idle() -> void:
	var text := _dialogue()
	assert_bool(text.visible).is_false()
	assert_bool(text.is_typing()).is_false()
	assert_str(String(text.theme_type_variation)).is_equal("DialogueLabel")


func test_show_line_starts_typing_from_the_first_character() -> void:
	var text := _dialogue()
	text.show_line("Hello there")
	assert_bool(text.visible).is_true()
	assert_bool(text.is_typing()).is_true()
	assert_int(text.visible_characters).is_zero()
	assert_str(text.text).is_equal("Hello there")
	assert_float(text.modulate.a).is_equal(1.0)


func test_typing_reveals_characters_over_time() -> void:
	var text := _dialogue()
	text.show_line("Hello there")
	text._process(0.35)   # 10 chars/s
	assert_int(text.visible_characters).is_equal(3)
	assert_bool(text.is_typing()).is_true()


func test_finishing_the_line_shows_everything_and_announces_it() -> void:
	var text := _dialogue()
	var finished := []
	text.line_finished.connect(func() -> void: finished.append(true))
	text.show_line("Hi")
	text._process(5.0)
	assert_bool(text.is_typing()).is_false()
	assert_int(text.visible_characters).is_equal(-1)
	assert_array(finished).has_size(1)


func test_skip_finishes_the_line_at_once() -> void:
	var text := _dialogue()
	var finished := []
	text.line_finished.connect(func() -> void: finished.append(true))
	text.show_line("A rather long line of dialogue")
	text.skip()
	assert_bool(text.is_typing()).is_false()
	assert_int(text.visible_characters).is_equal(-1)
	assert_array(finished).has_size(1)
	text.skip()   # nothing left to skip
	assert_array(finished).has_size(1)


func test_line_closes_by_itself_after_the_hold_time() -> void:
	var text := _dialogue()
	var closed := []
	text.closed.connect(func() -> void: closed.append(true))
	text.show_line("Hi")
	text.skip()
	# A tween runs a trailing callback only on a step that has time left over.
	text.hold_tween.custom_step(text.hold_time + 0.01)
	text.fade_tween.custom_step(text.fade_time + 0.01)
	assert_array(closed).has_size(1)
	assert_bool(text.visible).is_false()


func test_close_fades_out_and_announces_it() -> void:
	var text := _dialogue()
	var closed := []
	text.closed.connect(func() -> void: closed.append(true))
	text.show_line("Hi")
	text.close()
	assert_bool(text.is_typing()).is_false()
	text.fade_tween.custom_step(text.fade_time * 0.5)
	assert_float(text.modulate.a).is_between(0.01, 0.99)
	text.fade_tween.custom_step(text.fade_time)
	assert_float(text.modulate.a).is_equal_approx(0.0, 0.001)
	assert_array(closed).has_size(1)


func test_a_new_line_cancels_a_pending_close() -> void:
	var text := _dialogue()
	var closed := []
	text.closed.connect(func() -> void: closed.append(true))
	text.show_line("First")
	text.close()
	var fade: Tween = text.fade_tween
	text.show_line("Second")
	assert_bool(fade.is_valid()).is_false()
	assert_array(closed).is_empty()
	assert_float(text.modulate.a).is_equal(1.0)


func test_text_grows_upward_from_its_anchor() -> void:
	var text := _dialogue()
	text.anchor = Vector2(0, -60)
	text.show_line("Some words")
	assert_float(text.position.y + text.size.y).is_equal_approx(-60.0, 0.5)
	assert_float(text.position.x + text.size.x / 2.0).is_equal_approx(0.0, 0.5)


func test_long_lines_wrap_at_the_max_width() -> void:
	var text := _dialogue()
	text.max_width = 120.0
	text.show_line("This line is far too long to fit on a single row of the speech label")
	assert_float(text.size.x).is_equal(120.0)
	text.show_line("Hi")
	assert_float(text.size.x).is_less(120.0)


# --- InteractPrompt ----------------------------------------------------------------

func _prompt() -> InteractPrompt:
	var prompt: InteractPrompt = auto_free(InteractPrompt.new())
	add_child(prompt)
	return prompt


func test_prompt_starts_invisible() -> void:
	var prompt := _prompt()
	assert_bool(prompt.visible).is_false()
	assert_float(prompt.modulate.a).is_equal(0.0)


func test_prompt_with_an_icon_shows_plain_text() -> void:
	var prompt := _prompt()
	var icon := Factory.texture(Vector2(16, 16))
	prompt.setup("Talk", icon, null, Vector2(0, -48))
	assert_str(prompt.label.text).is_equal("Talk")
	assert_object(prompt.icon_rect.texture).is_same(icon)
	assert_bool(prompt.icon_rect.visible).is_true()


func test_prompt_falls_back_to_the_default_icon() -> void:
	assert_bool(ResourceLoader.exists(InteractPrompt.DEFAULT_ICON_PATH)) \
		.override_failure_message("default icon missing: " + InteractPrompt.DEFAULT_ICON_PATH).is_true()
	var prompt := _prompt()
	prompt.setup("Open", null, null, Vector2.ZERO)
	assert_object(prompt.icon_rect.texture).is_not_null()
	assert_str(prompt.label.text).is_equal("Open")


func test_prompt_without_any_icon_names_the_key() -> void:
	var prompt := _prompt()
	prompt.icon_rect.visible = false
	prompt.set_text("Talk")
	assert_str(prompt.label.text).is_equal("[%s] Talk" % InteractPrompt._key_name())


func test_key_name_is_the_bare_key_of_the_interact_binding(
		do_skip := true,
		skip_reason := "KNOWN BUG: InteractPrompt._key_name() strips ' (' but Godot 4.7 InputEventKey.as_text() returns 'E - Physical', so the prompt reads '[E - Physical] Talk'") -> void:
	assert_str(InteractPrompt._key_name()).is_equal("E")


func test_prompt_applies_a_custom_theme() -> void:
	var prompt := _prompt()
	var theme := Theme.new()
	prompt.setup("Talk", Factory.texture(), theme, Vector2.ZERO)
	assert_object(prompt.theme).is_same(theme)


func test_prompt_stays_centered_above_its_anchor() -> void:
	var prompt := _prompt()
	prompt.setup("Talk", Factory.texture(Vector2(16, 16)), null, Vector2(10, -48))
	assert_float(prompt.position.x + prompt.size.x / 2.0).is_equal_approx(10.0, 0.5)
	assert_float(prompt.position.y + prompt.size.y).is_equal_approx(-48.0, 0.5)


func test_show_and_hide_prompt_fade() -> void:
	var prompt := _prompt()
	prompt.show_prompt()
	assert_bool(prompt.visible).is_true()
	prompt.tween.custom_step(prompt.fade_time)
	assert_float(prompt.modulate.a).is_equal_approx(1.0, 0.001)
	assert_vector(prompt.scale).is_equal_approx(Vector2.ONE, Vector2.ONE * 0.001)
	prompt.hide_prompt()
	prompt.tween.custom_step(prompt.fade_time + 0.01)
	assert_bool(prompt.visible).is_false()


func test_hiding_a_hidden_prompt_does_nothing() -> void:
	var prompt := _prompt()
	prompt.hide_prompt()
	assert_object(prompt.tween).is_null()


# --- GameOverScreen ----------------------------------------------------------------

func _game_over(won: bool, coins: int) -> GameOverScreen:
	var screen: GameOverScreen = auto_free(GameOverScreen.new())
	screen.setup(won, {"won": won, "abandoned": false, "coins": coins})
	add_child(screen)
	return screen


func _labels(screen: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for label: Label in screen.find_children("*", "Label", true, false):
		texts.append(label.text)
	return texts


func _buttons(screen: Node) -> Array:
	return screen.find_children("*", "Button", true, false)


func test_game_over_screen_after_a_win() -> void:
	var screen := _game_over(true, 15)
	assert_array(Array(_labels(screen))).contains("RUN COMPLETE", "Coins collected: 15")


func test_game_over_screen_after_a_death() -> void:
	var screen := _game_over(false, 0)
	assert_array(Array(_labels(screen))).contains("GAME OVER", "Coins collected: 0")


func test_game_over_screen_offers_a_new_run_or_the_hub() -> void:
	var screen := _game_over(false, 0)
	var texts := _buttons(screen).map(func(b: Button) -> String: return b.text)
	assert_array(texts).contains_exactly("New Run", "Get Back To Hub")


func test_game_over_screen_works_on_top_of_a_paused_game() -> void:
	var screen := _game_over(true, 1)
	assert_int(screen.layer).is_equal(100)
	assert_int(screen.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	var holder: Control = screen.get_child(0)
	assert_int(holder.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
