extends Area2D

const eBULLET = preload("res://Placeholders/Scenes/Enemies/laser_bullet.tscn")

#func _ready():
	#$Reload.stop()

func _physics_process(delta):
	var target = get_parent().target
	if target and target.is_inside_tree():
		look_at(target.global_position)

func shoot():
	
	
	var target = get_parent().target
	if not target or not target.is_inside_tree():
		return
	
	var enemy_bullet = eBULLET.instantiate()
	enemy_bullet.global_position = $WeaponPivot/Sprite2D/ShootingPoint.global_position
	enemy_bullet.rotation = $WeaponPivot/Sprite2D/ShootingPoint.global_rotation
	get_tree().current_scene.add_child(enemy_bullet)
	print("shoot() called!") 

func start_shooting():
	$"../AnimatedSprite2D".play("Prepare")
	$Reload.start()

func stop_shooting():
	$"../AnimatedSprite2D".play("Return")
	$Reload.stop()

func _on_reload_timeout() -> void:
	shoot()
