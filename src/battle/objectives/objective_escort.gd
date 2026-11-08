extends ObjectiveBase
class_name ObjectiveEscort
## F-OBJ Escort (GDD Core Rules 6d/6e, 10, 11). Two variants of one type:
## - destination (`target_cell_x/y`): the NPC walks toward the tile in the NPC phase (after the
##   enemies); reaching it wins, killing every enemy does not;
## - timed (`turns_required`): the NPC must live through N enemy phases — or every enemy is
##   defeated first, whichever comes first.
## The NPC's death loses at once in both variants.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "escort"


func npc_id() -> String:
	return String(_params.get("npc_unit_id", ""))


func is_destination() -> bool:
	return _params.has("target_cell_x")


func target_cell() -> Vector2i:
	return Vector2i(int(_params.get("target_cell_x", 0)), int(_params.get("target_cell_y", 0)))


func required_turns() -> int:
	return int(_params.get("turns_required", 1))


func describe() -> String:
	if is_destination():
		return _t("Escort: the marked NPC must reach the destination tile alive.")
	return _t("Escort (turns): keep %s alive through %s enemy phases.") % [npc_id(), required_turns()]


func evaluate(state: BattleState) -> Dictionary:
	var npc: UnitState = state.units.get(npc_id(), null)
	if npc == null or not npc.alive:
		return {"status": "lose", "progress": "Escort target defeated"}
	if is_destination():
		if npc.pos == target_cell():
			return {"status": "win", "progress": "Escort target reached the destination"}
		return {"status": "ongoing", "progress": "at %s" % npc.pos}
	var held := int(state.objective_counters.get("escort_turns", 0))
	if held >= required_turns():
		return {"status": "win", "progress": "Survived %d enemy phases" % held}
	if _enemies_left(state) == 0:
		return {"status": "win", "progress": "All enemies defeated"}
	return {"status": "ongoing", "progress": "%d/%d enemy phases" % [held, required_turns()]}


static func _enemies_left(state: BattleState) -> int:
	var n := 0
	for u in state.alive_units():
		if u.side == "enemy":
			n += 1
	return n


## Timed variant: one tick per completed enemy phase while the NPC lives.
func on_event(state: BattleState, event_type: String, _data: Dictionary) -> void:
	if is_destination() or event_type != "enemy_phase_ended":
		return
	var npc: UnitState = state.units.get(npc_id(), null)
	if npc != null and npc.alive:
		state.objective_counters["escort_turns"] = int(state.objective_counters.get("escort_turns", 0)) + 1
