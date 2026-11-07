extends RefCounted
class_name ExpSystem
## EXP and level-up rules (F-EXP; GDD core-combat Core Rule 12). F-CC13 pays a flat EXP for
## performing an Attack or a Heal; F-CC14 is the ONE level-up resolution every EXP source
## calls (action EXP now, the Dual Restraint victory bonus later). Only player-side units
## take part — enemies never earn EXP or level.


## F-CC13: flat rules_config.exp_per_action for an Attack or Heal the unit just performed,
## hit or miss, kill or not. Callers: CombatResolver.execute (Attack), SkillCommand (Heal).
static func grant_action_exp(state: BattleState, unit: UnitState) -> void:
	if not bool(DataRegistry.rule("exp_enabled", true)):
		return
	# GDD-silent edge case (AGENTS.md F-EXP open item a): a unit felled during its own
	# exchange cannot level mid-battle, so it earns nothing for that action.
	if not unit.alive:
		return
	resolve_level_up(state, unit, int(DataRegistry.rule("exp_per_action", 25)))


## F-CC14: adds exp_delta, then while exp >= exp_per_level and level < level_cap: level +1,
## exp -exp_per_level, every growth stat rolls once (+1 on success unless the stat is already
## at its stat_caps ceiling — that success is wasted). At the cap the leftover EXP is discarded.
static func resolve_level_up(state: BattleState, unit: UnitState, exp_delta: int) -> void:
	if unit.side != "player" or exp_delta <= 0:
		return
	var per_level := int(DataRegistry.rule("exp_per_level", 100))
	var level_cap := int(DataRegistry.rule("level_cap", 20))
	if unit.level >= level_cap:
		unit.exp = 0   # AC-CC84: a capped unit gains nothing; EXP is never banked
		return
	state.exp_gained_set(unit.id, exp_delta)
	while unit.exp >= per_level and unit.level < level_cap:
		unit.exp -= per_level
		unit.level += 1
		state.level_ups.append({"unit_id": unit.id, "level": unit.level, "gains": _roll_growths(state, unit)})
	if unit.level >= level_cap:
		unit.exp = 0   # F-CC14: EXP left over at the cap is discarded


## One independent roll per growth stat for a single level gained; returns {stat_id: +1}.
static func _roll_growths(state: BattleState, unit: UnitState) -> Dictionary:
	var caps: Dictionary = DataRegistry.rule("stat_caps", {})
	var gains: Dictionary = {}
	for stat_key in unit.growths:
		var stat_id := String(stat_key)
		var chance := clampi(int(unit.growths[stat_key]), 0, 100)
		if state.rng().randi_range(1, 100) > chance:
			continue
		if _at_cap(unit, stat_id, caps):
			continue   # AC-CC82: a success on a capped stat is wasted, not an error
		unit.apply_stat_gain(stat_id, 1)
		gains[stat_id] = 1
	return gains


## Caps are keyed by GDD stat names; legacy keys (atk/skl/spd) resolve through the alias table.
static func _at_cap(unit: UnitState, stat_id: String, caps: Dictionary) -> bool:
	var cap_key := stat_id
	if not caps.has(cap_key):
		cap_key = String(UnitData.STAT_KEY_ALIASES.get(stat_id, ""))
	if not caps.has(cap_key):
		return false
	return unit.growth_stat_value(stat_id) >= int(caps[cap_key])
