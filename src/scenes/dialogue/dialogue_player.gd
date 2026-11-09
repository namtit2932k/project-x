extends Control
class_name DialoguePlayer
## Reusable module: takes DialogueData and renders it. New dialogue is data, not new logic.
## Click / Space advances, Esc or "Skip" finishes the scene (Skipped counts as watched for bonds).
## F-UI step 5 (UI doc visual-novel screens): placeholder scene backdrop, a small kind tag and a
## serif title, and the bottom box (x 7 %-93 %, bottom -216 to -28) with the speaker in gold
## capitals, 28 px text, progress dots and a Skip button.

signal finished(skipped: bool)

const BOX_LEFT := 90.0      # 7 % of 1280
const BOX_TOP := 504.0      # 720 - 216
const BOX_BOTTOM := 692.0   # 720 - 28

var _lines: Array = []
var _index: int = 0
var _data: Resource = null
var _name_label: Label
var _text_label: Label
var _dots: ProgressDots
var _box: PanelContainer
var _tag_label: Label
var _title_label: Label


static func build(data: Resource) -> DialoguePlayer:
	var player := DialoguePlayer.new()
	player.anchor_right = 1.0
	player.anchor_bottom = 1.0
	player._data = data
	player._lines = data.lines if data != null else []
	return player


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var backdrop := SceneBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.size = UITheme.FRAME
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_tag_label = UIBuilder.label(self, scene_tag(_data), 12)
	_tag_label.add_theme_color_override("font_color", UITheme.ACCENT)
	_tag_label.position = Vector2(116, 140)
	_title_label = UIBuilder.title(self, scene_title(_data), 56)
	_title_label.position = Vector2(112, 160)

	_box = UIBuilder.modal_panel(self, BOX_LEFT, BOX_TOP, UITheme.FRAME.x - 2.0 * BOX_LEFT, BOX_BOTTOM - BOX_TOP)
	_box.name = "DialogueBox"
	var inner := UIBuilder.vbox(_box, 6)
	var top := HBoxContainer.new()
	inner.add_child(top)
	_name_label = UIBuilder.label(top, "", 16)
	_name_label.add_theme_color_override("font_color", UITheme.ACCENT)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots = ProgressDots.new()
	_dots.custom_minimum_size = Vector2(120, 20)
	top.add_child(_dots)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 28)
	_text_label.custom_minimum_size = Vector2(1060, 84)
	_text_label.clip_text = false
	inner.add_child(_text_label)
	# Skip floats in the box's bottom-right corner so two lines of text never push the box past
	# the frame (the box stays 504-692 whatever the line length).
	var skip := UIBuilder.button(self, UIBuilder.t("→ Skip"), 16)
	skip.name = "SkipButton"
	skip.size = Vector2(150, 34)
	skip.position = Vector2(UITheme.FRAME.x - BOX_LEFT - 18.0 - 150.0, BOX_BOTTOM - 18.0 - 34.0)
	skip.pressed.connect(func() -> void: _finish(true))
	_show_line()


## Small capital tag above the title, from the dialogue id.
static func scene_tag(data: Resource) -> String:
	var id := String(data.id) if data != null else ""
	if id.begins_with("dlg_bond_"):
		return UIBuilder.t("BOND SCENE")
	if id.begins_with("dlg_aftermath") or id.begins_with("aftermath_"):
		return UIBuilder.t("AFTERMATH")
	if id.begins_with("dlg_bad_ending"):
		return UIBuilder.t("ENDING")
	return UIBuilder.t("STORY")


## The scene's display name (data), else nothing - the box already shows who speaks.
static func scene_title(data: Resource) -> String:
	return String(data.display_name) if data != null and "display_name" in data else ""


## "●○○" for short scenes, "3 / 12" for long ones, nothing for a single line.
static func progress_text(index: int, total: int) -> String:
	if total <= 1:
		return ""
	if total <= 8:
		var s := ""
		for i in total:
			s += "●" if i == index else "○"
		return s
	return "%d / %d" % [index + 1, total]


## Shows the line portrait when the asset exists; an empty or missing file leaves the
## placeholder rendering untouched (nothing crashes, content can arrive later).
func _show_portrait(path: String) -> void:
	if _portrait_rect != null:
		_portrait_rect.queue_free()
		_portrait_rect = null
	if path == "" or not FileAccess.file_exists(path.replace("res://", ProjectSettings.globalize_path("res://"))):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	_portrait_rect = TextureRect.new()
	_portrait_rect.texture = tex
	_portrait_rect.custom_minimum_size = Vector2(260, 300)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_portrait_rect)
	move_child(_portrait_rect, 1)   # above the backdrop, under the box and the title
	_portrait_rect.position = Vector2(BOX_LEFT + 20.0, BOX_TOP - 300.0)


var _portrait_rect: TextureRect = null


func _show_line() -> void:
	if _index >= _lines.size():
		_finish(false)
		return
	var line: Dictionary = _lines[_index]
	# D09: a line may set a story flag and/or show a portrait beside the text box. The flag
	# is written straight into GameState story_flags (saved with the campaign); a missing
	# portrait asset simply renders without the picture (placeholder art pipeline).
	var flag_key := String(line.get("set_flag", ""))
	if flag_key != "":
		GameState.story_flags[flag_key] = true
	_show_portrait(String(line.get("portrait", "")))
	_name_label.text = String(line.get("speaker", "")).to_upper()
	_text_label.text = String(line.get("text", ""))
	_dots.text = progress_text(_index, _lines.size())


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


## Page dots drawn as circles (the font's ● and ○ glyphs differ in size); past 8 lines the
## same `text` is "n / N" and is printed instead.
class ProgressDots:
	extends Control

	var text := "":
		set(value):
			text = value
			queue_redraw()

	func _draw() -> void:
		if text.contains("/"):
			draw_string(get_theme_default_font(), Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 14, UITheme.MUTED)
			return
		var r := 5.0
		var x := size.x - r - 1.0
		for i in range(text.length() - 1, -1, -1):
			var c := Vector2(x, size.y * 0.5)
			if text[i] == "●":
				draw_circle(c, r, UITheme.ACCENT)
			else:
				draw_arc(c, r - 0.5, 0.0, TAU, 20, UITheme.MUTED, 1.5, true)
			x -= r * 2.0 + 6.0


## Placeholder scene art (UI doc bond / story screens) until real backgrounds exist: a dusk sky,
## a pale moon and two mountain ridges in the theme colours.
class SceneBackdrop:
	extends Control

	func _draw() -> void:
		var w := UITheme.FRAME.x
		var h := UITheme.FRAME.y
		var bands := 12
		for i in bands:
			var c := Color("31505b").lerp(UITheme.BG, float(i) / float(bands - 1))
			draw_rect(Rect2(0, h * i / bands, w, h / bands + 1), c)
		draw_circle(Vector2(w * 0.6, h * 0.36), 46.0, Color(0.85, 0.88, 0.82, 0.14))
		draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.78), Vector2(w * 0.18, h * 0.6), Vector2(w * 0.34, h * 0.72), Vector2(w * 0.5, h * 0.55), Vector2(w * 0.72, h * 0.74), Vector2(w * 0.9, h * 0.62), Vector2(w, h * 0.7), Vector2(w, h), Vector2(0, h)]), Color("1d3a40"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.88), Vector2(w * 0.25, h * 0.76), Vector2(w * 0.45, h * 0.86), Vector2(w * 0.66, h * 0.74), Vector2(w, h * 0.86), Vector2(w, h), Vector2(0, h)]), Color("142c31"))
