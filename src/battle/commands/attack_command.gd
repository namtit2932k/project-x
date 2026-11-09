extends RefCounted
class_name AttackCommand
## Confirmed attack: runs the single CombatResolver and applies results; rewards bond pairs.

static func check(state: BattleState, unit: UnitState, target_id: String) -> String:
	if not state.units.has(unit.id) or not unit.alive or unit.acted:
		return "Unit unavailable or already acted."
	var target: UnitState = state.units.get(target_id, null)
	if target == null or not target.alive:
		return "No valid target."
	if target.side == unit.side:
		return "Cannot attack an ally."
	if not unit.can_attack:
		return "This unit cannot attack."
	# Attack must be done from inside the weapon range measured at the CURRENT position.
	var dist := RangeHandler.manhattan(unit.pos, target.pos)
	if dist < unit.attack_range_min or dist > unit.attack_max():
		return "Target out of weapon range."
	# Retrieve objective: while carrying, the unit may only move (no attack/skill).
	if _is_move_only(state, unit):
		return "Carrier may only move."
	return ""


static func _is_move_only(state: BattleState, unit: UnitState) -> bool:
	return state.is_move_only_carrier(unit)


static func apply(state: BattleState, unit: UnitState, target_id: String) -> Array:
	var target: UnitState = state.units[target_id]
	var strikes: Array = CombatResolver.execute(state, unit, target)
	unit.acted = true
	BondSystem.reward_action(state, unit)   # F-BOND: the attacker's adjacent partners
	for strike in strikes:
		if String(strike.get("slain", "")) != "":
			_on_slain(state, state.units[String(strike["slain"])])
	return strikes


static func _on_slain(_state: BattleState, slain: UnitState) -> void:
	# F-OBJ: a dead carrier keeps the item — the Retrieve objective reads it as an instant loss.
	EventBus.unit_died.emit(slain.id, "")
