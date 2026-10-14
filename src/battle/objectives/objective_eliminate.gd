extends ObjectiveBase
class_name ObjectiveEliminate
## Win when all specified enemy targets are down (empty list = every enemy on the field).

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "eliminate"


func describe() -> String:
	return "Rout: defeat all enemies (or the marked targets)."


func evaluate(state: BattleState) -> Dictionary:
	var targets: Array = _params.get("target_unit_ids", [])
	if targets.is_empty():
		# Empty list = every enemy-side unit (player squad and npc actors never count).
		var dynamic: Array = []
		for u in state.units.values():
			if not u.alive or u.side != "enemy":
				continue
			dynamic.append(u.id)
		targets = dynamic
	for target_id: String in targets:
		var u: UnitState = state.units.get(target_id, null)
		if u != null and u.alive:
			return {"status": "ongoing", "progress": "%d foes left" % _alive_count(state, targets)}
	return {"status": "win", "progress": "All targets defeated"}


## (removed _player_faction_ids: control side lives on UnitState.side now)
static func _alive_count(state: BattleState, targets: Array) -> int:
	var n := 0
	for t in targets:
		var u: UnitState = state.units.get(String(t), null)
		if u != null and u.alive:
			n += 1
	return n
