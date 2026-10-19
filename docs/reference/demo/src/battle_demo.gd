extends Control
## Authored example maps illustrating battle objectives.

signal battle_finished(result: Dictionary, state: String, finished_map_index: int)
signal combat_view_changed(active: bool)
signal village_gold_changed(total: int)
signal action_menu_requested

const BattleGrid = preload("res://src/battle_grid.gd")
const CombatRules = preload("res://src/combat_rules.gd")
const BattleDataValidator = preload("res://src/battle_data_validator.gd")
const CombatPresentation = preload("res://src/ui/combat_presentation.gd")
const DATA_PATH := "res://data/battle_demo.json"
const BOARD_ORIGIN := Vector2(44, 92)

var grid: RefCounted = BattleGrid.new()
var combat: RefCounted = CombatRules.new()
var battle_data: Dictionary = {}
var map_data: Dictionary = {}
var units: Array[Dictionary] = []
var map_index: int = 0
var selected: int = -1
var pending_action: String = ""
var move_origin: Vector2i = Vector2i.ZERO
var preview_target: int = -1
var reachable_cells: Dictionary = {}
var player_attack_cells: Dictionary = {}
var inspected_enemy: int = -1
var enemy_move_cells: Dictionary = {}
var enemy_attack_cells: Dictionary = {}
var inspected_npc: int = -1
var npc_move_cells: Dictionary = {}
var turn_number: int = 1
var enemy_phases: int = 0
var battle_kills: int = 0
var persuasion_kills: int = 0
var persistent_kills: int = 0
var faction_state: String = "Engaged"
var rewind_charges: int = 0
var rewind_unlimited: bool = false
var embedded_mode: bool = false
var selected_deployment_ids: Array[String] = []
var stat_upgrades: Dictionary = {}
var starting_items: Dictionary = {}
var snapshots: Array[Dictionary] = []
var support_progress: Dictionary = {}
var outcome: String = ""
var summary: Dictionary = {}
var aftermath_visible: bool = false
var aftermath_state: String = ""
var item_carrier_id: String = ""
var control_progress: int = 0
var village_states: Dictionary = {}
var village_gold_earned: int = 0
var message: String = ""
var rng := RandomNumberGenerator.new()
## Set false only for nonvisual rules tests; playable battles show combat.
var combat_presentation_enabled: bool = true
var combat_view: Control
var _recording_exchange: bool = false
var _exchange_attacker: int = -1
var _recorded_strikes: Array[Dictionary] = []
var _pending_battle_finished: bool = false


func _ready() -> void:
	combat_view = CombatPresentation.new()
	combat_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combat_view)
	combat_view.presentation_state_changed.connect(_on_combat_view_changed)
	combat_view.presentation_finished.connect(_on_combat_view_finished)
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Không mở được dữ liệu màn chơi")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var errors: Array[String] = accept_battle_data(parsed)
	if not errors.is_empty():
		push_error("Dữ liệu màn chơi không hợp lệ: %s" % "; ".join(errors))
		return
	rng.seed = 20261005
	load_example(0)


## Accepts authored battle data only after every map passes validation.
## Returns errors and preserves the current data when validation fails.
func accept_battle_data(data: Variant) -> Array[String]:
	var errors: Array[String] = BattleDataValidator.validate(data)
	if not errors.is_empty():
		return errors
	var validated_data: Dictionary = data
	battle_data = validated_data.duplicate(true)
	return errors


## Loads an authored map and resets its battle state. Empty selection deploys the authored default.
func load_example(index: int, deployment_ids: Array[String] = []) -> void:
	if battle_data.is_empty() or index < 0 or index >= battle_data["maps"].size():
		return
	combat_view.reset()
	_pending_battle_finished = false
	map_index = index
	map_data = battle_data["maps"][index].duplicate(true)
	var grid_data: Dictionary = map_data.duplicate(true)
	grid_data["terrain_rules"] = battle_data["terrain_rules"]
	if not grid.load_map(grid_data):
		push_error("Map không hợp lệ: " + str(map_data["id"]))
		return
	units.clear()
	for deployment in map_data["deployments"]:
		if not deployment_ids.is_empty() and battle_data["unit_catalog"][deployment["template"]]["side"] == "player" and bool(battle_data["unit_catalog"][deployment["template"]].get("controllable", true)) and not deployment_ids.has(str(deployment["id"])):
			continue
		var unit: Dictionary = battle_data["unit_catalog"][deployment["template"]].duplicate(true)
		unit["id"] = deployment["id"]
		unit["x"] = deployment["x"]
		unit["y"] = deployment["y"]
		unit["max_hp"] = unit["hp"]
		if unit["side"] == "player" and bool(unit.get("controllable", true)):
			unit["carried_items"] = starting_items.get(str(unit["id"]), unit.get("carried_items", [])).duplicate()
			unit["active_buffs"] = {}
		if unit["side"] == "player" and bool(unit.get("controllable", true)) and stat_upgrades.has(str(unit["id"])):
			for stat in stat_upgrades[str(unit["id"])].keys():
				unit[stat] = int(unit[stat]) + int(stat_upgrades[str(unit["id"])][stat])
			unit["max_hp"] = unit["hp"]
		elif unit["side"] == "enemy":
			var multiplier := float(battle_data["difficulty"].get("enemy_stat_multiplier", 1.0))
			for stat in ["str", "mag", "skill", "speed", "def", "res"]:
				unit[stat] = floori(int(unit[stat]) * multiplier)
		unit["moved"] = false
		unit["acted"] = false
		unit["has_traded_this_phase"] = false
		unit["last_context"] = "Hold"
		units.append(unit)
	combat.setup(battle_data, map_data, units)
	selected = -1
	pending_action = ""
	preview_target = -1
	reachable_cells.clear()
	player_attack_cells.clear()
	_clear_enemy_inspection()
	_clear_npc_inspection()
	turn_number = 1
	enemy_phases = 0
	battle_kills = 0
	persuasion_kills = 0
	persistent_kills = int(map_data.get("faction", {}).get("prior_kills", 0))
	faction_state = "Unpersuadable" if map_data.has("faction") and persistent_kills >= int(map_data["faction"]["kill_threshold"]) else "Engaged"
	rewind_charges = int(battle_data["difficulty"]["rewind_charges"])
	rewind_unlimited = bool(battle_data["difficulty"].get("rewind_unlimited", false))
	snapshots.clear()
	support_progress.clear()
	outcome = ""
	summary.clear()
	aftermath_visible = false
	aftermath_state = ""
	item_carrier_id = ""
	control_progress = 0
	village_states.clear()
	for village in map_data.get("villages", []):
		village_states[_village_key(Vector2i(int(village["x"]), int(village["y"])))] = "Available"
	village_gold_earned = 0
	village_gold_changed.emit(0)
	message = "Chọn quân xanh; di chuyển hoặc bấm lại quân để mở menu hành động." if embedded_mode else "Chọn quân xanh; bấm mục tiêu hai lần để xem rồi xác nhận đòn đánh."
	_record_boundary()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if battle_data.is_empty() or not visible:
		return
	if combat_view.active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				combat_view.skip()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				combat_view.advance()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			combat_view.advance()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if embedded_mode and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_R, KEY_ENTER, KEY_KP_ENTER]:
			return
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				load_example(event.keycode - KEY_1)
			KEY_R:
				load_example(map_index)
			KEY_ESCAPE:
				if not pending_action.is_empty():
					pending_action = ""
					preview_target = -1
					action_menu_requested.emit()
				elif aftermath_visible:
					aftermath_visible = false
				else:
					selected = -1
					preview_target = -1
					reachable_cells.clear()
					player_attack_cells.clear()
					_clear_enemy_inspection()
					_clear_npc_inspection()
				queue_redraw()
			KEY_ENTER, KEY_KP_ENTER:
				if not outcome.is_empty() and summary.get("eligible", false):
					aftermath_visible = true
					queue_redraw()
			KEY_W:
				if not embedded_mode and selected >= 0 and outcome.is_empty():
					if _is_item_carrier(selected):
						message = "Người cầm tài liệu chỉ có thể di chuyển. Space để hết lượt."
						queue_redraw()
					else:
						_finish_action("%s chờ." % units[selected]["name"])
			KEY_Z:
				_rewind_last_action()
			KEY_SPACE:
				if outcome.is_empty() and pending_action.is_empty():
					_end_player_turn()
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT or not outcome.is_empty():
		return
	var size: int = int(battle_data["tile_size"])
	var point: Vector2 = (event.position - BOARD_ORIGIN) / float(size)
	var cell := Vector2i(floori(point.x), floori(point.y))
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.width or cell.y >= grid.height:
		return
	var clicked: int = _unit_at(cell)
	if clicked >= 0 and units[clicked]["side"] == "player":
		if inspected_enemy >= 0:
			_clear_enemy_inspection()
			queue_redraw()
		if inspected_npc >= 0 and inspected_npc != clicked:
			_clear_npc_inspection()
			queue_redraw()
		if selected >= 0 and selected != clicked and _healer_can_reach(selected, clicked) and (pending_action == "Heal" or not embedded_mode):
			_heal_target(clicked)
		elif pending_action == "Heal" and selected == clicked and _healer_can_reach(selected, clicked):
			_heal_target(clicked)
		elif not pending_action.is_empty():
			message = "Chọn một mục tiêu hợp lệ hoặc Esc để trở lại menu."
			queue_redraw()
		elif selected == clicked and not bool(units[selected]["moved"]) and embedded_mode:
			_confirm_no_move()
		elif bool(units[clicked].get("controllable", true)) and not units[clicked]["acted"]:
			_select_unit(clicked)
		elif not bool(units[clicked].get("controllable", true)):
			if inspected_npc == clicked:
				_clear_npc_inspection()
				message = "Đã đóng tầm di chuyển của NPC."
				queue_redraw()
			else:
				_inspect_npc(clicked)
	elif clicked >= 0 and units[clicked]["side"] == "enemy":
		if selected >= 0 and (pending_action == "Attack" or not embedded_mode) and (_is_item_carrier(selected) or combat.in_range(units[selected], units[clicked])):
			_player_attack(clicked)
		elif not pending_action.is_empty():
			message = "Mục tiêu không hợp lệ. Esc để trở lại menu."
			queue_redraw()
		elif inspected_enemy == clicked:
			_clear_enemy_inspection()
			message = "Đã đóng tầm di chuyển và tầm đánh của địch."
			queue_redraw()
		else:
			_inspect_enemy(clicked)
	elif selected >= 0 and reachable_cells.has(cell):
		move_origin = _cell(selected)
		units[selected]["x"] = cell.x
		units[selected]["y"] = cell.y
		units[selected]["moved"] = true
		preview_target = -1
		reachable_cells.clear()
		_update_player_attack_cells()
		if map_data["objective_type"] == "Retrieve" and item_carrier_id.is_empty() and cell == _map_point("item_tile"):
			item_carrier_id = str(units[selected]["id"])
			_finish_action("%s đã lấy tài liệu; từ giờ chỉ có thể di chuyển." % units[selected]["name"])
			_check_outcome()
		elif _is_item_carrier(selected):
			_finish_action("%s mang tài liệu di chuyển." % units[selected]["name"])
			_check_outcome()
		else:
			if embedded_mode:
				action_menu_requested.emit()
			else:
				message = "%s đã đi. Chọn mục tiêu hoặc W để chờ." % units[selected]["name"]
				queue_redraw()
	elif inspected_enemy >= 0 or inspected_npc >= 0:
		_clear_enemy_inspection()
		_clear_npc_inspection()
		queue_redraw()


