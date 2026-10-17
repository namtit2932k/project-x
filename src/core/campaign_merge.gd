extends RefCounted
class_name CampaignMerge
## Applies one battle's outcome to the campaign (D06). Merge ONLY after a win: EXP,
## casualties per difficulty, bond points, chapter completion and reconcile outcomes.
## A defeat writes nothing, so Retry replays the chapter with the exact pre-battle
## roster and never counts a defeat. Called from Main and from tests; not an autoload.


## result is the director's ResultStore.last_result ("status": "win" / other).
static func merge(battle_state: BattleState, chapter: Resource, result: Dictionary) -> void:
	if battle_state == null or chapter == null:
		return
	# D06: only a victory touches the campaign. Defeat keeps the chapter open for retry.
	if String(result.get("status", "")) != "win":
		return
	var policy: String = String(DataRegistry.rule("casualty_by_difficulty", {}).get(GameState.difficulty, "temp_injury"))
	for unit_id in GameState.roster:
		if not battle_state.units.has(String(unit_id)):
			continue
		var state_unit: UnitState = battle_state.units[String(unit_id)]
		var entry: Dictionary = GameState.roster[unit_id]
		# D08: the battle carries the unit's starting exp (from_data) through level-ups;
		# the merged value is simply the live remainder plus already-applied levels.
		entry.exp = int(state_unit.exp)
		entry["level"] = int(state_unit.level)
		var carry: Dictionary = entry.get("stat_bonus", {})
		for stat_id in state_unit.stat_bonus:
			carry[String(stat_id)] = int(carry.get(String(stat_id), 0)) + int(state_unit.stat_bonus[stat_id])
		entry["stat_bonus"] = carry
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
	if result.has("reconcile"):
		var outcomes := {}
		for faction_id in result["reconcile"]:
			var fo: Dictionary = result["reconcile"][faction_id]
			outcomes[faction_id] = {"persuaded": bool(fo.get("persuaded", false)), "kills": int(fo.get("kills", 0)), "events": fo.get("events", [])}
		GameState.reconcile_outcomes[String(chapter.id)] = outcomes
