## Builders for test fixtures.
##
## Fixtures are assembled in code so tests do not depend on how game scenes are laid
## out. Textures are PlaceholderTexture2D instances: no asset file is ever opened.
extends RefCounted

const RecordingState := preload("res://tests/helpers/recording_state.gd")

const PLAYER_ANIMATIONS: Array[StringName] = [&"Idle", &"NewRun", &"Dash"]
const ENEMY_ANIMATIONS: Array[StringName] = [&"idle", &"run", &"attack", &"Fly"]


# --- Resources ---------------------------------------------------------------------

static func character_stats(max_health := 10.0, speed := 300.0, dash_distance := 300.0,
		luck := 1.0, special_chance := 0.0) -> CharacterStats:
	var stats := CharacterStats.new()
	stats.max_health = max_health
	stats.speed = speed
	stats.dash_distance = dash_distance
	stats.luck = luck
	stats.special_chance = special_chance
	return stats


static func weapon_stats(damage := 1.0, fire_rate := 1.0, bullet_speed := 800.0,
		shoot_range := 600.0) -> WeaponStats:
	var stats := WeaponStats.new()
	stats.damage = damage
	stats.fire_rate = fire_rate
	stats.bullet_speed = bullet_speed
	stats.shoot_range = shoot_range
	return stats


static func enemy_stats(max_health := 10.0, speed := 100.0, damage := 1.0,
		attack_cooldown := 0.5, immunities := 0) -> EnemyStats:
	var stats := EnemyStats.new()
	stats.max_health = max_health
	stats.speed = speed
	stats.damage = damage
	stats.attack_cooldown = attack_cooldown
	stats.status_immunities = immunities
	return stats


static func spin_boss_stats(properties := {}) -> SpinBossStats:
	var stats := SpinBossStats.new()
	stats.max_health = 40.0
	stats.speed = 200.0
	for key: String in properties:
		stats.set(key, properties[key])
	return stats


## Creates an ItemData and assigns every entry of [param properties] to it.
static func item(properties := {}) -> ItemData:
	var data := ItemData.new()
	for key: String in properties:
		data.set(key, properties[key])
	return data


static func pickup(type: PickupData.PickupType, value := 1) -> PickupData:
	var data := PickupData.new()
	data.type = type
	data.value = value
	return data


static func character_definition(id: String, properties := {}) -> CharacterDefinition:
	var def := CharacterDefinition.new()
	def.id = id
	def.display_name = id.capitalize()
	def.stats = character_stats()
	def.weapon_stats = weapon_stats()
	for key: String in properties:
		def.set(key, properties[key])
	return def


static func texture(size := Vector2(64, 64)) -> Texture2D:
	var tex := PlaceholderTexture2D.new()
	tex.size = size
	return tex


## SpriteFrames with the given (empty or placeholder-filled) animations.
static func sprite_frames(animations: Array, frame_count := 0, loop := true, fps := 30.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for anim_name in animations:
		if not frames.has_animation(anim_name):
			frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, fps)
		for i in frame_count:
			frames.add_frame(anim_name, texture(Vector2(8, 8)))
	return frames


# --- Nodes -------------------------------------------------------------------------

static func circle_shape(radius := 16.0) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	return shape


static func area(area_name: String, layer: int, mask: int, radius := 32.0) -> Area2D:
	var result := Area2D.new()
	result.name = area_name
	result.collision_layer = layer
	result.collision_mask = mask
	result.add_child(circle_shape(radius))
	return result


static func animated_sprite(sprite_name: String, animations: Array) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = sprite_name
	# play() ignores animations without frames, so each one gets a placeholder frame.
	sprite.sprite_frames = sprite_frames(animations, 1)
	return sprite


static func _make_unique(owner_node: Node, child: Node) -> void:
	owner_node.add_child(child)
	child.owner = owner_node
	child.unique_name_in_owner = true


## A Player with every node character.gd and the player states need (Body, Head,
## %HurtBox). Not added to the tree.
static func player(stats: CharacterStats = null, weapon: WeaponStats = null) -> Player:
	var result := Player.new()
	result.name = "TestPlayer"
	result.stats = stats if stats else character_stats()
	result.weapon_stats = weapon if weapon else weapon_stats()
	result.collision_layer = 2   # "player"
	result.collision_mask = 1    # "walls"
	result.add_to_group("Players")
	result.add_child(circle_shape(12.0))
	result.add_child(animated_sprite("Body", PLAYER_ANIMATIONS))
	result.add_child(animated_sprite("Head", PLAYER_ANIMATIONS))
	_make_unique(result, area("HurtBox", 2, 4 | 16, 16.0))   # same layers as character_1.tscn
	return result


## An Enemy with an AnimatedSprite2D, an AttackHitbox and a StateMachine.
## [param states] maps state names to scripts; by default it holds recording
## "Idle" and "Dead" states. Not added to the tree.
static func enemy(stats: EnemyStats = null, states := {}, enemy_script: GDScript = null) -> Enemy:
	var result: Enemy = enemy_script.new() if enemy_script else Enemy.new()
	result.name = "TestEnemy"
	result.stats = stats if stats else enemy_stats()
	result.collision_layer = 4   # "enemies"
	result.collision_mask = 1
	result.add_to_group("Enemies")
	result.add_child(circle_shape(12.0))
	result.add_child(animated_sprite("AnimatedSprite2D", ENEMY_ANIMATIONS))
	result.add_child(area("AttackHitbox", 0, 2, 40.0))
	var machine := StateMachine.new()
	machine.name = "StateMachine"
	result.add_child(machine)
	if states.is_empty():
		states = {"Idle": RecordingState, "Dead": RecordingState}
	for state_name: String in states:
		var state: State = (states[state_name] as GDScript).new()
		state.name = state_name
		machine.add_child(state)
	return result
