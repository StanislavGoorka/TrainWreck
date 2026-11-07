extends CharacterBody2D

var posit: Vector2
var rotat: float
var direct: float
var distance = 0

var SPEED = 500
var RANGE = 500


func _physics_process(delta):
	var motion = Vector2.RIGHT.rotated(rotation) * SPEED * delta
	var collision = move_and_collide(motion)
	var direction = Vector2.RIGHT.rotated(rotation)
	position += direction * SPEED * delta
#Powyżej mamy kod dotyczący kierunku i prędkości pocisków
	distance += SPEED * delta
	if distance > RANGE:
		queue_free()
#A tutaj usuwanie pocisków jeśli polecą za daleko i w nic nie trafią

	if collision:
		var collider = collision.get_collider()

		if collider is TileMap:
			queue_free()
			return
