extends Node2D
class_name BattleMapView
## Placeholder renderer: draws the tile grid as colored squares, range overlays and units as
## colored chips with initials + HP bars. Swaps cleanly behind real tileset art later.

const REF_CELL := 48.0                  # glyph sizes are drawn for this cell size
const MIN_CELL := 40.0
const MAX_CELL := 96.0
## F-UI step 4: live cell size in pixels (set_state fits the map to the 1280 x 720 frame).
var cell_px: float = 48.0
const TERRAIN_COLORS := {
	"plain": Color(0.42, 0.55, 0.32),
	"road": Color(0.6, 0.54, 0.42),
	"forest": Color(0.24, 0.42, 0.2),
	"mountain": Color(0.46, 0.42, 0.36),
	"water": Color(0.2, 0.36, 0.6),
	"wall": Color(0.12, 0.12, 0.14),
	# Terrains of the GDD / demo glyph table that had no colour (they drew magenta).
	"hill": Color(0.55, 0.5, 0.33),
	"cover": Color(0.4, 0.38, 0.36),
	"hazard": Color(0.55, 0.3, 0.25),
	"village": Color(0.72, 0.56, 0.3),
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
## F-BUI Rule 2: union of every enemy's threat range, tinted during the Player Phase.
var threat_cells: Dictionary = {}
const THREAT_COLOR := Color(1.0, 0.45, 0.1, 0.14)
var cursor_cell := Vector2i(-1, -1)
var origin := Vector2.ZERO
## Objective plugins whose markers(state) are drawn every frame (live progress / carrier).
var objectives: Array = []


func set_state(p_state: BattleState, p_player_sides: Array) -> void:
	state = p_state
	player_sides = p_player_sides
	# F-UI step 4: the map fills the frame - the largest whole cell size that fits (40-96 px).
	cell_px = clampf(floorf(minf(UITheme.FRAME.x / float(p_state.width), UITheme.FRAME.y / float(p_state.height))), MIN_CELL, MAX_CELL)
	origin = Vector2((UITheme.FRAME.x - p_state.width * cell_px) / 2.0, (UITheme.FRAME.y - p_state.height * cell_px) / 2.0)


## F-UI step 4 camera: on a map larger than the frame, scroll so `target` sits as close to the
## centre as the map edges allow. A map that fits stays centred.
func focus_cell(target: Vector2i) -> void:
	if state == null:
		return
	var map_px := Vector2(state.width, state.height) * cell_px
	for axis in 2:
		if map_px[axis] <= UITheme.FRAME[axis]:
			origin[axis] = (UITheme.FRAME[axis] - map_px[axis]) / 2.0
		else:
			var want := UITheme.FRAME[axis] / 2.0 - (float(target[axis]) + 0.5) * cell_px
			origin[axis] = clampf(want, UITheme.FRAME[axis] - map_px[axis], 0.0)
	queue_redraw()


func set_overlays(p_move: Dictionary, p_attack: Dictionary, p_targets: Dictionary) -> void:
	move_cells = p_move
	attack_cells = p_attack
	target_cells = p_targets
	queue_redraw()


func set_threat(p_cells: Dictionary) -> void:
	threat_cells = p_cells
	queue_redraw()


## F-BUI1: green above hp_high_band, yellow from hp_mid_band to hp_high_band, red below.
static func hp_band_color(ratio: float) -> Color:
	if ratio > float(DataRegistry.rule("hp_high_band", 0.66)):
		return Color(0.2, 0.85, 0.3)
	if ratio >= float(DataRegistry.rule("hp_mid_band", 0.33)):
		return Color(0.95, 0.8, 0.2)
	return Color(0.9, 0.2, 0.2)


## F-BUI2: at or below hp_blink_band the bar pulses.
static func hp_pulses(ratio: float) -> bool:
	return ratio <= float(DataRegistry.rule("hp_blink_band", 0.25))


func _process(_delta: float) -> void:
	# Only the low-HP pulse animates: redraw while any unit needs it.
	if state == null:
		return
	for u in state.alive_units():
		if hp_pulses(float(u.hp) / float(maxi(u.max_hp, 1))):
			queue_redraw()
			return


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
	var local := (global_pos - origin) / cell_px
	return Vector2i(floori(local.x), floori(local.y))


func cell_to_global(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell) * cell_px + Vector2(cell_px, cell_px) / 2.0


func _draw() -> void:
	if state == null:
		return
	var font := ThemeDB.fallback_font
	for y in state.height:
		for x in state.width:
			var cell := Vector2i(x, y)
			var rect := Rect2(cell_to_global(cell) - Vector2(cell_px, cell_px) / 2.0, Vector2(cell_px, cell_px))
			draw_rect(rect, TERRAIN_COLORS.get(state.terrain_at(cell), Color.MAGENTA))
			draw_rect(rect.grow(-1), TERRAIN_COLORS.get(state.terrain_at(cell), Color.MAGENTA).darkened(0.15))
			if threat_cells.has(cell):
				draw_rect(rect, THREAT_COLOR, true)
			if move_cells.has(cell):
				draw_rect(rect, MOVE_COLOR, true)
			if attack_cells.has(cell):
				draw_rect(rect, ATTACK_COLOR, true)
			if target_cells.has(cell):
				draw_rect(rect, TARGET_COLOR, true)
	# F-ITEM: claimed / destroyed villages are inert - dimmed and crossed out.
	for key in state.villages:
		if String(state.villages[key].get("state", "open")) == "open":
			continue
		var xy := String(key).split(",")
		var vrect := Rect2(cell_to_global(Vector2i(int(xy[0]), int(xy[1]))) - Vector2(cell_px, cell_px) / 2.0, Vector2(cell_px, cell_px))
		draw_rect(vrect, Color(0, 0, 0, 0.45))
		draw_line(vrect.position + Vector2(8, 8), vrect.end - Vector2(8, 8), Color(0.9, 0.9, 0.9, 0.8), 2.0)
		draw_line(Vector2(vrect.end.x - 8, vrect.position.y + 8), Vector2(vrect.position.x + 8, vrect.end.y - 8), Color(0.9, 0.9, 0.9, 0.8), 2.0)
	var markers := current_markers()
	_draw_area_markers(markers)
	# Units
	var unit_scale := cell_px / REF_CELL
	for u in state.alive_units():
		var center := cell_to_global(u.pos)
		# Unit glyphs are drawn for the reference cell and scaled to the live cell size.
		draw_set_transform(center, 0.0, Vector2(unit_scale, unit_scale))
		# Color by control side: player blue, npc yellow, enemy red (faction is story identity).
		var color := Color(0.85, 0.25, 0.2)
		if u.side == "player":
			color = Color(0.2, 0.55, 0.95)
		elif u.side == "npc":
			color = Color(0.95, 0.8, 0.25)
		var r := Rect2(Vector2.ZERO - Vector2(16, 16), Vector2(32, 32))
		draw_rect(r, color)
		draw_rect(r, Color(0, 0, 0), false, 2)
		draw_string(font, Vector2.ZERO + Vector2(-6, 5), u.display_name.substr(0, 2), HORIZONTAL_ALIGNMENT_CENTER, 12, 14, Color.WHITE)
		# F-BUI Rules 3/4: HP bar in its colour band, pulsing at low HP.
		var hp_ratio := float(u.hp) / float(maxi(u.max_hp, 1))
		var bar_color := hp_band_color(hp_ratio)
		if hp_pulses(hp_ratio):
			bar_color.a = 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() / 180.0))
		draw_rect(Rect2(Vector2.ZERO - Vector2(16, 24), Vector2(32, 4)), Color(0.1, 0.1, 0.1, 0.8))
		draw_rect(Rect2(Vector2.ZERO - Vector2(16, 24), Vector2(32 * clampf(hp_ratio, 0.0, 1.0), 4)), bar_color)
		draw_rect(Rect2(Vector2.ZERO - Vector2(16, 24), Vector2(32, 4)), Color(0, 0, 0), false, 1)
		# F-BUI Rule 5: one rank letter per active bond link, under the unit.
		var links := BondSystem.active_partners(state, u)
		for i in links.size():
			var bpos := Vector2.ZERO + Vector2(-16 + i * 12, 18)
			draw_rect(Rect2(bpos, Vector2(11, 11)), Color(0.85, 0.45, 0.9))
			draw_string(font, bpos + Vector2(2, 9), String(links[i]["rank"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		# F-BUI Rule 12: one badge per active item buff (stat, amount, turns left), above the bar.
		var row := 0
		for field in u.active_buffs:
			var buff: Dictionary = u.active_buffs[field]
			var text := "%s+%d (%d)" % [String(field).substr(0, 3), int(buff.get("amount", 0)), int(buff.get("turns_remaining", 0))]
			draw_string(font, Vector2.ZERO + Vector2(-20, -28 - row * 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 1.0, 0.6))
			row += 1
		if u.acted and u.side == "player":
			draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_unit_markers(markers)
	_draw_marker_labels(markers, font)
	# Cursor ring
	if cursor_cell.x >= 0 and state.in_bounds(cursor_cell):
		var c := cell_to_global(cursor_cell)
		draw_rect(Rect2(c - Vector2(cell_px, cell_px) / 2.0, Vector2(cell_px, cell_px)), CURSOR_COLOR, false, 3)


## Zones / exit areas (tinted + outlined), goal / control point tiles, item on the ground.
func _draw_area_markers(markers: Array) -> void:
	for m in markers:
		var kind := String(m.get("kind", ""))
		var color: Color = MARKER_COLORS.get(kind, Color.WHITE)
		match kind:
			"zone", "exit":
				var r: Rect2i = m["rect"]
				var area := Rect2(origin + Vector2(r.position) * cell_px, Vector2(r.size) * cell_px)
				draw_rect(area, Color(color, 0.18), true)
				draw_rect(area, color, false, 3)
			"goal", "point":
				var c := cell_to_global(m["cell"])
				var tile := Rect2(c - Vector2(cell_px, cell_px) / 2.0, Vector2(cell_px, cell_px))
				draw_rect(tile, Color(color, 0.3), true)
				draw_rect(tile.grow(-3), color, false, 3)
			"item":
				var ic := cell_to_global(m["cell"])
				var d := 12.0 * cell_px / REF_CELL
				var diamond := PackedVector2Array([ic + Vector2(0, -d), ic + Vector2(d, 0), ic + Vector2(0, d), ic + Vector2(-d, 0)])
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
		draw_arc(c, 22.0 * cell_px / REF_CELL, 0.0, TAU, 32, MARKER_COLORS["unit"], 3)


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
				anchor = origin + Vector2(r.position) * cell_px + Vector2(2, 2)
			"goal", "point":
				anchor = cell_to_global(m["cell"]) - Vector2(cell_px / 2.0, cell_px / 2.0 + LABEL_SIZE + 6)
			"unit":
				var u: UnitState = state.units.get(String(m.get("unit_id", "")), null)
				if u == null or not u.alive:
					continue
				anchor = cell_to_global(u.pos) + Vector2(-cell_px / 2.0, cell_px / 2.0 - 2)
		_draw_badge(font, anchor, text, MARKER_COLORS.get(kind, Color.WHITE))


func _draw_badge(font: Font, top_left: Vector2, text: String, color: Color) -> void:
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
	draw_rect(Rect2(top_left, size + Vector2(8, 4)), Color(0, 0, 0, 0.78), true)
	draw_rect(Rect2(top_left, size + Vector2(8, 4)), color, false, 1)
	draw_string(font, top_left + Vector2(4, LABEL_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)
