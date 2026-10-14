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
	var defender_was_hit := false
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
		if d is UnitState and d != attacker and entry["side"] == "attacker":
			defender_was_hit = true
		strikes.append({
			"side": entry["side"], "attacker_id": a.id, "target_id": d.id,
			"hit": true, "crit": crit, "damage": damage, "target_hp_after": d.hp, "slain": "",
		})
		if d.hp == 0:
			strikes[-1]["slain"] = d.id
	# EXP (placeholders from rules config).
	if not strikes.is_empty():
		attacker.exp += int(DataRegistry.rule("exp_gain_hit", 10))
		if defender.hp == 0:
			attacker.exp += int(DataRegistry.rule("exp_gain_kill", 30))
		elif defender_was_hit:
			defender.exp += int(DataRegistry.rule("exp_gain_nonlethal_loss", 4))
	EventBus.combat_resolved.emit(strikes)
	return strikes


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
	var bonus := BondSystem.support_attack_bonus(state, attacker)
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
	var support := BondSystem.support_attack_bonus(state, a)
	var raw := base + a.hit_bonus + a.skill * skill_scale + support - (d.speed * avoid_scale + state.terrain_avoid_at(d.pos))
	# Deterministic display uses the mean variance; rolls add +/- variance in execute? No:
	# execute rolls dice for hit/crit outcomes only; variance applies to damage rolls.
	return clampi(raw - variance / 2, 0, 100)


static func _crit_pct(state: BattleState, a: UnitState, d: UnitState) -> int:
	var base := int(DataRegistry.rule("crit_base", 5))
	var scale := int(DataRegistry.rule("crit_scale_skill", 2))
	var raw := base + a.crit_bonus + a.skill * scale - d.speed
	return clampi(raw, 0, 100)
