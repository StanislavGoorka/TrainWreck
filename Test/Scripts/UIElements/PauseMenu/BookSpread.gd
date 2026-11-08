class_name BookSpread
extends HBoxContainer

@export var tab_title: String = ""            # empty = use the node's name
@export var tab_tint: Color = Color.WHITE     # tints the tab sprite (green, red, blue)

func get_title() -> String:
	return tab_title if tab_title != "" else String(name)

# Override in subclasses. Called every time this spread is shown.
func opened() -> void:
	pass
