extends Resource
class_name UnitSpriteSet
## Placeholder unit art (AGENTS.md "Placeholder unit sprites"): which sprite sheet each class
## draws on the battle map, and which frames make the idle animation.

@export var id: String = ""
## Folder under res:// that holds the sheets; when a sheet is missing the map draws the old block.
@export var sheet_dir: String = ""
@export var frame_size: int = 32
@export var idle_row: int = 0
@export var idle_frames: int = 4
@export var frame_time: float = 0.18
## Control side -> the colour word used in the sheet names ("player" -> "Blue").
@export var side_colors: Dictionary = {}
## Class id -> sheet path inside sheet_dir, "{color}" replaced by the side colour.
@export var class_sheets: Dictionary = {}
@export var fallback_sheet: String = ""
## Draw box relative to the cell (1.0 = one cell); sprites are drawn a little larger than the tile.
@export var draw_scale: float = 1.4
