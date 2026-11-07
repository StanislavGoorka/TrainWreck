extends WeaponState

const BULLET := preload("res://Placeholders/Scenes/Characters/bullet.tscn")

func physics_update(_delta: float) -> void:
	%Arrow.play("Idle")
	var player := aim.get_parent() as Player
	if Input.is_action_pressed("Shoot") and player.can_shoot():
		_shoot()
		transition_requested.emit(&"WeaponCooldown")

func _shoot() -> void:
	var player := aim.get_parent() as Player
	var stats := player.current_weapon_stats

	var bullet := BULLET.instantiate()
	%Arrow.play("Shot")
	aim.call("recoil")   # gun kick

	bullet.global_position = %ShootingPoint.global_position
	bullet.rotation = %ShootingPoint.global_rotation
	bullet.damage = stats.damage
	bullet.speed = stats.bullet_speed

	bullet.statuses = player.roll_bullet_statuses()

	get_tree().current_scene.add_child(bullet)
