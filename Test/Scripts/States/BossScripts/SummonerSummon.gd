extends State

var delay_left := 0.0
var spawned := false

func enter(_msg := {}) -> void:
	var boss := actor as SummonerBoss
	var s := actor.stats as SummonerBossStats
	boss.set_vulnerable(false)
	actor.play_anim(&"summon")
	delay_left = s.first_wave_delay if boss.wave_number == 0 else s.wave_delay
	spawned = false

func physics_update(delta: float) -> void:
	var boss := actor as SummonerBoss
	if not spawned:
		delay_left -= delta
		if delay_left <= 0.0:
			boss.spawn_wave()
			spawned = true
			actor.play_anim(&"idle")
		return
	if boss.wave_cleared():
		transition_requested.emit(&"Vulnerable")
