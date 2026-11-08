extends ObjectiveBase
class_name ObjectiveElimination
## F-OBJ Elimination (GDD Core Rule 6a): win when the listed targets (a boss) — or, with an
## empty list, every enemy-side unit — are down. No loss condition of its own.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "elimination"


func describe() -> String:
	return _t("Rout: defeat all enemies (or the marked targets).")


func evaluate(state: BattleState) -> Dictionary:
	var targets: Array = (_params.get("target_unit_ids", []) as Array).duplicate()
	if targets.is_empty():
		for u in state.units.values():
			if u.alive and u.side == "enemy":
				targets.append(u.id)
		if targets.is_empty():
			return {"status": "win", "progress": "All targets defeated"}
	var left := 0
	for target_id in targets:
		var u: UnitState = state.units.get(String(target_id), null)
		if u != null and u.alive:
			left += 1
	if left == 0:
		return {"status": "win", "progress": "All targets defeated"}
	return {"status": "ongoing", "progress": "%d foes left" % left}
