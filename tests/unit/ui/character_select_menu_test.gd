## CharacterSelectMenu reads and changes the GameState autoload; the base suite
## restores GameState (and user://save.json) after every test.
extends "res://tests/helpers/tw_test_suite.gd"

var player: Player
var menu: CharacterSelectMenu


func before_test() -> void:
	super.before_test()
	GameState.characters = {
		"slinger": Factory.character_definition("slinger", {"unlocked_by_default": true, "description": "Default"}),
		"brute": Factory.character_definition("brute", {"unlock_cost": 30}),
		"ghost": Factory.character_definition("ghost", {"unlock_cost": 500}),
	}
	GameState.unlocked_characters.assign(["slinger"])
	GameState.selected_id = "slinger"
	GameState.meta_currency = 40
	player = auto_free(Factory.player())
	add_child(player)
	menu = auto_free(CharacterSelectMenu.new())
	add_child(menu)
	menu.setup(player)


func _live_cards() -> Array:
	return menu.cards.get_children().filter(func(card: Node) -> bool: return not card.is_queued_for_deletion())


func _card(id: String) -> VBoxContainer:
	var display_name: String = GameState.characters[id].display_name
	for card: VBoxContainer in _live_cards():
		if (card.get_child(1) as Label).text == display_name:
			return card
	return null


func _button(id: String) -> Button:
	return _card(id).get_child(3)


func test_menu_draws_above_the_game() -> void:
	assert_int(menu.layer).is_equal(50)


func test_menu_shows_a_card_per_character() -> void:
	assert_array(_live_cards()).has_size(3)
	assert_str((_card("slinger").get_child(2) as Label).text).is_equal("Default")


func test_menu_shows_the_meta_currency() -> void:
	assert_str(menu.info_label.text).is_equal("Meta currency: 40")


func test_selected_character_button_is_disabled() -> void:
	assert_str(_button("slinger").text).is_equal("Selected")
	assert_bool(_button("slinger").disabled).is_true()


func test_locked_characters_show_their_price() -> void:
	assert_str(_button("brute").text).is_equal("Unlock (30)")
	assert_bool(_button("brute").disabled).is_false()
	assert_str(_button("ghost").text).is_equal("Unlock (500)")
	assert_bool(_button("ghost").disabled).is_true()


func test_unlocking_spends_currency_and_refreshes_the_cards() -> void:
	_button("brute").pressed.emit()
	assert_bool(GameState.is_unlocked("brute")).is_true()
	assert_int(GameState.meta_currency).is_equal(10)
	assert_str(_button("brute").text).is_equal("Select")
	assert_str(menu.info_label.text).is_equal("Meta currency: 10")


func test_selecting_a_character_swaps_it_on_the_player() -> void:
	GameState.unlocked_characters.append("brute")
	GameState.characters["brute"].stats = Factory.character_stats(20.0, 111.0)
	menu._refresh()
	_button("brute").pressed.emit()
	assert_str(GameState.selected_id).is_equal("brute")
	assert_float(player.current_stats.speed).is_equal(111.0)
	assert_str(_button("brute").text).is_equal("Selected")


func test_back_button_closes_the_menu() -> void:
	var closed := []
	menu.closed.connect(func() -> void: closed.append(true))
	var back: Button = menu.find_children("*", "Button", true, false) \
		.filter(func(b: Button) -> bool: return b.text == "Back")[0]
	back.pressed.emit()
	assert_array(closed).has_size(1)
	assert_bool(menu.is_queued_for_deletion()).is_true()


func test_interact_key_closes_the_menu() -> void:
	var closed := []
	menu.closed.connect(func() -> void: closed.append(true))
	var event := InputEventAction.new()
	event.action = &"Interact"
	event.pressed = true
	menu._unhandled_input(event)
	assert_array(closed).has_size(1)
