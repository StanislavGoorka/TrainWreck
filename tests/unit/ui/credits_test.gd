## Credits data, scrolling and exit controls. Busy loading prevents replacing the runner.
extends "res://tests/helpers/tw_test_suite.gd"

const CreditsScript := preload("res://Placeholders/Scripts/credits.gd")
const TEAM_DATA := "res://Test/Scripts/Resource/CreditsResource/MainTeam.tres"


func _credits() -> CreditsScreen:
	var section := CreditsSection.new()
	section.heading = "Team"
	section.lines.assign(["First person", "Second person"])
	var data := CreditsData.new()
	data.game_title = "Test title"
	data.sections.assign([section])
	data.closing_text = "The end"
	var credits: CreditsScreen = auto_free(CreditsScript.new())
	credits.data = data
	credits.start_delay = 0.0
	credits.end_delay = 0.0
	credits.fade_time = 0.0
	add_child(credits)
	credits.set_process(false)
	assert_bool(await wait_until(func() -> bool: return credits.scrolling)).is_true()
	return credits


func test_credits_build_the_text_from_their_data() -> void:
	var credits := await _credits()
	var lines := []
	for child in credits.content.get_children():
		if child is Label:
			lines.append(child.text)
	assert_array(lines).contains_exactly("Test title", "Team", "First person", "Second person", "The end")


func test_credits_scroll_by_elapsed_time() -> void:
	var credits := await _credits()
	var before := credits.scroll_y
	credits._process(0.25)
	assert_float(credits.scroll_y).is_equal_approx(before - credits.scroll_speed * 0.25, 0.001)


func test_holding_down_accelerates_the_credits() -> void:
	var credits := await _credits()
	var before := credits.scroll_y
	Input.action_press("ui_down")
	credits._process(0.25)
	assert_float(credits.scroll_y).is_equal_approx(before - credits.scroll_speed * credits.fast_multiplier * 0.25, 0.001)


func test_skip_exits_once_and_stops_the_run() -> void:
	var credits := await _credits()
	var finished := []
	credits.finished.connect(func() -> void: finished.append(true))
	SceneLoader.busy = true
	GameState.run_active = true
	GameState.game_over = true
	credits.skip_button.pressed.emit()
	credits.skip_button.pressed.emit()
	assert_array(finished).has_size(1)
	assert_bool(credits.leaving).is_true()
	assert_bool(credits.scrolling).is_false()
	assert_bool(GameState.run_active).is_false()
	assert_bool(GameState.game_over).is_false()


func test_cancel_exits_the_credits() -> void:
	var credits := await _credits()
	SceneLoader.busy = true
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	credits._unhandled_input(event)
	assert_bool(credits.leaving).is_true()


func test_credits_exit_automatically_after_the_last_line() -> void:
	var credits := await _credits()
	SceneLoader.busy = true
	credits.scroll_y = -credits.content.size.y - 1.0
	credits._process(0.0)
	assert_bool(await wait_until(func() -> bool: return credits.leaving)).is_true()


func test_team_resource_contains_credits_sections() -> void:
	var data := load(TEAM_DATA) as CreditsData
	assert_object(data).is_not_null()
	assert_array(data.sections).is_not_empty()
	for section in data.sections:
		assert_object(section).is_instanceof(CreditsSection)
		assert_array(section.lines).is_not_empty()
