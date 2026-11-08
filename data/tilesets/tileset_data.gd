extends Resource
class_name TilesetData
## Placeholder map art: which region of a tileset texture each terrain draws (AGENTS.md
## "Placeholder tileset"). Coordinates are in tiles of `tile_size` px.

@export var id: String = ""
## Texture under res://; when it is missing the views draw the flat terrain colours.
@export var texture_path: String = ""
@export var tile_size: int = 16
## terrain id -> {"base": [Vector2i, ...], "overlay": [Vector2i, ...] (optional), "tint": Color (optional)}.
## One base (and one overlay) is picked per cell by a fixed hash, so the map never flickers.
@export var terrain_tiles: Dictionary = {}
