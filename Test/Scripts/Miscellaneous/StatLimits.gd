class_name StatLimits
extends RefCounted

const MAX_HEARTS := 12
const HP_PER_HEART := 2.0
const MAX_HEALTH := MAX_HEARTS * HP_PER_HEART        # 24.0

const MAX_FIRE_RATE := 5.0                           # shots per second, the number the stats screen shows
const MIN_FIRE_INTERVAL := 0.4 / MAX_FIRE_RATE       # 0.2 s between shots
