extends RefCounted
class_name WaitCommand
## Ends the unit's action without moving or attacking.


static func apply(state: BattleState, unit: UnitState) -> void:
	unit.acted = true


## Skill command pipeline: effect types are data-driven from SkillData (heal first).
static func execute_skill(state: BattleState, unit: UnitState, skill_id: String, target: UnitState) -> bool:
	var skill := DataRegistry.get_data("skills", skill_id)
	if skill == null:
		return false
	unit.acted = true
	match String(skill.effect_type):
		"heal":
			target.heal(int(skill.power))
			return true
		_:
			push_warning("Skill effect type not implemented: %s" % skill.effect_type)
			return false
