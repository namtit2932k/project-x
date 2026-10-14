extends ObjectiveBase
class_name ObjectiveDefend
## Keep the zone for N player turns. Policy "block": an enemy entering = lose at once.
## Policy "survive": just survive the required turns.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "defend"


func describe() -> String:
	return "Defend: hold the marked zone for %s turns." % [_params.get("turns_required", 0)]


func zone() -> Rect2i:
	return Rect2i(
		int(_params.get("zone_x", 0)), int(_params.get("zone_y", 0)),
		int(_params.get("zone_w", 1)), int(_params.get("zone_h", 1)))


func evaluate(state: BattleState) -> Dictionary:
	var required := int(_params.get("turns_required", 1))
	var held := int(state.objective_counters.get("defend_turns", 0))
	var policy := String(_params.get("policy", "block"))
	var z := zone()
	if policy == "block":
		for u in state.alive_units():
			if u.side == "player":
				continue
			if z.has_point(u.pos):
				return {"status": "lose", "progress": "Zone breached"}
	if held >= required:
		return {"status": "win", "progress": "Zone held %d turns" % held}
	return {"status": "ongoing", "progress": "%d/%d turns" % [held, required]}



## Turn bookkeeping event from the director.
func on_event(state: BattleState, event_type: String, _data: Dictionary) -> void:
	if event_type == "player_phase_ended":
		var held := int(state.objective_counters.get("defend_turns", 0))
		state.objective_counters["defend_turns"] = held + 1
