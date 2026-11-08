extends RefCounted
class_name EnemyAI
## Enemy turn logic (F-AI). `plan_unit` dispatches on the unit's ai_profile:
## StandardAggressive (GDD Core Rule 8, also the fallback), Raider (Core Rule 8a) and
## ProtectPersuade (ProtectPersuadeAI). Plans are returned to the director, which applies them
## as normal commands (snapshots per command, the same CombatResolver for every exchange).
## The player-side test bots reuse the StandardAggressive plan.

## One unit's turn plan: {unit_id, move_cell, target_id, wait, ai_context}. `target_sides` =
## the sides this unit should actively attack (opposing sides; never its own).
static func plan_unit(state: BattleState, unit: UnitState, target_sides: Array) -> Dictionary:
	if not unit.alive or unit.acted:
		return {}
	if unit.side == "enemy":
		if ProtectPersuadeAI.is_governed(state, unit):
			return ProtectPersuadeAI.plan(state, unit, target_sides)
		if unit.ai_profile == "Raider":
			var raid := plan_raider(state, unit, target_sides)
			if not raid.is_empty():
				return raid
	return plan_standard(state, unit, target_sides)


## GDD Core Rule 8: nearest reachable target (ties: lowest x+y), stand on the in-range tile
## closest to it, attack; otherwise walk toward the nearest one along the real path.
static func plan_standard(state: BattleState, unit: UnitState, target_sides: Array) -> Dictionary:
	var stands := standing_cells(state, unit)
	var foes := foes_of(state, unit, target_sides)
	if foes.is_empty():
		return {"unit_id": unit.id, "move_cell": unit.pos, "wait": true}
	var reachable: Array = []
	for e in foes:
		if not cells_in_range(unit, stands, e.pos).is_empty():
			reachable.append(e)
	if not reachable.is_empty():
		var target := _pick_target(state, unit, reachable)
		var cell := nearest_cell(cells_in_range(unit, stands, target.pos), target.pos)
		return {"unit_id": unit.id, "move_cell": cell, "target_id": target.id}
	var closest: UnitState = nearest_unit(unit.pos, foes)
	return {"unit_id": unit.id, "move_cell": MovementHandler.closest_by_path(state, unit, stands, closest.pos), "target_id": ""}


## Kept overrides on top of "nearest": the Retrieve carrier (F-OBJ), then priority_target_id
## (D-B7); otherwise the nearest by tile distance from the unit's current tile.
static func _pick_target(state: BattleState, unit: UnitState, reachable: Array) -> UnitState:
	for e in reachable:
		if state.is_move_only_carrier(e):
			return e
	if unit.priority_target_id != "":
		for e in reachable:
			if e.id == unit.priority_target_id:
				return e
	return nearest_unit(unit.pos, reachable)


## GDD Core Rule 8a: beeline onto the nearest open village reachable THIS turn (the move
## destroys it), then attack whatever is already in range from there. {} = no village to raid.
static func plan_raider(state: BattleState, unit: UnitState, target_sides: Array) -> Dictionary:
	var stands := standing_cells(state, unit)
	var villages: Array = []
	for cell in stands:
		if not state.open_village_at(cell).is_empty():
			villages.append(cell)
	if villages.is_empty():
		return {}
	var dest := nearest_cell(villages, unit.pos)
	return {"unit_id": unit.id, "move_cell": dest, "target_id": target_in_range_from(state, unit, dest, target_sides)}


# ------------------------------------------------------------ shared helpers

## Tiles the unit may end its move on this turn, its own tile included.
static func standing_cells(state: BattleState, unit: UnitState) -> Array:
	var out: Array = MovementHandler.compute_move_cells(state, unit).keys()
	if not out.has(unit.pos):
		out.append(unit.pos)
	return out


static func foes_of(state: BattleState, unit: UnitState, target_sides: Array) -> Array:
	var out: Array = []
	for u in state.alive_units():
		if u.side in target_sides and u.id != unit.id:
			out.append(u)
	return out


## Of `cells`, those from which `target_cell` is inside the unit's weapon range.
static func cells_in_range(unit: UnitState, cells: Array, target_cell: Vector2i) -> Array:
	var out: Array = []
	if not unit.can_attack:
		return out
	for cell in cells:
		var d := RangeHandler.manhattan(cell, target_cell)
		if d >= unit.attack_range_min and d <= unit.attack_max():
			out.append(cell)
	return out


## The nearest foe already in weapon range from `cell` (ties: lowest x+y), or "".
static func target_in_range_from(state: BattleState, unit: UnitState, cell: Vector2i, target_sides: Array) -> String:
	var in_range: Array = []
	for e in foes_of(state, unit, target_sides):
		if not cells_in_range(unit, [cell], e.pos).is_empty():
			in_range.append(e)
	return "" if in_range.is_empty() else nearest_unit(cell, in_range).id


## Deterministic "nearest": tile distance, then lowest x+y (the GDD tie-break), then x.
static func nearest_unit(from: Vector2i, units: Array) -> UnitState:
	var best: UnitState = units[0]
	for u in units:
		if _closer(from, u.pos, best.pos):
			best = u
	return best


static func nearest_cell(cells: Array, to: Vector2i) -> Vector2i:
	var best: Vector2i = cells[0]
	for c in cells:
		if _closer(to, c, best):
			best = c
	return best


static func _closer(origin: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	var da := RangeHandler.manhattan(origin, a)
	var db := RangeHandler.manhattan(origin, b)
	if da != db:
		return da < db
	if a.x + a.y != b.x + b.y:
		return a.x + a.y < b.x + b.y
	return a.x < b.x
