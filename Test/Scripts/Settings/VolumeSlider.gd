class_name VolumeSlider
extends HSlider

@export var bus: StringName = &"Master"

func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.05
	value = Audio.get_volume(bus)
	value_changed.connect(func(v: float): Audio.set_volume(bus, v))
