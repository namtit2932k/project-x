class_name CoreCombat
extends RefCounted
## Core Combat System — action-economy slice (Core Rule 3/3a: Ready/Acted
## state, unit positions, Trade, legal_actions()) plus F-CC1-CC7's pure
## exchange-math formulas (Accuracy/Avoid/Hit%/Crit%/Damage/CritDamage/
## Doubling), preview_attack_exchange() (Core Rule 4's exchange shape,
## preview only), and F-CC9/F-CC10's healing formulas (heal_preview(),
## use_item_preview(), resolve_use_item()). bond_bonus (Bond/Adjacency) and
## terrain_combat_modifier (Battle/Map) are caller-supplied parameters,
## never resolved internally — neither system's catalog is read from here,
## keeping this class decoupled. current_HP/max_HP (F-CC9/CC10's "battle
## state"/"unit stat block" sources) are likewise caller-supplied — this
## class does not itself track a per-unit current-HP battle state.
##
## NOT implemented: actual dice resolution (would need injectable
## randomness — deferred until a caller needs it), the Restraint Rule
## (Protect/Persuade AI doesn't exist in code), and death's life_status
## write-back (Unit/Roster Story 003's job, not this system's).
##
## Plain instantiable class, not an autoload — same dependency-injection
## convention as UnitRoster/BattleMap.

const READY := "Ready"
const ACTED := "Acted"
const CRIT_MULTIPLIER := 2.5
const DOUBLE_THRESHOLD := 4

## unit_id -> { "tile": Vector2i, "state": "Ready"|"Acted", "traded_this_phase": bool }
var _units: Dictionary = {}


## Registers a unit's battle-scoped position and resets it to Ready. Called
## once per unit at Setup/phase-start — this class does not decide deployment
## rules (Battle/Map's scope), only records the resulting position.
func set_position(unit_id: String, tile: Vector2i) -> void:
	if not _units.has(unit_id):
		_units[unit_id] = {"tile": tile, "state": READY, "traded_this_phase": false}
	else:
		_units[unit_id]["tile"] = tile


func position_of(unit_id: String) -> Vector2i:
	return _units.get(unit_id, {}).get("tile", Vector2i.ZERO)


func action_state_of(unit_id: String) -> String:
	return _units.get(unit_id, {}).get("state", "")


## Core Rule 3 — "Acting transitions a unit from Ready to Acted."
func mark_acted(unit_id: String) -> void:
	if _units.has(unit_id):
		_units[unit_id]["state"] = ACTED


## New Player Phase: every unit returns to Ready and each unit's one-Trade
## allowance refreshes (Core Rule 3a: "until its next Ready phase").
func reset_phase() -> void:
	for unit_id in _units:
		_units[unit_id]["state"] = READY
		_units[unit_id]["traded_this_phase"] = false


## Manhattan distance — the same tile-distance metric Trade (Core Rule 3a),
## Bond/Adjacency (F-BA1), and every other project distance check uses.
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## AC-CC21 — "attack rejected outside post-move weapon range." True if
## target_id's tile is within [range_pair[0], range_pair[1]] tiles of
## unit_id's tile (Manhattan distance — Core Combat names no other metric
## anywhere, and every other project distance check uses this one). Both
## units must be registered via set_position(). Works identically for
## weapon_range (Attack) and heal_range (Heal) — same [min,max] shape.
func target_in_range(unit_id: String, target_id: String, range_pair: Array) -> bool:
	if not _units.has(unit_id) or not _units.has(target_id):
		return false
	var distance := _manhattan_distance(position_of(unit_id), position_of(target_id))
	return distance >= range_pair[0] and distance <= range_pair[1]


## AC-CC45/48/49/50 — Core Rule 3a's full Trade legality, independent of
## whether it would actually move any items (Edge Case: empty-for-empty is
## still a legal, consuming no-op).
func can_trade(unit_a_id: String, unit_b_id: String, roster: UnitRoster) -> bool:
	if not _units.has(unit_a_id) or not _units.has(unit_b_id):
		return false
	if action_state_of(unit_a_id) != READY:
		return false
	if _units[unit_a_id]["traded_this_phase"]:
		return false
	if not roster.has_unit(unit_b_id):
		return false  # AC-CC50 — enemy/non-roster targets carry no carried_items field
	var target_record := roster.get_unit_record(unit_b_id)
	if target_record["life_status"] != "Active":
		return false
	return _manhattan_distance(position_of(unit_a_id), position_of(unit_b_id)) == 1


