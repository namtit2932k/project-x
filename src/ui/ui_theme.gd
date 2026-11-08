extends RefCounted
class_name UITheme
## F-UI shared look (designer UI document): dark teal background, thin-bordered panels, gold
## accent, serif titles, on the 1280 x 720 frame. Built in code (no binary .tres) and set on the
## root window by Main, so every screen inherits it.

const FRAME := Vector2(1280, 720)
const MARGIN := 48                      # content margin of game-flow screens (UI doc)

const BG := Color("0c1d22")
const PANEL := Color("10262b")
const PANEL_BORDER := Color("2e4a4f")
const ACCENT := Color("d8b46a")
const TEXT := Color("e9e4d4")
const MUTED := Color("8aa0a0")
const SELECTED := Color("2d4a45")


static var _shared: Theme = null


## One Theme instance for every screen (built on first use).
static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	for kind in ["Button", "CheckButton", "OptionButton"]:
		theme.set_color("font_color", kind, TEXT)
		theme.set_color("font_hover_color", kind, ACCENT)
		theme.set_color("font_pressed_color", kind, BG)
		theme.set_color("font_disabled_color", kind, MUTED)
		theme.set_color("font_focus_color", kind, TEXT)
	theme.set_stylebox("normal", "Button", _box(PANEL, PANEL_BORDER))
	theme.set_stylebox("hover", "Button", _box(Color("183338"), ACCENT))
	theme.set_stylebox("pressed", "Button", _box(ACCENT, ACCENT))
	theme.set_stylebox("disabled", "Button", _box(Color("0e1f23"), Color("1f3337")))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT))
	theme.set_stylebox("panel", "PanelContainer", _box(Color(PANEL, 0.96), PANEL_BORDER, 18))
	theme.set_stylebox("panel", "Panel", _box(Color(PANEL, 0.96), PANEL_BORDER, 18))
	theme.set_stylebox("background", "ProgressBar", _box(Color("0a1719"), PANEL_BORDER, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, ACCENT, 0))
	return theme


## Serif display font for titles (system serif until the artist's font arrives).
static func title_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Cambria", "Times New Roman", "Noto Serif", "serif"])
	return f


static func _box(bg: Color, border: Color, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(margin)
	s.content_margin_left = maxi(margin, 12)
	s.content_margin_right = maxi(margin, 12)
	return s
