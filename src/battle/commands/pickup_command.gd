extends RefCounted
class_name PickupCommand
## Picks up the item on the unit's tile. Retrieve objective then restricts the carrier
## to moving only (attack/skill blocked while carrying).

static func check(state: BattleState, unit: UnitState) -> String:
	if state.item_ground.has("%d,%d" % [unit.pos.x, unit.pos.y]):
		return ""
	return "No item on this tile."


static func apply(state: BattleState, unit: UnitState) -> bool:
	var key := "%d,%d" % [unit.pos.x, unit.pos.y]
	if not state.item_ground.has(key):
		return false
	unit.carried_item = String(state.item_ground[key])
	state.item_ground.erase(key)
	return true
