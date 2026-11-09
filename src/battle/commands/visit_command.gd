extends RefCounted
class_name VisitCommand
## F-ITEM Visit (GDD Core Rule 3 Visit, Battle/Map Core Rule 15): a squad unit standing on an
## open village claims its one reward - gold, an item (needs a free slot, D-B8) or just the
## visit - the tile turns inert, and the unit's action is spent.


static func check(state: BattleState, unit: UnitState) -> String:
	if not state.units.has(unit.id) or not unit.alive or unit.acted:
		return "Unit unavailable or already acted."
	if unit.side != "player":
		return "Only the squad visits villages."
	if state.is_move_only_carrier(unit):
		return "Carrier may only move."
	var v := state.open_village_at(unit.pos)
	if v.is_empty():
		return "No open village here."
	if String(v.get("item_id", "")) != "" and unit.items.size() >= int(DataRegistry.rule("max_item_slots", 2)):
		return "No free item slot."
	return ""


static func apply(state: BattleState, unit: UnitState) -> bool:
	var v := state.open_village_at(unit.pos)
	if v.is_empty():
		return false
	state.gold_earned += int(v.get("gold", 0))
	if String(v.get("item_id", "")) != "":
		unit.items.append(String(v["item_id"]))
	v["state"] = "claimed"
	unit.acted = true
	return true
