class_name CharacterDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var portrait: Texture2D

@export_group("Gameplay")
@export var stats: CharacterStats
@export var weapon_stats: WeaponStats
@export var starting_items: Array[ItemData] = []

@export_group("Visuals")
@export var body_frames: SpriteFrames      # leave empty to keep the scene's sprites
@export var head_frames: SpriteFrames

@export_group("Unlock")
@export var unlocked_by_default: bool = false
@export var unlock_cost: int = 0
