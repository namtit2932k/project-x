extends ObjectiveBase
class_name ObjectiveRetrieve
## F-OBJ Retrieve (GDD Core Rule 13): ending a move on the item's tile picks it up and ends that
## unit's action (MoveCommand); the carrier can only move (no attack, heal or counterattack).
## The living carrier entering the return area (`exit_zone_x/y/w/h`) wins; the carrier's death
## loses at once. Killing every enemy does not win.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "retrieve"


func item_id() -> String:
	return String(_params.get("item_id", ""))


func describe() -> String:
	return _t("Retrieve: grab the marked item and return to the exit zone. Carrier can only move.")


func exit_zone() -> Rect2i:
	return Rect2i(
		int(_params.get("exit_zone_x", 0)), int(_params.get("exit_zone_y", 0)),
		int(_params.get("exit_zone_w", 1)), int(_params.get("exit_zone_h", 1)))


func evaluate(state: BattleState) -> Dictionary:
	for u in state.units.values():
		if u.carried_item != item_id():
			continue
		if not u.alive:
			return {"status": "lose", "progress": "Carrier defeated"}
		if exit_zone().has_point(u.pos):
			return {"status": "win", "progress": "Item home"}
		return {"status": "ongoing", "progress": "carried by %s" % u.id}
	return {"status": "ongoing", "progress": "item still out"}


## Move-only restriction for the carrier (query hook used by the battle UI).
func get_constraints(unit: UnitState) -> Dictionary:
	if unit.carried_item == item_id():
		return {"move_only": true}
	return {}
