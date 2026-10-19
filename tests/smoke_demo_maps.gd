extends Node
## F6 (DEMO_PARITY_NEXT_STEPS.md): smoke for the six demo example maps. Every map is
## deployed through the real prep sources (chapter deployable list + map deploy cap +
## deploy tiles), then checked against docs/reference/demo/data/battle_demo.json:
## sides count the JSON placements, the two player units carry the demo stats, unit ids
## stay unique and MapData.objective_type matches the scenario JSON.
## Run with: godot --headless --path . res://tests/smoke_demo_maps.tscn
##
## W5/W7 will extend this file with scripted win/lose runs per objective type (the same
## pattern smoke_test_maps.gd uses for the mechanism test maps).

var checks := 0
var failures := 0


func _ready() -> void:
	await run_all()
	print("\nsmoke demo maps: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func run_all() -> void:
	GameState.new_game()
	# F4: the demo campaign is the default; roster = unit_demo_swordsman + unit_demo_knight.
	GameState.build_roster()
	# The scenario JSON is the reference: counts per deployment side and objective types.
	var raw := FileAccess.get_file_as_string("res://docs/reference/demo/data/battle_demo.json")
	var scenario: Variant = JSON.parse_string(raw)
	if not (scenario is Dictionary):
		ok(false, "demo maps: battle_demo.json unparsable")
		return
	var maps: Array = scenario["maps"]
	ok(maps.size() == 6, "demo maps: scenario json ships six maps")
	var catalog: Dictionary = scenario.get("unit_catalog", {})
	for i in maps.size():
		_check_map(int(i) + 1, maps[i], catalog)


## Deploys chapter i through the real data (chapter deployable ids, map deploy cap, tiles)
## and checks the loaded battle against the scenario JSON row.
func _check_map(number: int, scenario_map: Dictionary, catalog: Dictionary) -> void:
	var chapter_id := "chapter_demo_%02d" % number
	var chapter := DataRegistry.get_chapter(chapter_id)
	if chapter == null:
		ok(false, "%s: chapter missing" % chapter_id)
		return
	var map := DataRegistry.get_map(String(chapter.map_id))
	if map == null:
		ok(false, "%s: map missing" % String(chapter.map_id))
		return
	ok(String(map.objective_type) == String(scenario_map.get("objective_type", "")),
			"%s: objective_type matches the scenario json" % chapter_id)
	# Count placements from the scenario JSON, like the importer mirrors them.
	var json_enemy := 0
	var json_npc := 0
	var json_player_cells := 0
	for d: Dictionary in scenario_map.get("deployments", []):
		var side := String(catalog.get(String(d.get("template", "")), {}).get("side", "player"))
		var controllable: bool = bool(catalog.get(String(d.get("template", "")), {}).get("controllable", true))
		if side == "enemy":
			json_enemy += 1
		elif controllable:
			json_player_cells += 1
		else:
			json_npc += 1
	ok(int(map.map_deploy_cap) == int(scenario_map.get("map_deploy_cap", 0)),
			"%s: deploy cap matches the json" % chapter_id)
	ok(int(map.turn_par) == int(scenario_map.get("turn_par", 0)),
			"%s: turn_par matches the json" % chapter_id)
	# Deploy the roster through the prep budget: forced protagonist first (P-07), then the
	# remaining roster, capped by the chapter and map caps, placed on deploy_tiles.
	var deploy := _deploy_players(chapter, map)
	var director := BattleDirector.new()
	director.setup(map, deploy, "normal", 42)
	var state := director.state
	# No duplicate instance ids.
	var ids := {}
	var unique := true
	for u in state.units.values():
		if ids.has(u.id):
			unique = false
			break
		ids[u.id] = true
	ok(unique, "%s: all unit instance ids are unique" % chapter_id)
	var enemy_count := 0
	var npc_count := 0
	var player_count := 0
	for u in state.units.values():
		match u.side:
			"enemy":
				enemy_count += 1
			"npc":
				npc_count += 1
			"player":
				player_count += 1
	ok(enemy_count == json_enemy, "%s: enemy count %d == json %d" % [chapter_id, enemy_count, json_enemy])
	ok(npc_count == json_npc, "%s: npc count %d == json %d" % [chapter_id, npc_count, json_npc])
	ok(player_count == mini(int(map.map_deploy_cap), json_player_cells),
			"%s: player deploy count %d == cap %d" % [chapter_id, player_count, int(map.map_deploy_cap)])
	# F1 acceptance: the demo Swordsman/Knights carry the exact scenario stats.
	var swordsman: UnitState = state.units.get("unit_demo_swordsman", null)
	if swordsman != null:
		ok(swordsman.max_hp == 28 and swordsman.power == 10 and swordsman.skill == 28
				and swordsman.speed == 12 and swordsman.luck == 8 and swordsman.defense == 7
				and swordsman.resistance == 4 and swordsman.move_range == 5,
				"%s: demo swordsman stats (hp 28 / str 10 / skill 28 / speed 12 / luck 8 / def 7 / res 4 / move 5)" % chapter_id)
		ok(swordsman.is_protagonist, "%s: demo swordsman is the protagonist (P-07)" % chapter_id)
	var knight: UnitState = state.units.get("unit_demo_knight", null)
	if knight != null:
		ok(knight.max_hp == 34 and knight.power == 11 and knight.skill == 26 and knight.speed == 9
				and knight.luck == 6 and knight.defense == 10 and knight.resistance == 3
				and knight.move_range == 5, "%s: demo knight stats (hp 34 / str 11 / skill 26 ...)" % chapter_id)
	# F1 acceptance: the alias still feeds legacy rebels through the same accessors.
	if number == 1:
		var rebel := DataRegistry.get_unit("unit_rebel_soldier_1")
		ok(rebel != null and int(rebel.base_stat("atk", -1)) == 5, "legacy rebel reads atk via the F1 alias")


## Prep sources honored (F6): chapter deployable ids + deploy caps; the protagonist pairs
## with the roster order; cells come from the map's deploy tiles.
func _deploy_players(chapter: Resource, map: Resource) -> Dictionary:
	var deploy := {}
	var cap := mini(int(chapter.deploy_max), int(map.map_deploy_cap))
	var tiles: Array[Vector2i] = map.deploy_tiles
	tiles.assign(tiles)
	for i in cap:
		if i >= chapter.deployable_unit_ids.size() or i >= tiles.size():
			break
		deploy[String(chapter.deployable_unit_ids[i])] = tiles[i]
	return deploy
