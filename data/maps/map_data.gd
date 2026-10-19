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
@export var turn_limit: int = 0                       # 0 = unlimited; >0 = running out loses (D12)
## Win/lose priority when both fire on the same check: "win" or "lose" (TBD common rule).
@export var result_priority: String = "lose"

## ---- T2.4 additions (GDD/demo parity; all data-only, no per-chapter code) ----
## Deploy cap per map (1-10, never above deploy_cells count; validator enforces).
@export var map_deploy_cap: int = 6
## Required turn_par (GDD-Map §2, §7): always set, validator rejects a map without one.
@export var turn_par: int = 6
## Deploy tiles players may place units on during prep (C3: players place units themselves).
## Empty = fall back to deploy_cells placement behavior for the old campaign layers.
@export var deploy_tiles: Array[Vector2i] = []
## A single main objective type: "Elimination|Escort|Protect|Retrieve|Seize" per GDD-Map, or the
## legacy "eliminate|escort|defend|retrieve|capture|evacuate" vocabulary of the old layers.
## Keep using the objectives[] plugin configs; this field is metadata for prep UI/validation.
@export var objective_type: String = ""
@export var objective_text: String = ""
## Side texts shown in prep/battle HUD (placeholder Vietnamese is fine; final copy later).
@export var hint_lines: Array[String] = []
## Per reconcile outcome post-battle dialogue lines: {Persuaded: [...], Unpersuadable: [...], ...}
@export var aftermath_lines: Dictionary = {}
## Map-local remnant faction config (demo parity): {id, name, prior_kills, kill_threshold,
## persuasion_condition{type, unit_id}, behavior_tag}.
@export var faction: Dictionary = {}
## Boss/leader unit instance id used by Escort/persuasion objectives (may be empty).
@export var key_unit_id: String = ""
## Village tiles: [{cell: Vector2i, gold_amount: int, item_id: String}]; unclaimed -> claimed (visit)
## or destroyed (enemy steps on it). Terrain stays Village either way.
@export var villages: Array[Dictionary] = []
## Persuade-pressure display tuning for this map (hidden numbers stay in faction data).
@export var persuade_pressure: Dictionary = {"enabled": false}
## Map-local bond pairs for parity layers: [{a: unit_id, b: unit_id, level: int}].
@export var bonds: Array[Dictionary] = []


## Derived map size from terrain rows (no separate width/height fields to drift out of sync).
func map_width() -> int:
	return String(terrain_rows[0]).length() if terrain_rows.size() > 0 else 0


func map_height() -> int:
	return terrain_rows.size()

## ---- objective params (T2.4; engine reads them in W5 across all five GDD types) ----
## Escort variants (exclusive): reach a goal tile, or stay alive for N enemy phases.
@export var escort_unit_id: String = ""
@export var escort_goal: Vector2i = Vector2i(-1, -1)
@export var escort_turns_required: int = 0
## Protect (unit): the target unit must live; survive_enemy_phases counts enemy phases.
@export var protect_unit_id: String = ""
@export var protect_zone: Rect2i = Rect2i()
@export var survive_enemy_phases: int = 0
## Retrieve: item sits on item_tile; holder must reach return_tile (exclusive cells).
@export var item_tile: Vector2i = Vector2i(-1, -1)
@export var return_tile: Vector2i = Vector2i(-1, -1)
## Seize: hold control_point through hold_enemy_phases consecutive enemy phases.
@export var control_point: Vector2i = Vector2i(-1, -1)
@export var hold_enemy_phases: int = 0
