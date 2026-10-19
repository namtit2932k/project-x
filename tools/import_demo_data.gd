extends SceneTree
## tools/import_demo_data.gd — one-shot generator (T2.8): turns the reference demo JSON
## (docs/reference/demo/data/, read-only) into repo .tres data.
##
## Run: godot --headless --path . -s res://tools/import_demo_data.gd
##
## Generated (only under the documented OUTPUT roots; erased + rewritten idempotently):
##   data/weapons/weapon_*.tres                       (GDD canonical 12 weapons)
##   data/balance/demo/{weapons,items,classes,units,factions}/*.tres  (demo profile overlay)
##   data/items/item_demo_document.tres                (Retrieve payload)
##   data/maps/demo_0N_*/map.tres                      (6 example maps)
##   data/chapters/chapter_demo_0N.tres                (campaign_tag = "demo")
##
## Id mapping (T2.8): demo templates get a dedicated namespace `swordsman` -> `unit_demo_swordsman`
## (the base layer keeps unit_swordsman and friends untouched: ids are semantic, one person,
## and the parity layer must never silently replace the old campaign roster). Items keep no
## extra namespace because they do not collide with the base catalog. Every reference
## (carried_items, priority_target_id, key_unit_id, bonds...) uses the same prefix.

const REF_DIR := "res://docs/reference/demo/data/"
const OUT_WEAPONS := "res://data/weapons"
const OUT_BALANCE := "res://data/balance/demo"
const OUT_MAPS := "res://data/maps"
const OUT_CHAPTERS := "res://data/chapters"
const OUT_ITEMS := "res://data/items"

var errors: int = 0
var _demo: Dictionary = {}


func _init() -> void:
	var weapons_list: Variant = _load_json_any("weapons.json")
	var demo := _load_json("battle_demo.json")
	var goods := _load_json("tuning/gold_shop.json")
	_demo = demo
	if errors > 0:
		quit(1)
		return
	_generate_weapons(weapons_list)
	_generate_demo_profile(demo, goods)
	_generate_maps(demo)
	_generate_chapters(demo)
	print("import_demo_data: done, %d errors" % errors)
	quit(1 if errors > 0 else 0)


func _load_json(file: String) -> Dictionary:
	var raw: Variant = _load_json_any(file)
	return raw if raw is Dictionary else {}


func _load_json_any(file: String) -> Variant:
	var path := REF_DIR + file
	if not FileAccess.file_exists(path):
		printerr("import: missing reference file " + path)
		errors += 1
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		printerr("import: unparsable " + path)
		errors += 1
	return parsed


func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("import: cannot write %s" % path)
		errors += 1
		return
	f.store_string(content)


## Generic .tres writer for data-only resources.
func _write_tres(script_path: String, script_class: String, props: Dictionary, path: String) -> void:
	var lines: Array[String] = []
	lines.append("[gd_resource type=\"Resource\" script_class=\"%s\" load_steps=2 format=3]" % script_class)
	lines.append("")
	lines.append("[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]" % script_path)
	lines.append("")
	lines.append("[resource]")
	lines.append("script = ExtResource(\"1\")")
	for key in props:
		lines.append("%s = %s" % [key, _tres_value(props[key], LIST_FIELD_TYPES.get(key, ""))])
	_write(path, "\n".join(lines) + "\n")


## Field name -> element type for typed Array[T] script exports (empty arrays need it).
const LIST_FIELD_TYPES := {
	"enemy_placements": "Dictionary", "npc_placements": "Dictionary", "objectives": "Dictionary",
	"item_placements": "Dictionary", "villages": "Dictionary", "bonds": "Dictionary",
	"deployable_unit_ids": "String", "deploy_cells": "Vector2i", "deploy_tiles": "Vector2i",
	"hint_lines": "String", "skill_ids": "String", "carried_items": "String",
}


