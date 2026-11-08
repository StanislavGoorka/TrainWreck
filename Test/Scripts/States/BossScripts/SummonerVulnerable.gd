extends State

var time_left := 0.0

func enter(_msg := {}) -> void:
	var s := actor.stats as SummonerBossStats
	time_left = s.window_duration
	(actor as SummonerBoss).set_vulnerable(true)
	actor.play_anim(&"idle")

func exit() -> void:
	(actor as SummonerBoss).set_vulnerable(false)

func physics_update(delta: float) -> void:
	var boss := actor as SummonerBoss
	var s := actor.stats as SummonerBossStats
	time_left -= delta
	var cap_hit := s.end_window_at_cap and boss.window_damage >= boss.window_cap() - 0.001
	if time_left <= 0.0 or cap_hit:
		transition_requested.emit(&"Summon")
