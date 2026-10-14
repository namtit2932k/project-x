extends RefCounted
class_name UIBuilder
## Minimal code-built UI helpers so placeholder screens stay small and consistent.


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
