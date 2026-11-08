extends RefCounted
class_name PassiveSystem
## Class passives (F-PAS; GDD core-combat Core Rule 11 + Authored Passive Catalog). Each unit
## carries its class's passive_id; the numbers live in rules_config.passive_catalog and this
## file implements one branch per effect_type. CombatResolver, the commands and the director
## call the hooks below at the GDD trigger points; scenes never touch passives directly.


## Catalog entry of the unit's passive ({} when it has none).
static func params(unit: UnitState) -> Dictionary:
	if unit == null or unit.passive_id == "":
		return {}
	var catalog: Dictionary = DataRegistry.rule("passive_catalog", {})
	return catalog.get(unit.passive_id, {})


static func effect(unit: UnitState) -> String:
	return String(params(unit).get("effect_type", ""))


static func _hp_ratio_at_least(unit: UnitState, ratio: float) -> bool:
	return unit.max_hp > 0 and float(unit.hp) >= float(unit.max_hp) * ratio


# ------------------------------------------------------------ formula terms (previewed)

## extended_range: +bonus max range while HP >= min_hp_ratio (Magic Swordsman).
static func extra_range(unit: UnitState) -> int:
	var p := params(unit)
	if String(p.get("effect_type", "")) != "extended_range":
		return 0
	return int(p.get("bonus", 0)) if _hp_ratio_at_least(unit, float(p.get("min_hp_ratio", 1.0))) else 0


## adjacency_aura_avoid: Avoid bonus `defender` gets from every OTHER cardinally adjacent ally
## of its side whose passive is the aura (Bard). Live position check, no bond needed.
static func aura_avoid(state: BattleState, defender: UnitState) -> int:
	var total := 0
	for u in state.alive_units():
		if u.id == defender.id or u.side != defender.side:
			continue
		if RangeHandler.manhattan(u.pos, defender.pos) != 1:
			continue
		var p := params(u)
		if String(p.get("effect_type", "")) == "adjacency_aura_avoid":
			total += int(p.get("bonus", 0))
	return total


## ignore_defender_terrain: attacking from exactly the weapon's max range (Gunner).
static func ignores_terrain(attacker: UnitState, defender: UnitState) -> bool:
	return effect(attacker) == "ignore_defender_terrain" \
			and RangeHandler.manhattan(attacker.pos, defender.pos) == attacker.attack_range_max


## force_double (designer version): two strikes back to back before any counter (Lancer).
static func forces_double(attacker: UnitState) -> bool:
	return effect(attacker) == "force_double"


## suppress_retaliation: no counter while the target has not acted yet this phase (Assassin).
static func suppresses_retaliation(attacker: UnitState, defender: UnitState) -> bool:
	return effect(attacker) == "suppress_retaliation" and not defender.acted


## burst_damage: bonus on the first strike of the phase's first Attack (Magician).
static func burst_bonus(attacker: UnitState) -> int:
	var p := params(attacker)
	if String(p.get("effect_type", "")) != "burst_damage" or not attacker.fragile_circle_ready:
		return 0
	return int(p.get("bonus", 0))


# ------------------------------------------------------------ exchange side effects

## Called by CombatResolver.execute when an Attack is committed: the Magician's flag is spent
## whether or not the strike lands.
static func on_attack_committed(attacker: UnitState) -> void:
	if effect(attacker) == "burst_damage":
		attacker.fragile_circle_ready = false


## survive_once (designer version): the first time the unit would die in this battle — from any
## combat damage, attacking or defending — it stays at 1 HP. Returns the damage to apply.
static func guard_lethal(unit: UnitState, damage: int) -> int:
	if effect(unit) != "survive_once" or unit.miracle_used or damage < unit.hp:
		return damage
	unit.miracle_used = true
	return maxi(unit.hp - 1, 0)


## After one landed strike by `striker` on `target` (attacker side of the exchange only).
static func on_attacker_hit(striker: UnitState, target: UnitState, damage: int) -> void:
	var p := params(striker)
	match String(p.get("effect_type", "")):
		"debuff_target_stat":
			target.active_debuffs[String(p.get("stat", "defense"))] = {
				"amount": int(p.get("amount", 0)), "turns_remaining": int(p.get("duration", 0)),
			}
		"lifesteal":
			if striker.alive:
				striker.heal(int(floor(float(damage) * float(p.get("ratio", 0.0)))))


## thorns_damage: a defender that was at >= min_hp_ratio when the exchange began and is still
## alive deals flat damage to the attacker. Returns the strike entry for the combat screen, or {}.
static func thorns(defender: UnitState, attacker: UnitState, defender_hp_at_start: int) -> Dictionary:
	var p := params(defender)
	if String(p.get("effect_type", "")) != "thorns_damage" or not defender.alive or not attacker.alive:
		return {}
	if float(defender_hp_at_start) < float(defender.max_hp) * float(p.get("min_hp_ratio", 1.0)):
		return {}
	var amount := guard_lethal(attacker, int(p.get("damage", 0)))
	attacker.take_damage(amount)
	return {
		"side": "counter", "attacker_id": defender.id, "target_id": attacker.id, "hit": true,
		"crit": false, "damage": amount, "target_hp_after": attacker.hp,
		"slain": attacker.id if attacker.hp == 0 else "", "effect": "thorns",
	}


