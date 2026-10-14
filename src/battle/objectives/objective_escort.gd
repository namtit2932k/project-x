extends ObjectiveBase
class_name ObjectiveEscort
## NPC walks its own phase toward a target cell/zone. Reaches it: win. Dies: lose.

var _params: Dictionary

func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "escort"


func describe() -> String:
	return "Escort: the marked NPC must reach the destination tile alive."


func evaluate(state: BattleState) -> Dictionary:
	var npc_id := String(_params.get("npc_unit_id", ""))
	var target := target_cell()
	var npc: UnitState = state.units.get(npc_id, null)
	if npc == null or not npc.alive:
		return {"status": "lose", "progress": "Escort target defeated"}
	if npc.pos == target:
		return {"status": "win", "progress": "Escort target reached the destination"}
	return {"status": "ongoing", "progress": "at %s" % npc.pos}


func target_cell() -> Vector2i:
	return Vector2i(int(_params.get("target_cell_x", 0)), int(_params.get("target_cell_y", 0)))
