extends ObjectiveBase
class_name ObjectiveRetrieve
## A unit picks up the marked item and returns to the exit zone. While carried, the carrier
## may only move (attack/skill blocked by get_constraints()).

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "retrieve"


func describe() -> String:
	return "Retrieve: grab the marked item and return to the exit zone. Carrier can only move."


func exit_zone() -> Rect2i:
	return Rect2i(
		int(_params.get("exit_zone_x", 0)), int(_params.get("exit_zone_y", 0)),
		int(_params.get("exit_zone_w", 1)), int(_params.get("exit_zone_h", 1)))


func evaluate(state: BattleState) -> Dictionary:
	for u in state.alive_units():
		if u.carried_item == String(_params.get("item_id", "")) and exit_zone().has_point(u.pos):
			return {"status": "win", "progress": "Item home"}
	return {"status": "ongoing", "progress": "item still out"}


## Move-only restriction for the carrier (query hook used by the director/UI).
func get_constraints(unit: UnitState) -> Dictionary:
	if unit.carried_item == String(_params.get("item_id", "")):
		return {"move_only": true}
	return {}


func on_event(state: BattleState, event_type: String, data: Dictionary) -> void:
	# Carrier defeated: the item returns to the ground at its death tile (command handles it).
	if event_type == "unit_died":
		var u: UnitState = state.units.get(String(data.get("unit_id", "")))
		if u != null and u.carried_item != "":
			state.item_ground["%d,%d" % [u.pos.x, u.pos.y]] = u.carried_item
			u.carried_item = ""
