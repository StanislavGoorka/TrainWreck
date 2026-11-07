class_name Interactable
extends Area2D

@export var prompt_text: String = "Interact"
@export var prompt_icon: Texture2D      # empty = use the default interact icon
@export var prompt_theme: Theme         # empty = use the project theme
@export var prompt_offset: Vector2 = Vector2(0, -48)

var player_inside: Player = null
var prompt: InteractPrompt

func _ready() -> void:
	# Set in code so a forgotten mask can't break it: detects the player layer only.
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	prompt = InteractPrompt.new()
	prompt.setup(prompt_text, prompt_icon, prompt_theme, prompt_offset)
	add_child(prompt)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		player_inside = body
		refresh_prompt()

func _on_body_exited(body: Node) -> void:
	if body == player_inside:
		player_inside = null
		prompt.hide_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if player_inside and can_interact() and event.is_action_pressed("Interact"):
		get_viewport().set_input_as_handled()
		interact(player_inside)
		refresh_prompt()

# Call this whenever can_interact() may have changed.
func refresh_prompt() -> void:
	if player_inside and can_interact():
		prompt.show_prompt()
	else:
		prompt.hide_prompt()

# Override in subclasses
func can_interact() -> bool:
	return true

func interact(_player: Player) -> void:
	pass
