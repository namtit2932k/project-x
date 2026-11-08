extends RefCounted
class_name ProtectPersuadeAI
## F-AI Protect/Persuade AI (GDD protect-persuade-ai-system.md Core Rules 1-10, F-PPA1-5).
## A governed holdout-faction unit picks one state per Enemy Phase - Protect Key Unit,
## Flee, Cornered, Rally or Hold (first match wins) - and, outside Protect Key Unit, never
## kills with its strikes (Restraint Rule, applied in CombatResolver through restrained()).


## Core Rule 1: ai_profile ProtectPersuade AND its faction is a tracked holdout faction that
## is still Engaged (pressure below red). Otherwise the unit falls back to StandardAggressive.
static func is_governed(state: BattleState, unit: UnitState) -> bool:
	if unit.ai_profile != "ProtectPersuade" or not unit.alive:
		return false
	if not state.reconcile_state.has(unit.faction_id):
		return false
	return ReconcileSystem.kill_pressure_ratio(state, unit.faction_id) < 1.0


## F-PPA5: does this unit's strike stop at 1 HP? Every state except Protect Key Unit, when the
## difficulty keeps the rule on (off on Nightmare).
static func restrained(state: BattleState, unit: UnitState) -> bool:
	if not is_governed(state, unit) or unit.ai_context == "protect":
		return false
	return bool(DataRegistry.rule("restraint_rule_active_by_difficulty", {}).get(state.difficulty, true))


static func plan(state: BattleState, unit: UnitState, target_sides: Array) -> Dictionary:
	var stands := EnemyAI.standing_cells(state, unit)
	var key := key_unit(state, unit)
	var threats := player_threats(state)
	var threat_all := {}
	for p_id in threats:
		threat_all.merge(threats[p_id])
	# 1. Protect Key Unit.
	var threshold := float(DataRegistry.rule("protect_hp_threshold", 0.3))
	if key != null and key.id != unit.id and float(key.hp) <= threshold * float(key.max_hp) and threat_all.has(key.pos):
		var adjacent: Array = []
		for cell in stands:
			if RangeHandler.manhattan(cell, key.pos) == 1:
				adjacent.append(cell)
		if not adjacent.is_empty():
			var threatening := _threatening(state, threats, key.pos)
			var nearest_threat := EnemyAI.nearest_unit(key.pos, threatening)
			var block := EnemyAI.nearest_cell(adjacent, nearest_threat.pos)
			var target := nearest_threat.id if not EnemyAI.cells_in_range(unit, [block], nearest_threat.pos).is_empty() \
					else EnemyAI.target_in_range_from(state, unit, block, target_sides)
			return _plan(unit, block, target, "protect")
	# 2. Threatened -> Flee or Cornered.
	if threat_all.has(unit.pos):
		var safe: Array = []
		for cell in stands:
			if not threat_all.has(cell):
				safe.append(cell)
		if safe.is_empty():
			return _plan(unit, unit.pos, "", "cornered")
		var threatening2 := _threatening(state, threats, unit.pos)
		var dest := _flee_cell(state, unit, safe, threatening2, key)
		return _plan(unit, dest, EnemyAI.target_in_range_from(state, unit, dest, target_sides), "flee")
	# 3. Rally.
	if key != null and key.id != unit.id and not _ally_within(state, unit, int(DataRegistry.rule("rally_radius", 3))):
		var calm: Array = []
		for cell in stands:
			if not threat_all.has(cell):
				calm.append(cell)
		var pool: Array = calm if not calm.is_empty() else stands
		return _plan(unit, MovementHandler.closest_by_path(state, unit, pool, key.pos), "", "rally")
	# 4. Hold.
	return _plan(unit, unit.pos, EnemyAI.target_in_range_from(state, unit, unit.pos, target_sides), "hold")


static func _plan(unit: UnitState, cell: Vector2i, target_id: String, context: String) -> Dictionary:
	return {"unit_id": unit.id, "move_cell": cell, "target_id": target_id, "wait": target_id == "", "ai_context": context}


## The map's key unit (MapData.key_unit_id is a template id: resolve it to the placed copy of
## this unit's faction), alive, or null.
static func key_unit(state: BattleState, unit: UnitState) -> UnitState:
	var key_id := String(state.map.key_unit_id) if state.map != null and "key_unit_id" in state.map else ""
	if key_id == "":
		return null
	for u in state.alive_units():
		if (u.id == key_id or u.template_id == key_id) and u.faction_id == unit.faction_id:
			return u
	return null


## F-PPA1 / F-CC8: {player_unit_id: {cell: true}} - every tile each player unit could hit this
## turn (its move cells plus everything in weapon range of them). Non-attackers threaten nothing.
static func player_threats(state: BattleState) -> Dictionary:
	var out := {}
	for p in state.alive_units():
		if p.side != "player" or not p.can_attack:
			continue
		var reach := MovementHandler.compute_move_cells(state, p)
		reach[p.pos] = 0.0
		var cells := {}
		for c in reach:
			cells[c] = true
		for c in RangeHandler.compute_attack_cells(state, p, reach):
			cells[c] = true
		out[p.id] = cells
	return out


static func _threatening(state: BattleState, threats: Dictionary, cell: Vector2i) -> Array:
	var out: Array = []
	for p_id in threats:
		if threats[p_id].has(cell):
			out.append(state.units[p_id])
	return out


## Farthest from the nearest threatening player; ties toward the key unit, else toward the map
## edge nearest the unit's starting tile; then lowest x+y.
static func _flee_cell(state: BattleState, unit: UnitState, safe: Array, threatening: Array, key: UnitState) -> Vector2i:
	var best: Vector2i = safe[0]
	var best_key := _flee_key(state, unit, best, threatening, key)
	for cell in safe:
		var k := _flee_key(state, unit, cell, threatening, key)
		if k > best_key:
			best_key = k
			best = cell
	return best


static func _flee_key(state: BattleState, unit: UnitState, cell: Vector2i, threatening: Array, key: UnitState) -> Vector3:
	var nearest := 1 << 20
	for p in threatening:
		nearest = mini(nearest, RangeHandler.manhattan(cell, p.pos))
	var toward := -RangeHandler.manhattan(cell, key.pos) if key != null and key.id != unit.id else -_edge_distance(state, cell, unit.start_pos)
	return Vector3(nearest, toward, -(cell.x + cell.y))


## Distance from `cell` to the map edge that `start` is closest to.
static func _edge_distance(state: BattleState, cell: Vector2i, start: Vector2i) -> int:
	var edges := {"left": start.x, "right": state.width - 1 - start.x, "top": start.y, "bottom": state.height - 1 - start.y}
	var side := "left"
	for e in edges:
		if int(edges[e]) < int(edges[side]):
			side = e
	match side:
		"left": return cell.x
		"right": return state.width - 1 - cell.x
		"top": return cell.y
	return state.height - 1 - cell.y


static func _ally_within(state: BattleState, unit: UnitState, radius: int) -> bool:
	for u in state.alive_units():
		if u.id != unit.id and u.side == unit.side and RangeHandler.manhattan(u.pos, unit.pos) <= radius:
			return true
	return false
