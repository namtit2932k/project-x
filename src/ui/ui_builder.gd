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
static func fill_screen(screen: Control) -> void:
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not (screen.get_parent() is Control):
		screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
		screen.position = Vector2.ZERO
		screen.size = screen.get_viewport_rect().size
