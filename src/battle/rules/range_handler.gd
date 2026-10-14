extends RefCounted
class_name RangeHandler
## Attack range drawn from the edge of the move range (Fire Emblem style), plus target enumeration.

const DIRS: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Attack cells = cells at manhattan distance in [min..max] from any move-able/reachable tile,
## excluding the reachable set itself (those are move cells).
static func compute_attack_cells(state: BattleState, unit: UnitState, reach: Dictionary) -> Dictionary:
	var out := {}
	var all_cells := {}
	for cell in reach:
		all_cells[cell] = true
	for cell in reach:
		for dxx in range(-unit.attack_range_max, unit.attack_range_max + 1):
			for dyy in range(-unit.attack_range_max, unit.attack_range_max + 1):
				var dist: int = absi(dxx) + absi(dyy)
				if dist < unit.attack_range_min or dist > unit.attack_range_max:
					continue
				var cand: Vector2i = cell + Vector2i(dxx, dyy)
				if not state.in_bounds(cand):
					continue
				if not all_cells.has(cand):
					out[cand] = true
	return out


## Valid attack targets of a unit at its current position (same side = ally, excluded).
## This is the decided interaction flow: "red cells measured from the standing position".
static func compute_targets(state: BattleState, unit: UnitState, reach: Dictionary) -> Array:
	var attack_cells := compute_attack_cells(state, unit, reach)
	var targets: Array = []
	for cell in attack_cells:
		var occ: UnitState = state.unit_at(cell)
		if occ != null and occ.alive and occ != unit and occ.side != unit.side:
			targets.append(occ.id)
	return targets


## Valid attack targets from a unit's CURRENT position (no movement assumed). Same side
## = ally, excluded. This is the decided interaction flow: red cells measure the
## standing position, so attacks can never happen from outside real weapon range.
static func compute_targets_from_position(state: BattleState, unit: UnitState) -> Array:
	var standing: Dictionary = {unit.pos: 0.0}
	return compute_targets(state, unit, standing)


## Counter condition: defender can hit the attacker from its own tile distance.
static func can_counter(state: BattleState, defender: UnitState, attacker_cell: Vector2i) -> bool:
	var dist := manhattan(defender.pos, attacker_cell)
	return dist <= defender.attack_range_max and dist >= defender.attack_range_min


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
