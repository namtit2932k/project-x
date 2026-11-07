extends RefCounted
class_name CombatResolver
## The one and only combat calculation. Forecast is a dry-run of the same math execute() uses;
## the combat screen, post-battle HP and AI all consume the same numbers. Never duplicate this math.

## Dry-run forecast: expected strike sequence with hit/crit percentages and damage figures.
static func forecast(state: BattleState, attacker: UnitState, defender: UnitState) -> Dictionary:
	return _strike_plan(state, attacker, defender)


## Executes combat, mutating state; returns strikes for the combat screen to play back.
static func execute(state: BattleState, attacker: UnitState, defender: UnitState) -> Array:
	var plan := _strike_plan(state, attacker, defender)
	var strikes: Array = []
	for entry in plan["sequence"]:
		var a: UnitState = attacker if entry["side"] == "attacker" else defender
		var d: UnitState = defender if entry["side"] == "attacker" else attacker
		if not a.alive or not d.alive:
			continue
		var chance := int(entry["hit_pct"])
		var hit := state.rng().randi_range(1, 100) <= chance
		if not hit:
			strikes.append({
				"side": entry["side"], "attacker_id": a.id, "target_id": d.id,
				"hit": false, "crit": false, "damage": 0, "target_hp_after": d.hp, "slain": "",
			})
			continue
		var crit := state.rng().randi_range(1, 100) <= int(entry["crit_pct"])
		var damage := int(entry["damage"])
		if crit:
			damage = _round_value(int(damage * float(DataRegistry.rule("crit_multiplier", 2.5))))
		damage += state.rng().randi_range(0, int(DataRegistry.rule("damage_flat", 0)))
		d.take_damage(damage)
		strikes.append({
			"side": entry["side"], "attacker_id": a.id, "target_id": d.id,
			"hit": true, "crit": crit, "damage": damage, "target_hp_after": d.hp, "slain": "",
		})
		if d.hp == 0:
			strikes[-1]["slain"] = d.id
	# EXP per D08/P-04: only while rules_config.exp_enabled is on; the campaign that turns
	# it off fills progression via mid-battle points instead (W10). Engagement pays even
	# when the target avoids, the killer takes exp_gain_kill, and a surviving player defender
	# always pays back to the attacker with exp_gain_nonlethal_loss.
	if bool(DataRegistry.rule("exp_enabled", false)) and not strikes.is_empty():
		if attacker.side == "player" and attacker.alive:
			state.exp_gained_set(attacker.id, int(DataRegistry.rule("exp_gain_hit", 10)))
			if defender.hp == 0 and defender.side != "player":
				state.exp_gained_set(attacker.id, int(DataRegistry.rule("exp_gain_kill", 30)))
		if defender.side == "player" and defender.alive:
			state.exp_gained_set(defender.id, int(DataRegistry.rule("exp_gain_nonlethal_loss", 4)))
		_grant_levels(state, attacker)
		_grant_levels(state, defender)
	EventBus.combat_resolved.emit(strikes)
	return strikes


## Spends full exp batches level-ups (D08): every stat in the unit growths rolls the
## configured percent on the battle RNG; gains land in stat_bonus and the live stats.
static func _grant_levels(state: BattleState, unit: UnitState) -> void:
	if unit.side != "player":
		return
	var per_level := int(DataRegistry.rule("exp_per_level", 100))
	var level_cap := int(DataRegistry.rule("level_cap", 20))
	while unit.exp >= per_level and unit.level < level_cap:
		unit.exp -= per_level
		unit.level += 1
		var roll_gains: Dictionary = {}
		for stat_id in unit.growths:
			var chance := clampi(int(unit.growths[stat_id]), 0, 100)
			if state.rng().randi_range(1, 100) <= chance:
				unit.apply_stat_gain(String(stat_id), 1)
				roll_gains[String(stat_id)] = int(roll_gains.get(String(stat_id), 0)) + 1
		state.level_ups.append({"unit_id": unit.id, "level": unit.level, "gains": roll_gains.duplicate()})


