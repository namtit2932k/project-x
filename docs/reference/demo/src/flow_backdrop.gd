extends Control
## Draws the menu contour map and the simple landscape used behind VN dialogue.

var mode: String = "shell"


func _draw() -> void:
	var canvas := size
	if mode == "battle":
		draw_rect(Rect2(Vector2.ZERO, canvas), Color("#07141a"))
		return
	var scenic := mode.begins_with("vn_")
	var top := Color("#0b2228")
	if scenic:
		match mode:
			"vn_signal": top = Color("#55483d")
			"vn_magic": top = Color("#263e5a")
			"vn_ruins": top = Color("#533d3c")
			"vn_peace": top = Color("#344d4b")
			"vn_journey": top = Color("#334a55")
			_: top = Color("#304d54")
	var bottom := Color("#07141a")
	for step in 64:
		var portion := float(step) / 63.0
		var shade := top.lerp(bottom, portion)
		draw_rect(Rect2(0, portion * canvas.y, canvas.x, canvas.y / 63.0 + 2.0), shade)
	if scenic:
		_draw_landscape(canvas)
		_draw_scene_glow(canvas)
	else:
		_draw_map_art(canvas)


func _draw_map_art(canvas: Vector2) -> void:
	for x in range(0, int(canvas.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, canvas.y), Color(0.72, 0.84, 0.8, 0.035), 1.0)
	for y in range(0, int(canvas.y), 40):
		draw_line(Vector2(0, y), Vector2(canvas.x, y), Color(0.72, 0.84, 0.8, 0.035), 1.0)
	var map_width := canvas.x * 0.69
	for band in 11:
		var points := PackedVector2Array()
		for step in 85:
			var x := float(step) / 84.0 * map_width - 35.0
			var y := 145.0 + band * 36.0 + sin(x * 0.010 + band * 0.32) * 50.0 + cos(x * 0.017 + band * 0.6) * 19.0
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.66, 0.84, 0.79, 0.12), 1.2, true)
	var route := PackedVector2Array([Vector2(canvas.x * 0.21, -30), Vector2(canvas.x * 0.26, canvas.y * 0.24), Vector2(canvas.x * 0.36, canvas.y * 0.56), Vector2(canvas.x * 0.44, canvas.y * 0.83), Vector2(canvas.x * 0.49, canvas.y + 30)])
	for index in route.size() - 1:
		var a := route[index]
		var b := route[index + 1]
		var length := a.distance_to(b)
		for dash in int(length / 22.0):
			var from := a.lerp(b, float(dash * 22) / length)
			var to := a.lerp(b, minf(1.0, float(dash * 22 + 10) / length))
			draw_line(from, to, Color(0.88, 0.74, 0.50, 0.28), 2.0)
	for point in [route[1], route[3]]:
		draw_arc(point, 37.0, 0.0, TAU, 40, Color(0.66, 0.84, 0.79, 0.16), 1.0)
		draw_arc(point, 23.0, 0.0, TAU, 40, Color(0.66, 0.84, 0.79, 0.22), 1.0)
		draw_circle(point, 5.0, Color(0.88, 0.74, 0.50, 0.75))


func _draw_landscape(canvas: Vector2) -> void:
	var far := PackedVector2Array([Vector2(0, canvas.y * 0.61), Vector2(canvas.x * 0.12, canvas.y * 0.49), Vector2(canvas.x * 0.23, canvas.y * 0.58), Vector2(canvas.x * 0.34, canvas.y * 0.42), Vector2(canvas.x * 0.47, canvas.y * 0.57), Vector2(canvas.x * 0.61, canvas.y * 0.45), Vector2(canvas.x * 0.77, canvas.y * 0.6), Vector2(canvas.x, canvas.y * 0.48), Vector2(canvas.x, canvas.y), Vector2(0, canvas.y)])
	draw_colored_polygon(far, Color("#294147"))
	var near := PackedVector2Array([Vector2(0, canvas.y * 0.72), Vector2(canvas.x * 0.17, canvas.y * 0.64), Vector2(canvas.x * 0.28, canvas.y * 0.76), Vector2(canvas.x * 0.46, canvas.y * 0.66), Vector2(canvas.x * 0.62, canvas.y * 0.75), Vector2(canvas.x * 0.80, canvas.y * 0.64), Vector2(canvas.x, canvas.y * 0.73), Vector2(canvas.x, canvas.y), Vector2(0, canvas.y)])
	draw_colored_polygon(near, Color("#142b31"))
	draw_circle(Vector2(canvas.x * 0.55, canvas.y * 0.31), 74.0, Color(0.88, 0.82, 0.68, 0.055))
	for line in 9:
		var y := canvas.y * (0.73 + float(line) * 0.036)
		draw_line(Vector2(0, y), Vector2(canvas.x, y + 5), Color(0.04, 0.11, 0.13, 0.22), 2.0)


func _draw_scene_glow(canvas: Vector2) -> void:
	match mode:
		"vn_signal":
			var from := Vector2(canvas.x * 0.15, canvas.y * 0.38)
			var through := Vector2(canvas.x * 0.43, canvas.y * 0.27)
			var end := Vector2(canvas.x * 0.62, canvas.y * 0.40)
			draw_line(from, through, Color(0.96, 0.76, 0.51, 0.6), 2.0)
			draw_line(through, end, Color(0.96, 0.76, 0.51, 0.6), 2.0)
			for point in [from, through, end]:
				draw_circle(point, 6.0, Color(0.96, 0.76, 0.51, 0.7))
		"vn_magic":
			var center := Vector2(canvas.x * 0.79, canvas.y * 0.28)
			draw_arc(center, 85.0, 0, TAU, 64, Color(0.62, 0.81, 0.96, 0.5), 2.0)
			draw_arc(center, 112.0, 0, TAU, 64, Color(0.62, 0.81, 0.96, 0.25), 1.0)
			draw_line(center + Vector2(-120, 0), center + Vector2(120, 0), Color(0.62, 0.81, 0.96, 0.35), 1.0)
		"vn_ruins":
			var points := PackedVector2Array([Vector2(canvas.x * 0.72, canvas.y * 0.54), Vector2(canvas.x * 0.77, canvas.y * 0.62), Vector2(canvas.x * 0.82, canvas.y * 0.49), Vector2(canvas.x * 0.88, canvas.y * 0.60)])
			draw_polyline(points, Color(0.92, 0.58, 0.46, 0.55), 3.0)
		"vn_peace":
			draw_circle(Vector2(canvas.x * 0.54, canvas.y * 0.30), 95.0, Color(0.70, 0.86, 0.70, 0.07))
		"vn_journey":
			var path := PackedVector2Array([Vector2(canvas.x * 0.43, canvas.y), Vector2(canvas.x * 0.48, canvas.y * 0.75), Vector2(canvas.x * 0.56, canvas.y * 0.59), Vector2(canvas.x * 0.62, canvas.y * 0.75), Vector2(canvas.x * 0.69, canvas.y)])
			draw_colored_polygon(path, Color(0.85, 0.75, 0.53, 0.10))
