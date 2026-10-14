extends Control
class_name DialoguePlayer
## Reusable module: takes DialogueData and renders it. New dialogue is data, not new logic.
## Click / Space advances, Skip finishes the scene (Skipped counts as watched for bonds).

signal finished(skipped: bool)

var _lines: Array = []
var _index: int = 0
var _name_label: Label
var _text_label: Label
var _prompt: Label


static func build(data: Resource) -> DialoguePlayer:
	var player := DialoguePlayer.new()
	player.anchor_right = 1.0
	player.anchor_bottom = 1.0
	player._lines = data.lines if data != null else []
	return player


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 160
	box.offset_top = 720
	box.offset_right = -160
	box.offset_bottom = -60
	add_child(box)

	var panel_box := PanelContainer.new()
	box.add_child(panel_box)
	var inner := VBoxContainer.new()
	panel_box.add_child(inner)
	_name_label = UIBuilder.label(inner, "", 22)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 24)
	inner.add_child(_text_label)

	_prompt = UIBuilder.label(self, "Click / Space: continue   -   Esc: skip", 14)
	_prompt.position = Vector2(160, 1010)

	var skip := UIBuilder.button(self, "Skip scene", 16)
	skip.position = Vector2(1640, 990)
	skip.pressed.connect(func() -> void: _finish(true))

	var title := UIBuilder.label(header_anchor(), _title_text(), 14)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_show_line()


func header_anchor() -> Control:
	return self


func _title_text() -> String:
	return _lines[0].get("speaker", "") if not _lines.is_empty() else ""


func _show_line() -> void:
	if _index >= _lines.size():
		_finish(false)
		return
	var line: Dictionary = _lines[_index]
	_name_label.text = String(line.get("speaker", ""))
	_text_label.text = String(line.get("text", ""))
	_prompt.text = "[%d/%d]  Click / Space: continue  -  Esc: skip" % [_index + 1, _lines.size()]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
	elif event.is_action_pressed("ui_accept"):
		_advance()
	elif event.is_action_pressed("ui_cancel"):
		_finish(true)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree():
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			_advance()
			accept_event()
		elif event.is_action_pressed("ui_cancel"):
			_finish(true)


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish(false)
	else:
		_show_line()


func _finish(skipped: bool) -> void:
	finished.emit(skipped)
	queue_free()
