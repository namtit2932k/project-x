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