func _tres_value(v: Variant, list_hint: String = "") -> String:
	match typeof(v):
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return str(v)
		TYPE_STRING:
			return "\"%s\"" % str(v).replace("\n", "\\n")
		TYPE_VECTOR2I:
			return "Vector2i(%d, %d)" % [v.x, v.y]
		TYPE_RECT2I:
			return "Rect2i(%d, %d, %d, %d)" % [v.position.x, v.position.y, v.size.x, v.size.y]
		TYPE_ARRAY:
			var all_strings := true
			var all_vectors := true
			var all_dicts := true
			for e in v:
				if typeof(e) != TYPE_STRING:
					all_strings = false
				if typeof(e) != TYPE_VECTOR2I:
					all_vectors = false
				if typeof(e) != TYPE_DICTIONARY:
					all_dicts = false
			var values := _map_value_list(v)
			if v.is_empty() and list_hint != "":
				return "Array[%s]([])" % list_hint
			if all_strings:
				return "Array[String]([%s])" % ", ".join(values)
			if all_vectors:
				return "Array[Vector2i]([%s])" % ", ".join(values)
			if all_dicts:
				return "Array[Dictionary]([%s])" % ", ".join(values)
			return "[%s]" % ", ".join(values)
		TYPE_DICTIONARY:
			if v.is_empty():
				return "{}"
			var parts: Array[String] = []
			for k in v:
				parts.append("\n\"%s\": %s," % [str(k), _tres_value(v[k])])
			var joined: String = "".join(parts)
			return "{" + joined.trim_suffix(",") + "\n}"
	return "<unsupported type %d>" % typeof(v)


func _map_value_list(arr: Array) -> Array[String]:
	var out: Array[String] = []
	for v in arr:
		out.append(_tres_value(v))
	return out


## Typed string array helper for JSON lists of unknown content type.
func _string_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for e in v:
			out.append(str(e))
	return out


## ---------------------------------------------------------------- base weapons

func _generate_weapons(weapons_list: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_WEAPONS))
	_erase_generated(OUT_WEAPONS, ["weapon_data.gd"])
	if not (weapons_list is Array):
		return
	for w: Dictionary in weapons_list:
		var wid := "weapon_" + str(w.get("weapon_id", ""))
		if wid == "weapon_":
			continue
		var rng: Array = w.get("weapon_range", [1, 1])
		var props := {
			"id": wid,
			"display_name": str(w.get("name", wid.capitalize())),
			"action_category": str(w.get("action_category", "Combat")),
			"attack_type": str(w.get("attack_type", "")),
			"weapon_range": Vector2i(int(rng[0]), int(rng[1]) if rng.size() > 1 else int(rng[0])),
			"weapon_might": int(w.get("weapon_might", 0)),
			"weapon_accuracy_mod": int(w.get("weapon_accuracy_mod", 0)),
			"weapon_crit_mod": int(w.get("weapon_crit_mod", 0)),
			"heal_might": int(w.get("heal_might", 0)),
			"heal_range": _range2i(w.get("heal_range", [1, 1])),
		}
		_write_tres("res://data/weapons/weapon_data.gd", "WeaponData", props,
				"%s/weapon_%s.tres" % [OUT_WEAPONS, wid])


func _range2i(list: Variant) -> Vector2i:
	if list is Array and list.size() >= 2:
		return Vector2i(int(list[0]), int(list[1]))
	if list is Array and list.size() == 1:
		return Vector2i(int(list[0]), int(list[0]))
	return Vector2i(1, 1)


## ---------------------------------------------------------------- demo profile

