extends Node
## Data validation: run with
##   godot --headless --path . res://tools/validate_data.tscn
## Checks duplicate ids, broken references and missing fields across data/ (schema bàn giao).

var errors: int = 0
var warnings: int = 0

const UNIT_STAT_KEYS := ["hp", "atk", "def", "res", "skl", "spd", "mov", "crit", "hit"]
const GROWTH_KEYS := ["hp", "atk", "def", "res", "skl", "spd"]
const OBJECTIVE_TYPES := ["eliminate", "escort", "defend", "retrieve", "capture", "evacuate"]
const EVENT_TRIGGERS := ["enter_zone", "leave_zone", "pickup", "unit_dead", "turn_start", "turn_end", "talk", "faction_change"]
const EVENT_ACTIONS := ["spawn", "dialogue", "change_team", "set_flag", "win", "lose"]
const DIFFICULTIES := ["story", "normal", "hard", "nightmare"]


func _ready() -> void:
	check_rules()
	check_classes()
	check_units()
	check_items()
	check_maps()
	check_chapters()
	check_dialogues()
	check_bonds()
	print("Validation done: %d errors, %d warnings" % [errors, warnings])
	get_tree().quit(1 if errors > 0 else 0)


func _err(msg: String) -> void:
	errors += 1
	printerr("ERROR: " + msg)


func _warn(msg: String) -> void:
	warnings += 1
	print("WARNING: " + msg)


func _ids(kind: String) -> Dictionary:
	var out := {}
	for id in DataRegistry._cache[kind]:
		if out.has(id):
			_err("duplicate id in %s: %s" % [kind, id])
		out[id] = true
	return out


func check_rules() -> void:
	var costs: Dictionary = DataRegistry.rule("terrain_costs", {})
	var defs: Dictionary = DataRegistry.rule("terrain_defs", {})
	for terrain_id in costs:
		if not defs.has(terrain_id):
			_err("rules: terrain_costs '%s' has no terrain_defs entry" % terrain_id)
		var modes: Dictionary = costs.get(terrain_id, {})
		for key in modes:
			if key not in ["foot", "flying"]:
				_err("rules: terrain_costs '%s' unknown movement type '%s'" % [terrain_id, key])
	for terrain_id in defs:
		if not costs.has(terrain_id):
			_warn("rules: terrain_defs '%s' has no terrain_costs entry" % terrain_id)
		var td: Dictionary = defs[terrain_id]
		for key in ["def_bonus", "avoid_bonus", "blocked"]:
			if key not in td:
				_err("rules: terrain_defs '%s' missing '%s'" % [terrain_id, key])
	for mode in ["damage_formula_id", "rounding", "rewind_count_mode", "win_lose_priority"]:
		if String(DataRegistry.rule(mode, "")) == "":
			_warn("rules: '%s' empty" % mode)
	var rewind_table: Dictionary = DataRegistry.rule("rewind_per_difficulty", {})
	var casualty_table: Dictionary = DataRegistry.rule("casualty_by_difficulty", {})
	for difficulty in DIFFICULTIES:
		if not rewind_table.has(difficulty):
			_err("rules: rewind_per_difficulty missing difficulty '%s'" % difficulty)
		if not casualty_table.has(difficulty):
			_err("rules: casualty_by_difficulty missing difficulty '%s'" % difficulty)
		elif String(casualty_table[difficulty]) not in ["temp_injury", "permadeath", "none"]:
			_err("rules: casualty value '%s' invalid for '%s'" % [casualty_table[difficulty], difficulty])
	# Bond bonus constraint from the deck: total adjacent bonus caps at +16.
	var bonuses: Dictionary = DataRegistry.rule("bond_bonus_by_rank", {})
	var cap := int(DataRegistry.rule("max_adjacent_bond_bonus", 16))
	for rank in bonuses:
		if int(bonuses[rank]) > cap:
			_err("rules: bond bonus rank '%s' (%d) exceeds max_adjacent_bond_bonus %d" % [rank, int(bonuses[rank]), cap])


func check_classes() -> void:
	_ids("classes")
	for id in DataRegistry.all_ids("classes"):
		var c := DataRegistry.get_battle_class(id)
		if String(c.faction_id) != "" and DataRegistry.get_faction(String(c.faction_id)) == null:
			_err("class %s: unknown faction %s" % [id, c.faction_id])
		if int(c.move_range) < 1:
			_err("class %s: move_range < 1" % id)
		if int(c.attack_range_max) < int(c.attack_range_min):
			_err("class %s: attack range min > max" % id)
		if String(c.move_type) not in ["foot", "flying"]:
			_err("class %s: unknown movement '%s'" % [id, c.move_type])
		for skill_id in c.skill_ids:
			if DataRegistry.get_data("skills", String(skill_id)) == null:
				_err("class %s: unknown skill %s" % [id, skill_id])


