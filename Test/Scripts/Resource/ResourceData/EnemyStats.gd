class_name EnemyStats
extends Resource

@export var max_health: float = 5.0
@export var speed: float = 350.0
@export var damage: float = 1.0
@export var attack_cooldown: float = 0.5
@export_flags("Burn", "Poison", "Freeze", "Bleed") var status_immunities: int = 0
