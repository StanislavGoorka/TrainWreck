extends Control

@onready var book: BookMenu = $Book
@onready var buttons: VBoxContainer = $Book/Main/RightPage/Buttons

var fade_tween: Tween

func _ready() -> void:
	$AnimationPlayer.play("RESET")
	book.visible = false
	_connect_button("Resume", _on_resume_pressed)
	_connect_button("Restart", _on_restart_pressed)
	_connect_button("Abandon", _on_abandon_pressed)
	_connect_button("Quit", _on_quit_pressed)

func _connect_button(button_name: String, handler: Callable) -> void:
	var button := buttons.get_node_or_null(button_name) as BaseButton
	if button and not button.pressed.is_connected(handler):
		button.pressed.connect(handler)

func _process(_delta: float) -> void:
	if GameState.game_over or SceneLoader.busy:
		return
	if Input.is_action_just_pressed("Pause"):
		if get_tree().paused:
			resume()
		else:
			pause()

func _set_buttons_disabled(value: bool) -> void:
	for child in buttons.get_children():
		if child is BaseButton:
			child.disabled = value

func resume() -> void:
	get_tree().paused = false
	_set_buttons_disabled(true)
	$AnimationPlayer.play_backwards("Blur")
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(book, "modulate:a", 0.0, 0.15)
	fade_tween.tween_callback(func(): book.visible = false)

func pause() -> void:
	var in_run := GameState.run_active
	for button_name in ["Restart", "Abandon"]:
		var button := buttons.get_node_or_null(button_name) as Control
		if button:
			button.visible = in_run
	_set_buttons_disabled(false)

	book.visible = true
	book.select_tab(0, true)
	if fade_tween:
		fade_tween.kill()
	book.modulate.a = 0.0
	fade_tween = create_tween()
	fade_tween.tween_property(book, "modulate:a", 1.0, 0.15)

	get_tree().paused = true
	$AnimationPlayer.play("Blur")
	(buttons.get_node("Resume") as Control).grab_focus()   # keyboard and gamepad work right away

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	resume()
	GameState.start_run()

func _on_abandon_pressed() -> void:
	resume()
	GameState.end_run(false, true)

func _on_quit_pressed() -> void:
	GameState.go_to_menu()
