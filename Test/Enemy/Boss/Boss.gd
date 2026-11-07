class_name Boss
extends Enemy

func _ready() -> void:
	# Groups are added in code so a forgotten Inspector group can't break the boss.
	add_to_group("Enemies")
	add_to_group("Bosses")
	if not stats is BossStats:
		push_error("%s needs a BossStats resource assigned to Stats!" % name)
	super._ready()
