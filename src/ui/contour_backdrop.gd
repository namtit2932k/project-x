extends Control
class_name ContourBackdrop
## F-UI step 6: the results / end-of-run background of the UI doc - faint grid, contour lines on
## the left two thirds, a dashed route with two waypoint rings. Drawn in code until art exists.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := UITheme.FRAME.x
	var h := UITheme.FRAME.y
	draw_rect(Rect2(0, 0, w, h), UITheme.BG)
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color(0, 0, 0, 0.18))
	var grid := Color(1, 1, 1, 0.025)
	for x in range(0, int(w), 40):
		draw_line(Vector2(x, 0), Vector2(x, h), grid)
	for y in range(0, int(h), 40):
		draw_line(Vector2(0, y), Vector2(w, y), grid)
	var line := Color(UITheme.MUTED, 0.16)
	for k in 11:
		var pts := PackedVector2Array()
		for i in 86:
			var x := float(i) * 10.0
			pts.append(Vector2(x, 160.0 + k * 34.0 + 38.0 * sin(x / 150.0 + k * 0.33) + 16.0 * sin(x / 70.0 + k * 0.9)))
		draw_polyline(pts, line, 1.2, true)
	var route := Color(UITheme.ACCENT, 0.4)
	draw_dashed_line(Vector2(280, 0), Vector2(612, h), route, 1.5, 9.0)
	for c in [Vector2(333, 173), Vector2(563, 597)]:
		draw_arc(c, 36.0, 0.0, TAU, 40, Color(UITheme.MUTED, 0.3), 1.0, true)
		draw_arc(c, 22.0, 0.0, TAU, 32, Color(UITheme.MUTED, 0.3), 1.0, true)
		draw_circle(c, 5.0, Color(UITheme.ACCENT, 0.8))
