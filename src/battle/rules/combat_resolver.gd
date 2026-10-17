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
			damage = int(round(damage * float(DataRegistry.rule("crit_multiplier", 2.0))))
		damage += state.rng().randi_range(0, int(DataRegistry.rule("damage_flat", 0)))
		d.take_damage(damage)
		strikes.append({
			"side": entry["side"], "attacker_id": a.id, "target_id": d.id,
			"hit": true, "crit": crit, "damage": damage, "target_hp_after": d.hp, "slain": "",
		})
		if d.hp == 0:
			strikes[-1]["slain"] = d.id
	# EXP per D08: only the player side earns; engagement pays even when the target avoids,
	# the killer takes exp_gain_kill, and a surviving player defender always pays back to the
	# attacker with exp_gain_nonlethal_loss (the old "must be hit" requirement is gone).
	if not strikes.is_empty():
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
	var gap := int(DataRegistry.rule("double_attack_speed_gap", 5))
	if attacker.speed - defender.speed >= gap:
		sequence.append({"side": "attacker", "hit_pct": _hit_pct(state, attacker, defender), "crit_pct": _crit_pct(state, attacker, defender), "damage": _damage(state, attacker, defender)})
	elif counter_ok and defender.speed - attacker.speed >= gap:
		sequence.append({"side": "counter", "hit_pct": _hit_pct(state, defender, attacker), "crit_pct": _crit_pct(state, defender, attacker), "damage": _damage(state, defender, attacker)})
	return {
		"sequence": sequence,
		"can_counter": counter_ok,
	}


## Damage by formula id (rules_config.damage_formula_id, default "atk_minus_def") with the
## configured rounding; new formulas are designer-selectable without touching call sites.
static func _damage(state: BattleState, attacker: UnitState, defender: UnitState) -> int:
	var scaling := int(defender.defense) if attacker.damage_type == "physical" else int(defender.resistance)
	# D05: the bond adjacency bonus lands on the stat chosen by rules_config.bond_bonus_stat
	# (default "power" = damage); it only enters the formula that owns that stat.
	var bonus := BondSystem.stat_bonus(state, attacker, "power")
	var raw := 0
	match String(DataRegistry.rule("damage_formula_id", "atk_minus_def")):
		"atk_minus_def":
			raw = attacker.power + bonus - (scaling + state.terrain_def_at(defender.pos))
		_:
			push_warning("CombatResolver: unknown damage_formula_id, fallback atk_minus_def")
			raw = attacker.power + bonus - (scaling + state.terrain_def_at(defender.pos))
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


static func _hit_pct(state: BattleState, a: UnitState, d: UnitState) -> int:
	var base := int(DataRegistry.rule("hit_base", 100))
	var skill_scale := int(DataRegistry.rule("hit_scale_skill", 3))
	var avoid_scale := int(DataRegistry.rule("hit_scale_speed_avoid", 2))
	var variance := int(DataRegistry.rule("hit_variance", 10))
	# D05: bond bonus no longer feeds accuracy (only the bond_bonus_stat damage entry does).
	var support := BondSystem.stat_bonus(state, a, "hit")
	var raw := base + a.hit_bonus + a.skill * skill_scale + support - (d.speed * avoid_scale + state.terrain_avoid_at(d.pos))
	# Deterministic display uses the mean variance; rolls add +/- variance in execute? No:
	# execute rolls dice for hit/crit outcomes only; variance applies to damage rolls.
	return clampi(raw - variance / 2, 0, 100)


static func _crit_pct(state: BattleState, a: UnitState, d: UnitState) -> int:
	var base := int(DataRegistry.rule("crit_base", 5))
	var scale := int(DataRegistry.rule("crit_scale_skill", 2))
	var raw := base + a.crit_bonus + a.skill * scale - d.speed
	return clampi(raw, 0, 100)
