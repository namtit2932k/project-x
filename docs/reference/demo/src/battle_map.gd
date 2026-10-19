class_name BattleMap
extends RefCounted
## Battle/Map System — map load-time validation (Story 001: F-BM1, AC-BM1/2/3)
## and the ADR-0005 terrain lookup primitives shared by Story 003 (Tile
## Visibility) and Story 004 (Path Legality). reachable_tiles()/path_legal()/
## tile_visibility_state() are those stories' scope — not implemented here.
##
## Plain instantiable class, not an autoload — per this project's own
## dependency-injection-over-singletons standard. A production composition
## root decides where the shared instance lives; this class stays testable
## in isolation either way.

## MAX_DEPLOY_CAP is NOT defined here as a const — per Unit/Roster Story 004
## (ADR-0017: Tunable Constant File Format), it is a tuning constant owned by
## Unit/Roster System, loaded from res://data/tuning/unit_roster.json, never
## a hardcoded GDScript const literal. Callers supply it as a parameter to
## map_deploy_cap_valid()/validate_map_load() below; the production wiring
## (once Story 004 exists) is the composition root's job, not this file's.
const TERRAIN_CATALOG_PATH := "res://data/terrain_types.json"

## terrain_type (String) -> record Dictionary (ADR-0003 convention)
var terrain_catalog: Dictionary = {}


## Loads and validates the terrain-type catalog (ADR-0003 + ADR-0004 pattern).
## Fatal on any malformed record — this is authored content, not player input.
func load_terrain_catalog(path: String = TERRAIN_CATALOG_PATH) -> bool:
	var context := "Battle/Map: terrain catalog"
	var parsed: Variant = CatalogLoader.read_array(path, context)
	if parsed == null:
		return false
	var required_fields := ["terrain_type", "move_cost", "passable", "combat_modifier",
		"vision_stand_modifier", "vision_viewed_modifier", "blocks_line_of_sight"]
	var seen: Dictionary = {}
	for record in parsed:
		if not record is Dictionary:
			Validate.fatal(context, "each record must be an object")
			return false
		for field in required_fields:
			Validate.require_field(record, field, context)
			if not record.has(field):
				return false  # Validate.fatal() only SCHEDULES quit() — must return ourselves
		var terrain_type: String = record.get("terrain_type", "")
		Validate.require_unique(terrain_type, seen, context)
		if seen.has(terrain_type):
			return false
		seen[terrain_type] = true
		terrain_catalog[terrain_type] = _normalized_terrain_record(record)
	return true


## JSON.parse_string() returns every number as float — normalize the
## int-typed fields so callers get the types the GDD actually specifies
## (move_cost, combat_modifier, vision_stand_modifier, vision_viewed_modifier
## are all ints), rather than leaking JSON's float-by-default representation.
func _normalized_terrain_record(record: Dictionary) -> Dictionary:
	var normalized: Dictionary = record.duplicate()
	for field in ["move_cost", "combat_modifier", "vision_stand_modifier", "vision_viewed_modifier"]:
		if normalized.has(field):
			normalized[field] = int(normalized[field])
	return normalized


## ADR-0005 shared primitive — resolves a tile's terrain-type id from its
## placed cell on the given Terrain TileMapLayer. Empty string for an
## off-map/empty cell (caller treats as impassable).
func terrain_type_at(coords: Vector2i, terrain_layer: TileMapLayer) -> String:
	var tile_data := terrain_layer.get_cell_tile_data(coords)
	if tile_data == null:
		return ""
	return str(tile_data.get_custom_data("terrain_type"))


## ADR-0005 shared primitive — looks up the catalog record for a terrain
## type. Empty Dictionary for an unknown type.
func get_terrain_record(terrain_type: String) -> Dictionary:
	return terrain_catalog.get(terrain_type, {})


## F-BM1 pure predicate (AC-BM1/AC-BM2) — testable without routing through
## Validate.fatal(). deploy_tile_count is counted at load time, never
## authored separately. max_deploy_cap is Unit/Roster's tuning constant
## (ADR-0017, res://data/tuning/unit_roster.json) — supplied by the caller,
## never hardcoded here.
func map_deploy_cap_valid(map_deploy_cap: int, deploy_tile_count: int, max_deploy_cap: int) -> bool:
	return map_deploy_cap >= 1 and map_deploy_cap <= deploy_tile_count and map_deploy_cap <= max_deploy_cap


## AC-BM3 pure predicate — every deploy tile must sit on passable terrain.
## Returns the offending tile coordinates (empty = every deploy tile legal).
func impassable_deploy_tiles(deploy_tiles: Array[Vector2i], terrain_layer: TileMapLayer) -> Array[Vector2i]:
	var offenders: Array[Vector2i] = []
	for tile in deploy_tiles:
		var record := get_terrain_record(terrain_type_at(tile, terrain_layer))
		if record.is_empty() or not record.get("passable", false):
			offenders.append(tile)
	return offenders


## Fail-loud map-load gate (F-BM1 + AC-BM3) — the real entry point downstream
## stories call. Its failing branches call Validate.fatal() and are
## deliberately NOT exercised by the automated test (ADR-0004 Implementation
## Guidelines: tests must exercise the validity predicates directly, never a
## path that can reach fatal() and kill the test runner).
func validate_map_load(map_id: String, map_deploy_cap: int, deploy_tiles: Array[Vector2i], terrain_layer: TileMapLayer, max_deploy_cap: int) -> bool:
	var context := "Battle/Map: %s" % map_id
	if not map_deploy_cap_valid(map_deploy_cap, deploy_tiles.size(), max_deploy_cap):
		Validate.fatal(context, "map_deploy_cap=%s invalid for deploy_tile_count=%s, max_deploy_cap=%s" % [map_deploy_cap, deploy_tiles.size(), max_deploy_cap])
		return false
	var offenders := impassable_deploy_tiles(deploy_tiles, terrain_layer)
	if not offenders.is_empty():
		Validate.fatal(context, "deploy tile(s) on impassable terrain: %s" % [offenders])
		return false
	return true
