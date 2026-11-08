extends RefCounted
class_name CombatResolver
## The one and only combat calculation. Forecast is a dry-run of the same math execute() uses;
## the combat screen, post-battle HP and AI all consume the same numbers. Never duplicate this math.
## Class passives (F-PAS) enter here through PassiveSystem: formula terms in the plan (so the
## forecast shows them), side effects in execute().

## Dry-run forecast: expected strike sequence with hit/crit percentages and damage figures.
static func forecast(state: BattleState, attacker: UnitState, defender: UnitState) -> Dictionary:
	return _strike_plan(state, attacker, defender)


## Executes combat, mutating state; returns strikes for the combat screen to play back.
static func execute(state: BattleState, attacker: UnitState, defender: UnitState) -> Array:
	var plan := _strike_plan(state, attacker, defender)
	var strikes: Array = []
	var defender_hp_at_start: int = defender.hp
	# F-PAS burst_damage: the Magician's phase flag is spent by committing the Attack, hit or miss.
	PassiveSystem.on_attack_committed(attacker)
	for entry in plan["sequence"]:
		var attacker_side: bool = entry["side"] == "attacker"
		var a: UnitState = attacker if attacker_side else defender
		var d: UnitState = defender if attacker_side else attacker
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
			damage = _round_value(int(damage * float(DataRegistry.rule("crit_multiplier", 3.0))))
		damage += state.rng().randi_range(0, int(DataRegistry.rule("damage_flat", 0)))
		# F-PAS survive_once: the Wyvern Knight's first death in the battle is undone at 1 HP.
		var applied := PassiveSystem.guard_lethal(d, damage)
		d.take_damage(applied)
		strikes.append({
			"side": entry["side"], "attacker_id": a.id, "target_id": d.id,
			"hit": true, "crit": crit, "damage": applied, "target_hp_after": d.hp, "slain": "",
			"survived": applied < damage,
		})
		if d.hp == 0:
			strikes[-1]["slain"] = d.id
		if attacker_side:
			# F-PAS debuff_target_stat / lifesteal: the attacker's landed strikes.
			PassiveSystem.on_attacker_hit(a, d, damage)
	# F-PAS thorns_damage: a healthy defender that survived hits back for a flat amount.
	var thorn := PassiveSystem.thorns(defender, attacker, defender_hp_at_start)
	if not thorn.is_empty():
		strikes.append(thorn)
	# F-CC13 (F-EXP): performing the Attack pays the acting unit a flat EXP — hit, miss, crit
	# or kill alike. The defender earns nothing for being attacked; enemies never earn.
	if not strikes.is_empty():
		ExpSystem.grant_action_exp(state, attacker)
		PassiveSystem.on_action_performed(state, attacker, "attack", defender)
	EventBus.combat_resolved.emit(strikes)
	return strikes


## Sequence plan (no rng): sides, hit/crit percentages, deterministic damage for each strike.
static func _strike_plan(state: BattleState, attacker: UnitState, defender: UnitState) -> Dictionary:
	var sequence: Array = []
	# F-PAS burst_damage: first strike of the exchange only.
	sequence.append(_entry(state, "attacker", attacker, defender, PassiveSystem.burst_bonus(attacker)))
	# F-PAS Lancer (designer): always two strikes back to back, before any counter.
	var lancer := PassiveSystem.forces_double(attacker)
	if lancer:
		sequence.append(_entry(state, "attacker", attacker, defender))
	# F-PAS suppress_retaliation: no counter against an Assassin while the target is still Ready.
	var counter_ok := defender.alive and RangeHandler.can_counter(state, defender, attacker.pos) \
			and not PassiveSystem.suppresses_retaliation(attacker, defender)
	if counter_ok:
		sequence.append(_entry(state, "counter", defender, attacker))
	var gap := int(DataRegistry.rule("double_threshold", 4))
	# F-CC7: each side's doubling check is independent (a Lancer already struck twice).
	if not lancer and attacker.eff("speed") - defender.eff("speed") >= gap:
		sequence.append(_entry(state, "attacker", attacker, defender))
	if counter_ok and defender.eff("speed") - attacker.eff("speed") >= gap:
		sequence.append(_entry(state, "counter", defender, attacker))
	return {
		"sequence": sequence,
		"can_counter": counter_ok,
	}


