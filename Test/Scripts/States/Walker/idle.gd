extends State

func enter(_msg := {}) -> void:
	actor.velocity = Vector2.ZERO
	actor.get_node("AnimatedSprite2D").play("Idle")

func physics_update(_delta: float) -> void:
	if is_instance_valid(actor.target):
		transition_requested.emit(&"Chase")
