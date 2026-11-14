class_name NPC
extends Interactable

@export var dialogue: DialogueData
@export var npc_name: String = "NPC"
@export var talk_sound: AudioStream
@export var text_offset: Vector2 = Vector2(0, -80)
@export var persist_progress: bool = true    # remember the conversation between visits and runs

var dialogue_text: DialogueText
var talking := false
var local_store := {}

func _ready() -> void:
	super()
	dialogue_text = DialogueText.new()
	dialogue_text.sound = talk_sound
	dialogue_text.anchor = text_offset
	add_child(dialogue_text)
	dialogue_text.closed.connect(_on_text_closed)

# While talking there is nothing to interact with, so the prompt hides.
func can_interact() -> bool:
	return not talking

func interact(_player: Player) -> void:
	if talking:
		return
	talking = true
	dialogue_text.show_line(_next_line())

func _unhandled_input(event: InputEvent) -> void:
	# While talking, Interact finishes the line, and then closes it.
	if talking and player_inside and event.is_action_pressed("Interact"):
		get_viewport().set_input_as_handled()
		if dialogue_text.is_typing():
			dialogue_text.skip()
		else:
			dialogue_text.close()
		return
	super(event)

func _on_body_exited(body: Node) -> void:
	var was_player := body == player_inside
	super(body)
	if was_player and talking:
		dialogue_text.close()   # walking away ends the line

func _on_text_closed() -> void:
	talking = false
	refresh_prompt()   # brings the prompt back if the player is still here

func _next_line() -> String:
	if not dialogue:
		return "..."
	var key := dialogue.id if dialogue.id != "" else npc_name
	var store := _store()
	var index := int(store.get(key, 0))
	store[key] = mini(index + 1, dialogue.lines.size())   # stops counting at the last line
	return dialogue.get_line(index)

func _store() -> Dictionary:
	if persist_progress and "dialogue_progress" in GameState:
		return GameState.dialogue_progress
	return local_store
