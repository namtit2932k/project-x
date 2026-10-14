extends RefCounted
class_name SkillCommand
## Skill command pipeline: effect types are data-driven from SkillData (heal first).
## Split out of WaitCommand per the proposed command architecture.


static func check(state: BattleState, unit: UnitState, skill_id: String, target: UnitState) -> String:
	if not state.units.has(unit.id) or not unit.alive or unit.acted:
		return "Unit unavailable or already acted."
	var skill := DataRegistry.get_data("skills", skill_id)
	if skill == null:
		return "Unknown skill."
	if target == null or not target.alive:
		return "No valid target."
	# Retrieve objective: while carrying, the unit may only move (no attack/skill).
	if unit.carried_item != "":
		for cfg in state.objectives_config:
			if String(cfg.get("type", "")) == "retrieve" and String(cfg.get("params", {}).get("item_id", "")) == unit.carried_item:
				return "Carrier may only move."
	match String(skill.effect_type):
		"heal":
			if target.side != unit.side:
				return "Heal targets an ally."
			if target.hp >= target.max_hp:
				return "Target already at full HP."
			var dist := RangeHandler.manhattan(unit.pos, target.pos)
			if dist < int(skill.range_min) or dist > int(skill.range_max):
				return "Target out of skill range."
		_:
			return "Skill effect type not live yet."
	return ""


static func apply(state: BattleState, unit: UnitState, skill_id: String, target: UnitState) -> bool:
	var skill := DataRegistry.get_data("skills", skill_id)
	if skill == null:
		return false
	unit.acted = true
	match String(skill.effect_type):
		"heal":
			target.heal(int(skill.power))
			BondSystem.reward_heal(state, unit, target)
			return true
		_:
			return false