func _generate_demo_profile(demo: Dictionary, goods: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_BALANCE))
	for kind: String in ["weapons", "items", "classes", "units", "factions"]:
		var dir := OUT_BALANCE + "/" + kind
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		_erase_generated(dir, [])

	# -- scenario weapons (demo layer: sword/lance/staff/unarmed)
	var demo_weapons: Dictionary = demo.get("weapons", {})
	for key: String in demo_weapons:
		var w: Dictionary = demo_weapons[key]
		var action: String = str(w.get("action_category", "Combat"))
		var props := {
			"id": "weapon_" + key,
			"display_name": str(key).capitalize(),
			"action_category": action,
			"attack_type": str(w.get("attack_type", "")),
			"weapon_range": _range2i(w.get("range", [1, 1])),
			"weapon_might": int(w.get("might", 0)),
			"weapon_accuracy_mod": int(w.get("accuracy_mod", 0)),
			"weapon_crit_mod": int(w.get("crit_mod", 0)),
			"heal_might": int(w.get("heal_might", 0)),
			"heal_range": _range2i(w.get("heal_range", [1, 1])),
		}
		_write_tres("res://data/weapons/weapon_data.gd", "WeaponData", props,
				"%s/weapons/weapon_%s.tres" % [OUT_BALANCE, key])

	# -- consumable items with shop prices
	var items: Dictionary = demo.get("items", {})
	var prices: Dictionary = goods.get("prices", {})
	for key: String in items:
		var it: Dictionary = items[key]
		var type := str(it.get("type", "Heal"))
		var props := {
			"id": "item_" + key,
			"display_name": str(it.get("name", key)),
			"category": "consumable",
			"type": type,
			"price": int(prices.get(key, 0)),
			"heal_value": int(it.get("heal_value", 0)),
			"buff_stat": str(it.get("buff_stat", "")),
			"buff_amount": int(it.get("buff_amount", 0)),
			"buff_duration": int(it.get("buff_duration", 0)),
		}
		_write_tres("res://data/items/item_data.gd", "ItemData", props,
				"%s/items/item_%s.tres" % [OUT_BALANCE, key])

	# -- scenario classes: keep base-layer class ids where they exist so the profile
	#    overlays them; new scenario classes resolve the demo class_weapons table.
	var class_weapons: Dictionary = demo.get("class_weapons", {})
	var class_move := {"Swordsman": 5, "Knight": 5, "Healer": 5, "Civilian": 2, "Guard": 4, "Commander": 4}
	for key: String in class_weapons:
		var cid := "class_" + str(key).to_lower().replace(" ", "_")
		var weapon_key := str(class_weapons[key])
		var action: String = str(demo_weapons.get(weapon_key, {}).get("action_category", "Combat"))
		var move := int(class_move.get(key, 4))
		var props := {
			"id": cid,
			"display_name": key,
			"move_type": "foot",
			"move_range": move,
			"attack_range_min": 1 if action != "None" else 0,
			"attack_range_max": 1 if action != "None" else 0,
			"weapon_id": "weapon_" + weapon_key,
			"damage_type": "physical",
		}
		_write_tres("res://data/classes/class_data.gd", "BattleClassData", props,
				"%s/classes/%s.tres" % [OUT_BALANCE, cid])

	# -- factions: sideless roster faction + the map-local remnant from the persuade map
	var neutral := {
		"id": "faction_neutral",
		"display_name": "Trung lập",
		"remnant_id": "",
		"reconcile": {"kill_threshold": 0, "required_events": []},
	}
	_write_tres("res://data/factions/faction_data.gd", "FactionData", neutral,
			"%s/factions/faction_neutral.tres" % OUT_BALANCE)
	var river := {
		"id": "faction_river_guard",
		"display_name": "Đội gác sông",
		"remnant_id": "river_guard",
		"reconcile": {"kill_threshold": 2, "required_events": ["spared_commander"]},
	}
	_write_tres("res://data/factions/faction_data.gd", "FactionData", river,
			"%s/factions/faction_river_guard.tres" % OUT_BALANCE)

	# -- scenario unit templates (unit_catalog) with GDD stat keys
	var catalog: Dictionary = demo.get("unit_catalog", {})
	for key: String in catalog:
		var u: Dictionary = catalog[key]
		var class_key := str(u.get("class", "Swordsman"))
		var props := {
			"id": "unit_demo_" + key,
			"display_name": str(u.get("name", key)),				"class_id": "class_" + class_key.to_lower().replace(" ", "_"),
				"faction_id": "faction_" + str(u.get("faction_id", "neutral")),
			"controllable": bool(u.get("controllable", true)),
			"base_stats": {
				"hp": int(u.get("hp", 20)),
				"str": int(u.get("str", 0)),
				"mag": int(u.get("mag", 0)),
				"skill": int(u.get("skill", 0)),
				"speed": int(u.get("speed", 0)),
				"luck": int(u.get("luck", 0)),
				"def": int(u.get("def", 0)),
				"res": int(u.get("res", 0)),
				"move": int(u.get("move", 4)),
			},
			"carried_items": _prefixed(u.get("carried_items", []), "item_"),
			"ai_profile": str(u.get("ai_profile", "")),				"priority_target_id": _maybe_prefixed(u.get("priority_target_id", ""), "unit_demo_"),
		}
		# D03: the remnant leader records the spare event on survival.
		if str(u.get("ai_profile", "")) == "ProtectPersuade" and class_key == "Commander":
			props["reconcile_event_key"] = "spared_commander"
		_write_tres("res://data/units/unit_data.gd", "UnitData", props,
				"%s/units/unit_demo_%s.tres" % [OUT_BALANCE, key])

	# -- Retrieve payload item (objective category, lives on the base layer)
	var payload := {
		"id": "item_demo_document",
		"display_name": "Tài liệu",
		"category": "objective",
		"description": "Tài liệu nhiệm vụ cần thu hồi (map demo).",
	}
	_write_tres("res://data/items/item_data.gd", "ItemData", payload,
			"%s/item_demo_document.tres" % OUT_ITEMS)


