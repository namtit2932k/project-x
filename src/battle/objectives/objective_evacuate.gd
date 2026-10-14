extends ObjectiveBase
class_name ObjectiveEvacuate
## Evacuate (slide deck only; not in the coder PDF — flagged scope item): keep the marked NPCs
## alive for N turns (mode "survive_turns") or rout all foes (mode "clear_all"). NPC death loses.

var _params: Dictionary


func _init(params: Dictionary) -> void:
	_params = params


func identify() -> String:
	return "evacuate"


func describe() -> String:
	if String(_params.get("mode", "survive_turns")) == "clear_all":
		return "Evacuate: rout every foe while the marked NPCs live."
	return "Evacuate: keep the marked NPCs alive for %s turns." % [_params.get("turns_required", 1)]


func evaluate(state: BattleState) -> Dictionary:
	if _any_npc_dead(state):
		return {"status": "lose", "progress": "evacuee down"}
	var mode := String(_params.get("mode", "survive_turns"))
	if mode == "clear_all":
		if _foes_alive(state) == 0:
			return {"status": "win", "progress": "clear"}
		return {"status": "ongoing", "progress": "%d foes left" % _foes_alive(state)}
	var survived := int(state.objective_counters.get("evacuate_turns", 0))
	if survived >= int(_params.get("turns_required", 1)):
		return {"status": "win", "progress": "held %d turns" % survived}
	return {"status": "ongoing", "progress": "%d/%d turns" % [survived, int(_params.get("turns_required", 1))]}


func on_event(state: BattleState, event_type: String, _data: Dictionary) -> void:
	if event_type == "player_phase_ended":
		state.objective_counters["evacuate_turns"] = int(state.objective_counters.get("evacuate_turns", 0)) + 1


func _npc_ids(state: BattleState) -> Array:
	var ids: Array = _params.get("npc_ids", [])
	if ids.is_empty():
		ids = state.npc_unit_ids.duplicate()
	return ids


func _any_npc_dead(state: BattleState) -> bool:
	for npc_id: String in _npc_ids(state):
		var u: UnitState = state.units.get(npc_id, null)
		if u != null and not u.alive:
			return true
	return false


func _foes_alive(state: BattleState) -> int:
	var npc_ids := _npc_ids(state)
	var n := 0
	for u in state.alive_units():
		if u.side == "player" or u.id in npc_ids:
			continue
		n += 1
	return n

