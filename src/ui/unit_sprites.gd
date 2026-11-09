extends RefCounted
class_name UnitSprites
## Draws a unit's idle sprite from the placeholder sprite set (AGENTS.md "Placeholder unit
## sprites"). Returns false when nothing can be drawn (no data, sheet not installed) so the map
## falls back to its letter block.

const SET_PATH := "res://data/tilesets/unit_sprites.tres"
const ACTED_TINT := Color(0.45, 0.45, 0.45, 1.0)

static var _loaded := false
static var _set: UnitSpriteSet = null
static var _textures := {}   # path -> Texture2D or null


static func data() -> UnitSpriteSet:
	if not _loaded:
		_loaded = true
		if ResourceLoader.exists(SET_PATH):
			_set = load(SET_PATH) as UnitSpriteSet
	return _set


## Full res:// path of the sheet a class uses on a side ("" when there is no data).
static func sheet_path(class_id: String, side: String) -> String:
	var s := data()
	if s == null:
		return ""
	var pattern := String(s.class_sheets.get(class_id, s.fallback_sheet))
	var color := String(s.side_colors.get(side, s.side_colors.get("enemy", "Red")))
	return s.sheet_dir.path_join(pattern.replace("{color}", color))


static func texture_for(class_id: String, side: String) -> Texture2D:
	var path := sheet_path(class_id, side)
	if path == "":
		return null
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[path]


## Idle frame index at a given time (ms), the same for every unit so the squad breathes together.
static func idle_frame(msec: int) -> int:
	var s := data()
	if s == null or s.idle_frames <= 1:
		return 0
	return int(float(msec) / 1000.0 / maxf(s.frame_time, 0.01)) % s.idle_frames


## Draws the sprite centred on `center` for a cell of `cell` px (in the canvas' current transform).
static func draw_unit(canvas: CanvasItem, center: Vector2, cell: float, u: UnitState) -> bool:
	var tex := texture_for(u.class_id, u.side)
	if tex == null:
		return false
	var s := data()
	var fs := float(s.frame_size)
	var src := Rect2(Vector2(idle_frame(Time.get_ticks_msec()) * fs, s.idle_row * fs), Vector2(fs, fs))
	var size := cell * s.draw_scale
	# Feet near the bottom of the tile: the sheet leaves empty space above the figure.
	var dest := Rect2(center - Vector2(size / 2.0, size * 0.62), Vector2(size, size))
	if u.side == "enemy":
		dest.size.x = -size   # mirrored: faces the other way (Godot flips in place for a negative width)
	var tint := ACTED_TINT if (u.acted and u.side == "player") else Color.WHITE
	canvas.draw_texture_rect_region(tex, dest, src, tint)
	return true
