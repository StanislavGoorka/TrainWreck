class_name DialogueData
extends Resource

@export var id: String = ""    # unique per speaker, used to remember how far the conversation went
@export_multiline var lines: Array[String] = []

# Lines play in order. After the last one, it repeats forever.
func get_line(index: int) -> String:
	if lines.is_empty():
		return "..."
	return lines[mini(index, lines.size() - 1)]
