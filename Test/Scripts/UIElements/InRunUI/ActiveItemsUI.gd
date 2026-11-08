extends GridContainer

@export var max_columns: int = 8
@export var icon_size: Vector2 = UIStyle.ICON_SIZE

var player: Player
var shown_count := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns = max_columns
	add_theme_constant_override("h_separation", UIStyle.SPACING_SMALL)
	add_theme_constant_override("v_separation", UIStyle.SPACING_SMALL)

	player = get_tree().get_first_node_in_group("Players") as Player
	if not player:
		push_warning("ActiveItemsUI couldn't find Player.")
		return
	# stats_changed fires on every inventory change, including silent adds.
	player.stats_changed.connect(_refresh)
	call_deferred("_refresh")

func _refresh() -> void:
	if not player or player.inventory.size() == shown_count:
		return
	shown_count = player.inventory.size()

	for child in get_children():
		remove_child(child)   # removed immediately, so old and new icons never overlap
		child.queue_free()

	for item in player.inventory:
		var icon := TextureRect.new()
		icon.texture = item.get_icon_ui()
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
