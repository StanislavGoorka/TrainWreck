extends Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _process(_delta: float) -> void:
	text = GameState.format_time(GameState.run_time)
