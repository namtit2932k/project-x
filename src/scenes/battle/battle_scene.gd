extends Node2D
class_name BattleScene
## Battle view: renders BattleDirector.state and forwards mouse input through commands.
## Everything here is presentation; rules live inside the director/rule classes.

signal battle_finished(win: bool)
signal quit_to_menu   # N08: pause menu quit — straight to the menu, no campaign merge

enum Mode { IDLE, UNIT_SELECTED, TARGET_SELECT, CONFIRM_ATTACK, BUSY, SKILL_TARGET }


var director: BattleDirector
var map_view: BattleMapView
var mode: int = Mode.IDLE
var selected_unit_id := ""
var active_targets: Dictionary = {}     # target_id -> cell
var hover_cell := Vector2i(-1, -1)
var _pending_target_id := ""           # D01: target chosen, awaiting forecast confirmation
var _forecast_panel: ForecastPanel = null
## Skill target selection (Heal / Encore): pending skill, its valid targets, mode to return to.
var _pending_skill_id := ""
var _skill_targets: Dictionary = {}     # unit_id -> cell
var _mode_before_skill: int = Mode.IDLE
var paused: bool = false                # N08: pause blocks map input and the phase loops
var _pause_menu: PauseMenu = null

# UI panels
var _objective_label: Label
var _info_label: Label
## F-UI step 4 HUD: objective box (top-left), unit card (bottom-left), terrain box (bottom-right),
## small controls (top-right), the action menu panel next to the unit.
var _objective_box: PanelContainer = null
var _objective_vbox: VBoxContainer = null
var _turn_label: Label = null
var _unit_card: PanelContainer = null
var _terrain_box: PanelContainer = null
var _action_panel: PanelContainer = null
var _pause_button: Button = null
const CARD_SIZE := Vector2(500, 190)
const TERRAIN_SIZE := Vector2(180, 96)
const HUD_MARGIN := 16.0
var _action_menu: VBoxContainer
var _combat_layer: CanvasLayer
var _rewind_button: Button
var _rewind_pips: HBoxContainer = null
var _rewind_picker: Control = null
var _end_turn_button: Button
var _skip_btn_: Button = null
var _combat_skip: bool = false
var _reconcile_chip_box: HBoxContainer = null   # N10: one attitude chip per remnant faction
var _reconcile_notice: Label = null             # N10: "limit kills" warning at battle start
var _reconcile_attitudes: Dictionary = {}       # faction_id -> last attitude (transition detect)


func setup(p_director: BattleDirector) -> void:
	director = p_director


func _ready() -> void:
	map_view = BattleMapView.new()
	map_view.set_state(director.state, director.player_sides)
	map_view.set_objectives(director.objectives)   # F-OBJ markers drawn live
	add_child(map_view)
	_build_ui()
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.objectives_changed.connect(func(_progress: Array) -> void: _update_objective_label())
	EventBus.reconcile_state_changed.connect(_refresh_reconcile_hud)
	director.emit_objectives()
	map_view.queue_redraw()
	_build_reconcile_hud()
	map_view.set_threat(enemy_threat())   # F-BUI Rule 2 from the first Player Phase


