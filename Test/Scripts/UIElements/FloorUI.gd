extends Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long floor name wraps instead of widening the stack
	GameState.floor_changed.connect(func(_n: int): _refresh())
	_refresh()

func _refresh() -> void:
	text = GameState.floor_title(GameState.current_floor)