## AC-CC46/47 — swaps (or one-directionally gifts, when one side is empty)
## carried_items via UnitRoster. Does NOT call mark_acted() — Trade never
## consumes the unit's Action (AC-CC45) — and marks the allowance spent on
## a_id only, matching Core Rule 3a (the initiator's allowance, not the
## target's).
func trade(unit_a_id: String, unit_b_id: String, roster: UnitRoster) -> bool:
	if not can_trade(unit_a_id, unit_b_id, roster):
		return false
	var a_record := roster.get_unit_record(unit_a_id)
	var b_record := roster.get_unit_record(unit_b_id)
	roster.unit_records[unit_a_id]["carried_items"] = b_record["carried_items"]
	roster.unit_records[unit_b_id]["carried_items"] = a_record["carried_items"]
	_units[unit_a_id]["traded_this_phase"] = true
	return true


## Core Rule 3's action list: "Wait" (always legal while Ready), "Use Item"
## (carried_items non-empty — does not yet distinguish healing items from
## other item types, since Weapon/Item's item catalog has no per-item
## "is this a healing item" flag beyond existing at all), "Trade" (any
## in-range Active roster ally, per can_trade()), and — when weapon_item and
## unit_class are supplied — "Attack" (AC-CC21: only if a candidate_enemy_target
## is within the resolved weapon's weapon_range of this unit's current tile)
## or "Heal" (AC-CC44: ally or self within heal_range — self-targeting is
## legal exactly when heal_range[0] <= 0, which target_in_range()'s distance-0
## self-check already expresses with no special case needed). Omitting
## weapon_item/unit_class keeps the pre-Weapon/Item behavior (no Attack/Heal
## entries), so existing callers are unaffected.
func legal_actions(unit_id: String, roster: UnitRoster, candidate_trade_targets: Array[String], weapon_item: WeaponItem = null, unit_class: String = "", candidate_enemy_targets: Array[String] = []) -> Array[String]:
	var actions: Array[String] = []
	if action_state_of(unit_id) != READY:
		return actions
	actions.append("Wait")
	if roster.has_unit(unit_id) and not roster.get_unit_record(unit_id)["carried_items"].is_empty():
		actions.append("Use Item")
	if weapon_item != null and not unit_class.is_empty():
		var weapon_record: Dictionary = weapon_item.weapon_record_for_class(unit_class)
		if weapon_record.get("action_category") == "Combat":
			var weapon_range: Array = weapon_record["weapon_range"]
			for enemy_id in candidate_enemy_targets:
				if target_in_range(unit_id, enemy_id, weapon_range):
					actions.append("Attack")
					break
		elif weapon_record.get("action_category") == "Heal":
			var heal_range: Array = weapon_record["heal_range"]
			var heal_candidates: Array[String] = candidate_trade_targets.duplicate()
			heal_candidates.append(unit_id)  # AC-CC44 — self is a candidate; range gates it
			for ally_id in heal_candidates:
				var is_self: bool = ally_id == unit_id
				if not is_self and (not roster.has_unit(ally_id) or roster.get_unit_record(ally_id)["life_status"] != "Active"):
					continue
				if target_in_range(unit_id, ally_id, heal_range):
					actions.append("Heal")
					break
	for target_id in candidate_trade_targets:
		if can_trade(unit_id, target_id, roster):
			actions.append("Trade")
			break
	return actions


## F-CC1 — Accuracy. bond_bonus defaults to 0 (Bond/Adjacency not wired in
## yet); floored at 0 per the GDD so a negative Accuracy can never
## double-penalize a low-Skill attacker when it later feeds Hit% (F-CC3).
func accuracy(skill: int, luck: int, weapon_accuracy_mod: int, bond_bonus: int = 0) -> int:
	return maxi(0, (skill * 2) + int(luck * 0.5) + weapon_accuracy_mod + bond_bonus)


