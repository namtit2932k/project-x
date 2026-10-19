extends Node
## Data validation: run with
##   godot --headless --path . res://tools/validate_data.tscn
## Checks duplicate ids, broken references and missing fields across data/.
##
## Runs the checks TWICE (T2.9/T2.7): once for the base layers (old ch01 campaign data)
## with the profile overlay disabled, and once again with the balance_profile from
## rules_config merged in. Both must mention zero errors, otherwise the run fails.
## Every violation must be reported in hard text: broken data blocks the load, the engine
## never silently fixes or clamps (GDD-Map §7, GDD-Roster §6, GDD-Combat §13).

var errors: int = 0
var warnings: int = 0
## True while validating with the balance profile overlay loaded (pass 2).
var profile_active: bool = false

const OLD_UNIT_STAT_KEYS := ["hp", "atk", "def", "res", "skl", "spd", "mov", "crit", "hit"]
const GDD_UNIT_STAT_KEYS := ["hp", "str", "mag", "skill", "speed", "luck", "def", "res", "move", "base_vision"]
const OBJECTIVE_TYPES := ["eliminate", "escort", "escort_turns", "defend", "retrieve", "capture", "evacuate"]
const EVENT_TRIGGERS := ["enter_zone", "leave_zone", "pickup", "unit_dead", "turn_start", "turn_end", "talk", "faction_change"]
const EVENT_ACTIONS := ["spawn", "dialogue", "change_team", "set_flag", "win", "lose"]
const DIFFICULTIES := ["story", "normal", "hard", "nightmare"]
const AI_PROFILES := ["", "StandardAggressive", "Raider", "ProtectPersuade"]
const DEMO_STRICT := "res://data/balance/demo/"


func _ready() -> void:
	var profile: String = _current_profile()
	# Pass 1: base layers only (profile disabled).
	_set_profile("")
	DataRegistry._cache = _fresh_cache()
	DataRegistry._scan_all()
	run_checks("base")
	# Pass 2: base + configured balance profile overlay.
	if profile != "":
		_set_profile(profile)
		DataRegistry._cache = _fresh_cache()
		DataRegistry._scan_all()
		run_checks("profile:" + profile)
	else:
		print("validator: no balance profile configured, single pass")
	print("Validation done: %d errors, %d warnings" % [errors, warnings])
	get_tree().quit(1 if errors > 0 else 0)


func _current_profile() -> String:
	# Read the configured profile BEFORE pass 1 disables it; cache-bypass so the
	# _set_profile("") mutation never feeds back into this read.
	var configured: Resource = ResourceLoader.load(
		"res://data/rules/rules_config.tres", "", ResourceLoader.CACHE_MODE_REPLACE)
	var profile := String(configured.get("balance_profile")) if configured != null else ""
	_set_profile("")
	DataRegistry._cache = _fresh_cache()
	DataRegistry._scan_all()
	return profile


func _set_profile(value: String) -> void:
	var rules: Resource = load("res://data/rules/rules_config.tres")
	if rules != null:
		rules.set("balance_profile", value)
	# DataRegistry reads ITS rules reference; repoint it at the (reloaded) base config so
	# pass 1 truly scans base layers without the previous overlay still attached.
	DataRegistry._rules = rules


func _fresh_cache() -> Dictionary:
	var cache := {}
	for key: String in DataRegistry.SEARCH_FOLDERS:
		cache[key] = {}
	return cache


func _err(msg: String) -> void:
	errors += 1
	printerr("ERROR: " + msg)


func _warn(msg: String) -> void:
	warnings += 1
	print("WARNING: " + msg)


## True when the resource comes from the strict GDD/demo parity layer (T2.9).
func _is_strict_layer(res: Resource) -> bool:
	return res != null and res.resource_path.begins_with(DEMO_STRICT)


func _ids(kind: String) -> Dictionary:
	var out := {}
	for id in DataRegistry._cache[kind]:
		if out.has(id):
			_err("duplicate id in %s: %s" % [kind, id])
		out[id] = true
	return out


