extends ObjectiveBase
class_name ObjectiveCapture
## Capture & hold (N09): player units must hold every zone. The streak advances at the
## end of the player phase and must still be held at the end of the enemy phase.
## contested_rule (default "enemy_presence"): an enemy standing inside a zone blocks the
## count and resets the streak; an unoccupied zone resets it as well. Only data params,
## so maps may declare several zones or tune the rule without code changes.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "capture"


func describe() -> String:
	return "Capture & hold: keep player units inside every marked zone %s consecutive turns." % [_params.get("turns_required", 1)]


## All required zones. "zones" [{x, y, w, h}] first; the single legacy zone_x/y/w/h still works.
func zones() -> Array:
	var out: Array = []
	var raw_zones: Array = _params.get("zones", [])
	for z in raw_zones:
		out.append(_rect_from(z))
	if out.is_empty():
		out.append(_rect_from(_params))
	return out


static func _rect_from(d: Dictionary) -> Rect2i:
	return Rect2i(
		int(d.get("x", d.get("zone_x", 0))),
		int(d.get("y", d.get("zone_y", 0))),
		int(d.get("w", d.get("zone_w", 1))),
		int(d.get("h", d.get("zone_h", 1))))


func evaluate(state: BattleState) -> Dictionary:
	var required := int(_params.get("turns_required", 1))
	var streak := int(state.objective_counters.get("capture_streak", 0))
	if streak >= required:
		return {"status": "win", "progress": "Held %d turns" % streak}
	return {"status": "ongoing", "progress": "%d/%d turns" % [streak, required]}


## Zone survey shared by both phase-end events: {all_held, contested}.
func _survey(state: BattleState) -> Dictionary:
	var contested := false
	for z in zones():
		var player_inside := false
		var enemy_inside := false
		for u in state.alive_units():
			if z.has_point(u.pos):
				if u.side == "player":
					player_inside = true
				else:
					enemy_inside = true
		if enemy_inside and String(_params.get("contested_rule", "enemy_presence")) == "enemy_presence":
			contested = true
		if not player_inside:
			contested = true
	return {"all_held": not contested, "contested": contested}


func on_event(state: BattleState, event_type: String, _data: Dictionary) -> void:
	if event_type != "player_phase_ended" and event_type != "enemy_phase_ended":
		return
	var streak := int(state.objective_counters.get("capture_streak", 0))
	var held := _survey(state)
	match event_type:
		"player_phase_ended":
			state.objective_counters["capture_streak"] = streak + 1 if held["all_held"] else 0
		"enemy_phase_ended":
			# Holding through the enemy phase is required (N09): the phase may run, enemies
			# may step in, or the player may be pushed or wiped out of the zone.
			state.objective_counters["capture_streak"] = streak if held["all_held"] else 0
