extends RefCounted
class_name BattleDirector
## Orchestrates one battle: applies confirmed commands (with snapshots first), advances
## phases, runs AI plans, evaluates objectives and the game-over rules. Pure RefCounted;
## the scene calls it and animates the results.

var state: BattleState
var rewind: SnapshotStack
var objectives: Array = []            # Array[ObjectiveBase]
var rewind_uses_left: int = 0
var rewind_budget: int = 0            # -1 = unlimited

## Battle phases are sides, not factions: a mixed Empire+Kingdom squad all act on "player".
var player_sides: Array = ["player"]


func setup(p_map: Resource, deploy: Dictionary, difficulty: String, seed_value: int = -1) -> void:
	state = BattleState.new()
	state.setup(p_map, deploy, seed_value)
	rewind = SnapshotStack.new()
	objectives.clear()
	for cfg in state.objectives_config:
		var obj := ObjectiveBase.create(cfg)
		if obj != null:
			objectives.append(obj)
	rewind_budget = SnapshotStack.budget_for_difficulty(difficulty)
	rewind_uses_left = rewind_budget
	player_sides = ["player"]


## Applies one player/AI command: the command's check() runs first (no snapshot and no
## mutation when invalid), then a snapshot is pushed before the apply.
func commit(kind: String, payload: Dictionary) -> bool:
	if not state.battle_over.is_empty():
		return false
	var err := _check(kind, payload)
	if err != "":
		return false
	push_snapshot(kind)
	var ok := _apply(kind, payload)
	if not ok:
		rewind.frames.pop_back()
		return false
	_on_state_changed()
	return true


func _check(kind: String, payload: Dictionary) -> String:
	if kind == "end_phase":
		return ""
	if not state.units.has(String(payload.get("unit_id", ""))):
		push_error("BattleDirector: unknown unit in %s payload" % kind)
		return "unknown unit"
	var unit: UnitState = state.units[String(payload["unit_id"])]
	match kind:
		"move":
			return MoveCommand.check(state, unit, payload["cell"])
		"attack":
			return AttackCommand.check(state, unit, String(payload["target_id"]))
		"pickup":
			return PickupCommand.check(state, unit)
		"skill":
			return SkillCommand.check(state, unit, String(payload["skill_id"]), state.units[String(payload["target_id"])])
		"wait":
			return WaitCommand.check(state, unit)
		"end_phase":
			return ""
		_:
			push_error("BattleDirector: unknown command kind %s" % kind)
			return "unknown kind"


func _apply(kind: String, payload: Dictionary) -> bool:
	match kind:
		"move":
			var unit: UnitState = state.units[String(payload["unit_id"])]
			return MoveCommand.apply(state, unit, payload["cell"])
		"attack":
			var unit2: UnitState = state.units[String(payload["unit_id"])]
			return not AttackCommand.apply(state, unit2, String(payload["target_id"])).is_empty()
		"pickup":
			var unit3: UnitState = state.units[String(payload["unit_id"])]
			return PickupCommand.apply(state, unit3)
		"skill":
			var unit4: UnitState = state.units[String(payload["unit_id"])]
			return SkillCommand.apply(state, unit4, String(payload["skill_id"]), state.units[String(payload["target_id"])])
		"wait":
			var unit5: UnitState = state.units[String(payload["unit_id"])]
			WaitCommand.apply(state, unit5)
			return true
		"end_phase":
			if state.phase == BattleState.PHASE_PLAYER:
				dispatch_objective_event("player_phase_ended")
			return _advance_phase()
		_:
			push_error("BattleDirector: unknown command kind %s" % kind)
			return false


## AI plays one unit's plan through the same director path (each action = snapshot).
func commit_ai_plan(plan: Dictionary) -> bool:
	if plan.is_empty():
		return false
	var unit: UnitState = state.units[String(plan["unit_id"])]
	var move_cell: Variant = plan.get("move_cell", Vector2i(-1, -1))
	var moved_ok := true
	if move_cell is Vector2i and move_cell != unit.pos:
		moved_ok = commit("move", {"unit_id": unit.id, "cell": move_cell})
	var target_id := String(plan.get("target_id", ""))
	if moved_ok and target_id != "" and state.units.has(target_id) and state.units[target_id].alive:
		if commit("attack", {"unit_id": unit.id, "target_id": target_id}):
			return true
		# Attack refused by check(): the move already happened, so end the action as Wait
		# instead of pressing on from a stale position.
		return commit("wait", {"unit_id": unit.id})
	return commit("wait", {"unit_id": unit.id})


## Ends the current player phase (the scene ends enemy/NPC phases via end_phase as well).
## Single place where objective plugins receive world events (N09/T10). Phase endings,
## unit events and future triggers all funnel through this helper.
func dispatch_objective_event(event_type: String, data: Dictionary = {}) -> void:
	for obj in objectives:
		obj.on_event(state, event_type, data)



func end_player_phase() -> bool:
	return commit("end_phase", {})


