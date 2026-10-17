extends Node2D
class_name BattleScene
## Battle view: renders BattleDirector.state and forwards mouse input through commands.
## Everything here is presentation; rules live inside the director/rule classes.

signal battle_finished(win: bool)

enum Mode { IDLE, UNIT_SELECTED, TARGET_SELECT, CONFIRM_ATTACK, BUSY }

const CELL := BattleMapView.CELL

var director: BattleDirector
var map_view: BattleMapView
var mode: int = Mode.IDLE
var selected_unit_id := ""
var active_targets: Dictionary = {}     # target_id -> cell
var hover_cell := Vector2i(-1, -1)
var _pending_target_id := ""           # D01: target chosen, awaiting forecast confirmation
var _forecast_panel: ForecastPanel = null

# UI panels
var _objective_label: Label
var _info_label: Label
var _hint_label: Label
var _action_menu: VBoxContainer
var _combat_layer: CanvasLayer
var _rewind_button: Button
var _end_turn_button: Button
var _skip_btn_: Button = null
var _combat_skip: bool = false


func setup(p_director: BattleDirector) -> void:
	director = p_director


func _ready() -> void:
	map_view = BattleMapView.new()
	map_view.set_state(director.state, director.player_sides)
	add_child(map_view)
	_build_ui()
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.objectives_changed.connect(func(_progress: Array) -> void: _update_objective_label())
	director.emit_objectives()
	map_view.queue_redraw()


func _build_ui() -> void:
	_objective_label = UIBuilder.label(_ui_root(), "", 18)
	_objective_label.position = Vector2(24, 16)
	_objective_label.size = Vector2(700, 90)

	_info_label = UIBuilder.label(_ui_root(), "", 18)
	_info_label.position = Vector2(24, 920)
	_info_label.size = Vector2(700, 60)

	_hint_label = UIBuilder.label(_ui_root(), "Click unit: move range - click red enemy: Forecast - Confirm to attack - after move: click unit / other cell / right-click = Wait", 20)
	_hint_label.position = Vector2(400, 60)

	_end_turn_button = UIBuilder.button(_ui_root(), "End phase", 22)
	_end_turn_button.position = Vector2(1740, 990)
	_end_turn_button.size = Vector2(150, 52)
	_end_turn_button.pressed.connect(_on_end_phase)

	_rewind_button = UIBuilder.button(_ui_root(), "", 20)
	_rewind_button.position = Vector2(1740, 920)
	_rewind_button.size = Vector2(150, 52)
	_rewind_button.pressed.connect(_on_rewind)
	_refresh_rewind_button()

	_action_menu = VBoxContainer.new()
	_action_menu.add_theme_constant_override("separation", 6)
	_action_menu.visible = false
	_ui_root().add_child(_action_menu)




func _canvas() -> CanvasLayer:
	for child in get_children():
		if child is CanvasLayer:
			return child
	var layer := CanvasLayer.new()
	add_child(layer)
	return layer


## CanvasLayer giữ HUD nhưng không có root property — container Control bên trong nó là nơi
## các widget sống. IGNORE filter để chuột không bị UI chặn trước bản đồ.
var _ui_root_node: Control = null
var _forecast_layer_node: CanvasLayer = null


## Dedicated layer for the D01 ForecastPanel to own forecast input: the forecast eats
## map clicks (MOUSE_FILTER_STOP) while its own Confirm/Cancel buttons still work.
func _forecast_layer() -> CanvasLayer:
	if _forecast_layer_node == null:
		_forecast_layer_node = CanvasLayer.new()
		_forecast_layer_node.layer = 5
		add_child(_forecast_layer_node)
	return _forecast_layer_node


func _ui_root() -> Control:
	if _ui_root_node != null:
		return _ui_root_node
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas().add_child(c)
	_ui_root_node = c
	return c


# ------------------------------------------------------------------ input

