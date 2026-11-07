extends CharacterBody2D

@export var speed = 100
@export var health = 3
var target: Node = null
#@onready var player = 
func _physics_process(delta):
	if target and target.is_inside_tree():
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		if velocity.x > 0:
			$AnimatedSprite2D.play("Run")
			$AnimatedSprite2D.flip_h = false
		elif velocity.x < 0:
			$AnimatedSprite2D.play("Run")
			$AnimatedSprite2D.flip_h = true
	else:
		velocity = Vector2.ZERO
		$AnimatedSprite2D.play("Idle")

func hurt_enemy():
	health -= 1
	if health == 0:
		queue_free()
