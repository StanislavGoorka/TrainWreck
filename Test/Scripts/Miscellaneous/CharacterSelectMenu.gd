class_name CharacterSelectMenu
extends CanvasLayer

signal closed

var player: Player
var cards: HBoxContainer
var info_label: Label

func setup(target_player: Player) -> void:
	player = target_player
	layer = 50

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Choose your character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	box.add_child(cards)

	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info_label)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	box.add_child(back)

	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Interact"):
		get_viewport().set_input_as_handled()
		close()

func _refresh() -> void:
	for child in cards.get_children():
		child.queue_free()
	info_label.text = "Meta currency: %d" % GameState.meta_currency
	for def in GameState.characters.values():
		cards.add_child(_build_card(def))

func _build_card(def: CharacterDefinition) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(180, 0)

	var portrait := TextureRect.new()
	portrait.texture = def.portrait
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card.add_child(portrait)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var desc := Label.new()
	desc.text = def.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(180, 0)
	card.add_child(desc)

	var button := Button.new()
	if GameState.is_unlocked(def.id):
		if GameState.selected_id == def.id:
			button.text = "Selected"
			button.disabled = true
		else:
			button.text = "Select"
			button.pressed.connect(_on_select.bind(def))
	else:
		button.text = "Unlock (%d)" % def.unlock_cost
		button.disabled = GameState.meta_currency < def.unlock_cost
		button.pressed.connect(_on_unlock.bind(def))
	card.add_child(button)
	return card

func _on_select(def: CharacterDefinition) -> void:
	GameState.select_character(def.id)
	player.apply_character(def)   # swaps the character live in the hub
	_refresh()

func _on_unlock(def: CharacterDefinition) -> void:
	if GameState.unlock_character(def.id):
		_refresh()

func close() -> void:
	closed.emit()
	queue_free()
