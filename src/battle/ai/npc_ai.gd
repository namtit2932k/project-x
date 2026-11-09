extends RefCounted
class_name NpcAI
## NPC actors (escort/evacuee style) walk toward their objective goal during the NPC phase.
## They never attack (carriers may only move anyway); guarding behavior is designer-colored later.

## Walk plan toward the given goal cell: the reachable cell with the shortest real walk to
## the goal (terrain-aware, so the NPC goes around water instead of stopping at its edge).
static func plan_walk(state: BattleState, unit: UnitState, goal: Vector2i) -> Dictionary:
	if not unit.alive or unit.acted:
		return {}
	var reach := MovementHandler.compute_move_cells(state, unit)
	var best := MovementHandler.closest_by_path(state, unit, reach.keys(), goal)
	return {"unit_id": unit.id, "move_cell": best, "goal": goal}