func run_checks(layer: String) -> void:
	profile_active = layer.begins_with("profile:")
	var before := {"e": errors, "w": warnings}
	check_rules()
	check_classes()
	check_units()
	check_weapons()
	check_items()
	check_maps()
	check_chapters()
	check_dialogues()
	check_bonds()
	check_reconcile_keys()
	print("pass %s: %d errors, %d warnings" % [layer, errors - int(before["e"]), warnings - int(before["w"])])


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
	var enemy_mult: Dictionary = DataRegistry.rule("enemy_stat_multiplier_by_difficulty", {})
	for difficulty in DIFFICULTIES:
		if not enemy_mult.has(difficulty):
			_err("rules: enemy_stat_multiplier_by_difficulty missing '%s'" % difficulty)
		# GDD-Combat §5: enemy multiplier never scales HP/Luck and stays sane.
		var mult := float(enemy_mult.get(difficulty, 1.0))
		if mult < 1.0 or mult > 2.0:
			_err("rules: enemy_stat_multiplier '%s' out of [1.0, 2.0]" % difficulty)
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
		var strict := _is_strict_layer(c)
		# T2.9 move bounds are a unit-level rule (units below); classes only cheap-check.
		if int(c.move_range) < 1:
			_err("class %s: move_range < 1" % [id])
		if int(c.attack_range_max) < int(c.attack_range_min):
			_err("class %s: attack range min > max" % id)
		if String(c.move_type) not in ["foot", "flying"]:
			_err("class %s: unknown movement '%s'" % [id, c.move_type])
		# T2.2: a non-empty weapon_id must resolve from the weapon catalog.
		if String(c.weapon_id) != "" and DataRegistry.get_weapon(String(c.weapon_id)) == null:
			_err("class %s: unknown weapon %s" % [id, c.weapon_id])
		for skill_id in c.skill_ids:
			if DataRegistry.get_data("skills", String(skill_id)) == null:
				_err("class %s: unknown skill %s" % [id, skill_id])


const SHARED_UNIT_STAT_KEYS := ["hp", "def", "res"]

func _unit_key_set(u: Resource) -> String:
	var has_old := false
	var has_new := false
	for key in u.base_stats:
		var k := str(key)
		if k in SHARED_UNIT_STAT_KEYS:
			continue
		if k in OLD_UNIT_STAT_KEYS:
			has_old = true
		if k in GDD_UNIT_STAT_KEYS:
			has_new = true
	if has_old and has_new:
		return "mixed"
	return "new" if has_new else "old"


func check_units() -> void:
	_ids("units")
	for id in DataRegistry.all_ids("units"):
		var u := DataRegistry.get_unit(id)
		if DataRegistry.get_battle_class(String(u.class_id)) == null:
			_err("unit %s: unknown class %s" % [id, u.class_id])
		var strict := _is_strict_layer(u)
		if not strict and DataRegistry.get_faction(String(u.faction_id)) == null:
			# Demo overlay ships its own sideless faction; base units must resolve theirs.
			_err("unit %s: unknown faction %s" % [id, u.faction_id])
		var key_set := _unit_key_set(u)
		if key_set == "mixed":
			_err("unit %s: base_stats mixes legacy and GDD stat keys" % id)
		# T2.9 strict ranges on the GDD parity layer; base layer keeps its own scale.
		# Demo NPc (messenger, evacuee...) follow scenario values, so move is checked only
		# for controllable units (D-B12).
		if strict and key_set == "new":
			for key in u.base_stats:
				if str(key) == "move" and not bool(u.controllable):
					continue
				check_unit_strict_stat(id, str(key), int(u.base_stats[key]))
		elif strict:
			for key in u.growths:
				if str(key) not in OLD_UNIT_STAT_KEYS:
					_err("unit %s: unknown growths key '%s'" % [id, str(key)])
			for stat_key in u.base_stats:
				if str(stat_key) not in OLD_UNIT_STAT_KEYS:
					_err("unit %s: unknown base_stats key '%s'" % [id, str(stat_key)])
		if String(u.ai_profile) not in AI_PROFILES:
			_err("unit %s: unknown ai_profile '%s'" % [id, u.ai_profile])
		if String(u.priority_target_id) != "" and DataRegistry.get_unit(String(u.priority_target_id)) == null:
			_err("unit %s: unknown priority target %s" % [id, u.priority_target_id])
		# T2.9: carried item slots cap.
		if u.carried_items.size() > int(DataRegistry.rule("max_item_slots", 2)):
			_err("unit %s: carried %d items, cap is %d" % [id, u.carried_items.size(), int(DataRegistry.rule("max_item_slots", 2))])
		for item_id in u.carried_items:
			if DataRegistry.get_data("items", String(item_id)) == null:
				_err("unit %s: unknown carried item %s" % [id, item_id])
			elif not _is_strict_layer(u) and DataRegistry.get_data("items", String(item_id)).category == "consumable":
				_err("unit %s: enemy unit carries consumable %s (GDD-Roster §6)" % [id, item_id])
		for skill_id in u.skill_ids:
			if DataRegistry.get_data("skills", String(skill_id)) == null:
				_err("unit %s: unknown skill %s" % [id, skill_id])
		# D03: reconcile event keys must be declared on a unit of that remnant faction.
		if String(u.reconcile_event_key) != "" and DataRegistry.get_faction(String(u.faction_id)) == null:
			_err("unit %s: reconcile_event_key with unknown faction %s" % [id, u.faction_id])


