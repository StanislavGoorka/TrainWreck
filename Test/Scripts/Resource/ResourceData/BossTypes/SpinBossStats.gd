class_name SpinBossStats
extends BossStats

@export_group("Spin Attack")
@export var spin_trigger_range: float = 160.0   # distance at which the boss starts a spin
@export var spin_windup: float = 0.5            # red-blink telegraph
@export var spin_duration: float = 1.2
@export var spin_recovery: float = 0.8          # boss stands still and can be shot
@export var spin_cooldown: float = 3.0          # chase time before the next spin
@export var spin_damage: float = 1.0            # 1 = half a heart
@export var spin_move_speed_mult: float = 0.4   # boss drifts toward you while spinning
