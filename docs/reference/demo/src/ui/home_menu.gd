class_name HomeMenu
extends Control

signal new_game_requested
signal continue_requested
signal options_requested

const INK := Color("#07141a")
const GOLD := Color("#dfbd80")
const MINT := Color("#a9d7c9")
const PALE := Color("#f3eddd")
const MUTED := Color("#a9b8b7")
const LINE := Color(0.72, 0.84, 0.81, 0.20)

var _serif_font: Font
var _has_save: bool = false


func configure(serif_font: Font, has_save: bool) -> void:
	_serif_font = serif_font
	_has_save = has_save


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(1150, 430)
	row.add_theme_constant_override("separation", 45)
	center.add_child(row)

	var hero := VBoxContainer.new()
	hero.custom_minimum_size = Vector2(690, 0)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(hero)
	hero.add_child(_title("PROJECT", 112, PALE))

	var second_line := MarginContainer.new()
	second_line.add_theme_constant_override("margin_left", 48)
	second_line.add_child(_title("X", 132, MINT))
	hero.add_child(second_line)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 0)
	menu.add_child(_menu_button("Trò chơi mới", new_game_requested.emit))
	menu.add_child(_menu_button("Tiếp tục", continue_requested.emit, not _has_save))
	menu.add_child(_menu_button("Tùy chọn", options_requested.emit))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(398, 242)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.11, 0.14, 0.93)
	panel_style.border_color = LINE
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(23)
	card.add_theme_stylebox_override("panel", panel_style)
	card.add_child(menu)
	row.add_child(card)


func _title(value: String, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_OFF
	item.add_theme_color_override("font_color", color)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_font_override("font", _serif_font)
	return item


func _menu_button(caption: String, action: Callable, disabled: bool = false) -> Button:
	var item := Button.new()
	item.text = caption
	item.custom_minimum_size = Vector2(330, 64)
	item.disabled = disabled
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.add_theme_font_size_override("font_size", 16)
	item.add_theme_color_override("font_color", PALE)
	item.add_theme_color_override("font_hover_color", GOLD)
	item.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.31, 0.46, 0.44, 0.10) if state == "hover" else Color.TRANSPARENT
		style.border_color = LINE if state != "focus" else GOLD
		style.border_width_bottom = 1
		style.content_margin_left = 8
		item.add_theme_stylebox_override(state, style)
	item.pressed.connect(action)
	return item
