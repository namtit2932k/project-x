extends ObjectiveBase
class_name ObjectiveEscortTurns
## Escort variant on a turn budget (GDD-Map §5): the marked NPC just has to stay alive for
## the required number of enemy phases. Killing every enemy does NOT win by itself; the
## NPC dying loses immediately regardless of permadeath policy.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "escort_turns"


func describe() -> String:
	return "Escort (turns): keep %s alive through %s enemy phases." % [
		String(_params.get("npc_unit_id", "")), String(_params.get("turns_required", 0))]


func npc_id() -> String:
	return String(_params.get("npc_unit_id", ""))


func required_turns() -> int:
	return int(_params.get("turns_required", 1))


func evaluate(state: BattleState) -> Dictionary:
	var npc: UnitState = state.units.get(npc_id(), null)
	if npc == null or not npc.alive:
		return {"status": "lose", "progress": "Escort target defeated"}
	var held := int(state.objective_counters.get("escort_turns", 0))
	if held >= required_turns():
		return {"status": "win", "progress": "Survived %d enemy phases" % held}
	return {"status": "ongoing", "progress": "%d/%d enemy phases" % [held, required_turns()]}


## Enemy phase bookkeeping from the director.
func on_event(state: BattleState, event_type: String, _data: Dictionary) -> void:
	if event_type != "enemy_phase_ended":
		return
	var npc: UnitState = state.units.get(npc_id(), null)
	if npc == null or not npc.alive:
		return
	var held := int(state.objective_counters.get("escort_turns", 0))
	state.objective_counters["escort_turns"] = held + 1
