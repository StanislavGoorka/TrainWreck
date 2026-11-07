extends State

var attack_area: Area2D

func enter(_msg := {}) -> void:
	if not attack_area:
		attack_area = actor.get_node("AttackHitbox")
	actor.get_node("AnimatedSprite2D").play("run")
	if not attack_area.body_entered.is_connected(_on_attack_range_entered):
		attack_area.body_entered.connect(_on_attack_range_entered)

func exit() -> void:
	if attack_area and attack_area.body_entered.is_connected(_on_attack_range_entered):
		attack_area.body_entered.disconnect(_on_attack_range_entered)

func physics_update(_delta: float) -> void:
	var target: Node2D = actor.target
	if not is_instance_valid(target):
		transition_requested.emit(&"Idle")
		return
	var dir: Vector2 = (target.global_position - actor.global_position).normalized()
	actor.velocity = dir * actor.stats.speed
	actor.move_and_slide()
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("Players"):
			transition_requested.emit(&"Attack")
			return
	actor.face_direction(dir.x)

func _on_attack_range_entered(body: Node) -> void:
	if body.is_in_group("Players"):
		transition_requested.emit(&"Attack")
