extends RefCounted
class_name MovementHandler
## Movement rules: terrain costs, pass-through allies, blocked by enemies. Pure static rules code.

## Dijkstra from the unit's cell. Returns {cell -> cost}. Cells with allies (or the mover's own
## cell) are traversable but cannot be END positions (filtered by move_cells).
static func compute_reachable(state: BattleState, unit: UnitState) -> Dictionary:
	var flying := unit.move_type == "flying"
	var start := unit.pos
	var best: Dictionary = {start: 0.0}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		# Small maps: pick the cheapest open frontier cell.
		frontier.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return best[a] < best[b])
		var current: Vector2i = frontier.pop_front()
		for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + dir
			if not state.in_bounds(next):
				continue
			if not _passable(state, unit, next, flying):
				continue
			var step_cost := _step_cost(state, next, flying)
			var cost: float = best[current] + step_cost
			var known: Variant = best.get(next, INF)
			if cost < float(known) and cost <= float(unit.move_range) + 0.001:
				best[next] = cost
				frontier.append(next)
	return best


## Reachable tiles the unit may actually stop on (never an occupied cell).
static func compute_move_cells(state: BattleState, unit: UnitState) -> Dictionary:
	var reach := compute_reachable(state, unit)
	var out := {}
	for cell in reach:
		if state.in_bounds(cell) and state.unit_at(cell) == null:
			out[cell] = reach[cell]
	return out


static func _passable(state: BattleState, unit: UnitState, cell: Vector2i, flying: bool) -> bool:
	var occ := state.unit_at(cell)
	if occ != null and occ.id != unit.id:
		# May walk through allies; never through enemies.
		if occ.faction_id == unit.faction_id:
			return true
		return false
	var defs: Dictionary = DataRegistry.rule("terrain_defs", {})
	var td: Dictionary = defs.get(state.terrain_at(cell), {"blocked": true})
	if bool(td.get("blocked", false)):
		return flying
	return true


## Chi phí bước theo bảng terrain_costs (địa hình x movement_type) từ rules_config.
static func _step_cost(state: BattleState, cell: Vector2i, flying: bool) -> float:
	var costs: Dictionary = DataRegistry.rule("terrain_costs", {})
	var mode := "flying" if flying else "foot"
	var entry: Dictionary = costs.get(state.terrain_at(cell), {})
	if not entry.is_empty():
		return maxf(float(entry.get(mode, entry.get("flying", 999.0))), 0.5)
	# Fallback cǎtě: legacy flat cost in terrain_defs.
	var defs: Dictionary = DataRegistry.rule("terrain_defs", {})
	return maxf(float(defs.get(state.terrain_at(cell), {}).get("cost", 999.0)), 0.5)
