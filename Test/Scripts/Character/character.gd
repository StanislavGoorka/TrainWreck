class_name Player
extends CharacterBody2D

signal died
signal item_picked_up(item: ItemData)
signal currency_changed(new_amount: int)
signal keys_changed(new_amount: int)
signal health_changed(current: float, max: float)
signal stats_changed

var status_items: Array[ItemData] = []

@export var stats: CharacterStats
@export var weapon_stats: WeaponStats

var base_stats: CharacterStats
var base_weapon_stats: WeaponStats
var current_stats: CharacterStats
var current_weapon_stats: WeaponStats

var health: float
var inventory: Array[ItemData] = []
var active_effects: Array[StringName] = []
var currency: int = 0
var keys: int = 0
var bombs: int = 0
var last_move_direction: Vector2 = Vector2.RIGHT
var invulnerable: bool = false
var dash_cooldown_remaining: float = 0.0
@export var item_pickup_lock_time: float = 1.0
var shoot_lock_remaining: float = 0.0
var is_dead: bool = false

const DAMAGE_TICK_RATE: float = 2.5

@onready var hurtbox: Area2D = %HurtBox

func _ready() -> void:
	died.connect(_on_died)
	if GameState.selected_character:
		apply_character(GameState.selected_character)
	else:
		_setup_stats()   # no character chosen (test scenes): use the Inspector's stats

func _setup_stats() -> void:
	base_stats = stats
	base_weapon_stats = weapon_stats
	current_stats = base_stats.duplicate()
	current_weapon_stats = base_weapon_stats.duplicate()
	inventory.clear()
	active_effects.clear()
	status_items.clear()

	# A starting value above a limit is clamped before the first pickup.
	current_stats.max_health = minf(current_stats.max_health, StatLimits.MAX_HEALTH)
	current_weapon_stats.fire_rate = maxf(current_weapon_stats.fire_rate, StatLimits.MIN_FIRE_INTERVAL)

	health = current_stats.max_health
	health_changed.emit(health, current_stats.max_health)
	stats_changed.emit()

func apply_character(def: CharacterDefinition) -> void:
	stats = def.stats
	weapon_stats = def.weapon_stats
	if def.body_frames:
		$Body.sprite_frames = def.body_frames
	if def.head_frames:
		$Head.sprite_frames = def.head_frames
	_setup_stats()
	for item in def.starting_items:
		add_item(item, true)

func add_item(item: ItemData, silent: bool = false) -> void:
	inventory.append(item)
	if item.special_effect != &"" and not active_effects.has(item.special_effect):
		active_effects.append(item.special_effect)
	_recalculate_stats()
	if not silent:
		shoot_lock_remaining = item_pickup_lock_time
		item_picked_up.emit(item)

func _on_died() -> void:
	GameState.end_run(false)

func _physics_process(delta: float) -> void:
	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)
	if shoot_lock_remaining > 0.0:
		shoot_lock_remaining = maxf(shoot_lock_remaining - delta, 0.0)
	_process_hurtbox_damage(delta)

func can_dash() -> bool:
	return dash_cooldown_remaining <= 0.0

func can_shoot() -> bool:
	return shoot_lock_remaining <= 0.0

func start_dash_cooldown() -> void:
	dash_cooldown_remaining = current_stats.dash_cooldown

func _process_hurtbox_damage(delta: float) -> void:
	var overlapping_enemies := hurtbox.get_overlapping_bodies().filter(
		func(b): return b.is_in_group("Enemies") and not b.get("is_frozen")
	)
	if overlapping_enemies.is_empty():
		return
	take_damage(DAMAGE_TICK_RATE * overlapping_enemies.size() * delta)

func take_damage(amount: float) -> void:
	if invulnerable or is_dead:
		return
	health -= amount
	health_changed.emit(health, current_stats.max_health)
	if health <= 0:
		is_dead = true
		died.emit()

func _recalculate_stats() -> void:
	var old_max := current_stats.max_health

	current_stats = base_stats.duplicate()
	current_weapon_stats = base_weapon_stats.duplicate()
	status_items.clear()

	# Pass 1: collect every item's modifiers. Flat bonuses add up, multipliers multiply together.
	var health_flat := 0.0
	var speed_flat := 0.0
	var speed_mult := 1.0
	var dash_flat := 0.0
	var luck_flat := 0.0
	var special_flat := 0.0
	var damage_flat := 0.0
	var damage_mult := 1.0
	var interval_flat := 0.0
	var interval_mult := 1.0
	var bullet_flat := 0.0
	var bullet_mult := 1.0
	var range_flat := 0.0

	for item in inventory:
		health_flat += item.max_health_add
		speed_flat += item.speed_add
		speed_mult *= item.speed_mult
		dash_flat += item.dash_distance_add
		luck_flat += item.luck_add
		special_flat += item.special_chance_add
		damage_flat += item.damage_add
		damage_mult *= item.damage_mult
		interval_flat += item.fire_rate_add
		interval_mult *= item.fire_rate_mult
		bullet_flat += item.bullet_speed_add
		bullet_mult *= item.bullet_speed_mult
		range_flat += item.shoot_range_add
		if item.status_effect != StatusEffect.Type.NONE:
			status_items.append(item)

	# Pass 2: base + all flat bonuses, then the multipliers on that whole total, then the limits.
	current_stats.max_health = minf(base_stats.max_health + health_flat, StatLimits.MAX_HEALTH)
	current_stats.speed = (base_stats.speed + speed_flat) * speed_mult
	current_stats.dash_distance = base_stats.dash_distance + dash_flat
	current_stats.luck = base_stats.luck + luck_flat
	current_stats.special_chance = base_stats.special_chance + special_flat

	current_weapon_stats.damage = (base_weapon_stats.damage + damage_flat) * damage_mult
	var interval := (base_weapon_stats.fire_rate + interval_flat) * interval_mult   # seconds between shots
	current_weapon_stats.fire_rate = maxf(interval, StatLimits.MIN_FIRE_INTERVAL)
	current_weapon_stats.bullet_speed = (base_weapon_stats.bullet_speed + bullet_flat) * bullet_mult
	current_weapon_stats.shoot_range = base_weapon_stats.shoot_range + range_flat

	# A health up heals by the gain, and a capped one gains nothing beyond the cap.
	health += current_stats.max_health - old_max
	health = minf(health, current_stats.max_health)
	health_changed.emit(health, current_stats.max_health)
	stats_changed.emit()

func roll_bullet_statuses() -> Dictionary:
	var result := {}
	for item in status_items:
		if randf() * 100.0 < item.status_chance:
			result[item.status_effect] = result.get(item.status_effect, 0) + item.status_stacks_per_hit
	return result

func add_pickup(pickup: PickupData) -> void:
	match pickup.type:
		PickupData.PickupType.COIN:
			currency += pickup.value
			currency_changed.emit(currency)
		PickupData.PickupType.KEY:
			keys += pickup.value
			keys_changed.emit(keys)
		PickupData.PickupType.BOMB:
			bombs += pickup.value
		PickupData.PickupType.HEART:
			health = min(health + pickup.value, current_stats.max_health)
			health_changed.emit(health, current_stats.max_health)
