extends Node2D
class_name BattleMapView
## Placeholder renderer: draws the tile grid as colored squares, range overlays and units as
## colored chips with initials + HP bars. Swaps cleanly behind real tileset art later.

const CELL := 48
const TERRAIN_COLORS := {
	"plain": Color(0.42, 0.55, 0.32),
	"road": Color(0.6, 0.54, 0.42),
	"forest": Color(0.24, 0.42, 0.2),
	"mountain": Color(0.46, 0.42, 0.36),
	"water": Color(0.2, 0.36, 0.6),
	"wall": Color(0.12, 0.12, 0.14),
}

const MOVE_COLOR := Color(0.25, 0.5, 1.0, 0.35)
const ATTACK_COLOR := Color(1.0, 0.25, 0.2, 0.3)
const TARGET_COLOR := Color(1.0, 0.5, 0.1, 0.6)
const CURSOR_COLOR := Color(1.0, 0.9, 0.2, 0.9)
## F-OBJ map markers (shape per kind, color per meaning).
const MARKER_COLORS := {
	"zone": Color(0.95, 0.2, 0.2),     # protect zone: keep enemies out
	"exit": Color(0.25, 0.6, 1.0),     # retrieve return area
	"goal": Color(0.3, 0.95, 0.4),     # escort destination
	"point": Color(1.0, 0.8, 0.15),    # seize control point
	"item": Color(1.0, 0.8, 0.15),     # retrieve item on the ground
	"unit": Color(0.3, 1.0, 1.0),      # protected unit / escort NPC / carrier / named target (cyan: stands out on yellow NPCs)
}

var state: BattleState = null
var player_sides: Array = []
var move_cells: Dictionary = {}
var attack_cells: Dictionary = {}
var target_cells: Dictionary = {}
var cursor_cell := Vector2i(-1, -1)
var origin := Vector2.ZERO
## Objective plugins whose markers(state) are drawn every frame (live progress / carrier).
var objectives: Array = []


func set_state(p_state: BattleState, p_player_sides: Array) -> void:
	state = p_state
	player_sides = p_player_sides
	origin = Vector2((1920.0 - p_state.width * CELL) / 2.0, (1080.0 - p_state.height * CELL) / 2.0)


func set_overlays(p_move: Dictionary, p_attack: Dictionary, p_targets: Dictionary) -> void:
	move_cells = p_move
	attack_cells = p_attack
	target_cells = p_targets
	queue_redraw()


func set_objectives(p_objectives: Array) -> void:
	objectives = p_objectives
	queue_redraw()


## All markers of all objectives right now (plain data from the rules side).
func current_markers() -> Array:
	var out: Array = []
	if state == null:
		return out
	for obj in objectives:
		out.append_array(obj.markers(state))
	return out


func set_cursor(cell: Vector2i) -> void:
	cursor_cell = cell
	queue_redraw()


func global_to_cell(global_pos: Vector2) -> Vector2i:
	var local := (global_pos - origin) / float(CELL)
	return Vector2i(floori(local.x), floori(local.y))


func cell_to_global(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell) * float(CELL) + Vector2(CELL, CELL) / 2.0


func _draw() -> void:
	if state == null:
		return
	var font := ThemeDB.fallback_font
	for y in state.height:
		for x in state.width:
			var cell := Vector2i(x, y)
			var rect := Rect2(cell_to_global(cell) - Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL))
			draw_rect(rect, TERRAIN_COLORS.get(state.terrain_at(cell), Color.MAGENTA))
			draw_rect(rect.grow(-1), TERRAIN_COLORS.get(state.terrain_at(cell), Color.MAGENTA).darkened(0.15))
			if move_cells.has(cell):
				draw_rect(rect, MOVE_COLOR, true)
			if attack_cells.has(cell):
				draw_rect(rect, ATTACK_COLOR, true)
			if target_cells.has(cell):
				draw_rect(rect, TARGET_COLOR, true)
	var markers := current_markers()
	_draw_area_markers(markers)
	# Units
	for u in state.alive_units():
		var center := cell_to_global(u.pos)
		# Color by control side: player blue, npc yellow, enemy red (faction is story identity).
		var color := Color(0.85, 0.25, 0.2)
		if u.side == "player":
			color = Color(0.2, 0.55, 0.95)
		elif u.side == "npc":
			color = Color(0.95, 0.8, 0.25)
		var r := Rect2(center - Vector2(16, 16), Vector2(32, 32))
		draw_rect(r, color)
		draw_rect(r, Color(0, 0, 0), false, 2)
		draw_string(font, center + Vector2(-6, 5), u.display_name.substr(0, 2), HORIZONTAL_ALIGNMENT_CENTER, 12, 14, Color.WHITE)
		# HP pips: green over red
		var hp_ratio := float(u.hp) / float(u.max_hp)
		draw_rect(Rect2(center - Vector2(16, 24), Vector2(32 * clampf(hp_ratio, 0.0, 1.0), 4)), Color(0.2, 0.85, 0.3))
		draw_rect(Rect2(center - Vector2(16, 24), Vector2(32, 4)), Color(0.6, 0.2, 0.2), false, 1)
		if u.acted and u.side == "player":
			draw_circle(center, 18.0, Color(0, 0, 0, 0.25))
	_draw_unit_markers(markers)
	_draw_marker_labels(markers, font)
	# Cursor ring
	if cursor_cell.x >= 0 and state.in_bounds(cursor_cell):
		var c := cell_to_global(cursor_cell)
		draw_rect(Rect2(c - Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL)), CURSOR_COLOR, false, 3)


