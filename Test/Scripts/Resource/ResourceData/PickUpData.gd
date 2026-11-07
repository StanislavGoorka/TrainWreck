class_name PickupData
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE }
enum PickupType { COIN, KEY, HEART, BOMB }

@export var pickup_name: String
@export var icon: Texture2D
@export var type: PickupType
@export var rarity: Rarity = Rarity.COMMON
@export var value: int = 1   # e.g. 1 coin, 1 key, 1 heart of healing

@export var base_weight: float = 10.0   # higher = more common before luck is applied
