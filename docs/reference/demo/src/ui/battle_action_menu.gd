extends Control
## Post-move Action Menu (Core Rule 11, battle-ui-system.md) — Attack/Heal/
## Use Item/Visit/Trade/Wait, showing only currently-legal entries (AC-BUI14).
## Data in via show_for_unit()/show_trade_targets(), signals out — never
## reads or writes battle state itself (same contract as NarrativeDialogueBox,
## ADR-0018). Attack/Heal render if the caller's legal_actions list includes
## them; this component has no opinion on why an action is or isn't legal.
##
## design/ux/battle-action-menu.md fixes applied here (2026-10-08): anchors
## near the acting unit instead of a fixed screen offset, 24px text (this
## project's established menu-text floor), and keyboard/gamepad focus
## wiring + Escape-to-cancel.
class_name BattleActionMenu

signal action_chosen(action: String)
signal trade_target_chosen(target_id: String)
signal trade_cancelled()
signal cancelled()  ## Escape pressed on the main action list (not Trade's sub-list)

const GOLD := Color("#dfbd80")
const PALE := Color("#f3eddd")
const MUTED := Color("#a9b8b7")
const LINE := Color(0.72, 0.84, 0.81, 0.20)
const MENU_TEXT_SIZE := 24  ## This project's established menu-text floor (bond-support-menu.md, roster-progression-menu.md)
const DEFAULT_ANCHOR := Vector2(40, 40)
const ANCHOR_OFFSET := Vector2(24, -12)  ## Rendered slightly up-right of the supplied anchor, so the panel doesn't sit directly on top of the unit it belongs to

const ACTION_LABELS := {
	"Attack": "Tấn công",
	"Heal": "Hồi máu",
	"Use Item": "Dùng vật phẩm",
	"Visit": "Vào làng",
	"Trade": "Trao đổi",
	"Wait": "Chờ",
}

var _unit_label: Label
var _list: VBoxContainer
var _frame: PanelContainer
var _mode: String = "actions"  # "actions" | "trade_targets" — drives Escape's target signal


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_theme_constant_override("separation", 8)

	_unit_label = _make_label(MENU_TEXT_SIZE, GOLD)
	_unit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_unit_label)

	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_list.add_theme_constant_override("separation", 6)
	body.add_child(_list)

	_frame = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.11, 0.14, 0.93)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	_frame.add_theme_stylebox_override("panel", style)
	_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	_frame.add_child(body)
	_frame.custom_minimum_size = Vector2(280, 0)
	add_child(_frame)

	visible = false


## AC-BUI14 — renders exactly the legal_actions list the caller supplies, in
## order; this component never decides legality itself. anchor_position is
## the acting unit's screen position (e.g. a world-to-screen-projected tile
## center) — the panel renders offset from it, not at a fixed screen spot.
func show_for_unit(unit_label: String, legal_actions: Array[String], anchor_position: Vector2 = DEFAULT_ANCHOR) -> void:
	_mode = "actions"
	_unit_label.text = unit_label
	_clear_list()
	for action in legal_actions:
		var label: String = ACTION_LABELS.get(action, action)
		_list.add_child(_make_button(label, _on_action_pressed.bind(action)))
	_frame.position = anchor_position + ANCHOR_OFFSET
	visible = true
	_wire_focus_order()
	_grab_first_focus()


## AC-BUI17 — before/after carried_items preview, no Hit%/Crit%/Damage field.
## Each target: {"id": String, "label": String, "before": String, "after": String}
## (empty-slot contents already formatted by the caller, e.g. "(trống)").
func show_trade_targets(unit_label: String, targets: Array[Dictionary], anchor_position: Vector2 = DEFAULT_ANCHOR) -> void:
	_mode = "trade_targets"
	_unit_label.text = "%s — chọn mục tiêu trao đổi" % unit_label
	_clear_list()
	for target in targets:
		var caption: String = "%s   %s → %s" % [target["label"], target["before"], target["after"]]
		_list.add_child(_make_button(caption, _on_trade_target_pressed.bind(String(target["id"]))))
	_list.add_child(_make_button("Hủy", _on_trade_cancel_pressed))
	_frame.position = anchor_position + ANCHOR_OFFSET
	visible = true
	_wire_focus_order()
	_grab_first_focus()


func hide_menu() -> void:
	visible = false
	_clear_list()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _mode == "trade_targets":
		trade_cancelled.emit()
	else:
		cancelled.emit()


func _clear_list() -> void:
	for child in _list.get_children():
		child.queue_free()


func _grab_first_focus() -> void:
	if _list.get_child_count() > 0:
		(_list.get_child(0) as Control).grab_focus()


## Tab/D-pad cycles through every button in order and wraps from last back
## to first (this project's established convention — bond-support-menu.md
## AC-UX1) rather than stopping at the list's end.
func _wire_focus_order() -> void:
	var buttons := _list.get_children()
	for i in buttons.size():
		var current: Control = buttons[i]
		var next: Control = buttons[(i + 1) % buttons.size()]
		var previous: Control = buttons[(i - 1 + buttons.size()) % buttons.size()]
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_next = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_previous = current.get_path_to(previous)


func _on_action_pressed(action: String) -> void:
	action_chosen.emit(action)


func _on_trade_target_pressed(target_id: String) -> void:
	trade_target_chosen.emit(target_id)


func _on_trade_cancel_pressed() -> void:
	trade_cancelled.emit()


func _make_label(font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.add_theme_color_override("font_color", color)
	item.add_theme_font_size_override("font_size", font_size)
	return item


func _make_button(caption: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = caption
	item.custom_minimum_size = Vector2(0, 44)
	item.add_theme_font_size_override("font_size", MENU_TEXT_SIZE)
	item.add_theme_color_override("font_color", PALE)
	item.add_theme_color_override("font_hover_color", GOLD)
	item.add_theme_color_override("font_focus_color", GOLD)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.17, 0.20, 0.85) if (state == "hover" or state == "focus") else Color(0.02, 0.08, 0.10, 0.45)
		style.border_color = GOLD if state == "focus" else LINE
		style.set_border_width_all(1)
		style.set_content_margin_all(10)
		item.add_theme_stylebox_override(state, style)
	item.pressed.connect(action)
	return item
