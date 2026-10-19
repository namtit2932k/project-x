extends Control
## Reusable bottom-anchored narrative dialogue presentation (ADR-0018).
## Data in via load_scene_data(), signals out — never reads or writes
## game_flow.gd's screen-routing or campaign state.
class_name NarrativeDialogueBox

signal advanced()
signal skip_requested()
signal scene_finished()

const GOLD := Color("#dfbd80")
const PALE := Color("#f3eddd")
const LINE := Color(0.72, 0.84, 0.81, 0.20)

var scene_data: NarrativeSceneData
var line_index: int = 0

var _serif_font: Font
var _speaker_label: Label
var _body_label: Label
var _dots_label: Label
var _skip_row: HBoxContainer
var _skip_button: Button
var _frame: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_area_input)
	var system_serif := SystemFont.new()
	system_serif.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "Noto Serif"])
	_serif_font = system_serif

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_theme_constant_override("separation", 10)

	# Per design/ux/narrative-bond-scene.md's wireframe: speaker tag (left) +
	# progress dots (right) share the top row; Skip-to-end is alone on its
	# own row. There is no persistent "advance" button in the approved
	# Component Inventory — advancing is the full-stage click / Enter-Space
	# default action, handled by _on_area_input() and game_flow.gd's
	# keyboard handling, not a focusable widget here.
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_speaker_label = _make_label(24, GOLD)
	_speaker_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_speaker_label)
	top_row.add_spacer(false)
	_dots_label = _make_label(16, GOLD)
	_dots_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_dots_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_dots_label)
	body.add_child(top_row)

	_body_label = _make_label(28, PALE)
	_body_label.add_theme_font_override("font", _serif_font)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(0, 79)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_body_label)

	_skip_row = HBoxContainer.new()
	_skip_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_skip_row.custom_minimum_size = Vector2(0, 40)
	_skip_row.add_spacer(false)
	_skip_button = _make_button("↠ Bỏ qua", _on_skip_pressed, 180)
	_skip_row.add_child(_skip_button)
	body.add_child(_skip_row)

	_frame = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.11, 0.14, 0.93)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_frame.add_theme_stylebox_override("panel", style)
	_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	_frame.add_child(body)
	_frame.anchor_left = 0.07
	_frame.anchor_right = 0.93
	_frame.anchor_top = 1.0
	_frame.anchor_bottom = 1.0
	_frame.offset_top = -216
	_frame.offset_bottom = -28
	add_child(_frame)


func _input(event: InputEvent) -> void:
	# UX spec: Escape is a deliberate no-op on this screen (deviates from the
	# VN-Style default) rather than left unhandled for some other listener.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func load_scene_data(data: NarrativeSceneData) -> void:
	scene_data = data
	line_index = 0
	if scene_data.is_severance and is_instance_valid(_skip_button):
		_skip_button.queue_free()
		_skip_button = null
	_render_line()


func advance() -> void:
	if scene_data == null or scene_data.lines.is_empty():
		return
	advanced.emit()
	if line_index < scene_data.lines.size() - 1:
		line_index += 1
		_render_line()
	else:
		scene_finished.emit()


func current_background_mode() -> String:
	if scene_data == null or scene_data.lines.is_empty():
		return "journey"
	return str(scene_data.lines[line_index].get("scene", "journey"))


func _render_line() -> void:
	if scene_data == null or scene_data.lines.is_empty():
		return
	var line: Dictionary = scene_data.lines[line_index]
	_speaker_label.text = str(line.get("speaker", "")).to_upper()
	_body_label.text = str(line.get("text", ""))
	var remaining := scene_data.lines.size() - line_index - 1
	_dots_label.text = "● ".repeat(line_index + 1) + "○ ".repeat(remaining)


func _on_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _on_skip_pressed() -> void:
	skip_requested.emit()
	scene_finished.emit()


func _make_label(font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.add_theme_color_override("font_color", color)
	item.add_theme_font_size_override("font_size", font_size)
	return item


func _make_button(caption: String, action: Callable, minimum_width: float) -> Button:
	var item := Button.new()
	item.text = caption
	item.custom_minimum_size = Vector2(minimum_width, 40)
	item.add_theme_font_size_override("font_size", 24)
	item.add_theme_color_override("font_color", PALE)
	item.add_theme_color_override("font_hover_color", GOLD)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.17, 0.20, 0.85) if state == "hover" else Color(0.02, 0.08, 0.10, 0.45)
		style.border_color = GOLD if state == "focus" else LINE
		style.set_border_width_all(1)
		style.set_content_margin_all(10)
		item.add_theme_stylebox_override(state, style)
	item.pressed.connect(action)
	return item