## Sequence plan (no rng): sides, hit/crit percentages, deterministic damage for each strike.
static func _strike_plan(state: BattleState, attacker: UnitState, defender: UnitState) -> Dictionary:
	var sequence: Array = []
	sequence.append({"side": "attacker", "hit_pct": _hit_pct(state, attacker, defender), "crit_pct": _crit_pct(state, attacker, defender), "damage": _damage(state, attacker, defender)})
	var counter_ok := defender.alive and RangeHandler.can_counter(state, defender, attacker.pos)
	if counter_ok:
		sequence.append({"side": "counter", "hit_pct": _hit_pct(state, defender, attacker), "crit_pct": _crit_pct(state, defender, attacker), "damage": _damage(state, defender, attacker)})
	var gap := int(DataRegistry.rule("double_threshold", 4))
	if attacker.speed - defender.speed >= gap:
		sequence.append({"side": "attacker", "hit_pct": _hit_pct(state, attacker, defender), "crit_pct": _crit_pct(state, attacker, defender), "damage": _damage(state, attacker, defender)})
	elif counter_ok and defender.speed - attacker.speed >= gap:
		sequence.append({"side": "counter", "hit_pct": _hit_pct(state, defender, attacker), "crit_pct": _crit_pct(state, defender, attacker), "damage": _damage(state, defender, attacker)})
	return {
		"sequence": sequence,
		"can_counter": counter_ok,
	}


## F-CC5 (approved GDD): Damage = offense_stat + weapon_might - defense_stat + bond bonus,
## floored at min_damage. Physical uses Str/Def, magic uses Mag/Res. Terrain no longer feeds
## damage (terrain only feeds Avoid, F-CC2) — terrain_defs.def_bonus is legacy/unused here.
static func _damage(state: BattleState, attacker: UnitState, defender: UnitState) -> int:
	var is_magic := attacker.damage_type == "magic"
	var offense := int(attacker.magic) if is_magic else int(attacker.power)
	var defense_stat := int(defender.resistance) if is_magic else int(defender.defense)
	var weapon: Resource = DataRegistry.get_weapon(attacker.weapon_id)
	var weapon_might := int(weapon.weapon_might) if weapon != null else 0
	var bonus := BondSystem.stat_bonus(state, attacker, "power")
	var raw := offense + weapon_might - defense_stat + bonus
	return maxi(_round_value(raw), int(DataRegistry.rule("min_damage", 0)))


static func _round_value(value: int) -> int:
	match String(DataRegistry.rule("rounding", "floor")):
		"round":
			return int(round(float(value)))
		"ceil":
			return int(ceil(float(value)))
		_:
			return value


static func _round_damage(value: float) -> int:
	return _round_value(int(value))


## F-CC1/F-CC2/F-CC3 (approved GDD): Hit% = clamp(Accuracy - Avoid, 0, 100). No base-100 term,
## no variance spread — a direct subtraction. P-02: bond bonus feeds both sides (accuracy/avoid).
static func _hit_pct(state: BattleState, a: UnitState, d: UnitState) -> int:
	var accuracy := _accuracy(state, a)
	var avoid := _avoid(state, d)
	return clampi(int(round(accuracy - avoid)), 0, 100)


static func _accuracy(state: BattleState, a: UnitState) -> float:
	var skill_mult := float(DataRegistry.rule("accuracy_skill_mult", 2.0))
	var luck_mult := float(DataRegistry.rule("accuracy_luck_mult", 0.5))
	var weapon: Resource = DataRegistry.get_weapon(a.weapon_id)
	var weapon_accuracy_mod := int(weapon.weapon_accuracy_mod) if weapon != null else 0
	var support := BondSystem.stat_bonus(state, a, "hit")
	return a.skill * skill_mult + a.luck * luck_mult + a.hit_bonus + weapon_accuracy_mod + support


static func _avoid(state: BattleState, d: UnitState) -> float:
	var speed_mult := float(DataRegistry.rule("avoid_speed_mult", 2.0))
	var luck_mult := float(DataRegistry.rule("avoid_luck_mult", 0.5))
	var support := BondSystem.stat_bonus(state, d, "avoid")
	return d.speed * speed_mult + d.luck * luck_mult + state.terrain_avoid_at(d.pos) + support


## F-CC4 (approved GDD): Crit% = clamp(skill*0.5 + weapon_crit_mod - defender.luck*0.5 + bond, 0, 100).
static func _crit_pct(state: BattleState, a: UnitState, d: UnitState) -> int:
	var skill_mult := float(DataRegistry.rule("crit_skill_mult", 0.5))
	var luck_mult := float(DataRegistry.rule("crit_luck_mult", 0.5))
	var weapon: Resource = DataRegistry.get_weapon(a.weapon_id)
	var weapon_crit_mod := int(weapon.weapon_crit_mod) if weapon != null else 0
	var support := BondSystem.stat_bonus(state, a, "crit")
	var raw := a.skill * skill_mult + a.crit_bonus + weapon_crit_mod - d.luck * luck_mult + support
	return clampi(int(round(raw)), 0, 100)
