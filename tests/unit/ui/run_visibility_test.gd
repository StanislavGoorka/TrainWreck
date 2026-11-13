## Run HUD visibility and the floor label, without loading image files.
extends "res://tests/helpers/tw_test_suite.gd"

const HoldToShow := preload("res://Test/Scripts/Miscellaneous/HoldToShow.gd")
const FloorUI := preload("res://Test/Scripts/UIElements/FloorUI.gd")


func _panel(action: StringName = &"Show") -> Control:
	var panel: Control = auto_free(HoldToShow.new())
	panel.action = action
	add_child(panel)
	panel.set_process(false)
	return panel


func test_panel_starts_hidden_and_belongs_to_the_run_ui() -> void:
	var panel := _panel()
	assert_bool(panel.shown).is_false()
	assert_float(panel.modulate.a).is_zero()
	assert_bool(panel.is_in_group("RunOnlyUI")).is_true()


func test_holding_and_releasing_show_controls_visibility() -> void:
	var panel := _panel()
	Input.action_press("Show")
	panel._process(0.0)
	panel.tween.custom_step(panel.fade_time + 0.01)
	assert_bool(panel.shown).is_true()
	assert_float(panel.modulate.a).is_equal_approx(1.0, 0.001)
	Input.action_release("Show")
	panel._process(0.0)
	panel.tween.custom_step(panel.fade_time + 0.01)
	assert_bool(panel.shown).is_false()
	assert_float(panel.modulate.a).is_equal_approx(0.0, 0.001)


func test_releasing_mid_fade_reverses_the_transition() -> void:
	var panel := _panel()
	Input.action_press("Show")
	panel._process(0.0)
	panel.tween.custom_step(panel.fade_time / 2.0)
	Input.action_release("Show")
	panel._process(0.0)
	panel.tween.custom_step(panel.fade_time + 0.01)
	assert_float(panel.modulate.a).is_equal_approx(0.0, 0.001)
	assert_bool(panel.shown).is_false()


func test_panel_uses_its_configured_action() -> void:
	var panel := _panel(&"Interact")
	Input.action_press("Show")
	panel._process(0.0)
	assert_bool(panel.shown).is_false()
	Input.action_press("Interact")
	panel._process(0.0)
	panel.tween.custom_step(panel.fade_time + 0.01)
	assert_bool(panel.shown).is_true()
	assert_float(panel.modulate.a).is_equal_approx(1.0, 0.001)


func test_floor_label_shows_the_current_floor_on_startup() -> void:
	GameState.current_floor = 3
	var label: Label = auto_free(FloorUI.new())
	add_child(label)
	assert_str(label.text).is_equal(GameState.floor_title(3))


func test_floor_label_updates_when_the_floor_changes() -> void:
	var label: Label = auto_free(FloorUI.new())
	add_child(label)
	GameState.total_floors = 3
	GameState.advance_floor()
	assert_str(label.text).is_equal(GameState.floor_title(2))


func test_show_action_is_bound_to_the_physical_tab_key() -> void:
	var found := false
	for event in InputMap.action_get_events("Show"):
		if event is InputEventKey and event.physical_keycode == KEY_TAB:
			found = true
	assert_bool(found).is_true()
