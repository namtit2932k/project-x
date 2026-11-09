extends ObjectiveBase
class_name ObjectiveSeize
## F-OBJ Seize (GDD Core Rule 14): at the end of every enemy phase, a living player unit on
## `control_x/y` adds 1 to the hold count; an empty or enemy-held point resets it to 0. Reaching
## `hold_enemy_phases` wins. Enemy occupation never loses by itself; killing every enemy does
## not win.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "seize"


func control_point() -> Vector2i:
	return Vector2i(int(_params.get("control_x", 0)), int(_params.get("control_y", 0)))


func required_phases() -> int:
	return int(_params.get("hold_enemy_phases", 1))


func describe() -> String:
	return _t("Seize: hold the marked point through %s consecutive enemy phases.") % [required_phases()]


func markers(state: BattleState) -> Array:
	return [{"kind": "point", "cell": control_point(), "text": "%d/%d" % [int(state.objective_counters.get("seize_hold", 0)), required_phases()]}]


func evaluate(state: BattleState) -> Dictionary:
	var held := int(state.objective_counters.get("seize_hold", 0))
	if held >= required_phases():
		return {"status": "win", "progress": "Held %d enemy phases" % held}
	return {"status": "ongoing", "progress": "%d/%d enemy phases" % [held, required_phases()]}


func on_event(state: BattleState, event_type: String, _data: Dictionary) -> void:
	if event_type != "enemy_phase_ended":
		return
	var occupant: UnitState = state.unit_at(control_point())
	var held := occupant != null and occupant.alive and occupant.side == "player"
	state.objective_counters["seize_hold"] = int(state.objective_counters.get("seize_hold", 0)) + 1 if held else 0