func _select_unit(index: int) -> void:
	_clear_enemy_inspection()
	_clear_npc_inspection()
	selected = index
	pending_action = ""
	move_origin = _cell(index)
	preview_target = -1
	reachable_cells.clear()
	if not units[index]["moved"]:
		reachable_cells = grid.reachable(_cell(index), int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
	_update_player_attack_cells()
	message = "%s: %d/%d HP. Bấm lại quân để đứng yên và mở menu hành động." % [units[index]["name"], units[index]["hp"], units[index]["max_hp"]]
	queue_redraw()


func _confirm_no_move() -> void:
	move_origin = _cell(selected)
	units[selected]["moved"] = true
	reachable_cells.clear()
	_update_player_attack_cells()
	action_menu_requested.emit()


func cancel_action_menu() -> bool:
	if selected < 0 or bool(units[selected].get("has_traded_this_phase", false)):
		return false
	units[selected]["x"] = move_origin.x
	units[selected]["y"] = move_origin.y
	units[selected]["moved"] = false
	pending_action = ""
	preview_target = -1
	reachable_cells = grid.reachable(_cell(selected), int(units[selected]["move"]), _occupied_except(selected), _allied_occupied_except(selected))
	_update_player_attack_cells()
	queue_redraw()
	return true


func legal_actions() -> Array[String]:
	var actions: Array[String] = []
	if selected < 0 or not _active(selected) or bool(units[selected].get("acted", false)):
		return actions
	if not _is_item_carrier(selected):
		var weapon: Dictionary = combat.weapon(units[selected])
		for i in units.size():
			if not _active(i):
				continue
			if units[i]["side"] == "enemy" and weapon.get("action_category", "Combat") == "Combat" and combat.in_range(units[selected], units[i]):
				if not actions.has("Attack"):
					actions.append("Attack")
			elif units[i]["side"] == "player" and weapon.get("action_category", "Combat") == "Heal" and _healer_can_reach(selected, i):
				if not actions.has("Heal"):
					actions.append("Heal")
		if not units[selected].get("carried_items", []).is_empty():
			actions.append("Use Item")
		if can_visit():
			actions.append("Visit")
		for i in units.size():
			if can_trade(i):
				actions.append("Trade")
				break
	actions.append("Wait")
	return actions


func _update_player_attack_cells() -> void:
	player_attack_cells.clear()
	if selected < 0 or _is_item_carrier(selected):
		return
	var origins: Dictionary = reachable_cells.duplicate()
	origins[_cell(selected)] = 0
	player_attack_cells = _attack_fringe(selected, origins)


func _inspect_enemy(index: int) -> void:
	_clear_npc_inspection()
	selected = -1
	pending_action = ""
	preview_target = -1
	reachable_cells.clear()
	player_attack_cells.clear()
	inspected_enemy = index
	enemy_move_cells = grid.reachable(_cell(index), int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
	enemy_move_cells[_cell(index)] = 0
	enemy_attack_cells = _attack_fringe(index, enemy_move_cells)
	message = "%s: xanh là tầm đi, đỏ là tầm đánh sau khi đi." % units[index]["name"]
	queue_redraw()


func _attack_fringe(index: int, move_cells: Dictionary) -> Dictionary:
	var attack_cells: Dictionary = {}
	var weapon: Dictionary = combat.weapon(units[index])
	if weapon.get("action_category", "Combat") == "Combat":
		var min_range: int = int(weapon["range"][0])
		var max_range: int = int(weapon["range"][1])
		for origin in move_cells.keys():
			for y in range(maxi(0, origin.y - max_range), mini(grid.height, origin.y + max_range + 1)):
				for x in range(maxi(0, origin.x - max_range), mini(grid.width, origin.x + max_range + 1)):
					var cell := Vector2i(x, y)
					var distance: int = _distance(origin, cell)
					if distance >= min_range and distance <= max_range and not move_cells.has(cell):
						attack_cells[cell] = true
	return attack_cells


func _clear_enemy_inspection() -> void:
	inspected_enemy = -1
	enemy_move_cells.clear()
	enemy_attack_cells.clear()


func _inspect_npc(index: int) -> void:
	_clear_enemy_inspection()
	selected = -1
	preview_target = -1
	reachable_cells.clear()
	player_attack_cells.clear()
	inspected_npc = index
	npc_move_cells = grid.reachable(_cell(index), int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
	if map_data.has("escort_goal") and str(map_data.get("escort_unit_id", "")) == str(units[index]["id"]) and _cell(index) == _map_point("escort_goal"):
		npc_move_cells.clear()
	npc_move_cells[_cell(index)] = 0
	message = "%s là NPC nhiệm vụ: vàng là tầm có thể đi, không thể điều khiển." % units[index]["name"]
	queue_redraw()


func _clear_npc_inspection() -> void:
	inspected_npc = -1
	npc_move_cells.clear()


func _player_attack(target: int) -> void:
	if _is_item_carrier(selected):
		message = "Người cầm tài liệu không thể tấn công."
		queue_redraw()
		return
	if units[target]["side"] != "enemy" or not combat.in_range(units[selected], units[target]):
		message = "Mục tiêu ngoài tầm vũ khí."
		queue_redraw()
		return
	if preview_target != target:
		preview_target = target
		message = "Bấm mục tiêu lần nữa để xác nhận; Esc để hủy."
		queue_redraw()
		return
	var actor: int = selected
	_resolve_exchange(actor, target, false)
	_finish_action(message)
	_check_outcome()


func _heal_target(target: int) -> void:
	if _is_item_carrier(selected):
		message = "Người cầm tài liệu không thể dùng hành động khác."
		queue_redraw()
		return
	if preview_target != target:
		preview_target = target
		message = "Bấm đồng đội lần nữa để xác nhận hồi máu."
		queue_redraw()
		return
	var weapon: Dictionary = combat.weapon(units[selected])
	var amount: int = combat.effective_stat(units[selected], "mag") + int(weapon["heal_might"])
	var before: int = int(units[target]["hp"])
	units[target]["hp"] = mini(int(units[target]["max_hp"]), before + amount)
	if int(units[target]["hp"]) > before:
		_record_support_for_action(selected)
	_finish_action("%s hồi %d HP cho %s." % [units[selected]["name"], int(units[target]["hp"]) - before, units[target]["name"]])


func _healer_can_reach(healer: int, target: int) -> bool:
	var weapon: Dictionary = combat.weapon(units[healer])
	if weapon.get("action_category", "Combat") != "Heal":
		return false
	var distance: int = _distance(_cell(healer), _cell(target))
	return distance >= int(weapon["heal_range"][0]) and distance <= int(weapon["heal_range"][1])


func _resolve_exchange(attacker: int, defender: int, enemy_restrained: bool) -> void:
	_record_support_for_action(attacker)
	var opening_left: Dictionary = _combat_fighter_snapshot(attacker)
	var opening_right: Dictionary = _combat_fighter_snapshot(defender)
	_recorded_strikes.clear()
	_exchange_attacker = attacker
	_recording_exchange = combat_presentation_enabled
	var attacker_doubles: bool = combat.preview(units[attacker], units[defender])["doubles"]
	var defender_doubles: bool = combat.preview(units[defender], units[attacker]).get("doubles", false) if combat.weapon(units[defender]).get("action_category", "Combat") == "Combat" and not _is_item_carrier(defender) else false
	_strike(attacker, defender, enemy_restrained, "TẤN CÔNG")
	if _active(attacker) and _active(defender) and not _is_item_carrier(defender) and combat.in_range(units[defender], units[attacker]):
		var counter_restrained: bool = _is_restrained(defender, str(units[defender]["last_context"]))
		_strike(defender, attacker, counter_restrained, "PHẢN CÔNG")
		if defender_doubles and _active(attacker) and _active(defender):
			_strike(defender, attacker, counter_restrained, "ĐÁNH ĐÔI")
	if attacker_doubles and _active(attacker) and _active(defender) and combat.in_range(units[attacker], units[defender]):
		_strike(attacker, defender, enemy_restrained, "ĐÁNH ĐÔI")
	_recording_exchange = false
	_exchange_attacker = -1
	if combat_presentation_enabled and not _recorded_strikes.is_empty():
		combat_view.enqueue({"left": opening_left, "right": opening_right, "strikes": _recorded_strikes.duplicate(true)})
	queue_redraw()


func _record_support_for_action(actor: int) -> void:
	if str(units[actor]["side"]) != "player" or not bool(units[actor].get("controllable", true)):
		return
	var actor_id := str(units[actor]["id"])
	for pairing in map_data.get("bonds", []):
		var a := str(pairing["a"])
		var b := str(pairing["b"])
		if actor_id != a and actor_id != b:
			continue
		var partner := _index_by_id(b if actor_id == a else a)
		if partner < 0 or not _active(partner) or _distance(_cell(actor), _cell(partner)) != 1:
			continue
		var ids := [a, b]
		ids.sort()
		var key := "%s|%s" % ids
		support_progress[key] = mini(2, int(support_progress.get(key, 0)) + 1)


func _combat_fighter_snapshot(index: int) -> Dictionary:
	return {"name": str(units[index]["name"]), "class": str(units[index]["class"]), "side": str(units[index]["side"]), "hp": int(units[index]["hp"]), "max_hp": int(units[index]["max_hp"])}


func _record_strike(attacker: int, defender: int, label: String, hit: bool, critical: bool, damage: int, odds: Dictionary) -> void:
	if not _recording_exchange:
		return
	var actor_side: String = "left" if attacker == _exchange_attacker else "right"
	_recorded_strikes.append({"actor": actor_side, "target": "right" if actor_side == "left" else "left", "label": label, "hit": hit, "critical": critical, "damage": damage, "target_hp": int(units[defender]["hp"]), "hit_chance": int(odds["hit"]), "crit_chance": int(odds["crit"])})


func _strike(attacker: int, defender: int, restrained: bool, label: String = "TẤN CÔNG") -> void:
	var odds: Dictionary = combat.preview(units[attacker], units[defender])
	if rng.randi_range(1, 100) > int(odds["hit"]):
		message = "%s đánh hụt %s." % [units[attacker]["name"], units[defender]["name"]]
		_record_strike(attacker, defender, label, false, false, 0, odds)
		return
	var critical: bool = rng.randi_range(1, 100) <= int(odds["crit"])
	var damage: int = int(odds["damage"])
	if critical:
		damage = floori(damage * float(battle_data["combat_rules"]["crit_multiplier"]))
	if restrained:
		damage = mini(damage, int(units[defender]["hp"]) - 1)
	var before_hp: int = int(units[defender]["hp"])
	units[defender]["hp"] = maxi(0, int(units[defender]["hp"]) - damage)
	var dealt: int = before_hp - int(units[defender]["hp"])
	message = "%s đánh %s: -%d HP%s." % [units[attacker]["name"], units[defender]["name"], dealt, " (chí mạng)" if critical else ""]
	_record_strike(attacker, defender, label, true, critical, dealt, odds)
	if int(units[defender]["hp"]) == 0 and units[defender]["side"] == "enemy":
		_register_enemy_kill(defender)
	queue_redraw()


## Updates the two kill counters for a defeated enemy unit of the map's
## tagged holdout faction. `battle_kills` is Dual Restraint Scoring's
## whole-battle count — it never stops incrementing, even after the faction
## turns `Unpersuadable`, and is what the post-battle summary and the
## kill-tolerance scoring term read. `persuasion_kills` is Persuasion
## System's own `current_battle_kill_count` — it only increments while
## `faction_state == "Engaged"` (AC-PS8: a terminal faction ignores further
## kills) and is the sole input to the `Unpersuadable` threshold check. The
## two counters diverge the moment the threshold is crossed with enemies
## still left to kill — that divergence is intentional, not a bug.
func _register_enemy_kill(defender: int) -> void:
	if not map_data.has("faction") or units[defender].get("faction_id", "") != map_data["faction"]["id"]:
		return
	battle_kills += 1
	if faction_state == "Engaged":
		persuasion_kills += 1
		if persistent_kills + persuasion_kills >= int(map_data["faction"]["kill_threshold"]):
			faction_state = "Unpersuadable"


func _decrement_buffs(index: int) -> void:
	var buffs: Dictionary = units[index].get("active_buffs", {})
	for stat in buffs.keys():
		var effect: Dictionary = buffs[stat]
		effect["turns_remaining"] = int(effect["turns_remaining"]) - 1
		if int(effect["turns_remaining"]) <= 0:
			buffs.erase(stat)
		else:
			buffs[stat] = effect
	units[index]["active_buffs"] = buffs


func use_consumable(slot: int) -> bool:
	if selected < 0 or not outcome.is_empty() or not _active(selected) or bool(units[selected]["acted"]) or _is_item_carrier(selected):
		return false
	var carried: Array = units[selected].get("carried_items", [])
	if slot < 0 or slot >= carried.size():
		return false
	var item_id := str(carried[slot])
	var item: Dictionary = battle_data.get("items", {}).get(item_id, {})
	if item.is_empty():
		return false
	var actor := selected
	var result := ""
	if item.get("type") == "Heal":
		var recovered: int = mini(int(item.get("heal_value", 0)), int(units[actor]["max_hp"]) - int(units[actor]["hp"]))
		if recovered <= 0:
			message = "HP đã đầy; chưa dùng vật phẩm."
			queue_redraw()
			return false
		units[actor]["hp"] = int(units[actor]["hp"]) + recovered
		result = "%s dùng %s: +%d HP." % [str(units[actor]["name"]), str(item["name"]), recovered]
	elif item.get("type") == "Buff":
		var stat := str(item.get("buff_stat", ""))
		if stat.is_empty():
			return false
		_decrement_buffs(actor)
		var buffs: Dictionary = units[actor].get("active_buffs", {})
		buffs[stat] = {"amount": int(item["buff_amount"]), "turns_remaining": int(item["buff_duration"])}
		units[actor]["active_buffs"] = buffs
		result = "%s dùng %s: %s +%d trong %d lượt." % [str(units[actor]["name"]), str(item["name"]), stat.to_upper(), int(item["buff_amount"]), int(item["buff_duration"])]
	else:
		return false
	carried.remove_at(slot)
	units[actor]["carried_items"] = carried
	_finish_action(result, item.get("type") == "Buff")
	return true


func _village_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _village_at(cell: Vector2i) -> Dictionary:
	for village in map_data.get("villages", []):
		if int(village["x"]) == cell.x and int(village["y"]) == cell.y:
			return village
	return {}


func can_visit() -> bool:
	if selected < 0 or not outcome.is_empty() or not _active(selected) or bool(units[selected].get("acted", false)) or units[selected].get("side") != "player" or not bool(units[selected].get("controllable", true)) or _is_item_carrier(selected):
		return false
	var cell := _cell(selected)
	var village := _village_at(cell)
	if village.is_empty() or village_states.get(_village_key(cell), "") != "Available":
		return false
	return not village.has("item_id") or units[selected].get("carried_items", []).size() < 2


func visit_village() -> bool:
	if not can_visit():
		return false
	var cell := _cell(selected)
	var village := _village_at(cell)
	var result := "%s ghé làng." % str(units[selected]["name"])
	if village.has("gold_amount"):
		var amount := int(village["gold_amount"])
		village_gold_earned += amount
		village_gold_changed.emit(village_gold_earned)
		result += " Nhận %d vàng." % amount
	elif village.has("item_id"):
		var item_id := str(village["item_id"])
		var carried: Array = units[selected].get("carried_items", [])
		carried.append(item_id)
		units[selected]["carried_items"] = carried
		result += " Nhận %s." % str(battle_data.get("items", {}).get(item_id, {}).get("name", item_id))
	else:
		result += " %s" % str(village["info_text"])
	village_states[_village_key(cell)] = "Claimed"
	_finish_action(result)
	return true


func _destroy_village_under_enemy(index: int) -> void:
	var key := _village_key(_cell(index))
	if village_states.get(key, "") == "Available":
		village_states[key] = "Destroyed"
		message = "Địch đã phá ngôi làng!"


func can_trade(target: int) -> bool:
	if selected < 0 or target < 0 or target >= units.size() or selected == target or not outcome.is_empty():
		return false
	var actor: Dictionary = units[selected]
	var partner: Dictionary = units[target]
	return _active(selected) and _active(target) and actor.get("side") == "player" and partner.get("side") == "player" and bool(actor.get("controllable", true)) and bool(partner.get("controllable", true)) and not bool(actor.get("acted", false)) and not bool(actor.get("has_traded_this_phase", false)) and not _is_item_carrier(selected) and _distance(_cell(selected), _cell(target)) == 1


func trade_items(target: int, own_slot: int, target_slot: int) -> bool:
	if not can_trade(target):
		return false
	var own: Array = units[selected].get("carried_items", [])
	var other: Array = units[target].get("carried_items", [])
	if own_slot < -1 or own_slot >= own.size() or target_slot < -1 or target_slot >= other.size():
		return false
	if (own.size() == 1 and own_slot != 0) or (other.size() == 1 and target_slot != 0):
		return false
	if own_slot >= 0 and target_slot < 0 and other.size() >= 2:
		return false
	if target_slot >= 0 and own_slot < 0 and own.size() >= 2:
		return false
	var own_item := str(own[own_slot]) if own_slot >= 0 else ""
	var other_item := str(other[target_slot]) if target_slot >= 0 else ""
	if own_slot >= 0:
		own.remove_at(own_slot)
	if target_slot >= 0:
		other.remove_at(target_slot)
	if not other_item.is_empty():
		own.append(other_item)
	if not own_item.is_empty():
		other.append(own_item)
	var actor_name := str(units[selected]["name"])
	var partner_name := str(units[target]["name"])
	units[selected]["carried_items"] = own
	units[target]["carried_items"] = other
	units[selected]["moved"] = true
	units[selected]["has_traded_this_phase"] = true
	reachable_cells.clear()
	_update_player_attack_cells()
	message = "%s đã trao đổi vật phẩm với %s." % [actor_name, partner_name]
	_record_boundary()
	queue_redraw()
	return true


func _finish_action(result: String, buff_decay_done: bool = false) -> void:
	if not buff_decay_done:
		_decrement_buffs(selected)
	units[selected]["acted"] = true
	selected = -1
	pending_action = ""
	preview_target = -1
	reachable_cells.clear()
	player_attack_cells.clear()
	_clear_enemy_inspection()
	_clear_npc_inspection()
	message = result
	_record_boundary()
	queue_redraw()


func _end_player_turn() -> void:
	selected = -1
	preview_target = -1
	reachable_cells.clear()
	player_attack_cells.clear()
	_clear_enemy_inspection()
	_clear_npc_inspection()
	for i in units.size():
		if units[i]["side"] != "enemy" or not _active(i):
			continue
		if map_data.has("protect_zone"):
			_zone_assault_action(i)
		elif map_data["objective_type"] == "Seize":
			_control_point_enemy_action(i)
		elif units[i].get("ai_profile", "StandardAggressive") == "ProtectPersuade" and faction_state == "Engaged":
			_protect_persuade_action(i)
		elif units[i].get("ai_profile", "") == "Raider":
			_raider_action(i)
		else:
			_standard_enemy_action(i)
		_destroy_village_under_enemy(i)
		_record_boundary("Enemy")
		_check_outcome()
		if not outcome.is_empty():
			return
	if map_data.has("escort_goal"):
		_advance_escort_npc()
		_check_outcome()
		if not outcome.is_empty():
			return
	enemy_phases += 1
	if map_data["objective_type"] == "Seize":
		_update_control_progress()
		_check_outcome()
		if not outcome.is_empty():
			return
	for unit in units:
		unit["moved"] = false
		unit["acted"] = false
		unit["has_traded_this_phase"] = false
	turn_number += 1
	_record_boundary()
	_check_outcome()
	if outcome.is_empty():
		if map_data.has("escort_goal"):
			message = "Người đưa tin đang tới ô đích vàng. Chọn quân xanh."
		elif map_data.has("protect_zone"):
			message = "Giữ vùng vàng: %d/%d lượt địch." % [enemy_phases, int(map_data["survive_enemy_phases"])]
		elif map_data["objective_type"] == "Retrieve":
			message = "Đưa người cầm tài liệu về ô xanh." if not item_carrier_id.is_empty() else "Tới ô vàng để lấy tài liệu."
		elif map_data["objective_type"] == "Seize":
			message = "Giữ điểm vàng: %d/%d lượt địch liên tiếp." % [control_progress, int(map_data["hold_enemy_phases"])]
		elif map_data["objective_type"] == "Escort":
			message = "Sơ tán %d/%d lượt. Chọn quân xanh." % [enemy_phases, int(map_data["escort_turns_required"])]
		else:
			message = "Lượt %d. Chọn quân xanh." % turn_number
	queue_redraw()


func _advance_escort_npc() -> void:
	var index: int = _index_by_id(str(map_data.get("escort_unit_id", "")))
	if not _active(index):
		return
	var goal_data: Dictionary = map_data["escort_goal"]
	var goal := Vector2i(int(goal_data["x"]), int(goal_data["y"]))
	var current: Vector2i = _cell(index)
	if current == goal:
		return
	var occupied: Dictionary = _occupied_except(index)
	var allies: Dictionary = _allied_occupied_except(index)
	var costs: Dictionary = grid.costs_to_goal(goal, occupied, allies)
	var reachable: Dictionary = grid.reachable(current, int(units[index]["move"]), occupied, allies)
	var best: Vector2i = current
	var best_cost: int = int(costs.get(current, 999999))
	for cell in reachable.keys():
		var remaining: int = int(costs.get(cell, 999999))
		if remaining < best_cost or (remaining == best_cost and best != current and (cell.y < best.y or (cell.y == best.y and cell.x < best.x))):
			best = cell
			best_cost = remaining
	if best == current:
		message = "%s chờ đường tới ô đích được mở." % units[index]["name"]
		return
	units[index]["x"] = best.x
	units[index]["y"] = best.y
	message = "%s tự di chuyển tới (%d, %d)." % [units[index]["name"], best.x + 1, best.y + 1]
	_record_boundary("NPC")
	queue_redraw()


func _inside_protect_zone(cell: Vector2i) -> bool:
	if not map_data.has("protect_zone"):
		return false
	var zone: Dictionary = map_data["protect_zone"]
	return cell.x >= int(zone["x"]) and cell.y >= int(zone["y"]) and cell.x < int(zone["x"]) + int(zone["width"]) and cell.y < int(zone["y"]) + int(zone["height"])


func _zone_assault_action(index: int) -> void:
	var current: Vector2i = _cell(index)
	var options: Dictionary = grid.reachable(current, int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
	options[current] = 0
	var zone: Dictionary = map_data["protect_zone"]
	var distances: Dictionary = {}
	for y in range(int(zone["y"]), int(zone["y"]) + int(zone["height"])):
		for x in range(int(zone["x"]), int(zone["x"]) + int(zone["width"])):
			var route: Dictionary = grid.costs_to_goal(Vector2i(x, y), {})
			for cell in route.keys():
				if not distances.has(cell) or int(route[cell]) < int(distances[cell]):
					distances[cell] = route[cell]
	var best: Vector2i = current
	var best_distance: int = int(distances.get(current, 999999))
	for cell in options.keys():
		var distance: int = int(distances.get(cell, 999999))
		if distance < best_distance or (distance == best_distance and best != current and (cell.y < best.y or (cell.y == best.y and cell.x < best.x))):
			best = cell
			best_distance = distance
	units[index]["x"] = best.x
	units[index]["y"] = best.y
	if _inside_protect_zone(best):
		message = "%s đã lọt vào vùng phòng thủ!" % units[index]["name"]
		_check_outcome()
		return
	var target := -1
	var target_hp := 999999
	for i in units.size():
		if units[i]["side"] == "player" and _active(i) and combat.in_range(units[index], units[i]) and int(units[i]["hp"]) < target_hp:
			target = i
			target_hp = int(units[i]["hp"])
	if target >= 0:
		_resolve_exchange(index, target, false)
	else:
		message = "%s tiến về vùng phòng thủ." % units[index]["name"]


func _control_point_enemy_action(index: int) -> void:
	var current: Vector2i = _cell(index)
	var point: Vector2i = _map_point("control_point")
	var options: Dictionary = grid.reachable(current, int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
	options[current] = 0
	var distances: Dictionary = grid.costs_to_goal(point, {})
	var best: Vector2i = current
	var best_distance: int = int(distances.get(current, 999999))
	for cell in options.keys():
		var distance: int = int(distances.get(cell, 999999))
		if distance < best_distance or (distance == best_distance and best != current and (cell.y < best.y or (cell.y == best.y and cell.x < best.x))):
			best = cell
			best_distance = distance
	units[index]["x"] = best.x
	units[index]["y"] = best.y
	var target := -1
	var target_hp := 999999
	for i in units.size():
		if units[i]["side"] != "player" or not _active(i) or not combat.in_range(units[index], units[i]):
			continue
		var priority_hp: int = int(units[i]["hp"]) - (1000 if _cell(i) == point else 0)
		if priority_hp < target_hp:
			target = i
			target_hp = priority_hp
	if target >= 0:
		_resolve_exchange(index, target, false)
	else:
		message = "%s tiến về cứ điểm." % units[index]["name"]


func _update_control_progress() -> void:
	var holder: int = _unit_at(_map_point("control_point"))
	if _active(holder) and units[holder]["side"] == "player" and bool(units[holder].get("controllable", true)):
		control_progress += 1
	else:
		control_progress = 0


func _standard_enemy_action(index: int) -> void:
	var options: Dictionary = grid.reachable(_cell(index), int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
	options[_cell(index)] = 0
	var weapon: Dictionary = combat.weapon(units[index])
	var target := -1
	var destination: Vector2i = _cell(index)
	var best_target_distance := 9999
	var best_target_tie := 9999
	var best_destination_distance := 9999
	var priority_id: String = item_carrier_id if map_data["objective_type"] == "Retrieve" and not item_carrier_id.is_empty() else str(units[index].get("priority_target_id", ""))
	var priority_target: int = _index_by_id(priority_id)
	if priority_target >= 0 and (not _active(priority_target) or units[priority_target]["side"] != "player"):
		priority_target = -1
	var best_priority := 2
	for i in units.size():
		if units[i]["side"] != "player" or not _active(i):
			continue
		var target_distance: int = _distance(_cell(index), _cell(i))
		var tie: int = int(units[i]["x"]) + int(units[i]["y"])
		var priority: int = 0 if i == priority_target else 1
		for cell in options.keys():
			var attack_distance: int = _distance(cell, _cell(i))
			if attack_distance < int(weapon["range"][0]) or attack_distance > int(weapon["range"][1]):
				continue
			if priority < best_priority or (priority == best_priority and (target_distance < best_target_distance or (target_distance == best_target_distance and tie < best_target_tie) or (target_distance == best_target_distance and tie == best_target_tie and attack_distance < best_destination_distance))):
				target = i
				destination = cell
				best_priority = priority
				best_target_distance = target_distance
				best_target_tie = tie
				best_destination_distance = attack_distance
	if target >= 0:
		units[index]["x"] = destination.x
		units[index]["y"] = destination.y
		_resolve_exchange(index, target, false)
	else:
		target = priority_target if priority_target >= 0 else _nearest_player(index)
		if target >= 0:
			_move_toward(index, _cell(target))
			message = "%s tiến lên." % units[index]["name"]


func _raider_action(index: int) -> void:
	var current := _cell(index)
	var reachable: Dictionary = grid.reachable(current, int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
	reachable[current] = 0
	var destination := Vector2i(-1, -1)
	var best_distance := 999999
	var best_sum := 999999
	for village in map_data.get("villages", []):
		var cell := Vector2i(int(village["x"]), int(village["y"]))
		if village_states.get(_village_key(cell), "") != "Available" or not reachable.has(cell):
			continue
		var distance := _distance(current, cell)
		var coordinate_sum := cell.x + cell.y
		if distance < best_distance or (distance == best_distance and coordinate_sum < best_sum):
			destination = cell
			best_distance = distance
			best_sum = coordinate_sum
	if destination.x < 0:
		_standard_enemy_action(index)
		return
	units[index]["x"] = destination.x
	units[index]["y"] = destination.y
	_destroy_village_under_enemy(index)
	for i in units.size():
		if units[i]["side"] == "player" and _active(i) and combat.in_range(units[index], units[i]):
			_resolve_exchange(index, i, false)
			return
	message = "%s đã chiếm ngôi làng." % str(units[index]["name"])


func _protect_persuade_action(index: int) -> void:
	var context := "Hold"
	var current: Vector2i = _cell(index)
	var key: int = _index_by_id(str(map_data.get("key_unit_id", "")))
	var threatened: bool = _player_threatens(current)
	if key >= 0 and key != index and _active(key) and int(units[key]["hp"]) <= int(units[key]["max_hp"] * float(battle_data["ai_rules"]["protect_hp_threshold"])) and _player_threatens(_cell(key)):
		var options: Dictionary = grid.reachable(current, int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
		var closest_player: int = _nearest_player(key)
		var closest_distance: int = 9999
		for cell in options.keys():
			if _distance(cell, _cell(key)) == 1:
				var distance: int = _distance(cell, _cell(closest_player))
				if distance < closest_distance:
					closest_distance = distance
					units[index]["x"] = cell.x
					units[index]["y"] = cell.y
					context = "Protect"
	if context == "Hold" and threatened:
		var options: Dictionary = grid.reachable(current, int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
		var best: Vector2i = current
		var best_distance: int = -1
		for cell in options.keys():
			if _player_threatens(cell):
				continue
			var nearest: int = _nearest_player(index)
			var distance: int = _distance(cell, _cell(nearest))
			if distance > best_distance:
				best = cell
				best_distance = distance
		if best_distance >= 0:
			units[index]["x"] = best.x
			units[index]["y"] = best.y
			context = "Flee"
		else:
			context = "Cornered"
	if context == "Hold" and key >= 0 and key != index and _active(key) and not _nearby_enemy_ally(index):
		var options: Dictionary = grid.reachable(current, int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
		var best: Vector2i = current
		var best_distance: int = _distance(current, _cell(key))
		for cell in options.keys():
			var distance: int = _distance(cell, _cell(key))
			if distance < best_distance and not _player_threatens(cell):
				best = cell
				best_distance = distance
		units[index]["x"] = best.x
		units[index]["y"] = best.y
		context = "Rally"
	units[index]["last_context"] = context
	if context == "Cornered":
		message = "%s không còn đường rút và hạ vũ khí." % units[index]["name"]
		return
	if context == "Rally":
		message = "%s trở về cạnh thủ lĩnh." % units[index]["name"]
		return
	var target: int = _nearest_player(index)
	if target >= 0 and combat.in_range(units[index], units[target]):
		_resolve_exchange(index, target, _is_restrained(index, context))
	else:
		message = "%s %s." % [units[index]["name"], "rút lui" if context == "Flee" else ("che chắn thủ lĩnh" if context == "Protect" else "giữ vị trí")]


func _is_restrained(index: int, context: String) -> bool:
	return units[index]["side"] == "enemy" and units[index].get("ai_profile", "") == "ProtectPersuade" and faction_state == "Engaged" and context in ["Hold", "Flee"] and bool(battle_data["difficulty"].get("restraint_rule_active", true))


func _nearby_enemy_ally(index: int) -> bool:
	for i in units.size():
		if i != index and units[i]["side"] == "enemy" and _active(i) and _distance(_cell(index), _cell(i)) <= int(battle_data["ai_rules"]["rally_radius"]):
			return true
	return false


func _player_threatens(cell: Vector2i) -> bool:
	for i in units.size():
		if units[i]["side"] != "player" or not _active(i):
			continue
		var w: Dictionary = combat.weapon(units[i])
		if w.get("action_category", "Combat") != "Combat":
			continue
		var origins: Dictionary = grid.reachable(_cell(i), int(units[i]["move"]), _occupied_except(i), _allied_occupied_except(i))
		origins[_cell(i)] = 0
		for origin in origins.keys():
			var distance: int = _distance(origin, cell)
			if distance >= int(w["range"][0]) and distance <= int(w["range"][1]):
				return true
	return false


func _move_toward(index: int, target: Vector2i) -> void:
	var options: Dictionary = grid.reachable(_cell(index), int(units[index]["move"]), _occupied_except(index), _allied_occupied_except(index))
	var best: Vector2i = _cell(index)
	var best_distance: int = _distance(best, target)
	for cell in options.keys():
		var distance: int = _distance(cell, target)
		if distance < best_distance:
			best = cell
			best_distance = distance
	units[index]["x"] = best.x
	units[index]["y"] = best.y


func _check_outcome() -> void:
	if not outcome.is_empty():
		return
	var players := 0
	var enemies := 0
	for i in units.size():
		if _active(i):
			if units[i]["side"] == "player" and bool(units[i].get("controllable", true)):
				players += 1
			elif units[i]["side"] == "enemy":
				enemies += 1
	var guarded_field: String = "protect_unit_id" if map_data["objective_type"] == "Protect" and map_data.has("protect_unit_id") else ("escort_unit_id" if map_data["objective_type"] == "Escort" else "")
	var guarded_dead: bool = not guarded_field.is_empty() and not _active(_index_by_id(str(map_data[guarded_field])))
	var zone_breached := false
	if map_data.has("protect_zone"):
		for unit in units:
			if unit["side"] == "enemy" and int(unit["hp"]) > 0 and _inside_protect_zone(Vector2i(int(unit["x"]), int(unit["y"]))):
				zone_breached = true
				break
	var carrier: int = _index_by_id(item_carrier_id) if not item_carrier_id.is_empty() else -1
	if players == 0 or guarded_dead or zone_breached or (carrier >= 0 and not _active(carrier)):
		_finish_battle(false)
	elif map_data["objective_type"] == "Elimination" and enemies == 0:
		_finish_battle(true)
	elif map_data["objective_type"] == "Protect" and enemy_phases >= int(map_data["survive_enemy_phases"]):
		_finish_battle(true)
	elif map_data["objective_type"] == "Escort":
		if map_data.has("escort_goal"):
			var goal: Dictionary = map_data["escort_goal"]
			var escorted: int = _index_by_id(str(map_data["escort_unit_id"]))
			if _cell(escorted) == Vector2i(int(goal["x"]), int(goal["y"])):
				_finish_battle(true)
		elif enemies == 0 or enemy_phases >= int(map_data["escort_turns_required"]):
			_finish_battle(true)
	elif map_data["objective_type"] == "Retrieve" and carrier >= 0 and _cell(carrier) == _map_point("return_tile"):
		_finish_battle(true)
	elif map_data["objective_type"] == "Seize" and control_progress >= int(map_data["hold_enemy_phases"]):
		_finish_battle(true)


func _finish_battle(won: bool) -> void:
	_clear_enemy_inspection()
	_clear_npc_inspection()
	player_attack_cells.clear()
	outcome = "CHIẾN THẮNG" if won else "THẤT BẠI"
	var eligible: bool = map_data.has("faction")
	var clean: bool = true
	if bool(battle_data["difficulty"].get("permadeath", false)):
		for unit in units:
			if unit["side"] == "player" and int(unit["hp"]) <= 0:
				clean = false
				break
	var low_kill: bool = battle_kills <= int(battle_data["scoring"]["kill_tolerance"])
	var swift: bool = turn_number <= int(map_data["turn_par"])
	var points: int = (int(battle_data["scoring"]["ally_points"]) if clean else 0) + (int(battle_data["scoring"]["kill_points"]) if eligible and low_kill else 0) + (int(battle_data["scoring"]["perfect_points"]) if eligible and low_kill and clean else 0) + (int(battle_data["scoring"]["swift_points"]) if swift else 0)
	if won and eligible and faction_state == "Engaged":
		var condition: Dictionary = map_data["faction"]["persuasion_condition"]
		if condition["type"] == "named_unit_alive" and _active(_index_by_id(str(condition["unit_id"]))):
			faction_state = "Persuaded"
	summary = {"won": won, "eligible": eligible, "zero_ally_deaths": clean, "kills": battle_kills, "low_kill": low_kill, "swift": swift, "points": points, "persuaded": faction_state == "Persuaded"}
	aftermath_visible = false
	aftermath_state = faction_state if won and eligible else ("Lost" if eligible else "")
	message = "%s — Enter xem hậu trận." % outcome if eligible else "%s — R chơi lại, 1/2/3/4/5/6 đổi màn." % outcome
	queue_redraw()
	if combat_view.active:
		_pending_battle_finished = true
	else:
		battle_finished.emit(summary.duplicate(true), aftermath_state, map_index)


func _on_combat_view_changed(active: bool) -> void:
	combat_view_changed.emit(active)


func _on_combat_view_finished() -> void:
	if _pending_battle_finished:
		_pending_battle_finished = false
		battle_finished.emit(summary.duplicate(true), aftermath_state, map_index)


func _record_boundary(phase: String = "Player") -> void:
	snapshots.append({"phase": phase, "units": units.duplicate(true), "turn": turn_number, "enemy_phases": enemy_phases, "kills": battle_kills, "persuasion_kills": persuasion_kills, "faction": faction_state, "outcome": outcome, "item_carrier_id": item_carrier_id, "control_progress": control_progress, "support_progress": support_progress.duplicate(true), "village_states": village_states.duplicate(true), "village_gold_earned": village_gold_earned})


func _rewind_last_action() -> void:
	if not outcome.is_empty() or (not rewind_unlimited and rewind_charges <= 0) or snapshots.size() <= 1:
		return
	if selected >= 0 and units[selected]["moved"] and not bool(units[selected].get("has_traded_this_phase", false)):
		message = "Hãy kết thúc hành động trước khi quay lại."
		queue_redraw()
		return
	var target: int = snapshots.size() - 2
	while target >= 0 and snapshots[target]["phase"] != "Player":
		target -= 1
	if target < 0:
		return
	rewind_to_boundary(target)


## Restores a prior player action boundary and consumes one rewind charge.
func rewind_to_boundary(target: int) -> bool:
	if not outcome.is_empty() or (not rewind_unlimited and rewind_charges <= 0) or target < 0 or target >= snapshots.size() - 1 or snapshots[target]["phase"] != "Player":
		return false
	if selected >= 0 and units[selected]["moved"] and not bool(units[selected].get("has_traded_this_phase", false)):
		message = "Hãy kết thúc hành động trước khi quay lại."
		queue_redraw()
		return false
	combat_view.reset()
	_pending_battle_finished = false
	while snapshots.size() - 1 > target:
		snapshots.pop_back()
	var state: Dictionary = snapshots.back()
	units = state["units"].duplicate(true)
	combat.setup(battle_data, map_data, units)
	turn_number = int(state["turn"])
	enemy_phases = int(state["enemy_phases"])
	battle_kills = int(state["kills"])
	persuasion_kills = int(state.get("persuasion_kills", 0))
	faction_state = str(state["faction"])
	outcome = str(state["outcome"])
	item_carrier_id = str(state.get("item_carrier_id", ""))
	control_progress = int(state.get("control_progress", 0))
	support_progress = state.get("support_progress", {}).duplicate(true)
	village_states = state.get("village_states", {}).duplicate(true)
	village_gold_earned = int(state.get("village_gold_earned", 0))
	village_gold_changed.emit(village_gold_earned)
	if not rewind_unlimited:
		rewind_charges -= 1
	selected = -1
	pending_action = ""
	preview_target = -1
	reachable_cells.clear()
	player_attack_cells.clear()
	_clear_enemy_inspection()
	_clear_npc_inspection()
	message = "Đã quay lại ranh giới hành động trước."
	queue_redraw()
	return true


func _active(index: int) -> bool:
	return index >= 0 and int(units[index]["hp"]) > 0


func _index_by_id(id: String) -> int:
	for i in units.size():
		if units[i]["id"] == id:
			return i
	return -1


func _cell(index: int) -> Vector2i:
	return Vector2i(int(units[index]["x"]), int(units[index]["y"]))


func _map_point(field: String) -> Vector2i:
	var point: Dictionary = map_data[field]
	return Vector2i(int(point["x"]), int(point["y"]))


func _is_item_carrier(index: int) -> bool:
	return index >= 0 and not item_carrier_id.is_empty() and str(units[index]["id"]) == item_carrier_id


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _unit_at(cell: Vector2i) -> int:
	for i in units.size():
		if _active(i) and _cell(i) == cell:
			return i
	return -1


func _nearest_player(enemy: int) -> int:
	var result := -1
	var best := 9999
	for i in units.size():
		if units[i]["side"] == "player" and _active(i):
			var distance: int = _distance(_cell(enemy), _cell(i))
			if distance < best:
				best = distance
				result = i
	return result


func _occupied_except(excluded: int) -> Dictionary:
	var occupied: Dictionary = {}
	for i in units.size():
		if i != excluded and _active(i):
			occupied[_cell(i)] = true
	return occupied


func _allied_occupied_except(excluded: int) -> Dictionary:
	var occupied: Dictionary = {}
	for i in units.size():
		if i != excluded and _active(i) and units[i]["side"] == units[excluded]["side"]:
			occupied[_cell(i)] = true
	return occupied


func _enemy_threat_cells() -> Dictionary:
	var threatened: Dictionary = {}
	for i in units.size():
		if units[i]["side"] != "enemy" or not _active(i):
			continue
		var weapon: Dictionary = combat.weapon(units[i])
		var origins: Dictionary = grid.reachable(_cell(i), int(units[i]["move"]), _occupied_except(i), _allied_occupied_except(i))
		origins[_cell(i)] = 0
		for origin in origins.keys():
			for y in grid.height:
				for x in grid.width:
					var cell := Vector2i(x, y)
					var distance: int = _distance(origin, cell)
					if distance >= int(weapon["range"][0]) and distance <= int(weapon["range"][1]):
						threatened[cell] = true
	return threatened


func _draw() -> void:
	if map_data.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var size: int = int(battle_data["tile_size"])
	var threats: Dictionary = _enemy_threat_cells() if selected < 0 and inspected_enemy < 0 and inspected_npc < 0 else {}
	draw_string(font, Vector2(44, 50), str(map_data["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
	for y in grid.height:
		for x in grid.width:
			var cell := Vector2i(x, y)
			var symbol: String = grid.terrain[y].substr(x, 1)
			var rect := Rect2(BOARD_ORIGIN + Vector2(x, y) * size, Vector2(size - 2, size - 2))
			draw_rect(rect, Color.html(str(grid.rules[symbol]["color"])))
			if symbol == "V":
				var village_state := str(village_states.get(_village_key(cell), ""))
				var village_color := Color("#f4d48b") if village_state == "Available" else Color("#7d8582")
				draw_rect(rect.grow(-5), village_color, false, 3.0)
				draw_string(font, rect.position + Vector2(5, 26), "LÀNG" if village_state == "Available" else "XONG", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, village_color)
			if _inside_protect_zone(cell):
				draw_rect(rect.grow(-3), Color(0.96, 0.77, 0.35, 0.38))
				draw_rect(rect.grow(-3), Color("#f5c96b"), false, 3.0)
				if x == int(map_data["protect_zone"]["x"]) and y == int(map_data["protect_zone"]["y"]):
					draw_string(font, rect.position + Vector2(6, 24), "GIỮ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#fff2c9"))
			if map_data.has("escort_goal") and x == int(map_data["escort_goal"]["x"]) and y == int(map_data["escort_goal"]["y"]):
				draw_rect(rect.grow(-5), Color("#dfbd80"), false, 4.0)
				draw_string(font, rect.position + Vector2(7, 26), "ĐÍCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#dfbd80"))
			if map_data["objective_type"] == "Retrieve":
				if cell == _map_point("return_tile"):
					draw_rect(rect.grow(-5), Color("#8de0d2"), false, 4.0)
					draw_string(font, rect.position + Vector2(7, 26), "VỀ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8de0d2"))
				elif item_carrier_id.is_empty() and cell == _map_point("item_tile"):
					draw_rect(rect.grow(-5), Color("#f2c35c"), false, 4.0)
					draw_string(font, rect.position + Vector2(7, 26), "ĐỒ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f2c35c"))
			if map_data["objective_type"] == "Seize" and cell == _map_point("control_point"):
				draw_rect(rect.grow(-5), Color("#f2c35c"), false, 4.0)
				draw_string(font, rect.position + Vector2(7, 26), "ĐIỂM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f2c35c"))
			if threats.has(cell):
				draw_rect(rect.grow(-3), Color(0.9, 0.25, 0.25, 0.13))
			if enemy_attack_cells.has(cell):
				draw_rect(rect.grow(-3), Color(0.96, 0.28, 0.24, 0.42))
			if enemy_move_cells.has(cell):
				draw_rect(rect.grow(-3), Color(0.28, 0.55, 0.96, 0.46))
			if player_attack_cells.has(cell):
				draw_rect(rect.grow(-3), Color(0.96, 0.28, 0.24, 0.42))
			if reachable_cells.has(cell) or (selected >= 0 and not units[selected]["moved"] and cell == _cell(selected)):
				draw_rect(rect.grow(-3), Color(0.28, 0.55, 0.96, 0.46))
			if npc_move_cells.has(cell):
				draw_rect(rect.grow(-3), Color(0.97, 0.77, 0.28, 0.48))
	for pairing in map_data.get("bonds", []):
		var a: int = _index_by_id(str(pairing["a"]))
		var b: int = _index_by_id(str(pairing["b"]))
		if _active(a) and _active(b) and _distance(_cell(a), _cell(b)) == 1:
			var point_a := BOARD_ORIGIN + Vector2(float(units[a]["x"]) + 0.5, float(units[a]["y"]) + 0.5) * size
			var point_b := BOARD_ORIGIN + Vector2(float(units[b]["x"]) + 0.5, float(units[b]["y"]) + 0.5) * size
			draw_line(point_a, point_b, Color("#ffe07a"), 5.0)
	for i in units.size():
		if not _active(i):
			continue
		var unit: Dictionary = units[i]
		var center := BOARD_ORIGIN + Vector2(float(unit["x"]) + 0.5, float(unit["y"]) + 0.5) * size
		var color := Color("#e4b756") if not bool(unit.get("controllable", true)) else (Color("#4265cf") if unit["side"] == "player" else Color("#c65c58"))
		if unit["acted"]:
			color = color.darkened(0.4)
		draw_circle(center, size * 0.34, color)
		if i == selected or i == preview_target or i == inspected_enemy or i == inspected_npc:
			draw_arc(center, size * 0.39, 0, TAU, 32, Color.WHITE, 3.0)
		if _is_item_carrier(i):
			draw_arc(center, size * 0.42, 0, TAU, 32, Color("#f2c35c"), 4.0)
		draw_string(font, center + Vector2(-14, 5), str(unit["name"]).substr(0, 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var active_buffs: Dictionary = unit.get("active_buffs", {})
		if not active_buffs.is_empty():
			draw_string(font, center + Vector2(17, -16), "↑%d" % active_buffs.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a9d7c9"))
		var ratio: float = float(unit["hp"]) / float(unit["max_hp"])
		var hp_color := Color("#6fe686") if ratio > 0.66 else (Color("#ffe173") if ratio >= 0.33 else Color("#ff7777"))
		draw_rect(Rect2(center + Vector2(-19, 15), Vector2(38.0 * ratio, 5)), hp_color)
	_draw_sidebar(font)
	draw_string(font, Vector2(44, 635), "Lượt %d  |  %s" % [turn_number, message], HORIZONTAL_ALIGNMENT_LEFT, 1080, 15, Color.WHITE)


func _draw_sidebar(font: Font) -> void:
	var lines: Array[String] = [str(map_data["objective_type"]), str(map_data["objective_text"]), ""]
	if aftermath_visible:
		lines = ["HẬU TRẬN", ""]
		for line in map_data.get("aftermath_lines", {}).get(aftermath_state, []):
			lines.append(str(line))
		lines.append_array(["", "Esc: xem tổng kết", "R: chơi lại    1/2/3/4/5/6: đổi màn"])
		var aftermath_y := 112.0
		for line in lines:
			draw_string(font, Vector2(720, aftermath_y), line, HORIZONTAL_ALIGNMENT_LEFT, 425, 16, Color.WHITE)
			aftermath_y += 28.0
		return
	if not outcome.is_empty():
		lines.append(outcome)
		lines.append("Đội không có tử trận: %s" % ("Có" if summary["zero_ally_deaths"] else "Không"))
		if summary["eligible"]:
			lines.append("Địch tử trận trong trận: %d" % summary["kills"])
			lines.append("Kiềm chế: %s" % ("đạt" if summary["low_kill"] else "hỏng"))
		lines.append("Về đích đúng hạn: %s" % ("Có" if summary["swift"] else "Không"))
		lines.append("Điểm: %d%s" % [summary["points"], " (không nhận)" if not summary["won"] else ""])
		lines.append("")
		if summary["eligible"]:
			lines.append("Enter: xem hậu trận")
		lines.append("R: chơi lại    1/2/3/4/5/6: đổi màn")
		var summary_y := 112.0
		for line in lines:
			draw_string(font, Vector2(720, summary_y), line, HORIZONTAL_ALIGNMENT_LEFT, 425, 16, Color.WHITE)
			summary_y += 28.0
		return
	if inspected_enemy >= 0:
		lines.append_array(["Xanh: địch đi tới và dừng được", "Đỏ: địch đánh được sau khi di chuyển", "Bấm địch lần nữa hoặc Esc để đóng", ""])
	elif inspected_npc >= 0:
		lines.append_array(["Vàng: NPC có thể đi tới và dừng được", "NPC tự đi sau lượt địch", "Vị trí địch có thể làm thay đổi tầm này", "Bấm NPC lần nữa hoặc Esc để đóng", ""] if npc_move_cells.size() > 1 else ["NPC này đứng yên", "Bấm NPC lần nữa hoặc Esc để đóng", ""])
	elif preview_target >= 0:
		lines.append_array(["Bấm mục tiêu lần nữa để xác nhận", "Esc: hủy chọn", "", "Quay lại: %s" % ("∞" if rewind_unlimited else "●".repeat(rewind_charges)), ""])
	elif selected >= 0:
		if not units[selected]["moved"]:
			lines.append("Xanh: quân mình đi tới và dừng được")
		if _is_item_carrier(selected):
			lines.append("Người cầm tài liệu chỉ có thể di chuyển")
		elif combat.weapon(units[selected]).get("action_category", "Combat") == "Heal":
			lines.append("Chọn đồng đội ở cạnh để hồi máu")
		else:
			lines.append("Đỏ: tầm đánh sau khi đi" if not units[selected]["moved"] else "Đỏ: tầm đánh từ vị trí hiện tại")
		lines.append_array(["W: chờ   Esc: hủy chọn", ""])
	else:
		lines.append_array(["Ô đỏ mờ: vùng địch có thể đánh", "1/2/3/4/5/6: đổi màn   R: chơi lại" if not embedded_mode else "Esc: hủy chọn", "Chuột: chọn / đi / đánh", "Bấm địch: xem tầm đi và đánh", "Bấm NPC: xem tầm tự di chuyển", "Bấm địch 2 lần khi ở tầm: đánh", "W: chờ   Space: hết lượt", "Z: quay lại   Esc: hủy chọn", "", "Quay lại: %s" % ("∞" if rewind_unlimited else "●".repeat(rewind_charges)), "Đội chưa mất ai: Có", ""])
	if map_data.has("escort_goal"):
		var goal: Dictionary = map_data["escort_goal"]
		var npc: int = _index_by_id(str(map_data["escort_unit_id"]))
		lines.append("Đích: cột %d, hàng %d" % [int(goal["x"]) + 1, int(goal["y"]) + 1])
		if _active(npc):
			lines.append("Người đưa tin: cột %d, hàng %d" % [int(units[npc]["x"]) + 1, int(units[npc]["y"]) + 1])
		lines.append("")
	elif map_data["objective_type"] == "Escort":
		lines.append("Sơ tán: %d/%d lượt địch" % [enemy_phases, int(map_data["escort_turns_required"])])
		lines.append("")
	elif map_data["objective_type"] == "Protect":
		lines.append("Giữ vùng: %d/%d lượt địch" % [enemy_phases, int(map_data["survive_enemy_phases"])] if map_data.has("protect_zone") else "Bảo vệ: %d/%d lượt địch" % [enemy_phases, int(map_data["survive_enemy_phases"])])
		lines.append("")
	elif map_data["objective_type"] == "Retrieve":
		lines.append("Tài liệu: chưa lấy" if item_carrier_id.is_empty() else "Tài liệu: %s đang cầm" % units[_index_by_id(item_carrier_id)]["name"])
		lines.append("Đưa về ô xanh: cột %d, hàng %d" % [_map_point("return_tile").x + 1, _map_point("return_tile").y + 1])
		lines.append("")
	elif map_data["objective_type"] == "Seize":
		lines.append("Giữ điểm: %d/%d lượt địch liên tiếp" % [control_progress, int(map_data["hold_enemy_phases"])])
		lines.append("Điểm: cột %d, hàng %d" % [_map_point("control_point").x + 1, _map_point("control_point").y + 1])
		lines.append("")
	if map_data.has("hint_lines"):
		for hint in map_data["hint_lines"]:
			lines.append(str(hint))
		lines.append("")
	if selected >= 0:
		lines.append("Liên kết cạnh ô: +%d" % combat.bond_bonus(units[selected]))
		lines.append("")
	if preview_target >= 0 and selected >= 0:
		if combat.weapon(units[selected]).get("action_category", "Combat") == "Heal":
			var weapon: Dictionary = combat.weapon(units[selected])
			var amount: int = mini(int(units[preview_target]["max_hp"]) - int(units[preview_target]["hp"]), combat.effective_stat(units[selected], "mag") + int(weapon["heal_might"]))
			lines.append("HỒI MÁU DỰ KIẾN: +%d HP" % amount)
		else:
			var odds: Dictionary = combat.preview(units[selected], units[preview_target])
			lines.append("ĐÒN ĐÁNH DỰ KIẾN")
			lines.append("Trúng %d%%  Chí mạng %d%%" % [odds["hit"], odds["crit"]])
			lines.append("Sát thương %d%s" % [odds["damage"], " ×2" if odds["doubles"] else ""])
			if combat.in_range(units[preview_target], units[selected]):
				var counter: Dictionary = combat.preview(units[preview_target], units[selected])
				lines.append("Phản công: %d%% / %d HP" % [counter["hit"], counter["damage"]])
		lines.append("")
	for unit in units:
		lines.append("%s: %d/%d HP" % [unit["name"], unit["hp"], unit["max_hp"]])
		var active_buffs: Dictionary = unit.get("active_buffs", {})
		for stat in active_buffs:
			var effect: Dictionary = active_buffs[stat]
			lines.append("  %s +%d · %d lượt" % [str(stat).to_upper(), int(effect.get("amount", 0)), int(effect.get("turns_remaining", 0))])
	var y := 112.0
	for line in lines:
		draw_string(font, Vector2(720, y), line, HORIZONTAL_ALIGNMENT_LEFT, 425, 16, Color.WHITE)
		y += 24.0
