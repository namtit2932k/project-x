extends Node
## Loads every data resource under data/ at startup and exposes lookups by stable id.
## Adding a class, unit, map, faction, bond, skill or chapter is data-only: drop a .tres in the folder.

const SEARCH_FOLDERS := {
	"classes": "res://data/classes",
	"units": "res://data/units",
	"maps": "res://data/maps",
	"factions": "res://data/factions",
	"bonds": "res://data/bonds",
	"skills": "res://data/skills",
	"items": "res://data/items",
	"weapons": "res://data/weapons",
	"chapters": "res://data/chapters",
	"dialogues": "res://data/dialogues",
}

const RULES_PATH := "res://data/rules/rules_config.tres"

var _rules: Resource = null
var _cache := {}


func _ready() -> void:
	_rules = load(RULES_PATH)
	_scan_all()


## Loads every base layer folder, then applies the configured balance profile overlay
## (D-A1/T2.7). Also re-usable by the validator to re-scan with a chosen profile.
func _scan_all() -> void:
	for key: String in SEARCH_FOLDERS:
		_cache[key] = {}
		_scan_folder(key, SEARCH_FOLDERS[key])
	var profile := ""
	if _rules != null and "balance_profile" in _rules:
		profile = String(_rules.get("balance_profile"))
	if profile != "":
		_apply_profile_overlay(profile)


## Scans data/balance/<profile>/<kind>/ folders; entries there replace same-id base data.
func _apply_profile_overlay(profile: String) -> void:
	var root := "res://data/balance/" + profile
	if DirAccess.open(root) == null:
		push_warning("DataRegistry: unknown balance profile '%s'" % profile)
		return
	# Optional per-profile rules overlay (terrain numbers, difficulty multipliers...): a full
	# RulesConfig resource under <profile>/rules/. Script defaults act as the base layer.
	var profile_rules_path := root + "/rules/rules_config.tres"
	if ResourceLoader.exists(profile_rules_path):
		var profile_rules: Resource = load(profile_rules_path)
		if profile_rules != null:
			_rules = profile_rules
			print("DataRegistry: profile '%s' rules overlay loaded" % profile)
	for key: String in SEARCH_FOLDERS:
		var override_path := root + "/" + key
		if DirAccess.open(override_path) == null:
			continue
		var before: Dictionary = _cache[key].duplicate()
		_scan_folder(key, override_path)
		var overridden := 0
		for id: String in _cache[key]:
			if not before.has(id):
				overridden += 1
		print("DataRegistry: profile '%s' overrides %d %s entries" % [profile, overridden, key])
## Walks a folder (and its subfolders: one folder per map, ch01 layout...) and indexes every
## resource by id. Accepts .tres/.res, plus .tres.remap as written by exported builds
## (the export pipeline renames text resources, so scanning only .tres loses ALL data
## outside the editor).
func _scan_folder(kind: String, path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("DataRegistry: missing folder %s" % path)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		var full := path + "/" + file
		if dir.current_is_dir() and not file.begins_with("."):
			_scan_folder(kind, full)
		elif file.ends_with(".tres") or file.ends_with(".res") or file.ends_with(".remap"):
			var load_path := full.trim_suffix(".remap") if file.ends_with(".remap") else full
			var file_name := load_path.get_file()
			var base_ok := file_name.ends_with(".tres") or file_name.ends_with(".res")
			if not base_ok:
				# A .remap not referencing a resource file (none today) - skip safely.
				file = dir.get_next()
				continue
			var res: Resource = load(load_path)
			if res != null and "id" in res:
				if _cache[kind].has(String(res.id)):
					push_warning("DataRegistry: duplicate id '%s' in %s" % [res.id, full])
				_cache[kind][String(res.id)] = res
		file = dir.get_next()


## Rules config resource; gameplay placeholders live here, never hardcoded.
func rules() -> Resource:
	return _rules


## Numeric rule with a fallback so missing designer numbers never crash.
func rule(key: String, fallback: Variant = null) -> Variant:
	if _rules == null:
		return fallback
	var v: Variant = _rules.get(key)
	if v == null:
		return fallback
	return v


func get_data(kind: String, id: String) -> Resource:
	return _cache[kind].get(id, null)


func all_ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in _cache[kind]:
		out.append(id)
	return out


func get_weapon(id: String) -> Resource:
	return get_data("weapons", id)


func all_weapons() -> Array[Resource]:
	var list: Array[Resource] = []
	for id: String in _cache["weapons"]:
		list.append(_cache["weapons"][id])
	return list


func get_battle_class(id: String) -> Resource:
	return get_data("classes", id)


func get_unit(id: String) -> Resource:
	return get_data("units", id)


func get_map(id: String) -> Resource:
	return get_data("maps", id)


func get_faction(id: String) -> Resource:
	return get_data("factions", id)


func get_chapter(id: String) -> Resource:
	return get_data("chapters", id)


func chapters_sorted() -> Array[Resource]:
	var list: Array[Resource] = []
	for id: String in _cache["chapters"]:
		list.append(_cache["chapters"][id])
	list.sort_custom(func(a: Resource, b: Resource) -> bool: return a.order < b.order)
	return list


func get_dialogue(id: String) -> Resource:
	return get_data("dialogues", id)


func all_bond_pairs() -> Array[Resource]:
	var list: Array[Resource] = []
	for id: String in _cache["bonds"]:
		list.append(_cache["bonds"][id])
	return list
