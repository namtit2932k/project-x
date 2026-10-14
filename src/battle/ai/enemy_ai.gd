extends RefCounted
class_name EnemyAI
## Simple AI for enemy/NPC phases: attack the best reachable target, otherwise approach
## the closest player unit. Commands are returned to the director, which applies them
## (snapshots happen per confirmed command, AI uses the same CombatResolver).

## One unit's turn plan: {unit_id, move_cell, target_id, wait}. `target_factions` = the
## factions this unit should actively attack (opposing sides normally; never its own).
static func plan_unit(state: BattleState, unit: UnitState, target_factions: Array) -> Dictionary:
	if not unit.alive or unit.acted:
		return {}
	var reach := MovementHandler.compute_move_cells(state, unit)
	var reach_cells := reach.keys()
	# Include current position as a no-move option.
	if not reach_cells.has(unit.pos):
		reach_cells.append(unit.pos)

	var enemies: Array = []
	for u in state.alive_units():
		if u.faction_id in target_factions:
			enemies.append(u)
	if enemies.is_empty():
		return {"unit_id": unit.id, "move_cell": unit.pos, "wait": true}

	# Try to close on the nearest reachable enemy.
	var reach_attack := RangeHandler.compute_attack_cells(state, unit, reach)
	var attack_options: Array = []
	for cell in reach_attack:
		# Chỉ đứng vào ô trống (hoặc ô hiện tại) — ô có unit khác thì commit move sẽ bị từ chối.
		if cell != unit.pos and state.unit_at(cell) != null:
			continue
		for e in enemies:
			if e.id == unit.id:
				continue
			# Target phải nằm đúng tầm vào [min..max] tính từ ô sẽ đứng (manhattan theo giản đồ FE).
			var dist: int = RangeHandler.manhattan(cell, e.pos)
			if dist < unit.attack_range_min or dist > unit.attack_range_max:
				continue
			attack_options.append({"cell": cell, "target_id": e.id})
	if not attack_options.is_empty():
		var best: Dictionary = attack_options[0]
		var best_score := -999
		for opt in attack_options:
			var target: UnitState = state.units[String(opt["target_id"])]
			var forecast_ok := int(CombatResolver.forecast(state, unit, target).get("can_counter", false))
			var score := int(CombatResolver.forecast(state, unit, target)["sequence"][0]["damage"]) * 10
			score += target.max_hp - target.hp
			if target.is_protagonist:
				score += 30
			if not forecast_ok and target.attack_range_max >= 1:
				pass
			if score > best_score:
				best_score = score
				best = opt
		return {"unit_id": unit.id, "move_cell": best["cell"], "target_id": best["target_id"]}

	# Approach: move to the reachable cell minimizing distance to the closest player unit.
	var best_cell := unit.pos
	var best_dist := 1 << 30
	for target in enemies:
		for cell in reach_cells:
			var d := RangeHandler.manhattan(cell, target.pos)
			if d < best_dist:
				best_dist = d
				best_cell = cell
	return {"unit_id": unit.id, "move_cell": best_cell, "target_id": ""}
