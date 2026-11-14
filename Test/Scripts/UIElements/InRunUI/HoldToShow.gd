extends Control

@export var action: StringName = &"Show"
@export var fade_time: float = 0.12

var shown := false
var tween: Tween

func _ready() -> void:
	add_to_group("RunOnlyUI")   # Hub.gd hides everything in this group
	modulate.a = 0.0
	if not InputMap.has_action(action):
		push_warning("HoldToShow: input action '%s' does not exist." % action)

func _process(_delta: float) -> void:
	var want := InputMap.has_action(action) and Input.is_action_pressed(action)
	if want == shown:
		return
	shown = want
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0 if want else 0.0, fade_time)
