class_name StatusEffect
extends RefCounted

enum Type { NONE, BURN, POISON, FREEZE, BLEED }

const MAX_STACKS := 10

# Burn: 3 ticks over 3 seconds. Damage per tick = max(1, 0.5 x stacks)
const BURN_TICKS := 3
const BURN_INTERVAL := 1.0
const BURN_DAMAGE_PER_STACK := 0.5
const BURN_MIN_DAMAGE := 1.0

# Poison: constant damage every second for 10 seconds (stacks don't change the damage)
const POISON_DURATION := 10.0
const POISON_INTERVAL := 1.0
const POISON_DAMAGE := 0.5

# Freeze: flat 20% slow however many stacks. 10 stacks = frozen solid.
const FREEZE_DURATION := 4.0     # how long the slow lasts after the last stack
const FREEZE_SLOW := 0.8         # multiplier on move speed and attack rate
const FROZEN_DURATION := 2.5

# Bleed: the next hit does 1.5x damage, then the bleed is gone
const BLEED_MULTIPLIER := 1.5
const BLEED_DURATION := 10.0     # 0 = lasts until the next hit

static func display_name(type: int) -> String:
	return String(Type.keys()[type]).capitalize()
	
static func color(type: int) -> Color:
	match type:
		Type.BURN: return Color(1.0, 0.55, 0.2)
		Type.POISON: return Color(0.55, 1.0, 0.4)
		Type.FREEZE: return Color(0.6, 0.85, 1.0)
		Type.BLEED: return Color(1.0, 0.3, 0.35)
	return Color.WHITE

# Average of all effects on the bullet, so a bullet with two effects shows a mix.
static func bullet_color(statuses: Dictionary) -> Color:
	var total := Color(0, 0, 0, 1)
	for type in statuses:
		total += color(type)
	return total / maxf(statuses.size(), 1)