func _process(_delta: float) -> void:
	if map_view == null:
		return
	var cell := map_view.global_to_cell(get_global_mouse_position())
	if cell != hover_cell:
		hover_cell = cell
		map_view.set_cursor(cell)
		_update_hover_info()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell := map_view.global_to_cell(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click(cell)


func _on_left_click(cell: Vector2i) -> void:
	if mode == Mode.BUSY or mode == Mode.CONFIRM_ATTACK or not director.state.in_bounds(cell):
		return   # forecast waiting on Confirm/Cancel; map clicks are inert
	var unit: UnitState = director.state.unit_at(cell)
	match mode:
		Mode.IDLE:
			if unit != null:
				_select_unit(unit)
		Mode.UNIT_SELECTED:
			# Click địch trong ô đỏ (tính từ vị trí hiện tại) = mở forecast để xác nhận (D01).
			var standing_target := _target_at(cell)
			if standing_target != "":
				_open_forecast(standing_target)
				return
			var sel := _selected()
			if unit != null and unit.id == selected_unit_id:
				if sel != null and sel.moved:
					_do_wait()   # click lại chính mình sau khi đã move = chốt hành động
				return
			if sel != null and sel.side == "player" and not sel.acted and not sel.moved:
				var move_cells := MovementHandler.compute_move_cells(director.state, sel)
				if move_cells.has(cell):
					_commit_move(cell)
					return
			if unit != null:
				_select_unit(unit)
				# Phân biệt rõ khi người chơi click một địch không nằm trong ô đỏ:
				# click đó chỉ là xem range, không phải một đợt tấn công.
				if sel != null and not sel.acted and not active_targets.has(unit.id) and unit.side != sel.side:
					_info_label.text = "%s is OUT of reach of %s (unit acted? one action per phase — use another unit or Rewind)." % [unit.display_name, sel.display_name]
			else:
				_cancel_selection()
		Mode.TARGET_SELECT:
			# Sau khi move: click địch = mở forecast; click ô khác = kết thúc hành động.
			var target_id := _target_at(cell)
			if target_id != "":
				_open_forecast(target_id)
				return
			var sel2 := _selected()
			if sel2 != null and sel2.moved:
				_do_wait()
				return
			_cancel_selection()


func _on_right_click(cell: Vector2i) -> void:
	if mode == Mode.CONFIRM_ATTACK:
		_cancel_selection()   # D01: right-click during the forecast = Cancel (não commit)
		return
	var sel := _selected()
	if sel != null and sel.moved and not sel.acted and mode == Mode.TARGET_SELECT:
		_do_wait()   # T09: right click sau khi move = chốt Wait
		return
	_cancel_selection()

func _cancel_selection() -> void:
	if mode == Mode.BUSY:
		return
	_close_forecast()
	if mode == Mode.CONFIRM_ATTACK:
		var sel := _selected()
		if sel != null:
			_select_unit(sel)   # quay lại bước trước: chọn unit / chọn mục tiêu
			return
	mode = Mode.IDLE
	selected_unit_id = ""
	active_targets.clear()
	_hide_action_menu()
	_refresh_overlays()


# ------------------------------------------------------------------ selection

func _selected() -> UnitState:
	return director.state.units.get(selected_unit_id, null)


func _select_unit(unit: UnitState) -> void:
	selected_unit_id = unit.id
	active_targets.clear()
	if unit.side == "player" and not unit.acted and director.state.phase == BattleState.PHASE_PLAYER:
		# Targets tính từ vị trí hiện tại; unit đã move (đang chờ hành động) vào TARGET_SELECT luôn.
		active_targets = _compute_targets_for(director.state, unit)
		mode = Mode.TARGET_SELECT if unit.moved else Mode.UNIT_SELECTED
		_show_action_menu(unit)
	else:
		mode = Mode.IDLE
	_refresh_overlays()
	_update_hover_info()


## Targets hợp lệ của unit tại vị trí hiện tại (carrier move-only => không có target).
func _compute_targets_for(state: BattleState, unit: UnitState) -> Dictionary:
	if not _move_only_constraint(unit).is_empty():
		return {}
	var out := {}
	for target_id in RangeHandler.compute_targets_from_position(state, unit):
		out[target_id] = state.units[target_id].pos
	return out


func _commit_move(cell: Vector2i) -> void:
	var sel := _selected()
	if sel == null or sel.moved or sel.acted:
		# Một unit chỉ di chuyển một lần mỗi phase — chuyển vị trí phải qua Rewind.
		return
	mode = Mode.BUSY
	if director.commit("move", {"unit_id": sel.id, "cell": cell}):
		_enter_target_select()   # move xong: chỉ còn ô đỏ tầm đánh
		_refresh_overlays()
	else:
		mode = Mode.IDLE
	_refresh_rewind_button()


func _show_action_menu(unit: UnitState) -> void:
	_hide_action_menu()
	if unit.side != "player" or unit.acted or director.state.phase != BattleState.PHASE_PLAYER:
		return
	# Không còn nút Attack/Wait: click địch trong ô đỏ để đánh, click lại (hoặc ô khác/
	# right click) sau khi move để hoàn tác hành động bằng Wait. Menu chỉ còn skill.
	for skill_id in unit.skill_ids:
		var skill := DataRegistry.get_data("skills", skill_id)
		if skill == null or _find_skill_target(unit, skill) == null:
			continue
		var sk := UIBuilder.button(_action_menu, "skill: " + skill_id, 16)
		sk.pressed.connect(func() -> void: _use_skill(skill_id))
	if _action_menu.get_child_count() == 0:
		return
	_action_menu.visible = true
	_action_menu.position = map_view.cell_to_global(unit.pos) + Vector2(30, -60)


func _move_only_constraint(unit: UnitState) -> Dictionary:
	for obj in director.objectives:
		if obj.has_method("get_constraints"):
			var c: Dictionary = obj.get_constraints(unit)
			if not c.is_empty():
				return c
	return {}


func _enter_target_select() -> void:
	var sel := _selected()
	if sel == null:
		return
	active_targets = _compute_targets_for(director.state, _selected())
	mode = Mode.TARGET_SELECT


func _target_at(cell: Vector2i) -> String:
	for target_id in active_targets:
		if active_targets[target_id] == cell:
			return target_id
	return ""


func _do_wait() -> void:
	var sel := _selected()
	mode = Mode.BUSY
	director.commit("wait", {"unit_id": sel.id})
	_finish_action()


func _use_skill(skill_id: String) -> void:
	var skill := DataRegistry.get_data("skills", skill_id)
	if skill == null:
		return
	var target := _find_skill_target(_selected(), skill)
	if target == null:
		
		return
	mode = Mode.BUSY
	director.commit("skill", {"unit_id": _selected().id, "skill_id": skill_id, "target_id": target.id})
	_last_strikes = [{"side": "skill", "attacker_id": _selected().id, "target_id": target.id, "hit": true, "crit": false, "damage": -int(skill.power), "target_hp_after": target.hp, "slain": ""}]
	_finish_action()


## Skill target lookup is data-driven by effect type; "heal" finds the weakest hurt ally in range.
func _find_skill_target(unit: UnitState, skill: Resource) -> UnitState:
	var best: UnitState = null
	if String(skill.effect_type) == "heal":
		for u in director.state.alive_units():
			if u.side != unit.side or u.id == unit.id or u.hp >= u.max_hp:
				continue
			var d := RangeHandler.manhattan(u.pos, unit.pos)
			if d < int(skill.range_min) or d > int(skill.range_max):
				continue
			if best == null or (best.max_hp - best.hp) < (u.max_hp - u.hp):
				best = u
	return best




var _last_strikes: Array = []


# ------------------------------------------------------------------ D01 forecast

## Click địch trong ô đỏ → ForecastPanel (không commit). Panel hiển thị đúng chuỗi
## CombatResolver.forecast (đã gồm double attack và bonus bond).
func _open_forecast(target_id: String) -> void:
	var sel := _selected()
	if sel == null or sel.carried_item != "":
		return
	var target: UnitState = director.state.units.get(target_id, null)
	if target == null or not target.alive:
		return
	_pending_target_id = target_id
	mode = Mode.CONFIRM_ATTACK
	_hide_action_menu()
	map_view.set_overlays({}, {}, {})
	var forecast := CombatResolver.forecast(director.state, sel, target)
	if _forecast_panel != null:
		_forecast_panel.queue_free()
	_forecast_panel = ForecastPanel.build(forecast, sel, target)
	_forecast_layer().add_child(_forecast_panel)
	_forecast_panel.confirmed.connect(_confirm_forecast)
	_forecast_panel.cancelled.connect(func() -> void: _cancel_selection())


## Confirm: the previously displayed forecast becomes the real committed combat.
func _confirm_forecast() -> void:
	var target_id := _pending_target_id
	_close_forecast()
	_commit_attack(target_id)


func _close_forecast() -> void:
	if _forecast_panel != null:
		_forecast_panel.queue_free()
	_forecast_panel = null
	_pending_target_id = ""


## Click địch trong ô đỏ = vào màn giao chiến ngay (theo luồng tương tác chốt);
## CombatResolver vẫn là nguồn tính duy nhất, state HP đã cập nhật ngay tại commit.
func _commit_attack(target_id: String) -> void:
	var sel := _selected()
	if sel == null or sel.carried_item != "":   # carrier GetData move-only
		return
	mode = Mode.BUSY
	_hide_action_menu()
	_last_strikes.clear()
	director.commit("attack", {"unit_id": sel.id, "target_id": target_id})
	await _play_combat(_last_strikes.duplicate(true))
	_finish_action()


func _on_combat_resolved(strikes: Array) -> void:
	_last_strikes = strikes


# ------------------------------------------------------------------ combat screen

## Placeholder combat screen: plays the resolver's strike list over a simple overlay.
## Skippable — but the resulting battle state is identical either way.
func _play_combat(strikes: Array) -> void:
	if strikes.is_empty():
		return
	_combat_skip = false
	if _combat_layer == null:
		_combat_layer = CanvasLayer.new()
		add_child(_combat_layer)
	for c in _combat_layer.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_combat_layer.add_child(bg)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_combat_layer.add_child(overlay)
	var v := UIBuilder.vbox(overlay, 12)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 500
	v.offset_top = 260
	v.offset_right = -500
	_skip_btn_ = UIBuilder.button(overlay, "Skip", 20)
	_skip_btn_.position = Vector2(1740, 990)
	_skip_btn_.pressed.connect(func() -> void: _combat_skip = true)

	var first: UnitState = director.state.units.get(String(strikes[0].get("attacker_id", "")), null)
	var last_user: UnitState = null
	for s in strikes:
		var t: UnitState = director.state.units.get(String(s.get("target_id", "")), null)
		if t != null:
			last_user = t
	if first == null or last_user == null:
		return
	UIBuilder.label(v, "%s   vs   %s" % [first.display_name, last_user.display_name], 30)
	var att_bar := ProgressBar.new()
	var def_bar := ProgressBar.new()
	att_bar.custom_minimum_size = Vector2(600, 26)
	def_bar.custom_minimum_size = Vector2(600, 26)
	att_bar.max_value = first.max_hp
	def_bar.max_value = last_user.max_hp
	v.add_child(att_bar)
	UIBuilder.label(v, last_user.display_name, 18)
	v.add_child(def_bar)
	var log := UIBuilder.label(v, "", 20)
	att_bar.value = first.hp
	def_bar.value = last_user.hp
	await get_tree().create_timer(0.6).timeout
	for strike in strikes:
		if _combat_skip:
			break
		var target: UnitState = director.state.units.get(String(strike.get("target_id", "")), null)
		var attacker: UnitState = director.state.units.get(String(strike.get("attacker_id", "")), null)
		if target == null or attacker == null:
			continue
		var text := "%s %s %d dmg -> %s (HP %d)" % [
			attacker.display_name,
			"critical" if bool(strike.get("crit", false)) else ("misses" if not bool(strike.get("hit", true)) else "hits"),
			int(strike.get("damage", 0)),
			target.display_name,
			int(strike.get("target_hp_after", 0)),
		]
		if bool(strike.get("hit", true)):
			att_bar.value = attacker.hp
			def_bar.value = int(strike.get("target_hp_after", target.hp))
		log.text = text
		await get_tree().create_timer(0.7).timeout
	if not _combat_skip:
		await get_tree().create_timer(0.4).timeout
	for c in _combat_layer.get_children():
		c.queue_free()
	_combat_skip = false


# ------------------------------------------------------------------ turn flow

func _on_end_phase() -> void:
	if mode == Mode.BUSY or director.state.phase != BattleState.PHASE_PLAYER or not director.state.battle_over.is_empty():
		return
	mode = Mode.BUSY
	_cancel_selection()
	director.end_player_phase()
	await _run_enemy_phase()
	director.advance_after_enemy_phase()
	await _run_npc_phase()
	director.advance_to_player_phase()
	mode = Mode.IDLE
	_refresh_overlays()
	_check_battle_over()


## Enemy AI plays through the same director path, with small delays for readability.
func _run_enemy_phase() -> void:
	while director.state.battle_over.is_empty():
		var plan := director.run_next_enemy_plan()
		if plan.is_empty():
			break
		director.commit_ai_plan(plan)
		await get_tree().create_timer(0.2).timeout
		map_view.queue_redraw()
		if not director.state.battle_over.is_empty():
			break


func _run_npc_phase() -> void:
	# NPC actors walk toward escort goals through the same director path (snapshot + objectives).
	while director.state.battle_over.is_empty():
		var plan_room := director.run_next_npc_plan()
		if plan_room.is_empty():
			break
		director.commit("move", {"unit_id": String(plan_room["unit_id"]), "cell": plan_room["move_cell"]})
		await get_tree().create_timer(0.2).timeout
		map_view.queue_redraw()


func _refresh_rewind_button() -> void:
	var budget := director.rewind_budget
	var left := director.rewind_uses_left
	_rewind_button.text = "Rewind" if budget == -1 else "Rewind %d" % left
	_rewind_button.disabled = budget == 0 or (budget > 0 and left <= 0)


func _on_rewind() -> void:
	if mode == Mode.BUSY or director.state.phase != BattleState.PHASE_PLAYER:
		return
	if director.rewind.frames.is_empty():
		return
	# Rewind always restores the newest valid PLAYER frame; engine phase frames are skipped.
	var frame_index: int = director.rewind.find_last_player_frame()
	if frame_index < 0:
		return
	if director.use_rewind(frame_index):
		selected_unit_id = ""
		_hide_action_menu()
		_refresh_overlays()
		_refresh_rewind_button()
		_check_battle_over()


func _check_battle_over() -> void:
	if not director.state.battle_over.is_empty():
		_show_result_banner()


func _show_result_banner() -> void:
	var is_win: bool = director.state.battle_over.get("status", "") == "win"
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	var v := UIBuilder.vbox(overlay, 20)
	v.set_anchors_preset(Control.PRESET_CENTER)
	UIBuilder.label(v, "Victory" if is_win else "Defeat", 64)
	# D04: after a defeat the banner carries a Rewind button while uses remain (Nightmare
	# disables rewind entirely, so the button never shows there). Winning is final.
	if not is_win and _rewind_available_on_banner():
		var rw := UIBuilder.button(v, "Rewind", 26)
		rw.pressed.connect(func() -> void:
			layer.queue_free()
			_on_rewind())
	var cont := UIBuilder.button(v, "Continue", 26)
	cont.pressed.connect(func() -> void:
		layer.queue_free()
		battle_finished.emit(director.state.battle_over.get("status", "lose") == "win"))


## A defeat banner can offer Rewind only when the budget allows and a PLAYER frame exists.
func _rewind_available_on_banner() -> bool:
	if director.rewind_budget == 0 or director.rewind_uses_left <= 0 and director.rewind_budget > 0:
		return false
	return director.rewind.find_last_player_frame() >= 0


func _update_hover_info() -> void:
	var u := director.state.unit_at(hover_cell) if director.state != null else null
	var defs: Dictionary = DataRegistry.rule("terrain_defs", {})
	var terr: Dictionary = defs.get(director.state.terrain_at(hover_cell), {})
	if u != null:
		_info_label.text = "%s | HP %d/%d | Pow %d Def %d Res %d Spd %d | terrain +%d def, +%d avoid" % [
			u.display_name, u.hp, u.max_hp, u.power, u.defense, u.resistance, u.speed,
			int(terr.get("def_bonus", 0)), int(terr.get("avoid_bonus", 0))]
	else:
		_info_label.text = "terrain: %s (+%d def, +%d avoid)" % [director.state.terrain_at(hover_cell), int(terr.get("def_bonus", 0)), int(terr.get("avoid_bonus", 0))]


func _update_objective_label() -> void:
	var lines: Array[String] = []
	for res in director.active_objectives_progress():
		lines.append("%s: %s (%s)" % [res["id"], str(res["progress"]), str(res["status"])])
	_objective_label.text = "\n".join(lines)


## After any confirmed action: clear selection state and check the battle outcome.
func _finish_action() -> void:
	selected_unit_id = ""
	active_targets.clear()
	mode = Mode.IDLE
	_hide_action_menu()
	map_view.queue_redraw()   # HP/acted cập nhật ngay trên bản đồ sau khi màn giao chiến đóng
	_refresh_overlays()
	_refresh_rewind_button()
	if not director.state.battle_over.is_empty():
		_show_result_banner()


func _hide_action_menu() -> void:
	_action_menu.visible = false
	for c in _action_menu.get_children():
		c.queue_free()


func _refresh_overlays() -> void:
	var sel := _selected()
	if sel == null or not sel.alive:
		map_view.set_overlays({}, {}, {} if active_targets.is_empty() else active_targets)
		return
	var reach := MovementHandler.compute_reachable(director.state, sel)
	var move_cells := MovementHandler.compute_move_cells(director.state, sel) if mode == Mode.UNIT_SELECTED else {}
	var attacks := RangeHandler.compute_attack_cells(director.state, sel, reach)
	var targets := {}
	if mode == Mode.TARGET_SELECT:
		for t in active_targets:
			targets[active_targets[t]] = true
	map_view.set_overlays(move_cells, attacks, targets)
