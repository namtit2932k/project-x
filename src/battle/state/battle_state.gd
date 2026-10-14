extends RefCounted
class_name BattleState
## The single source of truth for one battle. Rules code (commands, resolver, AI, objectives,
## rewind) reads and writes this; scenes only render it and forward input through commands.

const PHASE_PLAYER := 0
const PHASE_ENEMY := 1
const PHASE_NPC := 2

var map: Resource = null                 # MapData
var width: int = 0
var height: int = 0
var terrain: Array = []                  # terrain[String] per cell: terrain_field[y][x] -> String
var units: Dictionary = {}               # unit_id -> UnitState

var turn: int = 1
var phase: int = PHASE_PLAYER
var battle_over: Dictionary = {}         # {status: "win"/"lose", ...} empty while running

var objective_counters: Dictionary = {}  # per-objective scratch counters
var objectives_config: Array = []        # [{type, params}] straight from map data

var bond_points: Dictionary = {}         # pair_id -> points earned this battle
var bond_rank_carry: Dictionary = {}     # pair_id -> rank snapshot from campaign (read-only copy)

var reconcile_state: Dictionary = {}     # faction_id -> {kills:int, events:Array[String], evaluated:bool, persuaded:bool}
var npc_unit_ids: Array = []             # escort-style NPC actors of this map
var item_ground: Dictionary = {}         # {unit_id? no, "x,y" -> item_id}

var rng_seed: int = 0
var _rng := RandomNumberGenerator.new()


func rng() -> RandomNumberGenerator:
	return _rng


func setup(p_map: Resource, deploy: Dictionary, seed_value: int = -1) -> void:
	map = p_map
	rng_seed = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system())
	_rng.seed = rng_seed
	# Terrain grid
	var rows: Array[String] = p_map.terrain_rows
	height = rows.size()
	width = 0
	terrain.clear()
	var glyphs: Dictionary = DataRegistry.rule("terrain_glyphs", {})
	for row in rows:
		width = maxi(width, String(row).length())
	for row in rows:
		var line: Array = []
		for i in width:
			var glyph := String(row)[i] if i < String(row).length() else "."
			line.append(String(glyphs.get(glyph, "plain")))
		terrain.append(line)
	# Objectives config
	objectives_config = []
	for o in p_map.objectives:
		objectives_config.append({"type": String(o.type), "params": o.params})
	# NPC actors (escort style)
	npc_unit_ids.clear()
	for npc in p_map.npc_placements:
		npc_unit_ids.append(String(npc.unit_id))
	# Units
	units.clear()
	_deploy_map_units(p_map, "faction_enemy_spawn", p_map.enemy_placements, PHASE_ENEMY)
	_deploy_map_units(p_map, "faction_npc_spawn", p_map.npc_placements, PHASE_NPC)
	for unit_id in deploy:
		var ud := DataRegistry.get_unit(String(unit_id))
		var cell: Vector2i = deploy[unit_id]
		if ud != null and can_place(cell):
			units[String(unit_id)] = UnitState.from_data(ud, cell, GameState.roster[unit_id].level if GameState.roster.has(unit_id) else -1)
	# Items on ground
	for item in p_map.item_placements:
		var cell2: Vector2i = item.cell
		item_ground["%d,%d" % [cell2.x, cell2.y]] = String(item.item_id)
	# Reconcile state per enemy faction present
	reconcile_state.clear()
	var seen := {}
	for u in units.values():
		if u.faction_id not in seen:
			seen[u.faction_id] = true
	var factions := seen.keys()
	for fid in factions:
		var f := DataRegistry.get_faction(String(fid))
		if f != null and not f.reconcile.is_empty():
			reconcile_state[fid] = {"kills": 0, "events": [], "evaluated": false, "persuaded": false}


func _deploy_map_units(p_map: Resource, _tag: String, placements: Array, _phase: int) -> void:
	for placement in placements:
		var ud := DataRegistry.get_unit(String(placement.unit_id))
		if ud == null:
			push_warning("BattleState: unknown unit %s in map %s" % [placement.unit_id, p_map.id])
			continue
		var cell: Vector2i = placement.cell
		if can_place(cell):
			units[String(placement.unit_id)] = UnitState.from_data(ud, cell, -1)


func can_place(cell: Vector2i) -> bool:
	return in_bounds(cell) and unit_at(cell) == null


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain_at(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return "wall"
	return String(terrain[cell.y][cell.x])


func terrain_def_at(cell: Vector2i) -> int:
	var defs: Dictionary = DataRegistry.rule("terrain_defs", {})
	var def_val = defs.get(terrain_at(cell), {}).get("def_bonus", 0)
	return int(def_val)


func terrain_avoid_at(cell: Vector2i) -> int:
	var defs: Dictionary = DataRegistry.rule("terrain_defs", {})
	var avoid = defs.get(terrain_at(cell), {}).get("avoid_bonus", 0)
	return int(avoid)


func unit_at(cell: Vector2i) -> UnitState:
	for u in units.values():
		if u.alive and u.pos == cell:
			return u
	return null


func alive_units() -> Array:
	return units.values().filter(func(u: UnitState) -> bool: return u.alive)


func units_of_faction(faction_id: String) -> Array:
	return units.values().filter(func(u: UnitState) -> bool: return u.alive and u.faction_id == faction_id)


func protagonist() -> UnitState:
	for u in units.values():
		if u.is_protagonist:
			return u
	return null


## Snapshot serialization keeps positions, HP, turn, phase, items, objectives, bond and
## reconcile state so rewind restores a truthful mid-battle point.
func to_dict() -> Dictionary:
	var units_dict := {}
	for u in units.values():
		units_dict[u.id] = u.to_dict()
	return {
		"turn": turn, "phase": phase, "battle_over": battle_over,
		"objective_counters": objective_counters,
		"units": units_dict,
		"bond_points": bond_points,
		"reconcile_state": reconcile_state,
		"item_ground": item_ground,
		"rng_seed": rng_seed,
	}


func from_dict(d: Dictionary) -> void:
	turn = int(d.get("turn", turn))
	phase = int(d.get("phase", phase))
	battle_over = d.get("battle_over", {})
	objective_counters = d.get("objective_counters", {})
	bond_points = d.get("bond_points", {})
	reconcile_state = d.get("reconcile_state", {})
	item_ground = d.get("item_ground", {})
	var seeds := int(d.get("rng_seed", rng_seed))
	rng_seed = seeds
	_rng.seed = rng_seed
	var units_dict: Dictionary = d.get("units", {})
	for unit_id in units_dict:
		if units.has(unit_id):
			units[unit_id].from_dict(units_dict[unit_id])
