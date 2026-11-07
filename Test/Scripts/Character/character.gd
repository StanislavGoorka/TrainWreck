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
@onready var health_bar: Node2D = %HealthBar

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
	var old_max_health := current_stats.max_health if current_stats else base_stats.max_health

	current_stats = base_stats.duplicate()
	current_weapon_stats = base_weapon_stats.duplicate()

	for item in inventory:
		current_stats.max_health += item.max_health_add
		current_stats.speed = (current_stats.speed + item.speed_add) * item.speed_mult
		current_stats.dash_distance += item.dash_distance_add
		current_stats.luck += item.luck_add
		current_stats.special_chance += item.special_chance_add
		
		current_weapon_stats.damage = (current_weapon_stats.damage + item.damage_add) * item.damage_mult
		current_weapon_stats.fire_rate = (current_weapon_stats.fire_rate + item.fire_rate_add) * item.fire_rate_mult
		current_weapon_stats.bullet_speed = (current_weapon_stats.bullet_speed + item.bullet_speed_add) * item.bullet_speed_mult
		current_weapon_stats.shoot_range += item.shoot_range_add
		current_stats.dash_distance += item.dash_distance_add
		
	status_items.clear()
	for item in inventory:
		if item.status_effect != StatusEffect.Type.NONE:
			status_items.append(item)
		
	var health_gain := current_stats.max_health - old_max_health
	health += health_gain
	if health_bar:
		health_bar.max_value = current_stats.max_health
		health_bar.value = health
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
			if health_bar:
				health_bar.value = health
			health_changed.emit(health, current_stats.max_health)
