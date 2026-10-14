extends RefCounted
class_name WaitCommand
## Ends the unit's action without moving or attacking.


static func check(state: BattleState, unit: UnitState) -> String:
	if not state.units.has(unit.id) or not unit.alive:
		return "Unit unavailable."
	if unit.acted:
		return "Unit already acted this phase."
	return ""


static func apply(state: BattleState, unit: UnitState) -> void:
	unit.acted = true