func check_unit_strict_stat(id: String, key: String, value: int) -> void:
	match key:
		"hp":
			if value < 15 or value > 60:
				_err("unit %s: hp %d outside 15-60" % [id, value])
		"move":
			# T2.9 bounds 4-7 target controllable roster units; demo NPc (messenger, evacuee)
			# follow the scenario values instead (D-B12).
			if value < 4 or value > 7:
				_err("unit %s: move %d outside 4-7" % [id, value])
		"base_vision":
			if value != 0 and (value < 3 or value > 6):
				_err("unit %s: base_vision %d outside 3-6 (0 = inherit)" % [id, value])
		_:
			if value < 0 or value > 30:
				_err("unit %s: stat %s=%d outside 0-30" % [id, key, value])


func check_weapons() -> void:
	_ids("weapons")
	for id in DataRegistry.all_ids("weapons"):
		var w := DataRegistry.get_weapon(id)
		if String(w.action_category) not in ["Combat", "Heal", "None"]:
			_err("weapon %s: unknown action_category '%s'" % [id, w.action_category])
		if int(w.weapon_range.y) < int(w.weapon_range.x):
			_err("weapon %s: range min > max (GDD-Combat §13, never clamped)" % id)
		if String(w.action_category) == "Combat":
			if String(w.attack_type) not in ["Physical", "Magic"]:
				_err("weapon %s: combat weapon needs attack_type Physical|Magic" % id)
			if int(w.heal_might) != 0:
				_err("weapon %s: combat weapon with heal_might" % id)
		if String(w.action_category) == "Heal" and int(w.heal_might) <= 0:
			_err("weapon %s: heal weapon with heal_might <= 0" % id)
		if int(w.heal_range.y) < int(w.heal_range.x):
			_err("weapon %s: heal_range min > max" % id)


## D03: every required event key of a remnant faction must come from a unit of that
## faction (UnitData.reconcile_event_key), so no dead vocabulary hides in faction data.
func check_reconcile_keys() -> void:
	var keys_by_faction := {}
	for unit_id in DataRegistry.all_ids("units"):
		var u := DataRegistry.get_unit(unit_id)
		var key := String(u.reconcile_event_key)
		if key != "":
			if not keys_by_faction.has(String(u.faction_id)):
				keys_by_faction[String(u.faction_id)] = []
			keys_by_faction[String(u.faction_id)].append(key)
	for faction_id in DataRegistry.all_ids("factions"):
		var f := DataRegistry.get_faction(faction_id)
		if f == null or String(f.remnant_id) == "":
			continue
		var known: Array = keys_by_faction.get(faction_id, [])
		for ev in f.reconcile.get("required_events", []):
			if str(ev) not in known:
				_err("faction %s: required event '%s' has no unit reconcile_event_key" % [faction_id, str(ev)])


func check_items() -> void:
	_ids("items")
	for id in DataRegistry.all_ids("items"):
		var item := DataRegistry.get_data("items", id)
		var cat := String(item.category)
		if cat not in ["objective", "consumable"]:
			_err("item %s: unknown category %s" % [id, cat])
			continue
		if cat == "consumable":
			if String(item.type) not in ["Heal", "Buff"]:
				_err("item %s: unknown consumable type %s" % [id, item.type])
			elif String(item.type) == "Heal" and int(item.heal_value) <= 0:
				_err("item %s: heal item with heal_value <= 0" % id)
			elif String(item.type) == "Buff":
				if String(item.buff_stat) not in ["hp", "str", "mag", "skill", "speed", "luck", "def", "res"]:
					_err("item %s: unknown buff_stat '%s'" % [id, item.buff_stat])
				if int(item.buff_amount) <= 0 or int(item.buff_duration) <= 0:
					_err("item %s: buff needs amount > 0 and duration > 0" % id)


