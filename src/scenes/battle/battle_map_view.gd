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

var state: BattleState = null
var player_sides: Array = []
var move_cells: Dictionary = {}
var attack_cells: Dictionary = {}
var target_cells: Dictionary = {}
var cursor_cell := Vector2i(-1, -1)
var origin := Vector2.ZERO


func set_state(p_state: BattleState, p_player_sides: Array) -> void:
	state = p_state
	player_sides = p_player_sides
	origin = Vector2((1920.0 - p_state.width * CELL) / 2.0, (1080.0 - p_state.height * CELL) / 2.0)


func set_overlays(p_move: Dictionary, p_attack: Dictionary, p_targets: Dictionary) -> void:
	move_cells = p_move
	attack_cells = p_attack
	target_cells = p_targets
	queue_redraw()


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
	# Cursor ring
	if cursor_cell.x >= 0 and state.in_bounds(cursor_cell):
		var c := cell_to_global(cursor_cell)
		draw_rect(Rect2(c - Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL)), CURSOR_COLOR, false, 3)
