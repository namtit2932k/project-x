extends RefCounted
class_name BondSystem
## Bond rules: pair list is designer data only; ranks unlock after scenes; unlocked ranks
## grant adjacency bonus in combat. Campaign rank/scene state lives in GameState.

## Adds points for one pair (if eligible and under the per-battle cap) and emits a signal.
static func add_points(state: BattleState, pair: Resource, amount: int) -> void:
	var pair_id := String(pair.id)
	var cap := int(DataRegistry.rule("bond_point_limit_per_pair_per_map", 20))
	state.bond_points[pair_id] = mini(int(state.bond_points.get(pair_id, 0)) + amount, cap)
	EventBus.bond_points_gained.emit(pair_id, amount)


static func eligible_pair_for(state: BattleState, unit_a: String, unit_b: String) -> Resource:
	for pair in DataRegistry.all_bond_pairs():
		if (String(pair.unit_a) == unit_a and String(pair.unit_b) == unit_b) \
				or (String(pair.unit_a) == unit_b and String(pair.unit_b) == unit_a):
			return pair
	return null


## Total combat bonus for `unit` from adjacent alive allies with an unlocked-rank bond pair.
static func support_attack_bonus(state: BattleState, unit: UnitState) -> int:
	return _adjacency_bonus(state, unit)


## P-02: the adjacency bonus lands on every target group in rules_config.bond_bonus_targets
## (accuracy, avoid, crit, damage). Combat formulas ask via their own stat name; the name
## maps onto the configured target group ("power"/damage side feeds damage, "hit" feeds accuracy).
static func stat_bonus(state: BattleState, unit: UnitState, stat_name: String) -> int:
	var group := ""
	match stat_name:
		"power", "magic":
			group = "damage"
		"hit":
			group = "accuracy"
		"avoid":
			group = "avoid"
		"crit":
			group = "crit"
	var targets: Array = DataRegistry.rule("bond_bonus_targets", ["accuracy", "avoid", "crit", "damage"])
	if group == "" or not (group in targets):
		return 0
	return _adjacency_bonus(state, unit)


static func _adjacency_bonus(state: BattleState, unit: UnitState) -> int:
	var total := 0
	var bonuses: Dictionary = DataRegistry.rule("bond_bonus_by_rank", {})
	for u in state.alive_units():
		if u.id == unit.id or u.side != unit.side:
			continue
		if RangeHandler.manhattan(u.pos, unit.pos) != 1:
			continue
		var pair := eligible_pair_for(state, unit.id, u.id)
		if pair == null:
			continue
		var rank: String = GameState.bond_rank_for(String(pair.id))
		if rank == "" or rank not in bonuses:
			continue
		total += int(bonuses[rank])
	return mini(total, int(DataRegistry.rule("max_adjacent_bond_bonus", 16)))


## D05 bond points: after each combat, every eligible pair gets points when ONE member took
## part in the engagement (attacked OR was attacked) and the OTHER member is alive, on the
## player side, standing adjacent (manhattan = 1) to that participant. One award per pair
## per engagement. Healing keeps its own rule in reward_heal().
static func reward_combat_pairs(state: BattleState, attacker: UnitState, defender: UnitState) -> void:
	var amount := int(DataRegistry.rule("bond_points_combat_action", 2))
	for pair in DataRegistry.all_bond_pairs():
		for participant in [attacker, defender]:
			if participant == null or _other_member_id(pair, participant.id) == "":
				continue
			# Pairs only earn points for player-side engagements ("cùng phe người chơi").
			# F2: partner lookups stay instance-id based; pairs are template-level data but
		# player instances carry the template id as their instance id.
			if participant.side != "player":
				continue
			var other_id := _other_member_id(pair, participant.id)
			var ally: UnitState = state.units.get(other_id, null)
			if ally != null and ally.alive and ally.side == "player" \
					and RangeHandler.manhattan(ally.pos, participant.pos) == 1:
				add_points(state, pair, amount)
				break


## Heal is a valid support action between pair members (explicit, distance-independent:
## heal range is a skill stat, not a bond rule).
static func reward_heal(state: BattleState, healer: UnitState, target: UnitState) -> void:
	var pair := eligible_pair_for(state, healer.id, target.id)
	if pair != null:
		add_points(state, pair, int(DataRegistry.rule("bond_points_combat_action", 2)))


static func _other_member_id(pair: Resource, unit_id: String) -> String:
	if String(pair.unit_a) == unit_id:
		return String(pair.unit_b)
	if String(pair.unit_b) == unit_id:
		return String(pair.unit_a)
	return ""


static func pair_contains_units(pair: Resource, participants: Array) -> bool:
	var ids := {}
	for u in participants:
		ids[u.id] = true
	for u in participants:
		var other := String(pair.unit_b) if String(pair.unit_a) == u.id else String(pair.unit_a) if String(pair.unit_b) == u.id else ""
		if other != "" and ids.has(other):
			return true
	return false
