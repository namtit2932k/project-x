extends RefCounted
class_name UIBuilder
## Minimal code-built UI helpers so placeholder screens stay small and consistent.


## I18N: UI text in the current language. The key is the English source text (also the
## fallback); the translations live in data/i18n/strings.csv. Usable from static code too.
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func label(parent: Control, text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


static func button(parent: Control, text: String, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	parent.add_child(b)
	return b


static func panel(parent: Control, x: float, y: float, w: float, h: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2(x, y)
	p.custom_minimum_size = Vector2(w, h)
	parent.add_child(p)
	return p


static func vbox(parent: Control, separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	parent.add_child(v)
	return v


## Full-screen dimmed layer that swallows clicks; put a panel inside it for a modal dialog.
static func modal(parent: Control) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	# A screen whose own rect is empty (a Control under a plain Node) would give the layer no
	# size: cover the viewport instead.
	if parent.size.x < 1.0 or parent.size.y < 1.0:
		root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		root.position = -parent.global_position
		root.size = parent.get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	return root


## An opaque panel for modal dialogs (the default panel style is see-through).
static func modal_panel(parent: Control, x: float, y: float, w: float, h: float) -> PanelContainer:
	var p := panel(parent, x, y, w, h)
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.PANEL
	style.set_border_width_all(1)
	style.border_color = UITheme.ACCENT
	style.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", style)
	return p


## F-UI: a modal panel of size w x h centred in the 1280 x 720 frame.
static func centered_modal_panel(parent: Control, w: float, h: float) -> PanelContainer:
	return modal_panel(parent, (UITheme.FRAME.x - w) / 2.0, (UITheme.FRAME.y - h) / 2.0, w, h)


## F-UI: a serif title label (UI doc: 55 px page titles).
static func title(parent: Control, text: String, size: int = 55) -> Label:
	var l := label(parent, text, size)
	l.add_theme_font_override("font", UITheme.title_font())
	return l


## F-UI: the screen background colour of the shared look.
static func background(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg


## F-UI: make a screen root cover the whole frame. Screens live under plain Nodes (Main,
## CanvasLayers, the battle Node2D), where full-rect anchors give a 0 x 0 rect - so the
## background, centred panels and anchored children would collapse. Size it explicitly then.
## A theme set on the root window does not reach Controls below a plain Node either, so such a
## screen root carries the shared theme itself (panel borders / padding, buttons).
static func fill_screen(screen: Control) -> void:
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not (screen.get_parent() is Control):
		if screen.theme == null:
			screen.theme = UITheme.shared()
		screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
		screen.position = Vector2.ZERO
		screen.size = screen.get_viewport_rect().size


## F-UI: small gold capitals tag (card headings, subtitles).
static func tag(parent: Control, text: String, size: int = 13) -> Label:
	var l := label(parent, text.to_upper(), size)
	l.add_theme_color_override("font_color", UITheme.ACCENT)
	return l


## F-UI: muted secondary text.
static func muted(parent: Control, text: String, size: int = 16) -> Label:
	var l := label(parent, text, size)
	l.add_theme_color_override("font_color", UITheme.MUTED)
	return l


## F-UI: the gold-filled main action of a screen (UI doc: "Continue", "Retry", "Main menu").
static func primary_button(parent: Control, text: String, size: int = 16) -> Button:
	var b := button(parent, text, size)
	b.add_theme_stylebox_override("normal", UITheme._box(UITheme.ACCENT, UITheme.ACCENT))
	b.add_theme_stylebox_override("hover", UITheme._box(UITheme.ACCENT.lightened(0.15), UITheme.ACCENT))
	b.add_theme_stylebox_override("focus", UITheme._box(Color(0, 0, 0, 0), UITheme.TEXT))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, UITheme.BG)
	return b


## F-UI step 6: the end-of-run layout of the UI doc (Game Over, bad ending, demo ending) on the
## contour backdrop - serif title, muted lines, a gold tag, then one row of buttons. `buttons` is
## [[text, primary, callable], ...]; returns the column so callers can add notes below.
static func verdict_screen(screen: Control, title_text: String, lines: Array, tag_text: String, buttons: Array) -> VBoxContainer:
	var backdrop := ContourBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.size = UITheme.FRAME
	screen.add_child(backdrop)
	var column := vbox(screen, 10)
	column.name = "VerdictColumn"
	column.position = Vector2(UITheme.MARGIN, 28)
	column.custom_minimum_size = Vector2(UITheme.FRAME.x - 2 * UITheme.MARGIN, 0)
	title(column, title_text, 55)
	for line in lines:
		var l := muted(column, String(line), 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if tag_text != "":
		tag(column, tag_text)
	var row := HBoxContainer.new()
	row.name = "VerdictButtons"
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	for spec in buttons:
		var b := primary_button(row, String(spec[0])) if bool(spec[1]) else button(row, String(spec[0]), 16)
		b.custom_minimum_size = Vector2(maxf(185.0, 16.0 * String(spec[0]).length() * 0.62 + 40.0), 46)
		b.pressed.connect(spec[2])
	return column
