extends RefCounted
class_name CampaignMerge
## Applies one battle's outcome to the campaign. Only a win merges (D06; designer: losing is
## a game over): EXP/levels/level-up gains, casualties per difficulty, bond points, chapter
## completion and reconcile outcomes. rules_config.action_exp_commits_on_defeat (off by
## default) would keep the EXP part after a defeat too. Called from Main and from tests.


## result is the director's ResultStore.last_result ("status": "win" / other).
static func merge(battle_state: BattleState, chapter: Resource, result: Dictionary) -> void:
	if battle_state == null or chapter == null:
		return
	var won := String(result.get("status", "")) == "win"
	if won or bool(DataRegistry.rule("action_exp_commits_on_defeat", false)):
		_merge_progression(battle_state)
	# D06: only a victory touches the rest of the campaign. Defeat keeps the chapter open for retry.
	if not won:
		return
	var policy: String = String(DataRegistry.rule("casualty_by_difficulty", {}).get(GameState.difficulty, "temp_injury"))
	for unit_id in GameState.roster:
		if not battle_state.units.has(String(unit_id)):
			continue
		var state_unit: UnitState = battle_state.units[String(unit_id)]
		var entry: Dictionary = GameState.roster[unit_id]
		if not state_unit.alive:
			match policy:
				"permadeath":
					entry.alive = false
				"none":
					entry.alive = true
				_:
					# temp_injury placeholder: units return for the next battle.
					entry.alive = true
					entry["defeats"] = int(entry.get("defeats", 0)) + 1
	# Bond points earned this battle flow into the campaign (capped per pair per battle
	# at the source); the camp reads GameState.bond_points, not the battle-local copy.
	for pair_id in battle_state.bond_points:
		GameState.bond_points[pair_id] = int(GameState.bond_points.get(pair_id, 0)) + int(battle_state.bond_points[pair_id])
	GameState.completed_chapters[String(chapter.id)] = true
	# F-ITEM: this victory's gold, and every deployed unit's items as they ended the battle.
	GameState.gold = maxi(GameState.gold + int(result.get("gold", {}).get("total", 0)), 0)
	for unit_id in GameState.roster:
		if battle_state.units.has(String(unit_id)):
			GameState.roster[unit_id]["items"] = (battle_state.units[String(unit_id)].items as Array).duplicate()
	# F-PS3: this battle's kills join the faction's cumulative count (victory only, see F-PSI).
	for faction_id in battle_state.reconcile_state:
		var battle_kills := int(battle_state.reconcile_state[faction_id].get("kills", 0))
		GameState.faction_kill_counts[String(faction_id)] = int(GameState.faction_kill_counts.get(String(faction_id), 0)) + battle_kills
	if result.has("reconcile"):
		var outcomes := {}
		for faction_id in result["reconcile"]:
			var fo: Dictionary = result["reconcile"][faction_id]
			outcomes[faction_id] = {"persuaded": bool(fo.get("persuaded", false)), "kills": int(fo.get("kills", 0)), "events": fo.get("events", [])}
		GameState.reconcile_outcomes[String(chapter.id)] = outcomes
	# F-FST: every faction tracked this battle is now Engaged, or Persuaded if evaluate() said so.
	for faction_id in battle_state.reconcile_state:
		if GameState.is_faction_terminal(String(faction_id)):
			continue
		var persuaded := bool(result.get("reconcile", {}).get(faction_id, {}).get("persuaded", false))
		GameState.faction_states[String(faction_id)] = "persuaded" if persuaded else "engaged"


## EXP / level / level-up stat gains of every deployed roster unit. The battle unit started
## from the roster's exp and level (from_data), so those are copied back as they are;
## stat_bonus on the battle unit holds only this battle's gains and is added to the total.
static func _merge_progression(battle_state: BattleState) -> void:
	for unit_id in GameState.roster:
		if not battle_state.units.has(String(unit_id)):
			continue
		var state_unit: UnitState = battle_state.units[String(unit_id)]
		var entry: Dictionary = GameState.roster[unit_id]
		entry.exp = int(state_unit.exp)
		entry["level"] = int(state_unit.level)
		var carry: Dictionary = entry.get("stat_bonus", {})
		for stat_id in state_unit.stat_bonus:
			carry[String(stat_id)] = int(carry.get(String(stat_id), 0)) + int(state_unit.stat_bonus[stat_id])
		entry["stat_bonus"] = carry
