class_name StatusComponent
extends Node

signal changed

var enemy: Enemy

var burn_stacks := 0
var burn_ticks_left := 0
var burn_timer := 0.0

var poison_stacks := 0
var poison_left := 0.0
var poison_timer := 0.0

var freeze_stacks := 0
var freeze_left := 0.0
var frozen := false
var frozen_left := 0.0

var bleeding := false
var bleed_left := 0.0

func apply(type: int, amount: int = 1) -> void:
	if enemy == null or enemy.is_dead or enemy.is_immune_to(type):
		return
	match type:
		StatusEffect.Type.BURN:
			if burn_ticks_left == 0:
				burn_timer = StatusEffect.BURN_INTERVAL   # only start the clock if not already burning
			burn_stacks = mini(burn_stacks + amount, StatusEffect.MAX_STACKS)
			burn_ticks_left = StatusEffect.BURN_TICKS
		StatusEffect.Type.POISON:
			if poison_left <= 0.0:
				poison_timer = StatusEffect.POISON_INTERVAL
			poison_stacks = mini(poison_stacks + amount, StatusEffect.MAX_STACKS)
			poison_left = StatusEffect.POISON_DURATION
		StatusEffect.Type.FREEZE:
			_apply_freeze(amount)
		StatusEffect.Type.BLEED:
			bleeding = true
			bleed_left = StatusEffect.BLEED_DURATION
	_refresh()

func _apply_freeze(amount: int) -> void:
	if frozen:
		return
	freeze_stacks = mini(freeze_stacks + amount, StatusEffect.MAX_STACKS)
	freeze_left = StatusEffect.FREEZE_DURATION
	if freeze_stacks >= StatusEffect.MAX_STACKS:
		frozen = true
		frozen_left = StatusEffect.FROZEN_DURATION
		enemy.set_frozen(true)
	_update_multipliers()

# Called by Enemy.take_damage() on every normal hit.
func consume_bleed() -> float:
	if not bleeding:
		return 1.0
	bleeding = false
	_refresh()
	return StatusEffect.BLEED_MULTIPLIER

func clear_all() -> void:
	burn_stacks = 0
	burn_ticks_left = 0
	poison_stacks = 0
	poison_left = 0.0
	freeze_stacks = 0
	freeze_left = 0.0
	bleeding = false
	if frozen:
		frozen = false
		enemy.set_frozen(false)
	_update_multipliers()
	_refresh()

func _physics_process(delta: float) -> void:
	if enemy == null or enemy.is_dead:
		return
	var dirty := false

	if burn_ticks_left > 0:
		burn_timer -= delta
		if burn_timer <= 0.0:
			burn_timer += StatusEffect.BURN_INTERVAL
			burn_ticks_left -= 1
			var dmg := maxf(StatusEffect.BURN_MIN_DAMAGE, StatusEffect.BURN_DAMAGE_PER_STACK * burn_stacks)
			if burn_ticks_left <= 0:
				burn_stacks = 0
				dirty = true
			enemy.take_status_damage(dmg)
			if enemy.is_dead:
				return

	if poison_left > 0.0:
		poison_left -= delta
		poison_timer -= delta
		if poison_timer <= 0.0:
			poison_timer += StatusEffect.POISON_INTERVAL
			enemy.take_status_damage(StatusEffect.POISON_DAMAGE)
			if enemy.is_dead:
				return
		if poison_left <= 0.0:
			poison_stacks = 0
			dirty = true

	if frozen:
		frozen_left -= delta
		if frozen_left <= 0.0:
			frozen = false
			freeze_stacks = 0
			freeze_left = 0.0
			enemy.set_frozen(false)
			_update_multipliers()
			dirty = true
	elif freeze_stacks > 0:
		freeze_left -= delta
		if freeze_left <= 0.0:
			freeze_stacks = 0
			_update_multipliers()
			dirty = true

	if bleeding and StatusEffect.BLEED_DURATION > 0.0:
		bleed_left -= delta
		if bleed_left <= 0.0:
			bleeding = false
			dirty = true

	if dirty:
		_refresh()

func _update_multipliers() -> void:
	var mult := StatusEffect.FREEZE_SLOW if freeze_stacks > 0 else 1.0
	enemy.speed_mult = mult
	enemy.attack_speed_mult = mult

func _refresh() -> void:
	# Tint uses self_modulate so it doesn't fight other effects on the sprite's modulate
	# (the boss's red windup blink).
	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		var color := Color.WHITE
		if frozen:
			color = Color(0.55, 0.8, 1.0)
		elif freeze_stacks > 0:
			color = Color(0.75, 0.9, 1.0)
		elif burn_stacks > 0:
			color = Color(1.0, 0.6, 0.3)
		elif poison_stacks > 0:
			color = Color(0.6, 1.0, 0.5)
		elif bleeding:
			color = Color(1.0, 0.5, 0.5)
		sprite.self_modulate = color
	changed.emit()
