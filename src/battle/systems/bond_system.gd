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


## Rewards every eligible pair whose members both participated (one member attacked in combat
## and the other is adjacent to either combatant alive at combat time).
static func reward_combat_pairs(state: BattleState, attacker: UnitState, defender: UnitState) -> void:
	# Bond points come from valid actions between pair members on the same side. Combat itself
	# is only a bond action through the SUPPORT: an adjacent pair-member ally of the attacker.
	# Rewarding attacker-vs-defender membership directly would reward enemy connections only
	# (both sides of a strike are of opposing sides), which never matches a designer pair.
	reward_support_actions(state, attacker)


## Support rewards: for each pair containing `actor`, the other member is an alive same-side
## ally adjacent to the actor -> +points (attack from an adjacent partner, or being healed).
static func reward_support_actions(state: BattleState, actor: UnitState) -> void:
	var amount := int(DataRegistry.rule("bond_points_combat_action", 2))
	for pair in DataRegistry.all_bond_pairs():
		var other_id := _other_member_id(pair, actor.id)
		if other_id == "":
			continue
		var ally: UnitState = state.units.get(other_id, null)
		if ally != null and ally.alive and ally.side == actor.side \
				and RangeHandler.manhattan(ally.pos, actor.pos) == 1:
			add_points(state, pair, amount)


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
