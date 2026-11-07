extends VBoxContainer

@export var speed_icon: Texture2D
@export var dash_icon: Texture2D
@export var damage_icon: Texture2D
@export var fire_rate_icon: Texture2D
@export var bullet_speed_icon: Texture2D
@export var range_icon: Texture2D
@export var luck_icon: Texture2D
@export var special_icon: Texture2D

@export var icon_size: Vector2 = Vector2(16, 16)

var player: Player
var value_labels: Dictionary = {}   # stat id -> Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = get_tree().get_first_node_in_group("Players") as Player
	if not player:
		push_warning("StatsUI couldn't find Player.")
		return

	_build_rows()
	player.stats_changed.connect(_refresh)
	# Player._ready() may not have run yet, so draw once it has.
	call_deferred("_refresh")

func _build_rows() -> void:
	var rows := [
		["speed", speed_icon],
		["dash", dash_icon],
		["damage", damage_icon],
		["fire_rate", fire_rate_icon],
		["bullet_speed", bullet_speed_icon],
		["range", range_icon],
		["luck", luck_icon],
		["special", special_icon],
	]

	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := TextureRect.new()
		icon.texture = row[1]
		icon.custom_minimum_size = icon_size
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(label)

		add_child(hbox)
		value_labels[row[0]] = label

func _refresh() -> void:
	if not player or not player.current_stats or not player.current_weapon_stats:
		return

	var c := player.current_stats
	var w := player.current_weapon_stats

	value_labels["speed"].text = _fmt(c.speed)
	value_labels["dash"].text = _fmt(c.dash_distance)
	value_labels["damage"].text = _fmt(w.damage)
	# fire_rate is seconds between shots, so show shots per second (higher = better)
	value_labels["fire_rate"].text = _fmt(1.0 / w.fire_rate) if w.fire_rate > 0.0 else "MAX"
	value_labels["bullet_speed"].text = _fmt(w.bullet_speed)
	value_labels["range"].text = _fmt(w.shoot_range)
	value_labels["luck"].text = _fmt(c.luck)
	value_labels["special"].text = "%d%%" % roundi(c.special_chance * 100.0)

func _fmt(value: float) -> String:
	return "%.2f" % value
