extends VBoxContainer

@export var coin_icon: Texture2D
@export var key_icon: Texture2D
@export var icon_size: Vector2 = UIStyle.ICON_SIZE

var player: Player
var coin_label: Label
var key_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", UIStyle.SPACING_SMALL)

	coin_label = _add_row(coin_icon)
	key_label = _add_row(key_icon)

	player = get_tree().get_first_node_in_group("Players") as Player
	if not player:
		push_warning("CurrencyUI couldn't find Player.")
		return
	player.currency_changed.connect(_on_currency_changed)
	player.keys_changed.connect(_on_keys_changed)
	_on_currency_changed(player.currency)
	_on_keys_changed(player.keys)

func _add_row(texture: Texture2D) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIStyle.SPACING_SMALL)

	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	add_child(row)
	return label

func _on_currency_changed(amount: int) -> void:
	coin_label.text = "%02d" % amount

func _on_keys_changed(amount: int) -> void:
	key_label.text = "%02d" % amount
