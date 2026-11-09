extends RefCounted
class_name GoldRewards
## F-ITEM gold at battle end (GDD Gold/Shop Core Rule 2): victory, Retrieve bonus, persuasion
## per faction persuaded this battle, plus village gold claimed during the battle. Only a
## victory pays (designer: a lost battle keeps nothing). Never from kills, never per difficulty.


static func on_victory(state: BattleState, reconcile: Dictionary) -> Dictionary:
	var retrieve := 0
	for cfg in state.objectives_config:
		if String(cfg.get("type", "")) == "retrieve":
			retrieve = int(DataRegistry.rule("gold_retrieve_bonus", 15))
	var persuaded := 0
	for faction_id in reconcile:
		if bool(reconcile[faction_id].get("persuaded", false)):
			persuaded += 1
	var out := {
		"victory": int(DataRegistry.rule("gold_per_victory", 15)),
		"retrieve": retrieve,
		"persuasion": persuaded * int(DataRegistry.rule("gold_per_persuasion", 20)),
		"villages": state.gold_earned,
	}
	out["total"] = int(out["victory"]) + retrieve + int(out["persuasion"]) + state.gold_earned
	return out
