class_name UnitRoster
extends RefCounted
## Single source-of-truth store for player unit records (Story 001).
## Enemy/holdout records (lighter shape, no bond_pairs/life_status) are
## Story 002's scope — not held here.

## Four cardinal cells limit simultaneous adjacency links, not relationship count.
const MAX_CARDINAL_BOND_LINKS := 4
const MAX_ITEM_SLOTS := 1
const LIFE_STATUSES := ["Active", "Dead", "Incapacitated"]
const FACTIONS_OF_ORIGIN := ["Physical Empire", "Magic Kingdom"]

## unit_id -> { "unit_id", "display_name", "class", "faction_tag", "stats",
## "bond_pairs", "carried_items", "life_status" }
var unit_records: Dictionary = {}


## Adds a new player unit record. bond_pairs and carried_items start empty
## (present, never null). life_status starts "Active" — the Dead/
## Incapacitated transition itself is Story 003's scope.
## Returns false without mutating state on any invalid input.
func add_player_unit(unit_id: String, display_name: String, unit_class: String, faction_tag: String, stats: UnitStatBlock) -> bool:
	if unit_id.is_empty() or display_name.is_empty() or unit_class.is_empty():
		return false
	if faction_tag not in FACTIONS_OF_ORIGIN:
		return false
	if stats == null:
		return false
	if unit_records.has(unit_id):
		return false
	unit_records[unit_id] = {
		"unit_id": unit_id,
		"display_name": display_name,
		"class": unit_class,
		"faction_tag": faction_tag,
		"stats": stats,
		"bond_pairs": [],
		"carried_items": [],
		"life_status": "Active",
	}
	return true


## Returns a defensive copy of the unit's record, or an empty Dictionary if
## unit_id is unknown. bond_pairs/carried_items are duplicated so a caller
## mutating the returned record cannot corrupt roster state through it;
## "stats" stays the same live UnitStatBlock reference — Core Combat reads
## and writes it directly during battle and growth (ADR-0006).
func get_unit_record(unit_id: String) -> Dictionary:
	if not unit_records.has(unit_id):
		return {}
	var record: Dictionary = unit_records[unit_id].duplicate()
	record["bond_pairs"] = record["bond_pairs"].duplicate()
	record["carried_items"] = record["carried_items"].duplicate()
	return record


## Returns true if unit_id has a record in this roster.
func has_unit(unit_id: String) -> bool:
	return unit_records.has(unit_id)


## Subset of the roster with life_status == status. Used by active_units()
## and by downstream systems validating permadeath/deploy-eligibility counts.
## An unrecognized status is a caller bug, not roster data — logs and
## returns an empty result rather than matching nothing silently.
func unit_ids_with_status(status: String) -> Array[String]:
	if status not in LIFE_STATUSES:
		push_error("UnitRoster.unit_ids_with_status: unrecognized life_status '%s'" % status)
		return []
	var ids: Array[String] = []
	for unit_id in unit_records:
		if unit_records[unit_id]["life_status"] == status:
			ids.append(unit_id)
	return ids


## Calculated field consumed by Battle/Map (deploy-eligibility pool) and
## Story 004 (Deployment Legality) — subset of the roster with
## life_status == "Active".
func active_units() -> Array[String]:
	return unit_ids_with_status("Active")