## F-CC2 — Avoid. terrain_combat_modifier is Battle/Map's per-tile value
## (BattleMap.get_terrain_record(...)["combat_modifier"]) — caller-supplied;
## this class never reads a terrain catalog directly.
func avoid(speed: int, luck: int, terrain_combat_modifier: int, bond_bonus: int = 0) -> int:
	return (speed * 2) + int(luck * 0.5) + terrain_combat_modifier + bond_bonus


## F-CC3 — Hit%. Hard-clamped both ends — the 0 floor means a crushing
## Avoid advantage never shows a negative percentage to the player.
func hit_percent(accuracy_value: int, avoid_value: int) -> int:
	return clampi(accuracy_value - avoid_value, 0, 100)


## F-CC4 — Crit%. defender_luck acts as crit evasion.
func crit_percent(skill: int, weapon_crit_mod: int, defender_luck: int, bond_bonus: int = 0) -> int:
	return clampi(int(skill * 0.5) + weapon_crit_mod - int(defender_luck * 0.5) + bond_bonus, 0, 100)


## F-CC5 — Damage. Caller resolves offense_stat/defense_stat by attack_type
## before calling (Physical: Str/Def; Magic: Mag/Res) — this function is
## type-agnostic, matching the GDD's own single shared formula for both.
## Floored at 0 via max() so a heavily-defended target never "heals" the
## defender through negative damage.
func damage(offense_stat: int, weapon_might: int, defense_stat: int, bond_bonus: int = 0) -> int:
	return maxi(0, offense_stat + weapon_might - defense_stat + bond_bonus)


## F-CC6 — Crit Damage. Rounds DOWN, never up — a crit must never exceed
## what the pre-commit preview promised the player (Pillar 2).
func crit_damage(base_damage: int) -> int:
	return int(floor(base_damage * CRIT_MULTIPLIER))


## F-CC7 — Doubling Check. Equal Speed (diff 0) never doubles.
func attacks_second_time(speed_self: int, speed_opponent: int) -> bool:
	return (speed_self - speed_opponent) >= DOUBLE_THRESHOLD


## Core Rule 4's exchange SHAPE, preview only — no dice are rolled, no HP is
## mutated, no death/life_status write-back happens (Unit/Roster Story 003's
## job). Returns the Hit%/Crit%/Damage/CritDamage a player would see before
## confirming: always a "strike" entry (attacker -> defender); a
## "retaliation" entry whenever the attacker's tile is within the DEFENDER's
## own weapon_range (Core Rule 4's structural retaliation gate) — whether it
## actually fires at resolution time still depends on the defender surviving
## the real roll, exactly as Hit%/Crit% are odds, not guarantees; a "double"
## entry on whichever side's Speed clears DOUBLE_THRESHOLD (mutually
## exclusive — only one side's gap can meet the threshold in a single
## exchange, per the GDD's own note). The Restraint Rule is never applied
## here (Protect/Persuade AI doesn't exist in code yet) — a caller
## integrating that system must cap retaliation damage itself before display.
func preview_attack_exchange(attacker: Dictionary, defender: Dictionary, attacker_weapon: Dictionary, defender_weapon: Dictionary, attacker_terrain_mod: int, defender_terrain_mod: int, attacker_bond_bonus: int = 0, defender_bond_bonus: int = 0) -> Dictionary:
	var preview: Dictionary = {
		"strike": _strike_preview(attacker, defender, attacker_weapon, defender_terrain_mod, attacker_bond_bonus),
	}
	var attacker_in_defender_range: bool = defender_weapon.get("action_category") == "Combat" \
		and target_in_range(defender["unit_id"], attacker["unit_id"], defender_weapon["weapon_range"])
	if attacker_in_defender_range:
		preview["retaliation"] = _strike_preview(defender, attacker, defender_weapon, attacker_terrain_mod, defender_bond_bonus)
	if attacks_second_time(attacker["stats"].speed, defender["stats"].speed):
		preview["double"] = "attacker"
	elif preview.has("retaliation") and attacks_second_time(defender["stats"].speed, attacker["stats"].speed):
		preview["double"] = "defender"
	return preview