func check_maps() -> void:
	_ids("maps")
	var glyphs: Dictionary = DataRegistry.rule("terrain_glyphs", {})
	var defs: Dictionary = DataRegistry.rule("terrain_defs", {})
	for id in DataRegistry.all_ids("maps"):
		var m := DataRegistry.get_map(id)
		# Pass 1 (base layer) has no profile overlay, so parity maps/chapters that only
		# resolve through it are validated in pass 2 only.
		if not profile_active and id.begins_with("map_demo_"):
			continue
		var strict := _is_strict_layer(m)
		var rows: Array = m.terrain_rows
		if rows.is_empty():
			_err("map %s: no terrain rows" % id)
			continue
		for r_idx in rows.size():
			for g in String(rows[r_idx]):
				if not glyphs.has(String(g)):
					_err("map %s: unknown glyph '%s'" % [id, g])
		var width: int = String(rows[0]).length()
		for r_idx in rows.size():
			if String(rows[r_idx]).length() != width:
				_warn("map %s: row %d width differs (non-rect map)" % [id, r_idx])
		var passable_ids := {}
		for r_idx in rows.size():
			var row := String(rows[r_idx])
			for c_idx in row.length():
				var terrain := str(glyphs.get(String(row[c_idx]), ""))
				var td: Dictionary = defs.get(terrain, {})
				if not bool(td.get("blocked", false)):
					passable_ids["%d,%d" % [c_idx, r_idx]] = true
		for placement in m.enemy_placements + m.npc_placements:
			if DataRegistry.get_unit(String(placement.unit_id)) == null:
				_err("map %s: placement unknown unit %s" % [id, placement.unit_id])
			if not _cell_in_map(placement.cell, rows):
				_err("map %s: placement %s out of bounds" % [id, placement.unit_id])
			elif not passable_ids.has("%d,%d" % [int(placement.cell.x), int(placement.cell.y)]):
				_err("map %s: placement %s on impassable tile" % [id, placement.unit_id])
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
		if strict:
			_check_map_strict(id, m)


## Appendix E map-load checklist (GDD-Map §7), for the parity layer's maps only.
func _check_map_strict(id: String, m: Resource) -> void:
	var cap := int(m.map_deploy_cap)
	if cap < 1 or cap > 10:
		_err("map %s: map_deploy_cap outside 1-10" % id)
	if cap > m.deploy_tiles.size():
		_err("map %s: map_deploy_cap %d exceeds deploy tile count %d" % [id, cap, m.deploy_tiles.size()])
	if int(m.turn_par) <= 0:
		_err("map %s: turn_par is required (GDD-Map §7)" % id)
	if int(m.turn_limit) > 0 and int(m.turn_par) > int(m.turn_limit):
		_err("map %s: turn_par %d exceeds turn_limit %d" % [id, int(m.turn_par), int(m.turn_limit)])
	var obj_type := str(m.objective_type)
	if obj_type not in ["Elimination", "Escort", "Protect", "Retrieve", "Seize"]:
		_err("map %s: unknown objective_type '%s'" % [id, obj_type])
	# Escort constraints.
	if obj_type == "Escort":
		if DataRegistry.get_unit(String(m.escort_unit_id)) == null:
			_err("map %s: escort_unit_id unknown" % id)
		if int(m.escort_turns_required) > 0 and Vector2i(m.escort_goal) != Vector2i(-1, -1):
			_err("map %s: escort declares both a goal tile and a turn budget (variants are exclusive)" % id)
		elif int(m.escort_turns_required) <= 0 and Vector2i(m.escort_goal) == Vector2i(-1, -1):
			_err("map %s: escort needs either a goal tile or escort_turns_required" % id)
		if int(m.escort_turns_required) > 0 and int(m.turn_par) < int(m.escort_turns_required):
			_err("map %s: turn_par < escort_turns_required" % id)
	# Protect (zone) constraints.
	if obj_type == "Protect":
		var zone: Rect2i = m.protect_zone
		var rows: Array = m.terrain_rows
		if zone.size == Vector2i.ZERO:
			_err("map %s: protect zone not declared" % id)
		elif zone.position.x < 0 or zone.position.y < 0 \
				or zone.end.x > rows[0].length() or zone.end.y > rows.size():
			_err("map %s: protect zone out of bounds" % id)
		if int(m.survive_enemy_phases) <= 0:
			_err("map %s: survive_enemy_phases must be > 0" % id)
		elif int(m.turn_par) < int(m.survive_enemy_phases):
			_err("map %s: turn_par < survive_enemy_phases" % id)
	# Retrieve constraints.
	if obj_type == "Retrieve":
		if Vector2i(m.item_tile) == Vector2i(-1, -1) or Vector2i(m.return_tile) == Vector2i(-1, -1):
			_err("map %s: retrieve needs item_tile and return_tile" % id)
		elif Vector2i(m.item_tile) == Vector2i(m.return_tile):
			_err("map %s: retrieve item_tile must differ from return_tile" % id)
	# Seize constraints.
	if obj_type == "Seize":
		if Vector2i(m.control_point) == Vector2i(-1, -1):
			_err("map %s: seize needs control_point" % id)
		if int(m.hold_enemy_phases) <= 0:
			_err("map %s: hold_enemy_phases must be > 0" % id)
		elif int(m.turn_par) < int(m.hold_enemy_phases):
			_err("map %s: turn_par < hold_enemy_phases" % id)
	# Village rewards: exactly one of gold or a real item id.
	for village in m.villages:
		var gold := int(village.get("gold_amount", 0))
		var item_id := String(village.get("item_id", ""))
		if gold > 0 and item_id != "":
			_err("map %s: village declares both a gold and an item reward" % id)
		elif gold == 0 and item_id == "":
			_err("map %s: village with no reward" % id)
		elif item_id != "" and DataRegistry.get_data("items", item_id) == null:
			_err("map %s: village item '%s' is not in the catalog" % [id, item_id])
	# Map-local bond pairs must reference real units and an existing bond pair.
	for bond_pair in m.bonds:
		if DataRegistry.get_unit(String(bond_pair.get("a", ""))) == null \
				or DataRegistry.get_unit(String(bond_pair.get("b", ""))) == null:
			_err("map %s: bond pair references unknown unit(s)" % id)
	if String(m.key_unit_id) != "" and DataRegistry.get_unit(String(m.key_unit_id)) == null:
		_err("map %s: key_unit_id unknown" % id)
	if String(m.faction.get("faction_id", "")) != "" and DataRegistry.get_faction(String(m.faction.get("faction_id"))) == null:
		_err("map %s: faction_id unknown" % id)


