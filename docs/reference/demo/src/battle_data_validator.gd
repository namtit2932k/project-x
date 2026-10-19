extends RefCounted
## Side-effect-free checks for the demo's authored battle catalog and maps.


## Returns developer-facing data errors without changing a running battle.
static func validate(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not data is Dictionary:
		errors.append("battle data: root must be an object")
		return errors
	var root: Dictionary = data
	var terrain_rules: Variant = root.get("terrain_rules")
	var catalog: Variant = root.get("unit_catalog")
	var class_weapons: Variant = root.get("class_weapons")
	var weapons: Variant = root.get("weapons")
	var maps: Variant = root.get("maps")
	if not terrain_rules is Dictionary or terrain_rules.is_empty():
		errors.append("battle data: terrain_rules must be a non-empty object")
	if not catalog is Dictionary or catalog.is_empty():
		errors.append("battle data: unit_catalog must be a non-empty object")
	if not class_weapons is Dictionary or not weapons is Dictionary:
		errors.append("battle data: class_weapons and weapons must be objects")
	if not maps is Array or maps.is_empty():
		errors.append("battle data: maps must be a non-empty array")
	if not errors.is_empty():
		return errors
	_validate_terrain_rules(terrain_rules, errors)
	_validate_catalog(catalog, class_weapons, weapons, errors)
	_validate_items(root.get("items", {}), catalog, errors)
	var seen_maps: Dictionary = {}
	for index in maps.size():
		if not maps[index] is Dictionary:
			errors.append("map[%d]: must be an object" % index)
			continue
		var battle_map: Dictionary = maps[index]
		var map_id: String = str(battle_map.get("id", ""))
		var context: String = "map[%d] %s" % [index, map_id]
		if map_id.is_empty() or seen_maps.has(map_id):
			errors.append("%s: missing or duplicate id" % context)
		seen_maps[map_id] = true
		_validate_map(battle_map, terrain_rules, catalog, root.get("items", {}), context, errors)
	return errors


static func _is_whole_number(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and float(value) == float(int(value)) and int(value) >= minimum


static func _validate_terrain_rules(rules: Dictionary, errors: Array[String]) -> void:
	for symbol in rules.keys():
		var record: Variant = rules[symbol]
		if not symbol is String or symbol.length() != 1 or not record is Dictionary:
			errors.append("terrain_rules: each symbol needs a one-character object")
			continue
		if not record.get("passable") is bool or not _is_whole_number(record.get("move_cost"), 1):
			errors.append("terrain_rules %s: invalid passable or move_cost" % symbol)


static func _validate_catalog(catalog: Dictionary, class_weapons: Dictionary, weapons: Dictionary, errors: Array[String]) -> void:
	for template in catalog.keys():
		var record: Variant = catalog[template]
		var context: String = "unit_catalog %s" % template
		if not record is Dictionary:
			errors.append("%s: must be an object" % context)
			continue
		var side: String = str(record.get("side", ""))
		if side not in ["player", "enemy"]:
			errors.append("%s: invalid side" % context)
		var unit_class: String = str(record.get("class", ""))
		if not class_weapons.has(unit_class) or not weapons.has(class_weapons[unit_class]):
			errors.append("%s: class has no weapon" % context)
		if not _is_whole_number(record.get("hp"), 1) or not _is_whole_number(record.get("move"), 0):
			errors.append("%s: invalid hp or move" % context)
		if side == "enemy" and str(record.get("ai_profile", "")) not in ["StandardAggressive", "ProtectPersuade", "Raider"]:
			errors.append("%s: missing or invalid ai_profile" % context)
		if record.has("controllable") and not record["controllable"] is bool:
			errors.append("%s: controllable must be boolean" % context)


static func _validate_items(items: Variant, catalog: Dictionary, errors: Array[String]) -> void:
	if not items is Dictionary:
		errors.append("battle data: items must be an object")
		return
	var item_catalog: Dictionary = items
	for item_id in item_catalog:
		var item: Variant = item_catalog[item_id]
		if not item is Dictionary:
			errors.append("items %s: must be an object" % item_id)
			continue
		if item.get("type") == "Buff":
			if str(item.get("buff_stat", "")) not in ["str", "mag", "skill", "speed", "luck", "def", "res"] or not _is_whole_number(item.get("buff_amount"), 1) or not _is_whole_number(item.get("buff_duration"), 1):
				errors.append("items %s: invalid Buff effect" % item_id)
		elif item.get("type") == "Heal":
			if not _is_whole_number(item.get("heal_value"), 1):
				errors.append("items %s: invalid Heal value" % item_id)
		else:
			errors.append("items %s: unknown type" % item_id)
	for unit_id in catalog:
		if not catalog[unit_id] is Dictionary:
			continue
		var record: Dictionary = catalog[unit_id]
		var carried: Variant = record.get("carried_items", [])
		if not carried is Array or carried.size() > 2:
			errors.append("unit_catalog %s: carried_items must have at most 2 entries" % unit_id)
			continue
		for item_id in carried:
			if not item_catalog.has(str(item_id)):
				errors.append("unit_catalog %s: unknown carried item %s" % [unit_id, item_id])


static func _validate_map(battle_map: Dictionary, rules: Dictionary, catalog: Dictionary, items: Variant, context: String, errors: Array[String]) -> void:
	var width_value: Variant = battle_map.get("width")
	var height_value: Variant = battle_map.get("height")
	if not _is_whole_number(width_value, 1) or not _is_whole_number(height_value, 1):
		errors.append("%s: width and height must be positive integers" % context)
		return
	var width: int = int(width_value)
	var height: int = int(height_value)
	var terrain: Variant = battle_map.get("terrain")
	if not terrain is Array or terrain.size() != height:
		errors.append("%s: terrain row count must equal height" % context)
		return
	for y in height:
		var row: Variant = terrain[y]
		if not row is String or row.length() != width:
			errors.append("%s: terrain row %d has wrong width" % [context, y])
			continue
		for x in width:
			if not rules.has(row.substr(x, 1)):
				errors.append("%s: terrain row %d has unknown symbol" % [context, y])
				break
	_validate_villages(battle_map, terrain, items, width, height, context, errors)
	var objective: String = str(battle_map.get("objective_type", ""))
	if objective not in ["Elimination", "Protect", "Escort", "Retrieve", "Seize"]:
		errors.append("%s: invalid objective_type" % context)
	if not _is_whole_number(battle_map.get("turn_par"), 1):
		errors.append("%s: turn_par must be positive" % context)
	var cap: Variant = battle_map.get("map_deploy_cap")
	if not _is_whole_number(cap, 1) or int(cap) > 10:
		errors.append("%s: map_deploy_cap must be 1..10" % context)
	var deployments: Variant = battle_map.get("deployments")
	if not deployments is Array or deployments.is_empty():
		errors.append("%s: deployments must be non-empty" % context)
		return
	var seen_ids: Dictionary = {}
	var seen_positions: Dictionary = {}
	var player_slots := 0
	for item in deployments:
		if not item is Dictionary:
			errors.append("%s: deployment must be an object" % context)
			continue
		var unit_id: String = str(item.get("id", ""))
		var template: String = str(item.get("template", ""))
		if unit_id.is_empty() or seen_ids.has(unit_id):
			errors.append("%s: missing or duplicate unit id %s" % [context, unit_id])
		seen_ids[unit_id] = true
		if not catalog.has(template) or not catalog[template] is Dictionary:
			errors.append("%s: unknown unit template %s" % [context, template])
			continue
		var unit: Dictionary = catalog[template]
		if unit.get("side") == "player" and bool(unit.get("controllable", true)):
			player_slots += 1
		if not _is_whole_number(item.get("x"), 0) or not _is_whole_number(item.get("y"), 0):
			errors.append("%s: unit %s has invalid position" % [context, unit_id])
			continue
		var x: int = int(item["x"])
		var y: int = int(item["y"])
		if x >= width or y >= height:
			errors.append("%s: unit %s is outside map" % [context, unit_id])
			continue
		var cell := Vector2i(x, y)
		if seen_positions.has(cell):
			errors.append("%s: duplicate position %s" % [context, cell])
		seen_positions[cell] = true
		if terrain[y] is String and terrain[y].length() == width:
			var symbol: String = terrain[y].substr(x, 1)
			if rules.has(symbol) and rules[symbol] is Dictionary and not bool(rules[symbol].get("passable", false)):
				errors.append("%s: unit %s starts on impassable terrain" % [context, unit_id])
		if unit.has("priority_target_id") and not _deployment_has_id(deployments, str(unit["priority_target_id"])):
			errors.append("%s: unit %s has unknown priority_target_id" % [context, unit_id])
	if _is_whole_number(cap, 1) and int(cap) > player_slots:
		errors.append("%s: map_deploy_cap exceeds player slots" % context)
	if objective == "Protect":
		if battle_map.has("protect_zone"):
			_validate_protect_zone(battle_map, deployments, catalog, terrain, rules, width, height, context, errors)
		else:
			_validate_target(battle_map, "protect_unit_id", "survive_enemy_phases", deployments, context, errors)
	elif objective == "Escort":
		if battle_map.has("escort_goal"):
			_validate_escort_goal(battle_map, deployments, catalog, terrain, rules, width, height, context, errors)
		else:
			_validate_target(battle_map, "escort_unit_id", "escort_turns_required", deployments, context, errors)
			if _is_whole_number(battle_map.get("turn_par"), 1) and _is_whole_number(battle_map.get("escort_turns_required"), 1) and int(battle_map["turn_par"]) < int(battle_map["escort_turns_required"]):
				errors.append("%s: turn_par precedes earliest Escort victory" % context)
	elif objective == "Retrieve":
		_validate_retrieve(battle_map, deployments, terrain, rules, width, height, context, errors)
	elif objective == "Seize":
		_validate_seize(battle_map, deployments, terrain, rules, width, height, context, errors)
	if battle_map.has("faction"):
		_validate_faction(battle_map["faction"], deployments, context, errors)


static func _validate_villages(battle_map: Dictionary, terrain: Array, items: Variant, width: int, height: int, context: String, errors: Array[String]) -> void:
	var villages: Variant = battle_map.get("villages", [])
	var item_catalog: Dictionary = items if items is Dictionary else {}
	if not villages is Array:
		errors.append("%s: villages must be an array" % context)
		return
	var seen: Dictionary = {}
	for village in villages:
		if not village is Dictionary or not _is_whole_number(village.get("x"), 0) or not _is_whole_number(village.get("y"), 0):
			errors.append("%s: village needs nonnegative x/y" % context)
			continue
		var x := int(village["x"])
		var y := int(village["y"])
		if x >= width or y >= height or not terrain[y] is String or terrain[y].length() != width or terrain[y].substr(x, 1) != "V":
			errors.append("%s: village must be on a V tile inside map" % context)
			continue
		var key := "%d,%d" % [x, y]
		if seen.has(key):
			errors.append("%s: duplicate village %s" % [context, key])
		seen[key] = true
		var kinds := 0
		for field in ["gold_amount", "item_id", "info_text"]:
			if village.has(field):
				kinds += 1
		if kinds != 1 or (village.has("gold_amount") and not _is_whole_number(village.get("gold_amount"), 1)) or (village.has("item_id") and not item_catalog.has(str(village["item_id"]))) or (village.has("info_text") and str(village["info_text"]).is_empty()):
			errors.append("%s: village %s needs exactly one valid reward" % [context, key])
	for y in height:
		if not terrain[y] is String or terrain[y].length() != width:
			continue
		for x in width:
			if terrain[y].substr(x, 1) == "V" and not seen.has("%d,%d" % [x, y]):
				errors.append("%s: V tile at %d,%d has no village reward" % [context, x, y])


static func _deployment_has_id(deployments: Array, unit_id: String) -> bool:
	for item in deployments:
		if item is Dictionary and str(item.get("id", "")) == unit_id:
			return true
	return false


static func _validate_target(battle_map: Dictionary, id_field: String, turns_field: String, deployments: Array, context: String, errors: Array[String]) -> void:
	if not _deployment_has_id(deployments, str(battle_map.get(id_field, ""))):
		errors.append("%s: %s references no deployed unit" % [context, id_field])
	if not _is_whole_number(battle_map.get(turns_field), 1):
		errors.append("%s: %s must be positive" % [context, turns_field])


static func _validate_protect_zone(battle_map: Dictionary, deployments: Array, catalog: Dictionary, terrain: Array, rules: Dictionary, width: int, height: int, context: String, errors: Array[String]) -> void:
	if battle_map.has("protect_unit_id"):
		errors.append("%s: zone Protect cannot also use protect_unit_id" % context)
	if not _is_whole_number(battle_map.get("survive_enemy_phases"), 1):
		errors.append("%s: survive_enemy_phases must be positive" % context)
	var zone: Variant = battle_map.get("protect_zone")
	if not zone is Dictionary or not _is_whole_number(zone.get("x"), 0) or not _is_whole_number(zone.get("y"), 0) or not _is_whole_number(zone.get("width"), 1) or not _is_whole_number(zone.get("height"), 1):
		errors.append("%s: protect_zone needs nonnegative x/y and positive width/height" % context)
		return
	var left: int = int(zone["x"])
	var top: int = int(zone["y"])
	var right: int = left + int(zone["width"])
	var bottom: int = top + int(zone["height"])
	if right > width or bottom > height:
		errors.append("%s: protect_zone must fit inside the map" % context)
		return
	for y in range(top, bottom):
		for x in range(left, right):
			if not terrain[y] is String or terrain[y].length() != width or not rules.has(terrain[y].substr(x, 1)) or not bool(rules[terrain[y].substr(x, 1)].get("passable", false)):
				errors.append("%s: protect_zone must contain only passable tiles" % context)
				return
	for deployment in deployments:
		if not deployment is Dictionary or not catalog.has(str(deployment.get("template", ""))):
			continue
		var x: int = int(deployment.get("x", -1))
		var y: int = int(deployment.get("y", -1))
		if x >= left and x < right and y >= top and y < bottom and catalog[str(deployment["template"])].get("side") == "enemy":
			errors.append("%s: enemy cannot start inside protect_zone" % context)
			return


static func _validate_retrieve(battle_map: Dictionary, deployments: Array, terrain: Array, rules: Dictionary, width: int, height: int, context: String, errors: Array[String]) -> void:
	var cells: Dictionary = {}
	for field in ["item_tile", "return_tile"]:
		var point: Variant = battle_map.get(field)
		if not point is Dictionary or not _is_whole_number(point.get("x"), 0) or not _is_whole_number(point.get("y"), 0):
			errors.append("%s: %s needs integer x and y" % [context, field])
			continue
		var x: int = int(point["x"])
		var y: int = int(point["y"])
		if x >= width or y >= height or not terrain[y] is String or terrain[y].length() != width or not rules.has(terrain[y].substr(x, 1)) or not bool(rules[terrain[y].substr(x, 1)].get("passable", false)):
			errors.append("%s: %s must be a passable tile inside the map" % [context, field])
			continue
		var cell := Vector2i(x, y)
		cells[field] = cell
		for deployment in deployments:
			if deployment is Dictionary and int(deployment.get("x", -1)) == x and int(deployment.get("y", -1)) == y:
				errors.append("%s: %s must start unoccupied" % [context, field])
				break
	if cells.has("item_tile") and cells.has("return_tile") and cells["item_tile"] == cells["return_tile"]:
		errors.append("%s: item_tile and return_tile must differ" % context)


static func _validate_seize(battle_map: Dictionary, deployments: Array, terrain: Array, rules: Dictionary, width: int, height: int, context: String, errors: Array[String]) -> void:
	if not _is_whole_number(battle_map.get("hold_enemy_phases"), 1):
		errors.append("%s: hold_enemy_phases must be positive" % context)
	elif _is_whole_number(battle_map.get("turn_par"), 1) and int(battle_map["turn_par"]) < int(battle_map["hold_enemy_phases"]):
		errors.append("%s: turn_par precedes earliest Seize victory" % context)
	var point: Variant = battle_map.get("control_point")
	if not point is Dictionary or not _is_whole_number(point.get("x"), 0) or not _is_whole_number(point.get("y"), 0):
		errors.append("%s: control_point needs integer x and y" % context)
		return
	var x: int = int(point["x"])
	var y: int = int(point["y"])
	if x >= width or y >= height or not terrain[y] is String or terrain[y].length() != width or not rules.has(terrain[y].substr(x, 1)) or not bool(rules[terrain[y].substr(x, 1)].get("passable", false)):
		errors.append("%s: control_point must be a passable tile inside the map" % context)
		return
	for deployment in deployments:
		if deployment is Dictionary and int(deployment.get("x", -1)) == x and int(deployment.get("y", -1)) == y:
			errors.append("%s: control_point must start unoccupied" % context)
			break


static func _validate_escort_goal(battle_map: Dictionary, deployments: Array, catalog: Dictionary, terrain: Array, rules: Dictionary, width: int, height: int, context: String, errors: Array[String]) -> void:
	var target_id: String = str(battle_map.get("escort_unit_id", ""))
	if not _deployment_has_id(deployments, target_id):
		errors.append("%s: escort_unit_id references no deployed unit" % context)
	else:
		for deployment in deployments:
			if str(deployment.get("id", "")) == target_id and catalog.has(str(deployment.get("template", ""))):
				var unit: Dictionary = catalog[str(deployment["template"])]
				if unit.get("side") != "player" or bool(unit.get("controllable", true)) or int(unit.get("move", 0)) < 1:
					errors.append("%s: destination Escort target must be a moving allied NPC" % context)
	if battle_map.has("escort_turns_required"):
		errors.append("%s: destination Escort cannot also use escort_turns_required" % context)
	var goal: Variant = battle_map.get("escort_goal")
	if not goal is Dictionary or not _is_whole_number(goal.get("x"), 0) or not _is_whole_number(goal.get("y"), 0):
		errors.append("%s: escort_goal needs integer x and y" % context)
		return
	var x: int = int(goal["x"])
	var y: int = int(goal["y"])
	if x >= width or y >= height or not terrain[y] is String or terrain[y].length() != width or not rules.has(terrain[y].substr(x, 1)) or not bool(rules[terrain[y].substr(x, 1)].get("passable", false)):
		errors.append("%s: escort_goal must be a passable tile inside the map" % context)
		return
	for deployment in deployments:
		if int(deployment.get("x", -1)) == x and int(deployment.get("y", -1)) == y:
			errors.append("%s: escort_goal must start unoccupied" % context)
			break


static func _validate_faction(faction: Variant, deployments: Array, context: String, errors: Array[String]) -> void:
	if not faction is Dictionary:
		errors.append("%s: faction must be an object" % context)
		return
	if str(faction.get("id", "")).is_empty() or not _is_whole_number(faction.get("kill_threshold"), 0) or not _is_whole_number(faction.get("prior_kills", 0), 0):
		errors.append("%s: faction id, kill_threshold or prior_kills invalid" % context)
	var condition: Variant = faction.get("persuasion_condition")
	if not condition is Dictionary:
		errors.append("%s: persuasion_condition must be an object" % context)
		return
	match str(condition.get("type", "")):
		"named_unit_alive":
			if not _deployment_has_id(deployments, str(condition.get("unit_id", ""))):
				errors.append("%s: persuasion_condition unit_id references no deployed unit" % context)
		"units_spared_pct":
			var threshold: Variant = condition.get("threshold")
			if not (threshold is int or threshold is float) or float(threshold) < 0.0 or float(threshold) > 1.0:
				errors.append("%s: persuasion_condition threshold must be 0..1" % context)
		_:
			errors.append("%s: unknown persuasion_condition type" % context)
