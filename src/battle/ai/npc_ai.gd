extends RefCounted
class_name NpcAI
## NPC actors (escort/evacuee style) walk toward their objective goal during the NPC phase.
## They never attack (carriers may only move anyway); guarding behavior is designer-colored later.

## Walk plan toward the given goal cell: reachable cell minimizing manhattan distance.
static func plan_walk(state: BattleState, unit: UnitState, goal: Vector2i) -> Dictionary:
	if not unit.alive or unit.acted:
		return {}
	var reach := MovementHandler.compute_move_cells(state, unit)
	var best := unit.pos
	var best_dist := RangeHandler.manhattan(unit.pos, goal)
	for cell in reach:
		var d: int = RangeHandler.manhattan(cell, goal)
		if d < best_dist:
			best_dist = d
			best = cell
	return {"unit_id": unit.id, "move_cell": best, "goal": goal}
