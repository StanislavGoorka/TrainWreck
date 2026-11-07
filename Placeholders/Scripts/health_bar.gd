extends ProgressBar

@onready var player = get_node("/root/Game/Character1")

func _process(delta):
	value = player.HEALTH
