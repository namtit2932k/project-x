extends RefCounted
class_name AttackCommand
## Confirmed attack: runs the single CombatResolver and applies results; rewards bond pairs.

static func check(state: BattleState, unit: UnitState, target_id: String) -> String:
	if not state.units.has(unit.id) or not unit.alive or unit.acted:
		return "Unit unavailable or already acted."
	var target: UnitState = state.units.get(target_id, null)
	if target == null or not target.alive:
		return "No valid target."
	if target.faction_id == unit.faction_id:
		return "Cannot attack an ally."
	return ""


static func apply(state: BattleState, unit: UnitState, target_id: String) -> Array:
	var target: UnitState = state.units[target_id]
	var strikes: Array = CombatResolver.execute(state, unit, target)
	unit.acted = true
	BondSystem.reward_combat_pairs(state, unit, target)
	for strike in strikes:
		if String(strike.get("slain", "")) != "":
			_on_slain(state, state.units[String(strike["slain"])])
	return strikes


static func _on_slain(state: BattleState, slain: UnitState) -> void:
	# Item drops back to the ground if the carrier dies (retrieve objective keeps its item).
	if slain.carried_item != "":
		state.item_ground["%d,%d" % [slain.pos.x, slain.pos.y]] = slain.carried_item
		slain.carried_item = ""
	EventBus.unit_died.emit(slain.id, "")
