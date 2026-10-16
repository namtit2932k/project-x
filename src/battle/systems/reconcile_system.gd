extends RefCounted
class_name ReconcileSystem
## Reconciliation is a battle-long side outcome, separate from map victory. Per-faction
## conditions come from FactionData (hidden kill threshold + required events). The outcome
## is stored so post-battle story can read it.

## Counts a kill against the faction the fallen unit belongs to (if that faction has reconcile rules).
static func record_kill(state: BattleState, slain: UnitState) -> void:
	if not state.reconcile_state.has(slain.faction_id):
		return
	state.reconcile_state[slain.faction_id]["kills"] = int(state.reconcile_state[slain.faction_id].get("kills", 0)) + 1
	EventBus.reconcile_state_changed.emit()


## Designer-configured event keys, e.g. "spared_unit_rebel_commander", "dialog_dlg_x".
static func record_event(state: BattleState, faction_id: String, event_key: String) -> void:
	if not state.reconcile_state.has(faction_id):
		return
	var events: Array = state.reconcile_state[faction_id]["events"]
	if event_key not in events:
		events.append(event_key)
		EventBus.reconcile_state_changed.emit()


## Spared remnant-faction enemies record their event key straight from UnitData (D03):
## no unit_id parsing, no per-faction mapping table. Units without a key record nothing.
static func record_spared_units(state: BattleState) -> void:
	for u in state.alive_units():
		if not state.reconcile_state.has(u.faction_id):
			continue
		if String(u.reconcile_event_key) != "":
			record_event(state, u.faction_id, String(u.reconcile_event_key))


## Final evaluation after map victory: threshold + required events. Recomputed from the
## same data every call (idempotent), always returning the same result schema:
## {faction_id: {persuaded: bool, kills: int, missing_events: Array[String]}}.
static func evaluate(state: BattleState) -> Dictionary:
	var outcomes := {}
	for faction_id in state.reconcile_state:
		var rs: Dictionary = state.reconcile_state[faction_id]
		var kills := int(rs.get("kills", 0))
		var f := DataRegistry.get_faction(String(faction_id))
		if f == null or f.reconcile.is_empty():
			outcomes[faction_id] = {"persuaded": false, "kills": kills, "missing_events": []}
			continue
		var cond: Dictionary = f.reconcile
		var threshold := int(cond.get("kill_threshold", 0))
		var ok := kills < threshold
		var missing: Array[String] = []
		for ev in cond.get("required_events", []):
			if String(ev) not in rs.get("events", []):
				ok = false
				missing.append(String(ev))
		outcomes[faction_id] = {"persuaded": ok, "kills": kills, "missing_events": missing}
		rs["persuaded"] = ok
		rs["evaluated"] = true
		rs["missing_events"] = missing
		rs["kills_threshold"] = threshold
	EventBus.reconcile_state_changed.emit()
	return outcomes


## UI hint (colour) without revealing the hidden threshold: safe/neutral/lost.
static func attitude(state: BattleState, faction_id: String) -> String:
	var rs: Dictionary = state.reconcile_state.get(faction_id, {})
	var f := DataRegistry.get_faction(String(faction_id))
	if f == null or f.reconcile.is_empty():
		return "neutral"
	var kills := int(rs.get("kills", 0))
	var threshold := int(f.reconcile.get("kill_threshold", 0))
	var missing: int = 0
	for ev in f.reconcile.get("required_events", []):
		if String(ev) not in rs.get("events", []):
			missing += 1
	if kills == 0 and missing == 0:
		return "safe"
	if kills >= threshold or (missing > 0 and kills > 0):
		return "lost"
	return "neutral"
