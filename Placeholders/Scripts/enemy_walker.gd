extends CharacterBody2D

@onready var visi = $Visible

@onready var visib = false

@export var stats: EnemyStats

var target: Node = null
#@onready var player = 


func _physics_process(delta):
	if target == null:
		return
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * stats.speed
	move_and_slide()
	if velocity.x > 0:
		$AnimatedSprite2D.play("Run")
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		$AnimatedSprite2D.play("Run")
		$AnimatedSprite2D.flip_h = true
	else:
		return
		
	
func hurt_enemy():
	var health = stats.health
	health -= 1
	if health == 0:
		queue_free()


func _on_visible_screen_entered() -> void:
	print("Entered")
	visib = true
#
#
func _on_visible_screen_exited() -> void:
	print("Exited")
	visib = false
	
