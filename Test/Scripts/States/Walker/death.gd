extends State

func enter(_msg := {}) -> void:
	actor.velocity = Vector2.ZERO
	actor.set_physics_process(false)
	actor.get_node("CollisionShape2D").set_deferred("disabled", true)

	var anim: AnimatedSprite2D = actor.get_node("AnimatedSprite2D")
	if anim.sprite_frames and anim.sprite_frames.has_animation("Death"):
		anim.play("Death")
		await anim.animation_finished
	else:
		push_warning("No 'Death' animation found — despawning after fallback delay.")
		await actor.get_tree().create_timer(0.3).timeout

	actor.queue_free()
