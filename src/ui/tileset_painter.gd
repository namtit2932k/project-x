extends RefCounted
class_name TilesetPainter
## Draws one map cell from the placeholder tileset (AGENTS.md "Placeholder tileset"), shared by
## the battle map and the prep map preview. Returns false when there is nothing to draw (no
## tileset data, the texture is not installed, or the terrain has no tiles) so the caller can
## fall back to its flat colour.

const TILESET_PATH := "res://data/tilesets/placeholder_tileset.tres"

static var _loaded := false
static var _data: TilesetData = null
static var _texture: Texture2D = null


static func available() -> bool:
	_ensure_loaded()
	return _data != null and _texture != null


static func data() -> TilesetData:
	_ensure_loaded()
	return _data


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not ResourceLoader.exists(TILESET_PATH):
		return
	_data = load(TILESET_PATH) as TilesetData
	if _data != null and _data.texture_path != "" and ResourceLoader.exists(_data.texture_path):
		_texture = load(_data.texture_path) as Texture2D


## Fixed per-cell choice among n variants (same cell -> same tile every frame).
static func variant(cell: Vector2i, n: int, salt: int = 0) -> int:
	if n <= 1:
		return 0
	var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	return absi(h) % n


static func draw_cell(canvas: CanvasItem, rect: Rect2, terrain: String, cell: Vector2i) -> bool:
	if not available():
		return false
	var spec: Dictionary = _data.terrain_tiles.get(terrain, {})
	var bases: Array = spec.get("base", [])
	if bases.is_empty():
		return false
	var size := float(_data.tile_size)
	var base: Vector2i = bases[variant(cell, bases.size())]
	canvas.draw_texture_rect_region(_texture, rect, Rect2(Vector2(base) * size, Vector2(size, size)))
	var overlays: Array = spec.get("overlay", [])
	if not overlays.is_empty():
		var over: Vector2i = overlays[variant(cell, overlays.size(), 1)]
		canvas.draw_texture_rect_region(_texture, rect, Rect2(Vector2(over) * size, Vector2(size, size)))
	if spec.has("tint"):
		canvas.draw_rect(rect, spec["tint"])
	return true
