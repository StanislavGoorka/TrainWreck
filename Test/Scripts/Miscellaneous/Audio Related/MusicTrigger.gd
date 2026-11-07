class_name MusicTrigger
extends Node

@export var track: AudioStream
@export var fade_time: float = 1.0

func _ready() -> void:
	Audio.play_music(track, fade_time)
