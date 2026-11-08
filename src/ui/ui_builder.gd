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