## Zones / exit areas (tinted + outlined), goal / control point tiles, item on the ground.
func _draw_area_markers(markers: Array) -> void:
	for m in markers:
		var kind := String(m.get("kind", ""))
		var color: Color = MARKER_COLORS.get(kind, Color.WHITE)
		match kind:
			"zone", "exit":
				var r: Rect2i = m["rect"]
				var area := Rect2(origin + Vector2(r.position) * CELL, Vector2(r.size) * CELL)
				draw_rect(area, Color(color, 0.18), true)
				draw_rect(area, color, false, 3)
			"goal", "point":
				var c := cell_to_global(m["cell"])
				var tile := Rect2(c - Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL))
				draw_rect(tile, Color(color, 0.3), true)
				draw_rect(tile.grow(-3), color, false, 3)
			"item":
				var ic := cell_to_global(m["cell"])
				var diamond := PackedVector2Array([ic + Vector2(0, -12), ic + Vector2(12, 0), ic + Vector2(0, 12), ic + Vector2(-12, 0)])
				draw_colored_polygon(diamond, color)
				draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color.BLACK, 2)


## Ring around units the objective is about (protect / escort / carrier / named targets).
func _draw_unit_markers(markers: Array) -> void:
	for m in markers:
		if String(m.get("kind", "")) != "unit":
			continue
		var u: UnitState = state.units.get(String(m.get("unit_id", "")), null)
		if u == null or not u.alive:
			continue
		var c := cell_to_global(u.pos)
		draw_arc(c, 22.0, 0.0, TAU, 32, MARKER_COLORS["unit"], 3)


const LABEL_SIZE := 16

## Labels last, in a dark badge, so units standing on a tile never hide them: zones/exits at
## their top-left corner, goal/point tiles just above the tile, unit countdowns below the unit.
func _draw_marker_labels(markers: Array, font: Font) -> void:
	for m in markers:
		var text := String(m.get("text", ""))
		var kind := String(m.get("kind", ""))
		if text == "" or kind == "item" or (kind == "unit" and not text.contains("/")):
			continue
		var anchor := Vector2.ZERO
		match kind:
			"zone", "exit":
				var r: Rect2i = m["rect"]
				anchor = origin + Vector2(r.position) * CELL + Vector2(2, 2)
			"goal", "point":
				anchor = cell_to_global(m["cell"]) - Vector2(CELL / 2.0, CELL / 2.0 + LABEL_SIZE + 6)
			"unit":
				var u: UnitState = state.units.get(String(m.get("unit_id", "")), null)
				if u == null or not u.alive:
					continue
				anchor = cell_to_global(u.pos) + Vector2(-CELL / 2.0, CELL / 2.0 - 2)
		_draw_badge(font, anchor, text, MARKER_COLORS.get(kind, Color.WHITE))


func _draw_badge(font: Font, top_left: Vector2, text: String, color: Color) -> void:
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
	draw_rect(Rect2(top_left, size + Vector2(8, 4)), Color(0, 0, 0, 0.78), true)
	draw_rect(Rect2(top_left, size + Vector2(8, 4)), color, false, 1)
	draw_string(font, top_left + Vector2(4, LABEL_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)
