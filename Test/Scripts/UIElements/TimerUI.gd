extends Label

var elapsed: float = 0.0
var running: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var player := get_tree().get_first_node_in_group("Players") as Player
	if player:
		player.died.connect(stop)
	_update_text()

func _process(delta: float) -> void:
	if not running or get_tree().paused:
		return
	elapsed += delta
	_update_text()

func stop() -> void:
	running = false

func _update_text() -> void:
	var total := int(elapsed)
	text = "%02d:%02d" % [floori(elapsed / 60.0), total % 60]
