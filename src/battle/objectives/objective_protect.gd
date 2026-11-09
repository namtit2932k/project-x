extends ObjectiveBase
class_name ObjectiveProtect
## F-OBJ Protect (GDD Core Rules 6b/6c, 12). Two variants of one type:
## - unit: `unit_id` must survive `survive_enemy_phases` enemy phases (its death loses at once);
## - zone: `zone_x/y/w/h` must stay free of enemies for `survive_enemy_phases` enemy phases (any
##   enemy inside the zone loses at once; killing every enemy does not end it early).

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "protect"


func is_zone() -> bool:
	return String(_params.get("unit_id", "")) == ""


func zone() -> Rect2i:
	return Rect2i(int(_params.get("zone_x", 0)), int(_params.get("zone_y", 0)),
			int(_params.get("zone_w", 1)), int(_params.get("zone_h", 1)))


func required_phases() -> int:
	return int(_params.get("survive_enemy_phases", 1))


func describe() -> String:
	if is_zone():
		return _t("Protect: keep every enemy out of the marked zone for %s enemy phases.") % [required_phases()]
	return _t("Protect: keep %s alive for %s enemy phases.") % [String(_params.get("unit_id", "")), required_phases()]


func markers(state: BattleState) -> Array:
	var progress := "%d/%d" % [int(state.objective_counters.get("protect_phases", 0)), required_phases()]
	if is_zone():
		return [{"kind": "zone", "rect": zone(), "text": "P " + progress}]
	return [{"kind": "unit", "unit_id": String(_params.get("unit_id", "")), "text": progress}]


func evaluate(state: BattleState) -> Dictionary:
	if _lost(state):
		return {"status": "lose", "progress": "Zone breached" if is_zone() else "Protect target defeated"}
	var held := int(state.objective_counters.get("protect_phases", 0))
	if held >= required_phases():
		return {"status": "win", "progress": "Held %d enemy phases" % held}
	return {"status": "ongoing", "progress": "%d/%d enemy phases" % [held, required_phases()]}


func _lost(state: BattleState) -> bool:
	if not is_zone():
		var target: UnitState = state.units.get(String(_params.get("unit_id", "")), null)
		return target == null or not target.alive
	var z := zone()
	for u in state.alive_units():
		if u.side == "enemy" and z.has_point(u.pos):
			return true
	return false


## Counts each completed enemy phase while the objective still stands.
func on_event(state: BattleState, event_type: String, _data: Dictionary) -> void:
	if event_type == "enemy_phase_ended" and not _lost(state):
		state.objective_counters["protect_phases"] = int(state.objective_counters.get("protect_phases", 0)) + 1
