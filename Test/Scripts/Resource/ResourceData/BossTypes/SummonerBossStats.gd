class_name SummonerBossStats
extends BossStats

@export_group("Waves")
@export var enemy_pool: Array[PackedScene] = []          # drag your enemy scenes here
@export var wave_size_pool: Array[int] = [2, 3, 4, 5, 6] # sizes, smallest to largest
@export var growth_after_pool: int = 1                   # extra enemies per wave once the pool runs out
@export var first_wave_delay: float = 1.5
@export var wave_delay: float = 0.5                      # pause between a window ending and the next wave
@export var spawn_fade_time: float = 0.6                 # enemies are harmless while they fade in
@export var spawn_radius_min: float = 160.0
@export var spawn_radius_max: float = 320.0

@export_group("Vulnerability Window")
@export var window_duration: float = 5.0
@export_range(0.0, 1.0, 0.01) var window_damage_cap: float = 0.25   # of max health, per window
@export var end_window_at_cap: bool = false                          # true = the window closes once the cap is hit
