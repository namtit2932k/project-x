extends RefCounted
class_name SkillCommand
## Skill command pipeline: effect types are data-driven from SkillData ("heal", "encore").
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
	var dist := RangeHandler.manhattan(unit.pos, target.pos)
	match String(skill.effect_type):
		"heal":
			if target.side != unit.side:
				return "Heal targets an ally."
			if target.hp >= target.max_hp:
				return "Target already at full HP."
			# F-HEAL: range from the Heal weapon's heal_range (min 0 would allow self-heal).
			var heal_range := CombatResolver.heal_range(unit, skill)
			if dist < heal_range.x or dist > heal_range.y:
				return "Target out of skill range."
		"encore":
			# F-PAS / GDD Core Rule 3b (Bard Diễn Tấu): an adjacent ally that already acted.
			if target.id == unit.id or target.side != unit.side:
				return "Encore targets another ally."
			if not target.acted:
				return "Target has not acted yet."
			if has_encore(target):
				return "Encore cannot target another Encore user."
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
			# F-CC9 / F-HEAL: Mag + heal_might, capped at max HP, no Hit/Crit roll.
			target.heal(CombatResolver.heal_amount(unit, skill))
			BondSystem.reward_action(state, unit)   # F-BOND: the healer's adjacent partners
			# F-CC13 (F-EXP): a Heal pays the healer the same flat EXP as an Attack.
			ExpSystem.grant_action_exp(state, unit)
			# F-PAS: Beastwoman-style self heal, Healer's mentor EXP to the healed ally.
			PassiveSystem.on_action_performed(state, unit, "heal", target)
			return true
		"encore":
			# Only the target's Move + Action come back; its position, HP, items, debuffs and
			# phase allowances (Trade, Magician burst) stay as they are.
			target.acted = false
			target.moved = false
			# GDD F-CC13: Encore pays the Bard the flat action EXP.
			ExpSystem.grant_action_exp(state, unit)
			return true
		_:
			return false


## True when the unit carries a skill with the "encore" effect (no Encore chains).
static func has_encore(unit: UnitState) -> bool:
	for skill_id in unit.skill_ids:
		var skill := DataRegistry.get_data("skills", String(skill_id))
		if skill != null and String(skill.effect_type) == "encore":
			return true
	return false
