extends ObjectiveBase
class_name ObjectiveCapture
## Occupy the zone with player units at the end of each player phase; consecutive turns
## tracked by the director's phase event. Enemies stepping in reset the streak.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "capture"


func describe() -> String:
	return "Capture & hold: keep player units inside the marked zone %s consecutive turns." % [_params.get("turns_required", 1)]


func zone() -> Rect2i:
	return Rect2i(
		int(_params.get("zone_x", 0)), int(_params.get("zone_y", 0)),
		int(_params.get("zone_w", 1)), int(_params.get("zone_h", 1)))


func evaluate(state: BattleState) -> Dictionary:
	var required := int(_params.get("turns_required", 1))
	var streak := int(state.objective_counters.get("capture_streak", 0))
	if streak >= required:
		return {"status": "win", "progress": "Held %d turns" % streak}
	return {"status": "ongoing", "progress": "%d/%d turns" % [streak, required]}


func on_event(state: BattleState, event_type: String, _data: Dictionary) -> void:
	if event_type != "player_phase_ended":
		return
	var z := zone()
	var occupied := false
	for u in state.alive_units():
		if z.has_point(u.pos) and u.faction_id in _player_sides(state):
			occupied = true
			break
	var streak := int(state.objective_counters.get("capture_streak", 0))
	state.objective_counters["capture_streak"] = streak + 1 if occupied else 0


static func _player_sides(state: BattleState) -> Array:
	var prot := state.protagonist()
	return [] if prot == null else [prot.faction_id]
