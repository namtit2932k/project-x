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
	# F-MOVE: "stay" - a 0-tile move on the unit's own tile (it then acts from where it stands).
	if target == unit.pos and not unit.moved:
		unit.moved = true
		return true
	var move_cells := MovementHandler.compute_move_cells(state, unit)
	if not move_cells.has(target):
		return false
	var from := unit.pos
	unit.pos = target
	unit.moved = true
	EventBus.unit_moved.emit(unit.id, from, target)
	# F-ITEM (GDD Battle/Map Core Rule 15): an enemy ending its move on an open village destroys it.
	if unit.side == "enemy":
		var village := state.open_village_at(target)
		if not village.is_empty():
			village["state"] = "destroyed"
	# F-OBJ Retrieve (GDD Core Rule 13): a player unit ending its move on the item picks it up,
	# and that move finishes its action.
	var key := "%d,%d" % [target.x, target.y]
	if unit.side == "player" and unit.carried_item == "" and state.item_ground.has(key):
		unit.carried_item = String(state.item_ground[key])
		state.item_ground.erase(key)
		unit.acted = true
	return true
