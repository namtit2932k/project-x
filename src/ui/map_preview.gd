extends Control
class_name MapPreview
## F-UI step 3 (UI doc prep screen "Xem trước bản đồ"): a small read-only drawing of the map -
## terrain, deploy tiles (filled = taken by a picked unit, hollow = free), enemies, NPCs and the
## objective markers the battle will show. Built from the map data only (a throwaway state).

var map: Resource = null
var picked: int = 0
var _state: BattleState = null
var _markers: Array = []
var cell: float = 24.0


func setup(p_map: Resource, p_picked: int) -> void:
	map = p_map
	picked = p_picked
	_state = BattleState.new()
	_state.setup(map, {}, 1)
	_markers.clear()
	for cfg in _state.objectives_config:
		var obj := ObjectiveBase.create(cfg)
		if obj != null:
			_markers.append_array(obj.markers(_state))
	queue_redraw()


func set_picked(n: int) -> void:
	picked = n
	queue_redraw()


func _draw() -> void:
	if _state == null:
		return
	cell = floorf(minf(size.x / float(_state.width), size.y / float(_state.height)))
	var origin := Vector2((size.x - cell * _state.width) / 2.0, (size.y - cell * _state.height) / 2.0)
	for y in _state.height:
		for x in _state.width:
			var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			draw_rect(r, BattleMapView.TERRAIN_COLORS.get(_state.terrain_at(Vector2i(x, y)), Color.MAGENTA).darkened(0.25))
			draw_rect(r, Color(0, 0, 0, 0.35), false, 1.0)
	for m in _markers:
		var kind := String(m.get("kind", ""))
		var color: Color = BattleMapView.MARKER_COLORS.get(kind, UITheme.ACCENT)
		if m.has("rect"):
			var rr: Rect2i = m["rect"]
			draw_rect(Rect2(origin + Vector2(rr.position) * cell, Vector2(rr.size) * cell), Color(color, 0.3))
		elif m.has("cell"):
			var c: Vector2i = m["cell"]
			draw_rect(Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)).grow(-2), color, false, 2.0)
	var deploy: Array = map.deploy_cells
	for i in deploy.size():
		var center := origin + (Vector2(deploy[i]) + Vector2(0.5, 0.5)) * cell
		if i < picked:
			draw_circle(center, cell * 0.22, Color("dff3ec"))
		else:
			draw_arc(center, cell * 0.22, 0, TAU, 16, Color("dff3ec"), 1.5)
	for u in _state.units.values():
		var dot := Color(0.85, 0.3, 0.3) if u.side == "enemy" else Color(0.95, 0.8, 0.25)
		draw_circle(origin + (Vector2(u.pos) + Vector2(0.5, 0.5)) * cell, cell * 0.22, dot)
