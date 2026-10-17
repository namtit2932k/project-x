extends Control
class_name ForecastPanel
## Pure display (D01): renders a CombatResolver.forecast() dictionary. Numbers come from
## the resolver only — this panel never recalculates damage, hit or crit. Confirm goes back
## to the scene which then commits the attack; Cancel (or right-click) aborts uncommitted.

signal confirmed
signal cancelled

const CELL := BattleMapView.CELL


## Builds the panel contents under a fixed-size window. Attacker column lists every
## attacker strike (including a double attack); defender column shows the counter (or none).
static func build(forecast: Dictionary, attacker: UnitState, defender: UnitState) -> ForecastPanel:
	var panel := ForecastPanel.new()
	panel._render(forecast, attacker, defender)
	return panel


func _render(forecast: Dictionary, attacker: UnitState, defender: UnitState) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # map input waits while the forecast is up

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var window := PanelContainer.new()
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.custom_minimum_size = Vector2(900, 520)
	add_child(window)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	window.add_child(columns)
	_render_side(columns, attacker, _strikes_for(forecast, "attacker"), false)
	_render_side(columns, defender, _strikes_for(forecast, "counter"), bool(forecast.get("can_counter", false)))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 30)
	buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	window.add_child(buttons)
	var ok_btn := UIBuilder.button(buttons, "Confirm attack", 24)
	ok_btn.pressed.connect(func() -> void: confirmed.emit())
	var cancel_btn := UIBuilder.button(buttons, "Cancel", 24)
	cancel_btn.pressed.connect(func() -> void: cancelled.emit())
	# A окна hint line under the title keeps the wait reminder from T09 visible.
	var wait_hint := UIBuilder.label(self, "NOT committed yet - Confirm to fight. Cancel / right-click to step back.", 14)
	wait_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	wait_hint.position = Vector2(wait_hint.position.x, wait_hint.position.y + 40)


static func _strikes_for(forecast: Dictionary, side: String) -> Array:
	var out: Array = []
	for entry in forecast.get("sequence", []):
		if String(entry.get("side", "")) == side:
			out.append(entry)
	return out


func _render_side(columns: Container, unit: UnitState, strikes: Array, active: bool) -> void:
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	columns.add_child(side_box)
	if strikes.is_empty() and not active:
		UIBuilder.label(side_box, "%s  (HP %d/%d)" % [unit.display_name, unit.hp, unit.max_hp], 24)
		UIBuilder.label(side_box, "No counter", 18)
		return
	UIBuilder.label(side_box, "%s  (HP %d/%d)" % [unit.display_name, unit.hp, unit.max_hp], 24)
	for i in strikes.size():
		var s: Dictionary = strikes[i]
		var label := "Strike %d: Hit %d%% / Crit %d%% / Dmg %d" % [
			i + 1, int(s.get("hit_pct", 0)), int(s.get("crit_pct", 0)), int(s.get("damage", 0))]
		UIBuilder.label(side_box, label, 18)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			cancelled.emit()
			accept_event()
		elif event.is_action_pressed("ui_cancel"):
			cancelled.emit()
			accept_event()
