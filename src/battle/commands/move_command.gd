extends RefCounted
class_name MoveCommand
## Moves a unit along its reachable cells to the target cell (target must be in move_cells).


static func check(state: BattleState, unit: UnitState, target: Vector2i) -> String:
	if not state.units.has(unit.id) or not unit.alive:
		return "Unit unavailable."
	if unit.acted:
		return "Unit already acted this phase."
	if not state.in_bounds(target):
		return "Target cell out of bounds."
	return ""


## Returns true when applied. Movement through allies, not onto occupied tiles.
## One move per unit per phase: the moved flag blocks a second move until rewind.
static func apply(state: BattleState, unit: UnitState, target: Vector2i) -> bool:
	var move_cells := MovementHandler.compute_move_cells(state, unit)
	if not move_cells.has(target):
		return false
	var from := unit.pos
	unit.pos = target
	unit.moved = true
	EventBus.unit_moved.emit(unit.id, from, target)
	return true