func _prefixed(list: Variant, prefix: String) -> Array[String]:
	var out: Array[String] = []
	if list is Array:
		for e in list:
			out.append(prefix + str(e))
	return out


func _maybe_prefixed(raw: String, prefix: String) -> String:
	return prefix + raw if raw != "" else ""


## ---------------------------------------------------------------- maps + chapters

const GLYPH_MAP := {".": ".", "F": "f", "V": "v", "W": "w"}


func _generate_maps(demo: Dictionary) -> void:
	var maps: Array = demo.get("maps", [])
	for i in maps.size():
		var m: Dictionary = maps[i]
		var id := "map_demo_%02d" % (i + 1)
		var dir := "%s/demo_%02d_%s" % [OUT_MAPS, i + 1, str(m.get("id", "example"))]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		_write_map(id, m, dir + "/map.tres")


func _write_map(id: String, m: Dictionary, path: String) -> void:
	var rows: Array[String] = []
	for row in m.get("terrain", []):
		var converted := ""
		for ch in str(row):
			var g := str(ch)
			converted += str(GLYPH_MAP.get(g, g))
		rows.append(converted)

	var enemy_target_ids: Array[String] = []
	var deploy_cells: Array[Vector2i] = []
	var enemy_placements: Array[Dictionary] = []
	var npc_placements: Array[Dictionary] = []
	var catalog: Dictionary = _demo.get("unit_catalog", {})
	for d: Dictionary in m.get("deployments", []):
		var template := str(d.get("template", ""))
		var ud: Dictionary = catalog.get(template, {})
		var cell := Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
		if str(ud.get("side", "player")) == "enemy":
			enemy_placements.append({
				"unit_id": "unit_demo_" + template,
				"cell": cell,
				"instance_id": str(d.get("id", template)),
				"ai": true,
			})
			if not enemy_target_ids.has("unit_demo_" + template):
				enemy_target_ids.append("unit_demo_" + template)
		elif bool(ud.get("controllable", true)):
			deploy_cells.append(cell)
		else:
			npc_placements.append({
				"unit_id": "unit_demo_" + template,
				"cell": cell,
				"instance_id": str(d.get("id", template)),
				"ai": false,
			})

	var objectives: Array[Dictionary] = []
	var item_placements: Array[Dictionary] = []
	var villages: Array[Dictionary] = []
	var obj_type := str(m.get("objective_type", "Elimination"))
	match obj_type:
		"Elimination":
			objectives.append({"type": "eliminate", "params": {"target_unit_ids": enemy_target_ids}})
		"Escort":
			var goal: Dictionary = m.get("escort_goal", {})
			if not goal.is_empty():
				objectives.append({
					"type": "escort",
					"params": {
						"npc_unit_id": "unit_demo_" + str(m.get("escort_unit_id", "")),
						"target_cell_x": int(goal.get("x", 0)),
						"target_cell_y": int(goal.get("y", 0)),
					},
				})
			if int(m.get("escort_turns_required", 0)) > 0:
				objectives.append({
					"type": "escort_turns",
					"params": {
						"npc_unit_id": "unit_demo_" + str(m.get("escort_unit_id", "")),
						"turns_required": int(m.get("escort_turns_required", 1)),
					},
				})
		"Protect":
			var zone: Dictionary = m.get("protect_zone", {})
			objectives.append({
				"type": "defend",
				"params": {
					"zone_x": int(zone.get("x", 0)),
					"zone_y": int(zone.get("y", 0)),
					"zone_w": int(zone.get("width", 1)),
					"zone_h": int(zone.get("height", 1)),
					"turns_required": int(m.get("survive_enemy_phases", 1)),
					"policy": "block",
				},
			})
		"Retrieve":
			var item_tile: Dictionary = m.get("item_tile", {})
			var return_tile: Dictionary = m.get("return_tile", {})
			item_placements.append({
				"item_id": "item_demo_document",
				"cell": Vector2i(int(item_tile.get("x", 0)), int(item_tile.get("y", 0))),
			})
			objectives.append({
				"type": "retrieve",
				"params": {
					"item_id": "item_demo_document",
					"exit_zone_x": int(return_tile.get("x", 0)),
					"exit_zone_y": int(return_tile.get("y", 0)),
					"exit_zone_w": 1,
					"exit_zone_h": 1,
				},
			})
		"Seize":
			var cp: Dictionary = m.get("control_point", {})
			objectives.append({
				"type": "capture",
				"params": {
					"zones": [{"x": int(cp.get("x", 0)), "y": int(cp.get("y", 0)), "w": 1, "h": 1}],
					"turns_required": int(m.get("hold_enemy_phases", 1)),
				},
			})

	for v: Dictionary in m.get("villages", []):
		villages.append({
			"cell": Vector2i(int(v.get("x", 0)), int(v.get("y", 0))),
			"gold_amount": int(v.get("gold_amount", 0)),
			"item_id": "",
		})

	var bond_pairs: Array[Dictionary] = []
	for b: Dictionary in m.get("bonds", []):
		bond_pairs.append({
			"a": "unit_demo_" + str(b.get("a", "")),
			"b": "unit_demo_" + str(b.get("b", "")),
			"level": int(b.get("level", 0)),
		})

	var map_faction := {}
	if m.has("faction"):
		var f: Dictionary = m.get("faction", {})
		map_faction = {
			"faction_id": "faction_" + str(f.get("id", "")),
			"prior_kills": int(f.get("prior_kills", 0)),
		}

	var props := {
		"id": id,
		"display_name": str(m.get("title", id)),
		"terrain_rows": rows,
		"deploy_cells": deploy_cells,
		"deploy_tiles": deploy_cells,
		"map_deploy_cap": int(m.get("map_deploy_cap", 2)),
		"turn_par": int(m.get("turn_par", 6)),
		"turn_limit": int(m.get("turn_limit", 0)),
		"objective_type": obj_type,
		"objective_text": str(m.get("objective_text", "")),
		"hint_lines": _string_array(m.get("hint_lines", [])),
		"aftermath_lines": _aftermath_dict(m.get("aftermath_lines", {})),
		"faction": map_faction,
		"key_unit_id": _maybe_prefixed(str(m.get("key_unit_id", "")), "unit_demo_"),
		"villages": villages,
		"bonds": bond_pairs,
		"enemy_placements": enemy_placements,
		"npc_placements": npc_placements,
		"item_placements": item_placements,
		"objectives": objectives,
		"result_priority": str(m.get("result_priority", "lose")),
	}
	_write_tres("res://data/maps/map_data.gd", "MapData", props, path)


func _aftermath_dict(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		out[str(key)] = _string_array(raw[key])
	return out


## ---------------------------------------------------------------- chapters

func _generate_chapters(demo: Dictionary) -> void:
	var maps: Array = demo.get("maps", [])
	for i in maps.size():
		var m: Dictionary = maps[i]
		var props := {
			"id": "chapter_demo_%02d" % (i + 1),
			"order": 100 + i,
			"display_name": str(m.get("title", "")),
			"map_id": "map_demo_%02d" % (i + 1),
			"deployable_unit_ids": ["unit_demo_swordsman", "unit_demo_knight"],
			"deploy_max": int(m.get("map_deploy_cap", 2)),
			"campaign_tag": "demo",
		}
		_write_tres("res://data/chapters/chapter_data.gd", "ChapterData", props,
				"%s/chapter_demo_%02d.tres" % [OUT_CHAPTERS, i + 1])


## ---------------------------------------------------------------- folders

## Removes only the generated .tres of a data folder so re-running stays idempotent.
func _erase_generated(dir_path: String, keep: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") and not keep.has(file):
			dir.remove(file)
		file = dir.get_next()
