class_name ItemData
extends Resource

const POOL_ITEM_ROOM := 1
const POOL_BOSS := 2

const POOL_BIOME := 1

@export_group("Pools")
@export_flags("Item Room", "Boss", "Shop") var pools: int = POOL_ITEM_ROOM
@export_flags("General", "Fantasy") var biomes: int = POOL_BIOME

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var item_name: String
@export_multiline var description: String
@export var rarity: Rarity = Rarity.COMMON

@export_group("Icons")
@export var icon_sheet: Texture2D                      # 32x32 grid sheet (in-game pedestal preview)
@export var icon_sheet_ui: Texture2D                   # 16x16 grid sheet (equipment display)
@export var icon_grid_pos: Vector2i = Vector2i.ZERO    # column, row, shared by both sheets
@export var icon: Texture2D                            # optional manual override, used if no sheet is set

@export_group("Weapon — Flat")
@export var damage_add: float = 0.0
@export var fire_rate_add: float = 0.0       # negative = shoots faster
@export var bullet_speed_add: float = 0.0
@export var shoot_range_add: float = 0.0

@export_group("Weapon — Multipliers")
@export var damage_mult: float = 1.0
@export var fire_rate_mult: float = 1.0      # < 1.0 = faster
@export var bullet_speed_mult: float = 1.0

@export_group("Character — Flat")
@export var max_health_add: float = 0.0
@export var speed_add: float = 0.0
@export var dash_distance_add: float = 0.0
@export var luck_add: float = 0.0
@export var special_chance_add: float = 0.0

@export_group("Character — Multipliers")
@export var speed_mult: float = 1.0

@export_group("Status Effect")
@export var status_effect: StatusEffect.Type = StatusEffect.Type.NONE
@export_range(1, 10) var status_stacks_per_hit: int = 1
@export_range(0.0, 100.0, 0.5, "suffix:%") var status_chance: float = 100.0   # chance per shot

@export_group("Special")
@export var special_effect: StringName = &""   # e.g. &"fire_bullets" — empty = none

const ICON_CELL_SIZE := Vector2i(32, 32)
const ICON_UI_CELL_SIZE := Vector2i(16, 16)

func get_icon() -> Texture2D:
	return _slice(icon_sheet, ICON_CELL_SIZE, icon)

func get_icon_ui() -> Texture2D:
	return _slice(icon_sheet_ui, ICON_UI_CELL_SIZE, get_icon())

func _slice(sheet: Texture2D, cell_size: Vector2i, fallback: Texture2D) -> Texture2D:
	if not sheet:
		return fallback
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(icon_grid_pos * cell_size, cell_size)
	return atlas


const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [
	Color.WHITE, Color(0.4, 1.0, 0.4), Color(0.4, 0.6, 1.0),
	Color(0.75, 0.4, 1.0), Color(1.0, 0.7, 0.2),
]

func get_rarity_name() -> String:
	return RARITY_NAMES[rarity]

func get_rarity_color() -> Color:
	return RARITY_COLORS[rarity]

# Readable stat lines for the overview. Pass player.base_weapon_stats so the
# fire rate effect can be shown in shots per second.
func get_stat_lines(base_weapon: WeaponStats = null) -> Array[String]:
	var lines: Array[String] = []
	if max_health_add != 0.0:
		lines.append("%s Heart" % _signed(max_health_add / 2.0))   # 2 HP = 1 heart
	if speed_add != 0.0: lines.append("%s Speed" % _signed(speed_add))
	if speed_mult != 1.0: lines.append("Speed x%s" % String.num(speed_mult, 2))
	if dash_distance_add != 0.0: lines.append("%s Dash Distance" % _signed(dash_distance_add))
	if damage_add != 0.0: lines.append("%s Damage" % _signed(damage_add))
	if damage_mult != 1.0: lines.append("Damage x%s" % String.num(damage_mult, 2))
	if fire_rate_add != 0.0 or fire_rate_mult != 1.0:
		if base_weapon and base_weapon.fire_rate > 0.0:
			var new_interval := (base_weapon.fire_rate + fire_rate_add) * fire_rate_mult
			if new_interval <= 0.0:
				lines.append("Fire Rate MAX")
			else:
				lines.append("%s Fire Rate" % _signed(1.0 / new_interval - 1.0 / base_weapon.fire_rate))
		else:
			lines.append("Fire Rate changed")
	if bullet_speed_add != 0.0: lines.append("%s Bullet Speed" % _signed(bullet_speed_add))
	if bullet_speed_mult != 1.0: lines.append("Bullet Speed x%s" % String.num(bullet_speed_mult, 2))
	if shoot_range_add != 0.0: lines.append("%s Range" % _signed(shoot_range_add))
	if luck_add != 0.0: lines.append("%s Luck" % _signed(luck_add))
	if special_chance_add != 0.0: lines.append("%s%% Special Chance" % _signed(special_chance_add * 100.0))
	if status_effect != StatusEffect.Type.NONE:
		var chance_text := "" if status_chance >= 100.0 else "%s%% chance: " % String.num(status_chance, 1)
		lines.append("%sShots apply %s x%d" % [chance_text, StatusEffect.display_name(status_effect), status_stacks_per_hit])
	return lines

static func _signed(value: float) -> String:
	return ("+" if value > 0.0 else "") + String.num(value, 2)