static func _entry(state: BattleState, side: String, a: UnitState, d: UnitState, extra_damage: int = 0) -> Dictionary:
	return {"side": side, "hit_pct": _hit_pct(state, a, d), "crit_pct": _crit_pct(state, a, d), "damage": _damage(state, a, d, extra_damage)}


## F-CC5 (approved GDD): Damage = offense_stat + weapon_might - defense_stat + bond bonus
## (+ Magician burst), floored at min_damage. Physical uses Str/Def, magic uses Mag/Res; stats
## are read through eff() so a passive debuff counts. Terrain does not feed damage.
static func _damage(state: BattleState, attacker: UnitState, defender: UnitState, extra: int = 0) -> int:
	var is_magic := attacker.damage_type == "magic"
	var offense := attacker.eff("magic") if is_magic else attacker.eff("power")
	var defense_stat := defender.eff("resistance") if is_magic else defender.eff("defense")
	var weapon: Resource = DataRegistry.get_weapon(attacker.weapon_id)
	var weapon_might := int(weapon.weapon_might) if weapon != null else 0
	var bonus := BondSystem.stat_bonus(state, attacker, "power")
	var raw := offense + weapon_might - defense_stat + bonus + extra
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


## F-CC1/F-CC2/F-CC3 + F-CC-FE: Hit% = clamp(Accuracy - Avoid, 0, 100), Accuracy includes hit_base (FE weapon Hit stand-in),
## no variance spread — a direct subtraction. P-02: bond bonus feeds both sides (accuracy/avoid).
static func _hit_pct(state: BattleState, a: UnitState, d: UnitState) -> int:
	var accuracy := _accuracy(state, a)
	var avoid := _avoid(state, a, d)
	return clampi(int(round(accuracy - avoid)), 0, 100)


static func _accuracy(state: BattleState, a: UnitState) -> float:
	var skill_mult := float(DataRegistry.rule("accuracy_skill_mult", 2.0))
	var luck_mult := float(DataRegistry.rule("accuracy_luck_mult", 0.5))
	var weapon: Resource = DataRegistry.get_weapon(a.weapon_id)
	var weapon_accuracy_mod := int(weapon.weapon_accuracy_mod) if weapon != null else 0
	var support := BondSystem.stat_bonus(state, a, "hit")
	# F-CC-FE: hit_base plays the role of Fire Emblem's weapon Hit stat (70 for every weapon).
	var hit_base := int(DataRegistry.rule("hit_base", 70))
	return hit_base + a.eff("skill") * skill_mult + a.eff("luck") * luck_mult + a.hit_bonus + weapon_accuracy_mod + support


## Avoid of `d` against attacker `a`: terrain drops out for a Gunner shooting from max range,
## and an adjacent Bard's aura adds to it (F-PAS).
static func _avoid(state: BattleState, a: UnitState, d: UnitState) -> float:
	var speed_mult := float(DataRegistry.rule("avoid_speed_mult", 2.0))
	var luck_mult := float(DataRegistry.rule("avoid_luck_mult", 1.0))
	var support := BondSystem.stat_bonus(state, d, "avoid")
	var terrain := 0 if PassiveSystem.ignores_terrain(a, d) else state.terrain_avoid_at(d.pos)
	return d.eff("speed") * speed_mult + d.eff("luck") * luck_mult + terrain + support + PassiveSystem.aura_avoid(state, d)


## F-CC4 + F-CC-FE: Crit% = clamp(skill*0.5 + weapon_crit_mod - defender.luck*1 + bond, 0, 100).
static func _crit_pct(state: BattleState, a: UnitState, d: UnitState) -> int:
	var skill_mult := float(DataRegistry.rule("crit_skill_mult", 0.5))
	var luck_mult := float(DataRegistry.rule("crit_luck_mult", 1.0))
	var weapon: Resource = DataRegistry.get_weapon(a.weapon_id)
	var weapon_crit_mod := int(weapon.weapon_crit_mod) if weapon != null else 0
	var support := BondSystem.stat_bonus(state, a, "crit")
	var raw := a.eff("skill") * skill_mult + a.crit_bonus + weapon_crit_mod - d.eff("luck") * luck_mult + support
	return clampi(int(round(raw)), 0, 100)
