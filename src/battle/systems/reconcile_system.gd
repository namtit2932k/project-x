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


## F-PS1 effective_kill_count: kills committed by earlier victories + this battle's kills.
static func effective_kills(state: BattleState, faction_id: String) -> int:
	var rs: Dictionary = state.reconcile_state.get(faction_id, {})
	return int(rs.get("prior_kills", 0)) + int(rs.get("kills", 0))


## F-PCOND: the faction's persuasion condition for this map - the map's override
## (MapData.faction.persuasion_condition for its faction) or the faction's own; {} = none.
static func condition_for(state: BattleState, faction_id: String) -> Dictionary:
	if state.map != null and "faction" in state.map:
		var mf: Dictionary = state.map.faction
		if String(mf.get("faction_id", "")) == faction_id and mf.get("persuasion_condition", {}) is Dictionary and not (mf.get("persuasion_condition", {}) as Dictionary).is_empty():
			return mf["persuasion_condition"]
	var f := DataRegistry.get_faction(faction_id)
	if f == null:
		return {}
	var cond: Variant = f.reconcile.get("persuasion_condition", {})
	return cond if cond is Dictionary else {}


## F-PS2 condition_eval, read live: named_unit_alive (every placed copy alive) or
## units_spared_pct (living / deployed at battle start >= threshold). No condition = true.
static func condition_met(state: BattleState, faction_id: String) -> bool:
	var cond := condition_for(state, faction_id)
	match String(cond.get("type", "")):
		"named_unit_alive":
			var unit_id := String(cond.get("unit_id", ""))
			var found := false
			for u in state.units.values():
				if u.id == unit_id or u.template_id == unit_id:
					found = true
					if not u.alive:
						return false
			return found
		"units_spared_pct":
			var deployed := int(state.reconcile_state.get(faction_id, {}).get("deployed", 0))
			if deployed <= 0:
				return false
			var living := 0
			for u in state.units.values():
				if u.faction_id == faction_id and u.alive:
					living += 1
			return float(living) / float(deployed) >= float(cond.get("threshold", 1.0))
	return true


## Final evaluation after map victory (F-PS2): kill gate + persuasion condition (+ any legacy
## required events). Recomputed from the same data every call (idempotent), always returning
## the same schema: {faction_id: {persuaded, kills, condition_met, missing_events}}.
static func evaluate(state: BattleState) -> Dictionary:
	var outcomes := {}
	for faction_id in state.reconcile_state:
		var rs: Dictionary = state.reconcile_state[faction_id]
		var kills := int(rs.get("kills", 0))
		var f := DataRegistry.get_faction(String(faction_id))
		if f == null or f.reconcile.is_empty():
			outcomes[faction_id] = {"persuaded": false, "kills": kills, "condition_met": false, "missing_events": []}
			continue
		var cond: Dictionary = f.reconcile
		var threshold := int(cond.get("kill_threshold", 0))
		var met := condition_met(state, String(faction_id))
		var ok := effective_kills(state, String(faction_id)) < threshold and met
		var missing: Array[String] = []
		for ev in cond.get("required_events", []):
			if String(ev) not in rs.get("events", []):
				ok = false
				missing.append(String(ev))
		outcomes[faction_id] = {"persuaded": ok, "kills": kills, "condition_met": met, "missing_events": missing}
		rs["persuaded"] = ok
		rs["evaluated"] = true
		rs["missing_events"] = missing
		rs["kills_threshold"] = threshold
	EventBus.reconcile_state_changed.emit()
	return outcomes


## F-PS4: the one kill value the HUD may read, 0.0-1.0. 1.0 exactly when kills reach the
## threshold (the same test evaluate() uses), and always 1.0 for a threshold of 0.
## Counts earlier victories' kills too (effective_kills).
static func kill_pressure_ratio(state: BattleState, faction_id: String) -> float:
	var f := DataRegistry.get_faction(faction_id)
	var threshold := int(f.reconcile.get("kill_threshold", 0)) if f != null else 0
	if threshold <= 0:
		return 1.0
	return clampf(float(effective_kills(state, faction_id)) / float(threshold), 0.0, 1.0)


## F-BAD: remnant factions whose pressure bar is red (ratio 1.0) - a victory with any of
## them ends in the bad ending.
static func unpersuadable_factions(state: BattleState) -> Array[String]:
	var out: Array[String] = []
	for faction_id in state.reconcile_state:
		if kill_pressure_ratio(state, String(faction_id)) >= 1.0:
			out.append(String(faction_id))
	return out


## Attitude used for the feedback dialogues (FactionData.feedback): safe/neutral/lost.
static func attitude(state: BattleState, faction_id: String) -> String:
	var rs: Dictionary = state.reconcile_state.get(faction_id, {})
	var f := DataRegistry.get_faction(String(faction_id))
	if f == null or f.reconcile.is_empty():
		return "neutral"
	var kills := effective_kills(state, String(faction_id))
	var threshold := int(f.reconcile.get("kill_threshold", 0))
	# F-PCOND: the live persuasion condition counts as one "missing" item while it fails.
	var missing: int = 0 if condition_met(state, String(faction_id)) else 1
	for ev in f.reconcile.get("required_events", []):
		if String(ev) not in rs.get("events", []):
			missing += 1
	if kills == 0 and missing == 0:
		return "safe"
	if kills >= threshold or (missing > 0 and kills > 0):
		return "lost"
	return "neutral"
