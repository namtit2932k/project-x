extends Resource
class_name WeaponData
## Weapon record (T2.2): might/accuracy/crit live here, keyed by stable id.
## Fake weapon numbers live in data only — combat code reads these fields, never hardcodes.
## action_category: "Combat" (melee/ranged attack) | "Heal" (staff; usable alone) | "None" (unarmed, cannot attack).
## attack_type: "Physical" (scales Str vs Def) | "Magic" (scales Mag vs Res). Empty for Heal weapons.
@export var id: String = ""
@export var display_name: String = ""
@export var action_category: String = "Combat"      # Combat | Heal | None
@export var attack_type: String = ""                # Physical | Magic ("" for Heal/None)
## Weapon range [min, max] measured from the acting unit's tile (validator: min <= max).
@export var weapon_range: Vector2i = Vector2i.ONE   # Vector2i(min, max)
@export var weapon_might: int = 5
@export var weapon_accuracy_mod: int = 0
@export var weapon_crit_mod: int = 0
## Heal weapons only: heal amount added to Mag, and heal range [min, max].
@export var heal_might: int = 0
@export var heal_range: Vector2i = Vector2i(1, 1)   # Vector2i(min, max)


func is_heal() -> bool:
	return action_category == "Heal"


func can_attack() -> bool:
	return action_category == "Combat"


func weapon_range_min() -> int:
	return int(weapon_range.x)


func weapon_range_max() -> int:
	return int(weapon_range.y)


func heal_range_min() -> int:
	return int(heal_range.x)


func heal_range_max() -> int:
	return int(heal_range.y)
