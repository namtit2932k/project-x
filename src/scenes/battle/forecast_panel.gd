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
	UIBuilder.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP   # map input waits while the forecast is up

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# F-UI: one opaque, centred window; columns, buttons and the reminder stack inside it
	# (they used to share the PanelContainer directly and overlapped).
	var window := UIBuilder.centered_modal_panel(self, 860, 400)
	var stack := UIBuilder.vbox(window, 16)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(columns)
	var left := _render_side(columns, attacker, _strikes_for(forecast, "attacker"), false)
	var right := _render_side(columns, defender, _strikes_for(forecast, "counter"), bool(forecast.get("can_counter", false)))
	# F-PAS preview: passive side effects listed under the side that owns them.
	for note in forecast.get("notes", []):
		var box: VBoxContainer = left if String(note.get("owner", "")) == "attacker" else right
		UIBuilder.label(box, note_text(note), 16)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 30)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(buttons)
	var ok_btn := UIBuilder.button(buttons, UIBuilder.t("Confirm attack"), 24)
	ok_btn.pressed.connect(func() -> void: confirmed.emit())
	var cancel_btn := UIBuilder.button(buttons, UIBuilder.t("Cancel"), 24)
	cancel_btn.pressed.connect(func() -> void: cancelled.emit())
	# A окна hint line under the title keeps the wait reminder from T09 visible.
	var wait_hint := UIBuilder.label(stack, UIBuilder.t("NOT committed yet - Confirm to fight. Cancel / right-click to step back."), 14)
	wait_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _strikes_for(forecast: Dictionary, side: String) -> Array:
	var out: Array = []
	for entry in forecast.get("sequence", []):
		if String(entry.get("side", "")) == side:
			out.append(entry)
	return out


func _render_side(columns: Container, unit: UnitState, strikes: Array, active: bool) -> VBoxContainer:
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(side_box)
	if strikes.is_empty() and not active:
		UIBuilder.label(side_box, "%s  (HP %d/%d)" % [unit.display_name, unit.hp, unit.max_hp], 24)
		UIBuilder.label(side_box, UIBuilder.t("No counter"), 18)
		return side_box
	UIBuilder.label(side_box, "%s  (HP %d/%d)" % [unit.display_name, unit.hp, unit.max_hp], 24)
	for i in strikes.size():
		var s: Dictionary = strikes[i]
		var label := UIBuilder.t("Strike %d: Hit %d%% / Crit %d%% / Dmg %d") % [
			i + 1, int(s.get("hit_pct", 0)), int(s.get("crit_pct", 0)), int(s.get("damage", 0))]
		UIBuilder.label(side_box, label, 18)
	return side_box


const STAT_LABELS := {"defense": "Def", "resistance": "Res", "power": "Str", "magic": "Mag", "skill": "Skill", "speed": "Speed", "luck": "Luck"}


## One readable line for a PassiveSystem.forecast_notes() entry (pure formatting, no math).
static func note_text(note: Dictionary) -> String:
	var value := int(note.get("value", 0))
	var stat := UIBuilder.t(String(STAT_LABELS.get(String(note.get("stat", "")), String(note.get("stat", "")))))
	var body := ""
	match String(note.get("effect_type", "")):
		"debuff_target_stat":
			body = UIBuilder.t("on hit: target %s -%d for %d turns") % [stat, value, int(note.get("turns", 0))]
		"lifesteal":
			body = UIBuilder.t("on hit: heals %d HP per hit (more on a crit)") % value
		"force_double":
			body = UIBuilder.t("strikes twice before the counter")
		"ignore_defender_terrain":
			body = UIBuilder.t("ignores the target's terrain Avoid (+%d)") % value
		"burst_damage":
			body = UIBuilder.t("+%d damage on the first strike") % value
		"suppress_retaliation":
			body = UIBuilder.t("target has not acted yet: no counter")
		"flat_self_heal":
			body = UIBuilder.t("heals %d HP after attacking") % value
		"thorns_damage":
			body = UIBuilder.t("deals %d damage back if it survives") % value
		"survive_once":
			body = UIBuilder.t("survives one lethal blow at 1 HP (not used yet)")
		"extended_range":
			body = UIBuilder.t("range +%d at high HP") % value
		"adjacency_aura_avoid":
			body = UIBuilder.t("+%d Avoid from an adjacent Bard") % value
		"active_debuff":
			return UIBuilder.t("Debuffed: %s -%d (%d turns left)") % [stat, value, int(note.get("turns", 0))]
		_:
			body = String(note.get("effect_type", ""))
	return "[%s] %s" % [UIBuilder.t(String(note.get("name", ""))), body]


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			cancelled.emit()
			accept_event()
		elif event.is_action_pressed("ui_cancel"):
			cancelled.emit()
			accept_event()
