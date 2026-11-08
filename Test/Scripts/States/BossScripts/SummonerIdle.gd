extends State

func enter(_msg := {}) -> void:
	actor.velocity = Vector2.ZERO
	actor.play_anim(&"idle")

func physics_update(_delta: float) -> void:
	if is_instance_valid(actor.target):   # the room sets this once the boss has faded in
		transition_requested.emit(&"Summon")
