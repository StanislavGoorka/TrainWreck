extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

var time: float = 600.0
var minutes: int = 0
var seconds: int = 0

func _process(delta) -> void:
	time -= delta
	seconds = fmod(time, 60)
	minutes = fmod(time, 3600) / 60
	%Minutes.text = "%02d:" % minutes
	%Seconds.text = "%02d" % seconds

func get_time_formatted() -> String: 
	return "%02d:%02d" % [minutes, seconds]