func _build_ui() -> void:
	# F-UI step 4 (UI doc battle reference): the map fills the frame, the HUD floats over it.
	_objective_box = UIBuilder.panel(_ui_root(), HUD_MARGIN, HUD_MARGIN, 280, 0)
	_objective_box.name = "ObjectiveBox"
	_objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_vbox = UIBuilder.vbox(_objective_box, 4)
	_turn_label = UIBuilder.title(_objective_vbox, "", 18)
	_objective_label = UIBuilder.label(_objective_vbox, "", 13)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(250, 0)

	# One short message line top-centre (target prompts, heal preview, warnings).
	_info_label = UIBuilder.label(_ui_root(), "", 14)
	_info_label.position = Vector2(340, 70)
	_info_label.size = Vector2(600, 40)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_unit_card = UIBuilder.panel(_ui_root(), HUD_MARGIN, UITheme.FRAME.y - HUD_MARGIN - CARD_SIZE.y, CARD_SIZE.x, CARD_SIZE.y)
	_unit_card.name = "UnitCard"
	_unit_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_card.visible = false
	_terrain_box = UIBuilder.panel(_ui_root(), UITheme.FRAME.x - HUD_MARGIN - TERRAIN_SIZE.x, UITheme.FRAME.y - HUD_MARGIN - TERRAIN_SIZE.y, TERRAIN_SIZE.x, TERRAIN_SIZE.y)
	_terrain_box.name = "TerrainBox"
	_terrain_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain_box.visible = false

	# Small controls top-right: Rewind (pips), End phase, Pause.
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.position = Vector2(UITheme.FRAME.x - HUD_MARGIN - 406, HUD_MARGIN)
	_ui_root().add_child(controls)
	_rewind_button = UIBuilder.button(controls, "", 14)
	_rewind_button.custom_minimum_size = Vector2(150, 38)
	_rewind_button.pressed.connect(open_rewind_picker)
	_end_turn_button = UIBuilder.button(controls, UIBuilder.t("End phase"), 14)
	_end_turn_button.custom_minimum_size = Vector2(130, 38)
	_end_turn_button.pressed.connect(_on_end_phase)
	_pause_button = UIBuilder.button(controls, UIBuilder.t("Pause"), 14)
	_pause_button.custom_minimum_size = Vector2(110, 38)
	_pause_button.pressed.connect(_toggle_pause)
	# F-BUI Rule 6: charges as pips (or the infinity glyph on Story) inside the button.
	_rewind_pips = HBoxContainer.new()
	_rewind_pips.add_theme_constant_override("separation", 3)
	_rewind_pips.position = Vector2(84, 12)
	_rewind_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rewind_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rewind_button.add_child(_rewind_pips)
	_refresh_rewind_button()

	# UI doc action menu: panel >= 280 wide, padding 16, 44 px rows 6 apart, next to the unit.
	_action_panel = PanelContainer.new()
	_action_panel.name = "ActionMenu"
	_action_panel.custom_minimum_size = Vector2(280, 0)
	_action_panel.visible = false
	_ui_root().add_child(_action_panel)
	_action_menu = VBoxContainer.new()
	_action_menu.add_theme_constant_override("separation", 6)
	_action_panel.add_child(_action_menu)




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
	c.theme = UITheme.shared()   # a CanvasLayer does not pass the window theme down
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
	if paused:
		return
	if event.is_action_pressed("ui_cancel") and mode != Mode.BUSY and director.state.battle_over.is_empty():
		_toggle_pause()
		return
	if event is InputEventMouseButton and event.pressed:
		var cell := map_view.global_to_cell(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click(cell)


func _on_left_click(cell: Vector2i) -> void:
	if paused or mode == Mode.BUSY or mode == Mode.CONFIRM_ATTACK or not director.state.in_bounds(cell):
		return   # forecast waiting on Confirm/Cancel; map clicks are inert
	var unit: UnitState = director.state.unit_at(cell)
	match mode:
		Mode.SKILL_TARGET:
			# Only a highlighted target commits; other clicks are ignored (right click cancels).
			for target_id in _skill_targets:
				if _skill_targets[target_id] == cell:
					_commit_skill(String(target_id))
					return
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
				# F-MOVE: a second click on the unit = stay on this tile; the action menu opens.
				if sel != null and sel.side == "player" and not sel.acted and not sel.moved:
					_commit_move(sel.pos)
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
					_info_label.text = UIBuilder.t("%s is OUT of reach of %s (unit acted? one action per phase — use another unit or Rewind).") % [unit.display_name, sel.display_name]
			else:
				_cancel_selection()
		Mode.TARGET_SELECT:
			# After the move: a red enemy opens the forecast. F-MOVE: other clicks do nothing - only
			# a menu action confirms the turn, right click takes the move back.
			var target_id := _target_at(cell)
			if target_id != "":
				_open_forecast(target_id)
			elif unit != null and unit.side == "player" and unit.id != selected_unit_id:
				_select_unit(unit)   # switching units takes this unconfirmed move back


func _on_right_click(cell: Vector2i) -> void:
	if paused:
		return
	if mode == Mode.CONFIRM_ATTACK:
		_cancel_selection()   # D01: right-click during the forecast = Cancel (não commit)
		return
	if mode == Mode.SKILL_TARGET:
		_cancel_skill_target()   # back out of Heal / Encore target choice, nothing spent
		return
	var sel := _selected()
	if sel != null and sel.moved and not sel.acted and mode == Mode.TARGET_SELECT:
		if not _action_panel.visible:
			_show_action_menu(sel)   # back from choosing an Attack target to the menu
			_refresh_overlays()
			return
		# F-MOVE: right click before confirming = the move is taken back, unit still selected.
		if director.cancel_move(sel.id):
			_select_unit(director.state.units[sel.id])
			_refresh_rewind_button()
			return
	_cancel_selection()


## F-MOVE: takes back a move the player has not confirmed with an action (no-op otherwise).
func _revert_pending(unit: UnitState) -> bool:
	if unit == null or unit.side != "player" or not unit.moved or unit.acted:
		return false
	var ok := director.cancel_move(unit.id)
	if ok:
		_refresh_rewind_button()
	return ok


func _cancel_selection() -> void:
	if mode == Mode.BUSY:
		return
	_close_forecast()
	if mode == Mode.CONFIRM_ATTACK:
		var sel := _selected()
		if sel != null:
			_select_unit(sel)   # quay lại bước trước: chọn unit / chọn mục tiêu
			return
	_revert_pending(_selected())   # F-MOVE: deselecting never keeps an unconfirmed move
	mode = Mode.IDLE
	selected_unit_id = ""
	active_targets.clear()
	_hide_action_menu()
	_refresh_overlays()


# ------------------------------------------------------------------ selection

func _selected() -> UnitState:
	return director.state.units.get(selected_unit_id, null)


func _select_unit(unit: UnitState) -> void:
	# F-MOVE: picking another unit takes back the previous unit's unconfirmed move (the state is
	# restored from a snapshot, so re-read the unit afterwards).
	var prev := _selected()
	if prev != null and prev.id != unit.id and _revert_pending(prev):
		unit = director.state.units[unit.id]
	selected_unit_id = unit.id
	map_view.focus_cell(unit.pos)   # F-UI step 4 camera (only moves on maps larger than the frame)
	active_targets.clear()
	if unit.side == "player" and not unit.acted and director.state.phase == BattleState.PHASE_PLAYER:
		# Targets tính từ vị trí hiện tại; unit đã move (đang chờ hành động) vào TARGET_SELECT luôn.
		active_targets = _compute_targets_for(director.state, unit)
		mode = Mode.TARGET_SELECT if unit.moved else Mode.UNIT_SELECTED
		# F-MOVE: the action menu only opens after the unit has moved (or chosen to stay).
		if unit.moved:
			_show_action_menu(unit)
		else:
			_hide_action_menu()
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
		_show_action_menu(sel)   # F-ITEM: Visit depends on the tile the unit ended on
		_refresh_overlays()
	else:
		mode = Mode.IDLE
	_refresh_rewind_button()


func _show_action_menu(unit: UnitState) -> void:
	_hide_action_menu()
	if unit.side != "player" or unit.acted or not unit.moved or director.state.phase != BattleState.PHASE_PLAYER:
		return   # F-MOVE: no menu before the move
	# F-BUI Rule 11 (GDD order, illegal entries omitted): Attack, Heal, Use Item, Visit, Encore,
	# Trade, Wait. Shortcuts of the D01 flow stay: click a red enemy, re-click the unit = Wait.
	for entry in action_menu_entries(director.state, unit, _compute_targets_for(director.state, unit)):
		var btn := UIBuilder.button(_action_menu, String(entry["label"]), 18)
		btn.custom_minimum_size = Vector2(248, 44)
		var kind := String(entry["kind"])
		var arg := String(entry.get("arg", ""))
		btn.pressed.connect(func() -> void: _on_menu_entry(kind, arg))
	_action_panel.visible = true
	_action_panel.reset_size()
	_action_panel.position = action_menu_position(map_view.cell_to_global(unit.pos), map_view.cell_px, _action_panel.get_combined_minimum_size())


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


## Skill button (designer 08-11-2026): enter target selection — the player picks the target
## for Heal / Encore. Valid targets are highlighted; right click cancels at no cost.
func _use_skill(skill_id: String) -> void:
	var sel := _selected()
	var skill := DataRegistry.get_data("skills", skill_id)
	if sel == null or skill == null:
		return
	var targets := _skill_targets_for(sel, skill_id)
	if targets.is_empty():
		return
	_pending_skill_id = skill_id
	_skill_targets = targets
	_mode_before_skill = mode
	mode = Mode.SKILL_TARGET
	_hide_action_menu()
	var skill_name := String(skill.display_name) if String(skill.display_name) != "" else skill_id
	_info_label.text = UIBuilder.t("Choose a target for %s (right click to cancel).") % UIBuilder.t(skill_name)
	_refresh_overlays()


## Commits the pending skill on the clicked target, through the director like every action.
func _commit_skill(target_id: String) -> void:
	var sel := _selected()
	var skill := DataRegistry.get_data("skills", _pending_skill_id)
	if sel == null or skill == null:
		_cancel_skill_target()
		return
	var target: UnitState = director.state.units[target_id]
	var hp_before: int = target.hp
	mode = Mode.BUSY
	director.commit("skill", {"unit_id": sel.id, "skill_id": _pending_skill_id, "target_id": target_id})
	# Only a heal has a number to show on the combat screen (the real HP gain, F-HEAL).
	if String(skill.effect_type) == "heal":
		_last_strikes = [{"side": "skill", "attacker_id": sel.id, "target_id": target_id, "hit": true, "crit": false, "damage": -(target.hp - hp_before), "target_hp_after": target.hp, "slain": ""}]
	else:
		_last_strikes = []
	_pending_skill_id = ""
	_skill_targets.clear()
	_finish_action()


## Leaves target selection without spending anything; back to the step before the button.
func _cancel_skill_target() -> void:
	_pending_skill_id = ""
	_skill_targets.clear()
	mode = _mode_before_skill
	var sel := _selected()
	if sel != null:
		_show_action_menu(sel)
	_refresh_overlays()


## Every unit the skill command accepts as a target right now: {unit_id: cell}.
func _skill_targets_for(unit: UnitState, skill_id: String) -> Dictionary:
	var out := {}
	for u in director.state.alive_units():
		if SkillCommand.check(director.state, unit, skill_id, u) == "":
			out[u.id] = u.pos
	return out




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
	overlay.theme = UITheme.shared()
	_combat_layer.add_child(overlay)
	var v := UIBuilder.vbox(overlay, 12)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 240
	v.offset_top = 180
	v.offset_right = -240
	_skip_btn_ = UIBuilder.button(overlay, UIBuilder.t("Skip"), 18)
	_skip_btn_.position = Vector2(1110, 664)
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
		var text := UIBuilder.t("%s %s %d dmg -> %s (HP %d)") % [
			attacker.display_name,
			UIBuilder.t("critical") if bool(strike.get("crit", false)) else (UIBuilder.t("misses") if not bool(strike.get("hit", true)) else UIBuilder.t("hits")),
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
	if paused or mode == Mode.BUSY or director.state.phase != BattleState.PHASE_PLAYER or not director.state.battle_over.is_empty():
		return
	_revert_pending(_selected())   # F-MOVE: an unconfirmed move does not survive End phase
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
		# N08: park the whole phase loop while pausing — nothing applies until Resume.
		if paused:
			await get_tree().process_frame
			continue
		var plan := director.run_next_enemy_plan()
		if plan.is_empty():
			break
		map_view.focus_cell(director.state.units[String(plan["unit_id"])].pos)
		director.commit_ai_plan(plan)
		await get_tree().create_timer(0.2).timeout
		map_view.queue_redraw()
		if not director.state.battle_over.is_empty():
			break


func _run_npc_phase() -> void:
	# NPC actors walk toward escort goals through the same director path (snapshot + objectives).
	while director.state.battle_over.is_empty():
		if paused:
			await get_tree().process_frame
			continue
		var plan_room := director.run_next_npc_plan()
		if plan_room.is_empty():
			break
		director.commit("move", {"unit_id": String(plan_room["unit_id"]), "cell": plan_room["move_cell"]})
		await get_tree().create_timer(0.2).timeout
		map_view.queue_redraw()


func _refresh_rewind_button() -> void:
	var budget := director.rewind_budget
	var left := director.rewind_uses_left
	_rewind_button.text = UIBuilder.t("Rewind")
	_rewind_button.disabled = budget == 0 or (budget > 0 and left <= 0) or director.rewind.player_frames().is_empty()
	for c in _rewind_pips.get_children():
		c.queue_free()
	if budget == -1:
		var inf := UIBuilder.label(_rewind_pips, "∞", 18)
		inf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	for i in budget:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(8, 14)
		pip.color = Color(0.4, 0.8, 1.0) if i < left else Color(0.25, 0.25, 0.3)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rewind_pips.add_child(pip)


func _on_rewind() -> void:
	if mode == Mode.BUSY or director.state.phase != BattleState.PHASE_PLAYER:
		return
	_revert_pending(_selected())   # F-MOVE: a provisional move is taken back for free first
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
	overlay.theme = UITheme.shared()
	layer.add_child(overlay)
	var v := UIBuilder.vbox(overlay, 20)
	v.set_anchors_preset(Control.PRESET_CENTER)
	UIBuilder.label(v, UIBuilder.t("Victory") if is_win else UIBuilder.t("Defeat"), 64)
	# D04: after a defeat the banner carries a Rewind button while uses remain (Nightmare
	# disables rewind entirely, so the button never shows there). Winning is final.
	if not is_win and _rewind_available_on_banner():
		var rw := UIBuilder.button(v, UIBuilder.t("Rewind"), 26)
		rw.pressed.connect(func() -> void:
			layer.queue_free()
			_on_rewind())
	var cont := UIBuilder.button(v, UIBuilder.t("Continue"), 26)
	cont.pressed.connect(func() -> void:
		layer.queue_free()
		battle_finished.emit(director.state.battle_over.get("status", "lose") == "win"))


## A defeat banner can offer Rewind only when the budget allows and a PLAYER frame exists.
func _rewind_available_on_banner() -> bool:
	if director.rewind_budget == 0 or director.rewind_uses_left <= 0 and director.rewind_budget > 0:
		return false
	return director.rewind.find_last_player_frame() >= 0


func _update_hover_info() -> void:
	if director.state == null:
		return
	var u := director.state.unit_at(hover_cell)
	# F-HEAL preview (GDD Pillar 2): hovering a Heal target shows the raw amount and real gain.
	if mode == Mode.SKILL_TARGET and u != null and _skill_targets.has(u.id):
		var heal_text := heal_preview_text(_selected(), u, _pending_skill_id)
		if heal_text != "":
			_info_label.text = heal_text
	_show_unit_card(u if u != null else _selected())
	_show_terrain_box(hover_cell)


## F-UI step 4 unit card (bottom-left; bottom-right when it would cover the unit).
func _show_unit_card(u: UnitState) -> void:
	if _unit_card == null:
		return
	for c in _unit_card.get_children():
		c.queue_free()
	if u == null:
		_unit_card.visible = false
		return
	_unit_card.visible = true
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_card.add_child(row)
	var portrait := ColorRect.new()   # placeholder until portrait art exists
	portrait.custom_minimum_size = Vector2(110, 150)
	portrait.color = Color(0.2, 0.45, 0.75) if u.side == "player" else (Color(0.75, 0.6, 0.2) if u.side == "npc" else Color(0.7, 0.25, 0.22))
	row.add_child(portrait)
	var initials := UIBuilder.title(portrait, u.display_name.substr(0, 2), 40)
	initials.position = Vector2(26, 46)
	var info := UIBuilder.vbox(row, 3)
	for line in unit_card_lines(u):
		UIBuilder.label(info, line, 13)
	(info.get_child(0) as Label).add_theme_font_size_override("font_size", 20)
	var bar := ProgressBar.new()
	bar.max_value = maxi(u.max_hp, 1)
	bar.value = u.hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BattleMapView.hp_band_color(float(u.hp) / float(maxi(u.max_hp, 1)))
	bar.add_theme_stylebox_override("fill", fill)
	info.add_child(bar)
	info.move_child(bar, 2)
	var screen := map_view.cell_to_global(u.pos)
	var left_rect := Rect2(Vector2(HUD_MARGIN, UITheme.FRAME.y - HUD_MARGIN - CARD_SIZE.y), CARD_SIZE)
	var on_left := not left_rect.grow(map_view.cell_px / 2.0).has_point(screen)
	_unit_card.position.x = HUD_MARGIN if on_left else UITheme.FRAME.x - HUD_MARGIN - CARD_SIZE.x
	_terrain_box.position.x = UITheme.FRAME.x - HUD_MARGIN - TERRAIN_SIZE.x if on_left else HUD_MARGIN


## Card text: name, class / level, HP numbers, stats, items, buffs.
static func unit_card_lines(u: UnitState) -> Array[String]:
	var lines: Array[String] = []
	lines.append(u.display_name)
	lines.append(UIBuilder.t("Lv %d · %s") % [u.level, u.class_id.replace("class_", "").capitalize()])
	lines.append("HP %d / %d" % [u.hp, u.max_hp])
	lines.append("Str %d  Mag %d  Skill %d  Spd %d" % [u.eff("power"), u.eff("magic"), u.eff("skill"), u.eff("speed")])
	lines.append("Luck %d  Def %d  Res %d  Move %d" % [u.eff("luck"), u.eff("defense"), u.eff("resistance"), u.move_range])
	if not u.items.is_empty():
		lines.append(UIBuilder.t("Items: %s") % item_list_text(u.items))
	var buffs: Array[String] = []
	for field in u.active_buffs:
		buffs.append("%s +%d (%d)" % [String(field), int(u.active_buffs[field].get("amount", 0)), int(u.active_buffs[field].get("turns_remaining", 0))])
	if not buffs.is_empty():
		lines.append(UIBuilder.t("Buffs: %s") % ", ".join(buffs))
	return lines


## F-UI step 4 terrain box (bottom-right): terrain name, Def / Avoid bonus, move cost on foot.
func _show_terrain_box(target: Vector2i) -> void:
	if _terrain_box == null:
		return
	for c in _terrain_box.get_children():
		c.queue_free()
	if not director.state.in_bounds(target):
		_terrain_box.visible = false
		return
	_terrain_box.visible = true
	var box := UIBuilder.vbox(_terrain_box, 2)
	for line in terrain_box_lines(director.state.terrain_at(target)):
		UIBuilder.label(box, line, 13)
	(box.get_child(0) as Label).add_theme_font_override("font", UITheme.title_font())
	(box.get_child(0) as Label).add_theme_font_size_override("font_size", 18)


static func terrain_box_lines(terrain: String) -> Array[String]:
	var defs: Dictionary = DataRegistry.rule("terrain_defs", {}).get(terrain, {})
	var cost: Dictionary = DataRegistry.rule("terrain_costs", {}).get(terrain, {})
	var lines: Array[String] = [UIBuilder.t(terrain.capitalize())]
	lines.append(UIBuilder.t("Def +%d · Avoid +%d") % [int(defs.get("def_bonus", 0)), int(defs.get("avoid_bonus", 0))])
	var foot := float(cost.get("foot", 1.0))
	lines.append(UIBuilder.t("Blocked") if bool(defs.get("blocked", false)) or foot >= 99.0 else UIBuilder.t("Move cost %s") % str(foot).trim_suffix(".0"))
	return lines


## "Heal 20 -> +12 HP (36->48)" for a heal skill, "" for other skills (numbers from CombatResolver).
func heal_preview_text(healer: UnitState, target: UnitState, skill_id: String) -> String:
	var skill := DataRegistry.get_data("skills", skill_id)
	if healer == null or target == null or skill == null or String(skill.effect_type) != "heal":
		return ""
	var p := CombatResolver.heal_preview(healer, target, skill)
	return UIBuilder.t("%s: Heal %d -> +%d HP (%d->%d)") % [target.display_name, int(p["raw"]), int(p["gain"]), int(p["hp_before"]), int(p["hp_after"])]


func _update_objective_label() -> void:
	if _turn_label != null:
		var phase := UIBuilder.t("Player phase") if director.state.phase == BattleState.PHASE_PLAYER else (UIBuilder.t("Enemy phase") if director.state.phase == BattleState.PHASE_ENEMY else UIBuilder.t("NPC phase"))
		_turn_label.text = UIBuilder.t("Turn %d · %s") % [director.state.turn, phase]
	var lines: Array[String] = []
	for res in director.active_objectives_progress():
		lines.append("%s: %s (%s)" % [UIBuilder.t(String(res["id"])), str(res["progress"]), UIBuilder.t(str(res["status"]))])
	# F-DRS (GDD Core Rule 6): the squad's death-free status is shown live; kills stay hidden.
	lines.append(UIBuilder.t("Squad: no ally lost") if DualRestraint.zero_ally_deaths(director.state) else UIBuilder.t("Squad: an ally has fallen"))
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


## Next to the unit at (24, -12) past its tile, flipped to the left at the right edge, kept in frame.
static func action_menu_position(unit_center: Vector2, cell_px: float, menu_size: Vector2) -> Vector2:
	var pos := unit_center + Vector2(cell_px / 2.0 + 24.0, -12.0 - cell_px / 2.0)
	if pos.x + menu_size.x > UITheme.FRAME.x - HUD_MARGIN:
		pos.x = unit_center.x - cell_px / 2.0 - 24.0 - menu_size.x
	pos.x = clampf(pos.x, HUD_MARGIN, UITheme.FRAME.x - HUD_MARGIN - menu_size.x)
	pos.y = clampf(pos.y, HUD_MARGIN, UITheme.FRAME.y - HUD_MARGIN - menu_size.y)
	return pos


func _hide_action_menu() -> void:
	if _action_panel != null:
		_action_panel.visible = false
	for c in _action_menu.get_children():
		c.queue_free()


func _refresh_overlays() -> void:
	map_view.set_threat(enemy_threat())
	var sel := _selected()
	if sel == null or not sel.alive:
		map_view.set_overlays({}, {}, {} if active_targets.is_empty() else active_targets)
		return
	if mode == Mode.SKILL_TARGET:
		# Only the skill's valid targets are highlighted while choosing.
		var skill_cells := {}
		for t in _skill_targets:
			skill_cells[_skill_targets[t]] = true
		map_view.set_overlays({}, {}, skill_cells)
		return
	var reach := MovementHandler.compute_reachable(director.state, sel)
	var move_cells := MovementHandler.compute_move_cells(director.state, sel) if mode == Mode.UNIT_SELECTED else {}
	var attacks := RangeHandler.compute_attack_cells(director.state, sel, reach)
	var targets := {}
	if mode == Mode.TARGET_SELECT:
		for t in active_targets:
			targets[active_targets[t]] = true
	map_view.set_overlays(move_cells, attacks, targets)


# ------------------------------------------------------------------ N08 pause

## Esc opens/closes the pause menu. While open, map input and the enemy/NPC loops stall
## (the loops wait on process_frame until paused is cleared); nothing mid-battle is saved.
func _toggle_pause() -> void:
	if paused:
		return
	paused = true
	_pause_menu = PauseMenu.new()
	_pause_menu.battle_state = director.state
	_pause_menu.resumed.connect(_on_resume)
	_pause_menu.quit_to_menu.connect(func() -> void:
		paused = false
		quit_to_menu.emit())
	add_child(_pause_menu)


func _on_resume() -> void:
	paused = false
	_pause_menu = null


# ------------------------------------------------------------------ N10 reconcile HUD

## F-PSI: one pressure chip per remnant faction (name + continuous colour bar from
## ReconcileSystem.kill_pressure_ratio(), no numbers); plus the battle-start warning.
func _build_reconcile_hud() -> void:
	var factions: Array = director.state.reconcile_state.keys()
	if factions.is_empty():
		return
	# F-UI step 4: the pressure chips and the note live in the objective box.
	_reconcile_notice = UIBuilder.label(_objective_vbox,
		UIBuilder.t("Limit your kills if you want to persuade the remnants - watch the pressure colour."), 12)
	_reconcile_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reconcile_notice.custom_minimum_size = Vector2(250, 0)
	_reconcile_chip_box = HBoxContainer.new()
	_reconcile_chip_box.add_theme_constant_override("separation", 14)
	_objective_vbox.add_child(_reconcile_chip_box)
	_refresh_reconcile_hud()


## Continuous green -> yellow -> red blend (GDD Rule 14b: not bands). The three stops come
## from FactionData.attitude_colors so the colours stay data.
static func pressure_color(ratio: float, stops: Dictionary) -> Color:
	var green: Color = stops.get("safe", Color(0.3, 0.8, 0.4))
	var yellow: Color = stops.get("neutral", Color(0.9, 0.85, 0.3))
	var red: Color = stops.get("lost", Color(0.85, 0.3, 0.3))
	var r := clampf(ratio, 0.0, 1.0)
	if r <= 0.5:
		return green.lerp(yellow, r * 2.0)
	return yellow.lerp(red, (r - 0.5) * 2.0)


func _refresh_reconcile_hud() -> void:
	if _reconcile_chip_box == null:
		return
	for c in _reconcile_chip_box.get_children():
		c.queue_free()
	for faction_id in director.state.reconcile_state:
		var f := DataRegistry.get_faction(String(faction_id))
		var att := ReconcileSystem.attitude(director.state, String(faction_id))
		var rs: Dictionary = director.state.reconcile_state[faction_id]
		var persuaded := bool(rs.get("evaluated", false)) and bool(rs.get("persuaded", false))
		var chip := VBoxContainer.new()
		chip.name = "Pressure_%s" % String(faction_id)
		chip.visible = not persuaded   # Rule 14e: the persuasion scene owns that moment
		chip.add_theme_constant_override("separation", 2)
		_reconcile_chip_box.add_child(chip)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(200, 10)
		var ratio := ReconcileSystem.kill_pressure_ratio(director.state, String(faction_id))
		swatch.color = pressure_color(ratio, f.attitude_colors if f != null else {})
		chip.add_child(swatch)
		# Name only: no number, percentage or attitude word next to the colour (AC-BUI32).
		var lbl := UIBuilder.label(chip, f.display_name if f != null else String(faction_id), 14)
		lbl.size = Vector2(200, 22)
		# Feedback dialogue when the attitude FLIPS into a state (rewind flips count too, N10).
		var previous: String = String(_reconcile_attitudes.get(String(faction_id), ""))
		if previous != "" and previous != att and f != null and not f.feedback.is_empty():
			var dlg_id: Variant = f.feedback.get(att, "")
			if String(dlg_id) != "":
				_play_feedback_dialogue(String(dlg_id))
		_reconcile_attitudes[String(faction_id)] = att


func _play_feedback_dialogue(dialogue_id: String) -> void:
	var dlg := DataRegistry.get_dialogue(dialogue_id)
	if dlg == null:
		push_warning("BattleScene: missing reconcile feedback dialogue %s" % dialogue_id)
		return
	var layer := _forecast_layer()   # above the map, below nothing critical
	var player := DialoguePlayer.build(dlg)
	layer.add_child(player)


# ------------------------------------------------------------ F-ITEM actions

var _trade_panel: Control = null


## F-BUI Rule 11: the Action Menu entries for `unit` right now, in GDD order -
## [{kind, label, arg}]. Entries with no legal target or condition are left out.
static func action_menu_entries(state: BattleState, unit: UnitState, targets: Dictionary) -> Array:
	var out: Array = []
	if not targets.is_empty():
		out.append({"kind": "attack", "label": UIBuilder.t("Attack")})
	var heals: Array = []
	var encores: Array = []
	for skill_id in unit.skill_ids:
		var skill := DataRegistry.get_data("skills", skill_id)
		if skill == null:
			continue
		var has_target := false
		for other in state.alive_units():
			if SkillCommand.check(state, unit, skill_id, other) == "":
				has_target = true
				break
		if not has_target:
			continue
		var label := String(skill.display_name) if String(skill.display_name) != "" else skill_id
		var e := {"kind": "skill", "arg": skill_id, "label": UIBuilder.t("Skill: %s") % UIBuilder.t(label)}
		if String(skill.effect_type) == "encore":
			encores.append(e)
		else:
			heals.append(e)
	out.append_array(heals)
	for item_id in unit.items:
		if UseItemCommand.check(state, unit, String(item_id)) == "":
			out.append({"kind": "use_item", "arg": String(item_id), "label": UIBuilder.t("Use: %s") % item_name(String(item_id))})
	if VisitCommand.check(state, unit) == "":
		out.append({"kind": "visit", "label": UIBuilder.t("Visit village")})
	out.append_array(encores)
	if not trade_partners(state, unit).is_empty():
		out.append({"kind": "trade", "label": UIBuilder.t("Trade")})
	if WaitCommand.check(state, unit) == "":
		out.append({"kind": "wait", "label": UIBuilder.t("Wait")})
	return out


func _on_menu_entry(kind: String, arg: String) -> void:
	match kind:
		"attack":
			_hide_action_menu()
			_enter_target_select()
			_info_label.text = UIBuilder.t("Choose a target (red tiles), right click to go back.")
			_refresh_overlays()
		"skill":
			_use_skill(arg)
		"use_item":
			_use_item(arg)
		"visit":
			_do_visit()
		"trade":
			_open_trade_partners()
		"wait":
			_do_wait()


## Trade sub-list: the adjacent allies a legal exchange exists with.
func _open_trade_partners() -> void:
	var sel := _selected()
	if sel == null:
		return
	_close_trade()
	_trade_panel = UIBuilder.modal(_ui_root())
	var box := UIBuilder.vbox(UIBuilder.centered_modal_panel(_trade_panel, 600, 380), 8)
	UIBuilder.label(box, UIBuilder.t("Trade with whom?"), 18)
	for partner_id in trade_partners(director.state, sel):
		var btn := UIBuilder.button(box, director.state.units[partner_id].display_name, 16)
		var chosen := String(partner_id)
		btn.pressed.connect(func() -> void: _open_trade(chosen))
	var cancel := UIBuilder.button(box, UIBuilder.t("Cancel"), 16)
	cancel.pressed.connect(_close_trade)


## Adjacent squad allies with at least one legal, non-empty trade.
static func trade_partners(state: BattleState, unit: UnitState) -> Array[String]:
	var out: Array[String] = []
	for other in state.alive_units():
		if other.id != unit.id and not trade_options(state, unit, other).is_empty():
			out.append(other.id)
	return out


## Every legal non-empty trade: [{give, take, label}] (gifts, takes, swaps).
static func trade_options(state: BattleState, unit: UnitState, partner: UnitState) -> Array:
	var out: Array = []
	var gives: Array = [""] + unit.items
	var takes: Array = [""] + partner.items
	for give in gives:
		for take in takes:
			if String(give) == "" and String(take) == "":
				continue
			if TradeCommand.check(state, unit, partner, String(give), String(take)) != "":
				continue
			# GDD Battle UI Rule 1: a plain before/after readout of what each side receives.
			var label := UIBuilder.t("%s receives: %s · %s receives: %s") % [
				partner.display_name, item_name(String(give)) if String(give) != "" else UIBuilder.t("nothing"),
				unit.display_name, item_name(String(take)) if String(take) != "" else UIBuilder.t("nothing")]
			out.append({"give": String(give), "take": String(take), "label": label})
	return out


static func item_name(item_id: String) -> String:
	var item := DataRegistry.get_item(item_id)
	return String(item.display_name) if item != null and String(item.display_name) != "" else item_id


static func item_list_text(items: Array) -> String:
	var names: Array[String] = []
	for item_id in items:
		names.append(item_name(String(item_id)))
	return ", ".join(names)


func _use_item(item_id: String) -> void:
	var sel := _selected()
	if sel == null:
		return
	mode = Mode.BUSY
	director.commit("use_item", {"unit_id": sel.id, "item_id": item_id})
	_finish_action()


func _do_visit() -> void:
	var sel := _selected()
	if sel == null:
		return
	mode = Mode.BUSY
	director.commit("visit", {"unit_id": sel.id})
	_finish_action()


func _open_trade(partner_id: String) -> void:
	var sel := _selected()
	if sel == null:
		return
	_close_trade()
	var partner: UnitState = director.state.units[partner_id]
	_trade_panel = UIBuilder.modal(_ui_root())
	var box := UIBuilder.vbox(UIBuilder.centered_modal_panel(_trade_panel, 600, 380), 8)
	UIBuilder.label(box, UIBuilder.t("Trade with %s - choose:") % partner.display_name, 18)
	for opt in trade_options(director.state, sel, partner):
		var btn := UIBuilder.button(box, String(opt["label"]), 16)
		var give := String(opt["give"])
		var take := String(opt["take"])
		btn.pressed.connect(func() -> void: _commit_trade(partner_id, give, take))
	var cancel := UIBuilder.button(box, UIBuilder.t("Cancel"), 16)
	cancel.pressed.connect(_close_trade)


## Trade is free: the unit stays selected and can still act.
func _commit_trade(partner_id: String, give: String, take: String) -> void:
	var sel := _selected()
	_close_trade()
	if sel == null:
		return
	director.commit("trade", {"unit_id": sel.id, "partner_id": partner_id, "give_item": give, "take_item": take})
	_show_action_menu(sel)
	_update_hover_info()
	_refresh_rewind_button()


func _close_trade() -> void:
	if _trade_panel != null and is_instance_valid(_trade_panel):
		_trade_panel.queue_free()
	_trade_panel = null


# ------------------------------------------------------------ F-BUI rewind point screen

## Rewind Core Rule 3: every rewindable boundary since battle start, newest first, with
## "Undo last action" on top. Any entry costs exactly one charge.
func open_rewind_picker() -> void:
	if mode == Mode.BUSY or paused or director.state.phase != BattleState.PHASE_PLAYER:
		return
	if _revert_pending(_selected()):   # F-MOVE: free take-back, never a paid rewind point
		_cancel_selection()
	var frames := director.rewind.player_frames()
	var budget := director.rewind_budget
	if frames.is_empty() or budget == 0 or (budget > 0 and director.rewind_uses_left <= 0):
		return
	_close_rewind_picker()
	_rewind_picker = UIBuilder.modal(_ui_root())
	var box := UIBuilder.vbox(UIBuilder.centered_modal_panel(_rewind_picker, 600, 600), 6)
	UIBuilder.label(box, UIBuilder.t("Rewind to which point? (costs 1 use)"), 22)
	var quick := UIBuilder.button(box, UIBuilder.t("Undo last action"), 18)
	quick.pressed.connect(func() -> void: _rewind_to(frames[0]))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 420)
	box.add_child(scroll)
	var list := UIBuilder.vbox(scroll, 4)
	for index in frames:
		var btn := UIBuilder.button(list, rewind_point_label(index), 16)
		var chosen: int = index
		btn.pressed.connect(func() -> void: _rewind_to(chosen))
	var cancel := UIBuilder.button(box, UIBuilder.t("Cancel"), 18)
	cancel.pressed.connect(_close_rewind_picker)


## "Turn 2 - before: Swordsman move" / "Turn 3 - start of turn".
func rewind_point_label(index: int) -> String:
	var frame: Dictionary = director.rewind.frames[index]
	var turn := int(frame["snapshot"].get("turn", 1))
	var label := String(frame.get("label", ""))
	if label == "turn_start":
		return UIBuilder.t("Turn %d - start of turn") % turn
	var who := ""
	var unit_id := String(frame.get("unit_id", ""))
	if director.state.units.has(unit_id):
		who = director.state.units[unit_id].display_name + " "
	return UIBuilder.t("Turn %d - before: %s%s") % [turn, who, UIBuilder.t(label)]


func _rewind_to(frame_index: int) -> void:
	_close_rewind_picker()
	if director.use_rewind(frame_index):
		selected_unit_id = ""
		mode = Mode.IDLE
		_hide_action_menu()
		_refresh_overlays()
		_refresh_rewind_button()
		_check_battle_over()


func _close_rewind_picker() -> void:
	if _rewind_picker != null and is_instance_valid(_rewind_picker):
		_rewind_picker.queue_free()
	_rewind_picker = null


## F-BUI Rule 2: every enemy's threat range during the Player Phase.
func enemy_threat() -> Dictionary:
	var out := {}
	if director.state.phase != BattleState.PHASE_PLAYER:
		return out
	for u in director.state.alive_units():
		if u.side == "enemy":
			out.merge(RangeHandler.threat_cells(director.state, u))
	return out