# ------------------------------------------------------------ forecast preview

## Passives that apply to this exchange, as data for the forecast panel (F-PAS preview):
## [{owner: "attacker"|"defender", name, effect_type, value, ...}]. `plan` is the strike plan
## the same exchange would run, so per-hit numbers match execution.
static func forecast_notes(state: BattleState, attacker: UnitState, defender: UnitState, plan: Dictionary) -> Array:
	var notes: Array = []
	var p := params(attacker)
	var first_damage := 0
	for entry in plan.get("sequence", []):
		if String(entry["side"]) == "attacker":
			first_damage = int(entry["damage"])
			break
	match String(p.get("effect_type", "")):
		"debuff_target_stat":
			notes.append(_note("attacker", attacker, int(p.get("amount", 0)), {"stat": String(p.get("stat", "")), "turns": int(p.get("duration", 0))}))
		"lifesteal":
			notes.append(_note("attacker", attacker, int(floor(float(first_damage) * float(p.get("ratio", 0.0))))))
		"force_double":
			notes.append(_note("attacker", attacker, 2))
		"ignore_defender_terrain":
			if ignores_terrain(attacker, defender):
				notes.append(_note("attacker", attacker, state.terrain_avoid_at(defender.pos)))
		"burst_damage":
			if burst_bonus(attacker) > 0:
				notes.append(_note("attacker", attacker, burst_bonus(attacker)))
		"suppress_retaliation":
			if suppresses_retaliation(attacker, defender):
				notes.append(_note("attacker", attacker, 0))
		"flat_self_heal":
			notes.append(_note("attacker", attacker, int(p.get("amount", 0))))
	var q := params(defender)
	if String(q.get("effect_type", "")) == "thorns_damage" \
			and float(defender.hp) >= float(defender.max_hp) * float(q.get("min_hp_ratio", 1.0)):
		notes.append(_note("defender", defender, int(q.get("damage", 0))))
	# Effects either side can carry into this exchange.
	for side in ["attacker", "defender"]:
		var unit: UnitState = attacker if side == "attacker" else defender
		if effect(unit) == "survive_once" and not unit.miracle_used:
			notes.append(_note(side, unit, 1))
		if extra_range(unit) > 0 and (side == "attacker" or bool(plan.get("can_counter", false))):
			notes.append(_note(side, unit, extra_range(unit)))
		var aura := aura_avoid(state, unit)
		if aura > 0:
			notes.append({"owner": side, "name": _catalog_name("adjacency_aura_avoid"), "effect_type": "adjacency_aura_avoid", "value": aura})
		for field in unit.active_debuffs:
			var entry: Dictionary = unit.active_debuffs[field]
			notes.append({"owner": side, "name": "", "effect_type": "active_debuff", "value": int(entry.get("amount", 0)),
					"stat": String(field), "turns": int(entry.get("turns_remaining", 0))})
	return notes


static func _note(owner: String, unit: UnitState, value: int, extra: Dictionary = {}) -> Dictionary:
	var note := {"owner": owner, "name": String(params(unit).get("name", unit.passive_id)), "effect_type": effect(unit), "value": value}
	note.merge(extra)
	return note


## Display name of the first catalog passive with this effect type (e.g. the Bard aura).
static func _catalog_name(effect_type: String) -> String:
	var catalog: Dictionary = DataRegistry.rule("passive_catalog", {})
	for pid in catalog:
		if String((catalog[pid] as Dictionary).get("effect_type", "")) == effect_type:
			return String((catalog[pid] as Dictionary).get("name", pid))
	return effect_type


# ------------------------------------------------------------ action / phase hooks

## After the unit performed an Attack or a Heal ("attack" / "heal"): flat_self_heal on the actor,
## grant_target_exp on the healed ally (another unit, never self).
static func on_action_performed(state: BattleState, unit: UnitState, action: String, target: UnitState) -> void:
	var p := params(unit)
	match String(p.get("effect_type", "")):
		"flat_self_heal":
			if unit.alive and (action == "attack" or action == "heal"):
				unit.heal(int(p.get("amount", 0)))
		"grant_target_exp":
			if action == "heal" and target != null and target.id != unit.id and target.alive:
				ExpSystem.resolve_level_up(state, target, int(p.get("exp", 0)))


## The unit just went Ready -> Acted: its debuffs count down one turn (F-CC11).
static func on_unit_acted(unit: UnitState) -> void:
	for field in unit.active_debuffs.keys():
		var entry: Dictionary = unit.active_debuffs[field]
		entry["turns_remaining"] = int(entry.get("turns_remaining", 0)) - 1
		if int(entry["turns_remaining"]) <= 0:
			unit.active_debuffs.erase(field)


## A side's phase begins: the Magician's burst is ready only if it starts the phase at full HP;
## everyone else's flag is cleared (the flag is phase-local).
static func on_phase_started(state: BattleState, side: String) -> void:
	for u in state.units.values():
		u.fragile_circle_ready = u.side == side and u.alive and effect(u) == "burst_damage" and u.hp >= u.max_hp
