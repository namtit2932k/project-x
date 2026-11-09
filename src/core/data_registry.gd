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
## UI text in every language (I18N): CSV "key,en,vi,..."; the key is the English source text.
## Imported as "keep" so it ships as a plain file and is read here, no generated files.
const I18N_PATH := "res://data/i18n/strings.csv"

var _rules: Resource = null
var _cache := {}
## key -> {locale: text} as read from I18N_PATH (validator/tests read it back).
var _i18n: Dictionary = {}
var _i18n_locales: Array[String] = []


func _ready() -> void:
	_rules = load(RULES_PATH)
	_scan_all()
	_load_translations()


## Reads the UI string table and registers one Translation per language column with the
## engine's TranslationServer; empty cells fall back to the key (English source text).
func _load_translations() -> void:
	_i18n.clear()
	_i18n_locales.clear()
	var file := FileAccess.open(I18N_PATH, FileAccess.READ)
	if file == null:
		push_warning("DataRegistry: missing %s, UI stays in English" % I18N_PATH)
		return
	var header := file.get_csv_line()
	var translations: Array[Translation] = []
	for col in range(1, header.size()):
		var tr_res := Translation.new()
		tr_res.locale = header[col].strip_edges()
		translations.append(tr_res)
		_i18n_locales.append(tr_res.locale)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		var key := row[0]
		var texts := {}
		for col in range(1, mini(row.size(), header.size())):
			texts[_i18n_locales[col - 1]] = row[col]
			if row[col] != "":
				translations[col - 1].add_message(key, row[col])
		_i18n[key] = texts
	for tr_res in translations:
		TranslationServer.add_translation(tr_res)


## The loaded UI string table: {key: {locale: text}}.
func i18n_table() -> Dictionary:
	return _i18n


## Language codes that have a column in the UI string table ("en", "vi", ...).
func i18n_locales() -> Array[String]:
	return _i18n_locales


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


## F-ITEM: item records (objective relics and consumables).
func get_item(id: String) -> ItemData:
	return get_data("items", id) as ItemData


func get_unit(id: String) -> Resource:
	return get_data("units", id)


func get_map(id: String) -> Resource:
	return get_data("maps", id)


func get_faction(id: String) -> Resource:
	return get_data("factions", id)


func get_chapter(id: String) -> Resource:
	return get_data("chapters", id)


## Chapters in data order, filtered by campaign tag (F4.1): a non-empty tag returns only
## that campaign; the empty tag request reads legacy chapters ("" = untagged legacy data
## is also acceptable, F4.4).
func chapters_sorted(tag: String = "") -> Array[Resource]:
	var list: Array[Resource] = []
	for id: String in _cache["chapters"]:
		var chapter: Resource = _cache["chapters"][id]
		# F4.4: an untagged chapter IS legacy data — it only plays in the legacy campaign.
		var chapter_tag := String(chapter.campaign_tag)
		if chapter_tag == "":
			chapter_tag = "legacy"
		if tag == "":
			if chapter_tag != "legacy":
				continue
		elif chapter_tag != tag:
			continue
		list.append(chapter)
	list.sort_custom(func(a: Resource, b: Resource) -> bool: return a.order < b.order)
	return list


func get_dialogue(id: String) -> Resource:
	return get_data("dialogues", id)


func all_bond_pairs() -> Array[Resource]:
	var list: Array[Resource] = []
	for id: String in _cache["bonds"]:
		list.append(_cache["bonds"][id])
	return list
