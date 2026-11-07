extends Node2D

#@onready var detect_area = $EnemyArea
#
#func _ready():
	#detect_area.body_entered.connect(_on_enemy_area_body_entered)
	#detect_area.body_exited.connect(_on_enemy_area_body_exited)
	#$Doors/Door/CollisionShape2D.set_deferred("disabled", true)
	#$Doors/Door.visible = false
	#
#
#func _on_enemy_area_body_entered(body: Node2D) -> void:
	#if body.is_in_group("Players"):
		## Tell enemies that the player entered
		#for enemy in get_tree().get_nodes_in_group("Enemies"):
			#enemy.target = body
			#print("Player entered area, enemies will chase!!!")
		#$Doors/Door/CollisionShape2D.set_deferred("disabled", false)
		#$Doors/Door.visible = true
		#print("Inside")
			#
#
#
#func _on_enemy_area_body_exited(body: Node2D) -> void:
	#if body.is_in_group("Players"):
		#for enemy in get_tree().get_nodes_in_group("Enemies"):
			#enemy.target = null
			#print("Player left area, enemies stop!!!")
		#$Doors/Door/CollisionShape2D.set_deferred("disabled", true)
		#$Doors/Door.visible = false
		#print("Outside")
#
#
#
#func _on_character_1_death() -> void:
	#pass # Replace with function body.
