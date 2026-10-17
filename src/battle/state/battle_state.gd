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
var exp_gained: Dictionary = {}          # unit_id -> exp earned this battle (player side only, D08)
var level_ups: Array = []                # [{unit_id, level, gains:{stat:+n}}] for post-battle display

var reconcile_state: Dictionary = {}     # faction_id -> {kills:int, events:Array[String], evaluated:bool, persuaded:bool}
var npc_unit_ids: Array = []             # escort-style NPC actors of this map
var item_ground: Dictionary = {}         # {unit_id? no, "x,y" -> item_id}

var rng_seed: int = 0
var _rng := RandomNumberGenerator.new()


func rng() -> RandomNumberGenerator:
	return _rng


## Recursive copy: snapshot/restore must never share nested containers (rewind of
## counters, reconcile kills and bond points relies on isolated copies).
static func _deep_copy(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _deep_copy(v[k])
		return out
	if v is Array:
		var arr := []
		for item: Variant in v:
			arr.append(_deep_copy(item))
		return arr
	return v


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
	# Units: control side comes from the placement source, not from faction ids.
	units.clear()
	_deploy_map_units(p_map, "enemy", p_map.enemy_placements)
	_deploy_map_units(p_map, "npc", p_map.npc_placements)
	for unit_id in deploy:
		var ud := DataRegistry.get_unit(String(unit_id))
		var cell: Vector2i = deploy[unit_id]
		if ud != null and can_place(cell):
			var u := UnitState.from_data(ud, cell, GameState.roster[unit_id].level if GameState.roster.has(unit_id) else -1)
			u.side = "player"
			units[String(unit_id)] = u
	# Items on ground
	for item in p_map.item_placements:
		var cell2: Vector2i = item.cell
		item_ground["%d,%d" % [cell2.x, cell2.y]] = String(item.item_id)
	# Reconcile tracking is for remnant factions only (remnant_id set): kills of the player's
	# own Empire/Kingdom units must never count toward a persuade threshold.
	reconcile_state.clear()
	var seen := {}
	for u in units.values():
		if u.faction_id in seen:
			continue
		seen[u.faction_id] = true
		var f := DataRegistry.get_faction(String(u.faction_id))
		if f != null and String(f.remnant_id) != "":
			reconcile_state[String(u.faction_id)] = {"kills": 0, "events": [], "evaluated": false, "persuaded": false}


func _deploy_map_units(p_map: Resource, side: String, placements: Array) -> void:
	for placement in placements:
		var ud := DataRegistry.get_unit(String(placement.unit_id))
		if ud == null:
			push_warning("BattleState: unknown unit %s in map %s" % [placement.unit_id, p_map.id])
			continue
		var cell: Vector2i = placement.cell
		if can_place(cell):
			var u := UnitState.from_data(ud, cell, -1)
			u.side = side
			# faction_override lets a map place a unit on a different lore faction (e.g. an
			# empire defector fighting for the rebels) without a duplicate unit entry.
			if placement.get("faction_override", "") != "":
				u.faction_id = String(placement.faction_override)
			units[String(placement.unit_id)] = u


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


## Grants exp to a player-side unit (D08) and records the battle-wide total for the
## post-battle screen. Snapshot restore simply overwrites both containers.
func exp_gained_set(unit_id: String, amount: int) -> void:
	if not units.has(unit_id):
		return
	var u: UnitState = units[unit_id]
	u.exp += amount
	if amount > 0:
		exp_gained[unit_id] = int(exp_gained.get(unit_id, 0)) + amount


func alive_units() -> Array:
	return units.values().filter(func(u: UnitState) -> bool: return u.alive)


func units_of_faction(faction_id: String) -> Array:
	return units.values().filter(func(u: UnitState) -> bool: return u.alive and u.faction_id == faction_id)


func units_of_side(side: String) -> Array:
	return units.values().filter(func(u: UnitState) -> bool: return u.alive and u.side == side)


## True when the unit acts on the player side (mixed squads: any faction, side == "player").
func is_player_side(unit: UnitState) -> bool:
	return unit.side == "player"


func protagonist() -> UnitState:
	for u in units.values():
		if u.is_protagonist:
			return u
	return null


## All campaign-critical units on this map (D02): the protagonist plus every must_survive
## flag; the death of any one of them ends the battle immediately (protagonist_death_loses).
func critical_units() -> Array:
	return units.values().filter(func(u: UnitState) -> bool: return u.is_protagonist or u.must_survive)


## Snapshot serialization keeps positions, HP, turn, phase, items, objectives, bond and
## reconcile state so rewind restores a truthful mid-battle point.
func to_dict() -> Dictionary:
	var units_dict := {}
	for u in units.values():
		units_dict[u.id] = u.to_dict()
	# Nested containers are copied: a stored snapshot must never mirror live state.
	return {
		"turn": turn, "phase": phase, "battle_over": _deep_copy(battle_over),
		"objective_counters": _deep_copy(objective_counters),
		"units": _deep_copy(units_dict),
		"bond_points": _deep_copy(bond_points),
		"exp_gained": _deep_copy(exp_gained),
		"level_ups": _deep_copy(level_ups),
		"reconcile_state": _deep_copy(reconcile_state),
		"item_ground": _deep_copy(item_ground),
		"rng_seed": rng_seed,
	}


func from_dict(d: Dictionary) -> void:
	turn = int(d.get("turn", turn))
	phase = int(d.get("phase", phase))
	battle_over = _deep_copy(d.get("battle_over", {}))
	objective_counters = _deep_copy(d.get("objective_counters", {}))
	bond_points = _deep_copy(d.get("bond_points", {}))
	exp_gained = _deep_copy(d.get("exp_gained", {}))
	level_ups = _deep_copy(d.get("level_ups", []))
	reconcile_state = _deep_copy(d.get("reconcile_state", {}))
	item_ground = _deep_copy(d.get("item_ground", {}))
	# RNG state is NOT snapshot-restored (D04/N04): a rewind continues the same random
	# sequence, so replaying the same actions after a rewind gives different rolls.
	var seeds := int(d.get("rng_seed", rng_seed))
	rng_seed = seeds
	var units_dict: Dictionary = d.get("units", {})
	for unit_id in units_dict:
		if units.has(unit_id):
			units[unit_id].from_dict(units_dict[unit_id])