func _cell_in_map(cell: Vector2i, rows: Array) -> bool:
	return cell.y >= 0 and cell.y < rows.size() and cell.x >= 0 and cell.x < String(rows[cell.y]).length()


func check_chapters() -> void:
	_ids("chapters")
	for id in DataRegistry.all_ids("chapters"):
		if not profile_active and id.begins_with("chapter_demo_"):
			continue
		var c := DataRegistry.get_chapter(id)
		if DataRegistry.get_map(String(c.map_id)) == null:
			_err("chapter %s: unknown map %s" % [id, c.map_id])
		# Campaign-critical units (D02) count toward deploy_max; a requirement pile above the
		# deploy cap makes the chapter literally undeployable.
		var required_count := 0
		var unit_error := false
		for unit_id in c.deployable_unit_ids:
			if DataRegistry.get_unit(String(unit_id)) == null:
				_err("chapter %s: unknown deployable unit %s" % [id, unit_id])
				unit_error = true
				continue
			var ud_req := DataRegistry.get_unit(String(unit_id))
			if bool(ud_req.is_protagonist) or bool(ud_req.must_survive):
				required_count += 1
		if required_count > int(c.deploy_max):
			_err("chapter %s: %d required-live units exceed deploy_max %d" % [id, required_count, int(c.deploy_max)])
		if String(c.story_dialogue_id) != "" and DataRegistry.get_dialogue(String(c.story_dialogue_id)) == null:
			_err("chapter %s: unknown story dialogue %s" % [id, c.story_dialogue_id])
		if String(c.post_dialogue_id) != "" and DataRegistry.get_dialogue(String(c.post_dialogue_id)) == null:
			_err("chapter %s: unknown post dialogue %s" % [id, c.post_dialogue_id])
		if unit_error:
			_warn("chapter %s: deploy list had unknown units, required-live count may be off" % id)


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
		# D05: every rank that has a scene threshold must have a playable scene dialogue.
		for rank_key in b.scene_thresholds:
			if not b.scene_dialogue_ids.has(rank_key) or String(b.scene_dialogue_ids[rank_key]) == "":
				_err("bond %s: rank %s has a threshold but no scene dialogue id" % [id, rank_key])
