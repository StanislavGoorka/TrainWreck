extends WeaponState

func enter(_msg := {}) -> void:
	var player := aim.get_parent() as Player
	var timer := aim.get_node("Cooldown") as Timer
	timer.wait_time = player.current_weapon_stats.fire_rate
	if not timer.timeout.is_connected(_on_cooldown_timeout):
		timer.timeout.connect(_on_cooldown_timeout, CONNECT_ONE_SHOT)
	timer.start()

func _on_cooldown_timeout() -> void:
	transition_requested.emit(&"WeaponIdle")
