class_name WeaponItem
extends RefCounted
## Weapon/Item System — weapon + item catalogs (ADR-0003), F-WS1/F-WS2
## load-time validation (ADR-0004), and the class → assigned_weapon_id
## assignment table (Core Rule 3). Plain instantiable class, not an
## autoload — same DI convention as BattleMap/UnitRoster/CoreCombat.

const WEAPON_CATALOG_PATH := "res://data/weapons.json"
const ITEM_CATALOG_PATH := "res://data/items.json"
const CLASS_WEAPONS_PATH := "res://data/class_weapons.json"
const ATTACK_TYPES := ["Physical", "Magic"]

var weapon_catalog: Dictionary = {}   # weapon_id -> record Dictionary
var item_catalog: Dictionary = {}     # item_id -> record Dictionary
var class_weapons: Dictionary = {}    # class name -> weapon_id


## ADR-0003 pattern — ids checked, invalid/duplicate records fatal.
func load_weapon_catalog(path: String = WEAPON_CATALOG_PATH) -> bool:
	var context := "Weapon/Item: weapon catalog"
	var records: Variant = CatalogLoader.read_array(path, context)
	if records == null:
		return false
	var seen: Dictionary = {}
	for record in records:
		if not record is Dictionary:
			Validate.fatal(context, "each record must be an object")
			return false
		if not weapon_record_valid(record):
			Validate.fatal(context, "invalid weapon record: %s" % record.get("weapon_id", "<missing id>"))
			return false
		var id: String = record.get("weapon_id", "")
		Validate.require_unique(id, seen, context)
		if seen.has(id):
			return false
		seen[id] = true
		weapon_catalog[id] = _normalized_weapon_record(record)
	return true


## ADR-0003 pattern, F-WS2 validation.
func load_item_catalog(path: String = ITEM_CATALOG_PATH) -> bool:
	var context := "Weapon/Item: item catalog"
	var records: Variant = CatalogLoader.read_array(path, context)
	if records == null:
		return false
	var seen: Dictionary = {}
	for record in records:
		if not record is Dictionary:
			Validate.fatal(context, "each record must be an object")
			return false
		if not item_record_valid(record):
			Validate.fatal(context, "invalid item record: %s" % record.get("item_id", "<missing id>"))
			return false
		var id: String = record.get("item_id", "")
		Validate.require_unique(id, seen, context)
		if seen.has(id):
			return false
		seen[id] = true
		var normalized: Dictionary = record.duplicate()
		normalized["item_heal_value"] = int(normalized["item_heal_value"])
		item_catalog[id] = normalized
	return true


## Core Rule 3 — class_weapons.json is a flat Object (ADR-0017 shape: no
## second field to justify ADR-0003's array-of-records), class name -> weapon_id.
## AC-WS12/AC-WS13 — every class must have an assignment, and it must resolve
## to a real catalog entry; both are fatal, not silently dropped.
func load_class_weapons(path: String = CLASS_WEAPONS_PATH) -> bool:
	var context := "Weapon/Item: class weapon assignment"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Validate.fatal(context, "cannot open %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		Validate.fatal(context, "root must be an object")
		return false
	for class_name_key in parsed:
		var weapon_id: String = str(parsed[class_name_key])
		if get_weapon_record(weapon_id).is_empty():
			Validate.fatal(context, "class '%s' assigned_weapon_id '%s' has no catalog entry" % [class_name_key, weapon_id])
			return false
		class_weapons[class_name_key] = weapon_id
	return true


func get_weapon_record(weapon_id: String) -> Dictionary:
	return weapon_catalog.get(weapon_id, {})


func get_item_record(item_id: String) -> Dictionary:
	return item_catalog.get(item_id, {})


## Core Rule 4 — "class → assigned_weapon_id → weapon record" resolution.
## Empty Dictionary if the class has no assignment (AC-WS12).
func weapon_record_for_class(class_name_value: String) -> Dictionary:
	if not class_weapons.has(class_name_value):
		return {}
	return get_weapon_record(class_weapons[class_name_value])


## F-WS1 — pure predicate, testable without routing through Validate.fatal().
func weapon_record_valid(w: Dictionary) -> bool:
	if not w.has("weapon_id") or not w.has("name") or not w.has("action_category"):
		return false
	var category: Variant = w["action_category"]
	if category == "Combat":
		return _in_range(w.get("weapon_might"), 0, 20) \
			and _in_range(w.get("weapon_accuracy_mod"), -15, 15) \
			and _in_range(w.get("weapon_crit_mod"), 0, 30) \
			and _valid_range_pair(w.get("weapon_range"), 1, 3) \
			and ATTACK_TYPES.has(w.get("attack_type"))
	if category == "Heal":
		return _in_range(w.get("heal_might"), 5, 15) \
			and _valid_range_pair(w.get("heal_range"), 0, 3)
	return false


## F-WS2 — pure predicate.
func item_record_valid(i: Dictionary) -> bool:
	if not i.has("item_id") or not i.has("name"):
		return false
	return _in_range(i.get("item_heal_value"), 10, 30)


func _in_range(value: Variant, min_v: int, max_v: int) -> bool:
	return (value is int or value is float) and value >= min_v and value <= max_v


func _valid_range_pair(range_pair: Variant, min_bound: int, max_bound: int) -> bool:
	if not range_pair is Array or range_pair.size() != 2:
		return false
	var lo: Variant = range_pair[0]
	var hi: Variant = range_pair[1]
	return _in_range(lo, min_bound, max_bound) and _in_range(hi, min_bound, max_bound) and lo <= hi


## JSON.parse_string() returns every number as float — normalize int-typed
## fields so CoreCombat's formulas get real ints, not JSON's float-by-default
## representation. weapon_range/heal_range elements are normalized too.
func _normalized_weapon_record(record: Dictionary) -> Dictionary:
	var normalized: Dictionary = record.duplicate(true)
	for field in ["weapon_might", "weapon_accuracy_mod", "weapon_crit_mod", "heal_might"]:
		if normalized.has(field):
			normalized[field] = int(normalized[field])
	for field in ["weapon_range", "heal_range"]:
		if normalized.has(field):
			var pair: Array = normalized[field]
			normalized[field] = [int(pair[0]), int(pair[1])]
	return normalized