## One strike's full preview (Hit%/Crit%/Damage/CritDamage), resolving
## Physical vs. Magic offense/defense stats by the attacking weapon's
## attack_type (F-CC5's own resolution rule).
func _strike_preview(attacker: Dictionary, defender: Dictionary, weapon: Dictionary, defender_terrain_mod: int, bond_bonus: int) -> Dictionary:
	var attacker_stats: UnitStatBlock = attacker["stats"]
	var defender_stats: UnitStatBlock = defender["stats"]
	var offense_stat: int = attacker_stats.str_stat if weapon["attack_type"] == "Physical" else attacker_stats.mag
	var defense_stat: int = defender_stats.def if weapon["attack_type"] == "Physical" else defender_stats.res
	var acc: int = accuracy(attacker_stats.skill, attacker_stats.luck, weapon["weapon_accuracy_mod"], bond_bonus)
	var avo: int = avoid(defender_stats.speed, defender_stats.luck, defender_terrain_mod)
	var base_damage: int = damage(offense_stat, weapon["weapon_might"], defense_stat, bond_bonus)
	return {
		"hit_percent": hit_percent(acc, avo),
		"crit_percent": crit_percent(attacker_stats.skill, weapon["weapon_crit_mod"], defender_stats.luck, bond_bonus),
		"damage": base_damage,
		"crit_damage": crit_damage(base_damage),
	}


## F-CC9 — Heal (Healer class action). Returns {"heal_amount": raw,
## "target_hp_after": clamped, "effective_gain": actual HP restored} — the
## GDD requires showing BOTH the raw HealAmount and the effective
## (deficit-clamped) gain pre-commit (AC-CC35), not just the final HP. A
## fully healthy target legally receives 0 effective healing (GDD's own
## Output Range note) — this function does not reject that case.
func heal_preview(mag_healer: int, heal_might: int, target_current_hp: int, target_max_hp: int) -> Dictionary:
	var raw: int = mag_healer + heal_might
	var hp_after: int = mini(target_current_hp + raw, target_max_hp)
	return {"heal_amount": raw, "target_hp_after": hp_after, "effective_gain": hp_after - target_current_hp}


## F-CC10 — Item Heal (Use Item action). Same shape as heal_preview() but
## item_heal_value is a fixed data-file value, not stat-scaled — "all units
## restore the same HP from the same item type" (GDD's own Output Range
## note). AC-CC36 requires showing both item_heal_value and the effective
## gain pre-commit.
func use_item_preview(item_heal_value: int, current_hp: int, max_hp: int) -> Dictionary:
	var hp_after: int = mini(current_hp + item_heal_value, max_hp)
	return {"item_heal_value": item_heal_value, "hp_after": hp_after, "effective_gain": hp_after - current_hp}


## Resolves Use Item: computes the F-CC10 preview AND consumes the item from
## carried_items (Core Rule 3 — "consumes one item from the slot on
## resolution"; AC-CC30) — the item is consumed regardless of effective gain
## (AC-CC32: still consumed at full HP). Returns {} without consuming
## anything if the unit isn't actually carrying item_id or the item has no
## catalog entry — mirrors can_trade()'s defensive-but-should-be-unreachable
## pattern (a correctly-gated legal_actions() call should never hit this).
func resolve_use_item(unit_id: String, item_id: String, current_hp: int, max_hp: int, weapon_item: WeaponItem, roster: UnitRoster) -> Dictionary:
	if not roster.has_unit(unit_id):
		return {}
	var carried: Array = roster.get_unit_record(unit_id)["carried_items"]
	if not carried.has(item_id):
		return {}
	var item_record: Dictionary = weapon_item.get_item_record(item_id)
	if item_record.is_empty():
		return {}
	var preview: Dictionary = use_item_preview(item_record["item_heal_value"], current_hp, max_hp)
	roster.unit_records[unit_id]["carried_items"].erase(item_id)
	return preview