func check_units() -> void:
	_ids("units")
	for id in DataRegistry.all_ids("units"):
		var u := DataRegistry.get_unit(id)
		if DataRegistry.get_battle_class(String(u.class_id)) == null:
			_err("unit %s: unknown class %s" % [id, u.class_id])
		if DataRegistry.get_faction(String(u.faction_id)) == null:
			_err("unit %s: unknown faction %s" % [id, u.faction_id])
		for stat_key in u.base_stats:
			if stat_key != null and str(stat_key) not in UNIT_STAT_KEYS:
				_err("unit %s: unknown base_stats key '%s'" % [id, stat_key])
		for key in UNIT_STAT_KEYS:
			if not u.base_stats.has(key):
				_warn("unit %s: base_stats missing '%s' (fallback to class)" % [id, key])
		for gk in u.growths:
			if str(gk) not in GROWTH_KEYS:
				_err("unit %s: unknown growths key '%s'" % [id, gk])
		for skill_id in u.skill_ids:
			if DataRegistry.get_data("skills", String(skill_id)) == null:
				_err("unit %s: unknown skill %s" % [id, skill_id])


func check_items() -> void:
	_ids("items")
	for id in DataRegistry.all_ids("items"):
		var item := DataRegistry.get_data("items", id)
		if String(item.category) not in ["objective", "consumable"]:
			_err("item %s: unknown category %s" % [id, item.category])


func check_maps() -> void:
	_ids("maps")
	var glyphs: Dictionary = DataRegistry.rule("terrain_glyphs", {})
	for id in DataRegistry.all_ids("maps"):
		var m := DataRegistry.get_map(id)
		var rows: Array = m.terrain_rows
		if rows.is_empty():
			_err("map %s: no terrain rows" % id)
			continue
		for r_idx in rows.size():
			for g in String(rows[r_idx]):
				if not glyphs.has(String(g)):
					_err("map %s: unknown glyph '%s'" % [id, g])
		var w: int = rows[0].length()
		for r_idx in rows.size():
			if String(rows[r_idx]).length() != w:
				_warn("map %s: row %d width differs (non-rect map)" % [id, r_idx])
		for placement in m.enemy_placements + m.npc_placements:
			if DataRegistry.get_unit(String(placement.unit_id)) == null:
				_err("map %s: placement unknown unit %s" % [id, placement.unit_id])
			if not _cell_in_map(placement.cell, rows):
				_err("map %s: placement %s out of bounds" % [id, placement.unit_id])
		for cell in m.deploy_cells:
			if not _cell_in_map(cell, rows):
				_err("map %s: deploy cell out of bounds" % id)
		for item in m.item_placements:
			if DataRegistry.get_data("items", String(item.item_id)) == null:
				_err("map %s: unknown item %s" % [id, item.item_id])
		for cfg in m.objectives:
			if String(cfg.get("type", "")) not in OBJECTIVE_TYPES:
				_err("map %s: unknown objective type '%s'" % [id, cfg.get("type", "?")])
			elif ObjectiveBase.create(cfg) == null:
				_err("map %s: objective plugin failed (type %s)" % [id, cfg.get("type", "?")])
		for cfg in m.fail_conditions:
			if String(cfg.get("type", "")) not in OBJECTIVE_TYPES:
				_err("map %s: unknown fail condition type '%s'" % [id, cfg.get("type", "?")])
		for ev in m.events:
			var trigger := str(ev.get("trigger", ""))
			if trigger != "" and trigger not in EVENT_TRIGGERS:
				_err("map %s: unknown event trigger '%s'" % [id, trigger])
			for action in ev.get("actions", []):
				if str(action.get("type", "")) not in EVENT_ACTIONS:
					_err("map %s: unknown event action '%s'" % [id, action.get("type", "?")])


func _cell_in_map(cell: Vector2i, rows: Array) -> bool:
	return cell.y >= 0 and cell.y < rows.size() and cell.x >= 0 and cell.x < String(rows[cell.y]).length()


func check_chapters() -> void:
	_ids("chapters")
	for id in DataRegistry.all_ids("chapters"):
		var c := DataRegistry.get_chapter(id)
		if DataRegistry.get_map(String(c.map_id)) == null:
			_err("chapter %s: unknown map %s" % [id, c.map_id])
		for unit_id in c.deployable_unit_ids:
			if DataRegistry.get_unit(String(unit_id)) == null:
				_err("chapter %s: unknown deployable unit %s" % [id, unit_id])
		if String(c.story_dialogue_id) != "" and DataRegistry.get_dialogue(String(c.story_dialogue_id)) == null:
			_err("chapter %s: unknown story dialogue %s" % [id, c.story_dialogue_id])
		if String(c.post_dialogue_id) != "" and DataRegistry.get_dialogue(String(c.post_dialogue_id)) == null:
			_err("chapter %s: unknown post dialogue %s" % [id, c.post_dialogue_id])


func check_dialogues() -> void:
	_ids("dialogues")
	for id in DataRegistry.all_ids("dialogues"):
		var d := DataRegistry.get_dialogue(id)
		if d.lines.is_empty():
			_warn("dialogue %s: no lines" % id)


func check_bonds() -> void:
	_ids("bonds")
	for id in DataRegistry.all_ids("bonds"):
		var b := DataRegistry.get_data("bonds", id)
		if DataRegistry.get_unit(String(b.unit_a)) == null or DataRegistry.get_unit(String(b.unit_b)) == null:
			_err("bond %s: unknown unit(s)" % id)
		for rank in b.scene_dialogue_ids:
			var dlg_id := String(b.scene_dialogue_ids[rank])
			if dlg_id != "" and DataRegistry.get_dialogue(dlg_id) == null:
				_err("bond %s: unknown dialogue %s" % [id, dlg_id])
