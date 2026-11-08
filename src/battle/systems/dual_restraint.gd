extends RefCounted
class_name DualRestraint
## Dual Restraint scoring (F-DRS; GDD dual-restraint-scoring.md). Everything is derived from the
## battle state when it is read, so a rewind past a death or a kill undoes it with no extra
## tracking. F-DRS1 = display-only score; F-DRS2 = small victory bonus EXP for the squad.


## True while no player-side unit has died on a permadeath tier (GDD Core Rule 2: on
## Story/Normal nobody reaches Dead, so it always holds there).
static func zero_ally_deaths(state: BattleState) -> bool:
	var policy := String(DataRegistry.rule("casualty_by_difficulty", {}).get(state.difficulty, "temp_injury"))
	if policy != "permadeath":
		return true
	for u in state.units.values():
		if u.side == "player" and not u.alive:
			return false
	return true


## Locked result at battle end: {zero_ally_deaths, kill_restraint_eligible, battle_kill_count,
## low_kill_restraint, swift_clear_met, ally_points, kill_points, perfect_bonus, swift_bonus,
## restraint_points_awarded, bonus_exp}.
static func result(state: BattleState) -> Dictionary:
	var zero := zero_ally_deaths(state)
	# The engaged holdout faction = the remnant faction(s) this map tracks for reconciliation.
	var eligible := not state.reconcile_state.is_empty()
	var kills := 0
	for faction_id in state.reconcile_state:
		kills += int(state.reconcile_state[faction_id].get("kills", 0))
	var low_kill := kills <= int(DataRegistry.rule("drs_kill_tolerance", 2))
	var turn_par := int(state.map.turn_par) if state.map != null and "turn_par" in state.map else 0
	var swift := turn_par > 0 and state.turn <= turn_par
	var ally_points := int(DataRegistry.rule("drs_ally_points", 50)) if zero else 0
	var kill_points := int(DataRegistry.rule("drs_kill_points", 50)) if (low_kill and eligible) else 0
	var perfect := int(DataRegistry.rule("drs_perfect_bonus", 25)) if (zero and low_kill and eligible) else 0
	var swift_bonus := int(DataRegistry.rule("drs_swift_bonus", 25)) if swift else 0
	var bonus_exp := 0
	if zero:
		bonus_exp += int(DataRegistry.rule("drs_ally_bonus_exp", 15))
	if low_kill and eligible:
		bonus_exp += int(DataRegistry.rule("drs_kill_restraint_bonus_exp", 15))
	return {
		"zero_ally_deaths": zero, "kill_restraint_eligible": eligible, "battle_kill_count": kills,
		"low_kill_restraint": low_kill, "swift_clear_met": swift,
		"ally_points": ally_points, "kill_points": kill_points, "perfect_bonus": perfect, "swift_bonus": swift_bonus,
		"restraint_points_awarded": ally_points + kill_points + perfect + swift_bonus,
		"bonus_exp": bonus_exp,
	}


## F-DRS2: on a victory, every living deployed player unit gets the bonus EXP through the one
## level-up resolution (F-CC14). Dead units earn nothing (designer rule).
static func grant_bonus_exp(state: BattleState, bonus_exp: int) -> void:
	if bonus_exp <= 0:
		return
	for u in state.units.values():
		if u.side == "player" and u.alive:
			ExpSystem.resolve_level_up(state, u, bonus_exp)
