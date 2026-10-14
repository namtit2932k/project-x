extends Resource
class_name MapData
## Map definition. Objectives are plugin configs ({type, params}); no per-chapter code.
## Side objective (reconcile) comes from faction data, not the map.

@export var id: String = ""
@export var display_name: String = ""
## Ascii rows, one string per row, glyphs defined by RulesConfig.terrain_glyphs.
@export var terrain_rows: Array[String] = []
## Deploy points: player candidates pick cells from this list (prep phase).
@export var deploy_cells: Array[Vector2i] = []
## Pre-placed units: {unit_id, cell, faction_override (optional), ai: bool}
@export var enemy_placements: Array[Dictionary] = []
@export var npc_placements: Array[Dictionary] = []
## Objective configs: [{type: String, params: Dictionary}]
@export var objectives: Array[Dictionary] = []
## Map-specific fail conditions: [{type, params}] — same plugin vocabulary, treated as lose. Validators check; engine reads them in the director before win checks.
@export var fail_conditions: Array[Dictionary] = []
## Event skeleton: [{trigger, conditions, actions[]}] — closed vocabulary validated in tools/; executor engine is a planned step (maps ship empty arrays for now).
@export var events: Array[Dictionary] = []
@export var item_placements: Array[Dictionary] = []   # {item_id, cell}
@export var turn_limit: int = 0                       # 0 = unlimited (TBD per-map)
## Win/lose priority when both fire on the same check: "win" or "lose" (TBD common rule).
@export var result_priority: String = "lose"
