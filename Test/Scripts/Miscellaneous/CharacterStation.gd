class_name CharacterStation
extends Interactable

var menu: CharacterSelectMenu

func can_interact() -> bool:
	return menu == null

func interact(p: Player) -> void:
	menu = CharacterSelectMenu.new()
	get_tree().current_scene.add_child(menu)
	menu.setup(p)
	# Freezes the player (and their own UI) while the menu is open.
	p.process_mode = Node.PROCESS_MODE_DISABLED
	menu.closed.connect(func():
		p.process_mode = Node.PROCESS_MODE_INHERIT
		menu = null
	)
