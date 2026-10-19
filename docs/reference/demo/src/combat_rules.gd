extends RefCounted
## GDD Core Combat F-CC1 through F-CC7, using authored weapon and map data.

var data: Dictionary
var map: Dictionary
var units: Array[Dictionary]


## Injects the current battle data and live unit list.
func setup(battle_data: Dictionary, map_data: Dictionary, battle_units: Array[Dictionary]) -> void:
	data = battle_data
	map = map_data
	units = battle_units


## Returns the weapon record assigned to a unit's class.
func weapon(unit: Dictionary) -> Dictionary:
	var weapon_id: String = data["class_weapons"][unit["class"]]
	return data["weapons"][weapon_id]


## Returns true when an attacker's weapon can reach a defender from current tiles.
func in_range(attacker: Dictionary, defender: Dictionary) -> bool:
	var w := weapon(attacker)
	if w.get("action_category", "Combat") != "Combat":
		return false
	var distance: int = absi(int(attacker["x"]) - int(defender["x"])) + absi(int(attacker["y"]) - int(defender["y"]))
	return distance >= int(w["range"][0]) and distance <= int(w["range"][1])


## Returns the capped bonus from cardinally adjacent, authored bond partners.
func bond_bonus(unit: Dictionary) -> int:
	if unit["side"] != "player":
		return 0
	var total := 0
	for pairing in map.get("bonds", []):
		var partner_id: String = ""
		if pairing["a"] == unit["id"]:
			partner_id = pairing["b"]
		elif pairing["b"] == unit["id"]:
			partner_id = pairing["a"]
		if partner_id.is_empty():
			continue
		for partner in units:
			if partner["id"] == partner_id and int(partner["hp"]) > 0:
				var distance: int = absi(int(unit["x"]) - int(partner["x"])) + absi(int(unit["y"]) - int(partner["y"]))
				if distance == 1:
					total += int(data["combat_rules"]["bond_bonus_by_level"][int(pairing["level"])])
	return mini(total, int(data["combat_rules"]["bond_bonus_stack_cap"]))


func effective_stat(unit: Dictionary, stat: String) -> int:
	var value := int(unit.get(stat, 0))
	var buffs: Dictionary = unit.get("active_buffs", {})
	if buffs.has(stat) and int(buffs[stat].get("turns_remaining", 0)) > 0:
		value += int(buffs[stat].get("amount", 0))
	return value


## Computes the full displayed odds for one strike before commitment.
func preview(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var w := weapon(attacker)
	var terrain_row: String = map["terrain"][int(defender["y"])]
	var symbol: String = terrain_row.substr(int(defender["x"]), 1)
	var terrain_bonus: int = int(data["terrain_rules"][symbol]["combat_modifier"])
	var accuracy: float = maxf(0.0, effective_stat(attacker, "skill") * 2 + effective_stat(attacker, "luck") * 0.5 + int(w["accuracy_mod"]) + bond_bonus(attacker))
	var avoid: float = effective_stat(defender, "speed") * 2 + effective_stat(defender, "luck") * 0.5 + terrain_bonus + bond_bonus(defender)
	var hit: int = int(clampf(accuracy - avoid, 0.0, 100.0))
	var crit: int = int(clampf(effective_stat(attacker, "skill") * 0.5 + int(w["crit_mod"]) - effective_stat(defender, "luck") * 0.5 + bond_bonus(attacker), 0.0, 100.0))
	var offense: int = effective_stat(attacker, "mag") if w["attack_type"] == "Magic" else effective_stat(attacker, "str")
	var defense: int = effective_stat(defender, "res") if w["attack_type"] == "Magic" else effective_stat(defender, "def")
	var damage: int = maxi(0, offense + int(w["might"]) - defense + bond_bonus(attacker))
	var doubles: bool = effective_stat(attacker, "speed") - effective_stat(defender, "speed") >= int(data["combat_rules"]["double_threshold"])
	return {"hit": hit, "crit": crit, "damage": damage, "doubles": doubles}