## AI tick: apply one ready enemy plan. Returns false when the enemy phase is over.
func run_next_enemy_plan() -> Dictionary:
	if state.phase != BattleState.PHASE_ENEMY:
		return {}
	for u in state.alive_units():
		if u.side == "player" or u.acted:
			continue
		var plan := EnemyAI.plan_unit(state, u, _enemy_target_sides())
		if not plan.is_empty():
			return plan
	return {}


## NPC phase: escort/evacuee actors walk toward their goal tile (NpcAI), never attacking.
func run_next_npc_plan() -> Dictionary:
	if state.phase != BattleState.PHASE_NPC:
		return {}
	var goals := _npc_goals()
	var unit: UnitState = null
	for u in state.alive_units():
		if state.npc_unit_ids.has(u.id) and not u.acted and goals.has(u.id):
			unit = u
			break
	if unit == null:
		return {}
	var plan := NpcAI.plan_walk(state, unit, goals[unit.id])
	return plan


## Active escort goals for NPC actors, straight from objective plugin params.
func _npc_goals() -> Dictionary:
	var out := {}
	for obj in objectives:
		if obj.identify() == "escort":
			var npc_id: String = String(obj._params.get("npc_unit_id", ""))
			if npc_id != "":
				out[npc_id] = obj.target_cell()
	return out


## Enemies attack whoever is not on their own side: the player squad and NPC actors.
func _enemy_target_sides() -> Array:
	return ["player", "npc"]


func clear_acted_flags() -> void:
	for u in state.units.values():
		u.acted = false
		u.moved = false


func push_snapshot(label: String) -> void:
	rewind.push(state, label)


## Rewinds to the frame chosen by the player; consumes one use if the budget is finite.
func use_rewind(frame_index: int) -> bool:
	if rewind_budget == 0 or not rewind.has_frames():
		return false
	if rewind_uses_left <= 0 and rewind_budget > 0:
		return false
	# Clear any previous result first so the restored position is re-evaluated fresh.
	state.battle_over = {}
	rewind.restore_to(state, frame_index)
	if rewind_budget > 0:
		rewind_uses_left -= 1
	_on_state_changed()
	return true


## Recomputes objectives + game-over rules after any state change.
func _on_state_changed() -> void:
	_check_deaths()
	emit_objectives()
	if state.battle_over.is_empty():
		_check_battle_end()
	if not state.battle_over.is_empty():
		var result: Dictionary = state.battle_over
		if result.get("status", "") == "win":
			ReconcileSystem.record_spared_units(state)
			result["reconcile"] = ReconcileSystem.evaluate(state)
		ResultStore.last_result = result


func _check_deaths() -> void:
	for u in state.units.values():
		if not u.alive and not u.death_recorded:
			u.death_recorded = true
			if state.reconcile_state.has(u.faction_id):
				ReconcileSystem.record_kill(state, u)
	# Any campaign-critical unit down = immediate loss (D02). The rule keeps its old key.
	if bool(DataRegistry.rule("protagonist_death_loses", true)):
		for critical in state.critical_units():
			if not critical.alive:
				state.battle_over = {"status": "lose", "reason": "critical_unit_down", "unit_id": critical.id}


func _check_battle_end() -> void:
	var win := false
	var lose := false
	for obj in objectives:
		var res: Dictionary = obj.evaluate(state)
		if res["status"] == "win":
			win = true
		elif res["status"] == "lose":
			lose = true
	var priority := String(state.map.result_priority) if state.map != null else "lose"
	var status := ""
	if win and lose:
		status = "win" if priority == "win" else "lose"
	elif win:
		status = "win"
	elif lose:
		status = "lose"
	if status != "":
		state.battle_over = {"status": status, "results": objective_results()}


func objective_results() -> Array:
	var out: Array = []
	for obj in objectives:
		var res: Dictionary = obj.evaluate(state)
		out.append({"id": obj.identify(), "progress": str(res.get("progress", "")), "status": str(res.get("status", "ongoing"))})
	return out


func emit_objectives() -> void:
	EventBus.objectives_changed.emit(objective_results())


func active_objectives_progress() -> Array:
	return objective_results()


func _advance_phase() -> bool:
	if state.phase == BattleState.PHASE_PLAYER:
		state.phase = BattleState.PHASE_ENEMY
	EventBus.phase_changed.emit(state.phase, state.turn)
	return true


func _emit_phase_event() -> void:
	dispatch_objective_event("player_phase_ended")


## Called by the scene when the enemy phase finishes: hands over to NPC phase or next turn.
## The enemy end of phase reaches the objectives first (N09: capture must judge holding
## through the enemy phase before the handover happens).
func advance_after_enemy_phase() -> void:
	dispatch_objective_event("enemy_phase_ended")
	state.phase = BattleState.PHASE_NPC
	EventBus.phase_changed.emit(state.phase, state.turn)


## Called by the scene when the NPC phase finishes: back to player, new turn.
func advance_to_player_phase() -> void:
	state.turn += 1
	state.phase = BattleState.PHASE_PLAYER
	clear_acted_flags()
	# Turn-start snapshot: rewinding right at the start of a player turn is always valid.
	push_snapshot("turn_start")
	EventBus.phase_changed.emit(state.phase, state.turn)
	EventBus.turn_started.emit(state.turn)
	emit_objectives()
