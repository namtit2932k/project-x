extends RefCounted
class_name EnemyAI
## Simple AI for enemy/NPC phases: attack the best reachable target, otherwise approach
## the closest player unit. Commands are returned to the director, which applies them
## (snapshots happen per confirmed command, AI uses the same CombatResolver).

## One unit's turn plan: {unit_id, move_cell, target_id, wait}. `target_sides` = the sides
## this unit should actively attack (opposing sides; never its own).
static func plan_unit(state: BattleState, unit: UnitState, target_sides: Array) -> Dictionary:
	if not unit.alive or unit.acted:
		return {}
	var reach := MovementHandler.compute_move_cells(state, unit)
	var reach_cells := reach.keys()
	# Include current position as a no-move option.
	if not reach_cells.has(unit.pos):
		reach_cells.append(unit.pos)

	var enemies: Array = []
	for u in state.alive_units():
		if u.side in target_sides:
			enemies.append(u)
	if enemies.is_empty():
		return {"unit_id": unit.id, "move_cell": unit.pos, "wait": true}

	# Try to close on the nearest reachable enemy.
	# Standing cells are the cells the unit can MOVE to (plus where it stands). The old code
	# used compute_attack_cells(), which only returns the threat ring outside the move area,
	# so every planned move was illegal and the unit just waited (found by the demo playtest).
	var attack_options: Array = []
	if not unit.can_attack:
		reach_cells = []
	for cell in reach_cells:
		# Only stand on an empty cell (or the current one) - commit would reject a move onto
		# another unit's tile.
		if cell != unit.pos and state.unit_at(cell) != null:
			continue
		for e in enemies:
			if e.id == unit.id:
				continue
			# Target must actually be in [min..max] range from the standing cell.
			var dist: int = RangeHandler.manhattan(cell, e.pos)
			if dist < unit.attack_range_min or dist > unit.attack_max():
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
			# F-OBJ Retrieve: enemies go for the item carrier once the item is taken.
			if state.is_move_only_carrier(target):
				score += 100
			if not forecast_ok and target.attack_range_max >= 1:
				pass
			if score > best_score:
				best_score = score
				best = opt
		return {"unit_id": unit.id, "move_cell": best["cell"], "target_id": best["target_id"]}

	# Approach the closest target by real walking distance (terrain-aware), not straight line.
	var closest: UnitState = enemies[0]
	for target in enemies:
		if RangeHandler.manhattan(unit.pos, target.pos) < RangeHandler.manhattan(unit.pos, closest.pos):
			closest = target
	var best_cell := MovementHandler.closest_by_path(state, unit, reach_cells, closest.pos)
	return {"unit_id": unit.id, "move_cell": best_cell, "target_id": ""}
