extends Node
## N12 smoke: exercises all five mechanism-test maps (escort/defend/retrieve/capture/evacuate)
## headlessly through BattleDirector. Each map gets one scripted win and one scripted lose run.
## Run with: godot --headless --path . res://tests/smoke_test_maps.tscn

const ITEM_ID := "item_border_relic"

var checks := 0
var failures := 0


func _ready() -> void:
	await run_all()
	print("\nsmoke maps: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func run_all() -> void:
	for map_id in ["map_test_escort", "map_test_defend", "map_test_retrieve", "map_test_capture", "map_test_evacuate"]:
		GameState.new_game()
		GameState.build_roster()
		var director := _setup(map_id, ["unit_swordsman", "unit_knight", "unit_lancer", "unit_gunner"])
		var win: Dictionary = await _run_win(map_id, director)
		ok(String(win.get("status", "")) == "win", "%s: scripted run reaches WIN" % map_id)
		GameState.new_game()
		GameState.build_roster()
		var director2 := _setup(map_id, ["unit_swordsman", "unit_knight", "unit_lancer", "unit_gunner"])
		var lose: Dictionary = await _run_lose(map_id, director2)
		ok(String(lose.get("status", "")) == "lose", "%s: scripted run reaches LOSE" % map_id)


func _setup(map_id: String, ids: Array) -> BattleDirector:
	var map := DataRegistry.get_map(map_id)
	var deploy := {}
	var i := 0
	for unit_id in ids:
		if i >= map.deploy_cells.size():
			break
		deploy[unit_id] = map.deploy_cells[i]
		i += 1
	var director := BattleDirector.new()
	director.setup(map, deploy, "normal", 42)
	return director


## Per-map player-side control for the win run. (unit, state, map_id): Callable.bind appends.
func _win_actor(unit: UnitState, state: BattleState, map_id: String) -> Dictionary:
	match map_id:
		"map_test_escort", "map_test_evacuate":
			return _hunt_plan(state, unit)
		"map_test_retrieve":
			return _retrieve_plan(state, unit)
		_: # defend / capture: hold position, pure turn passing
			return {}


## Deterministic loss setup executed right after _setup; default: do nothing.
func _prep_lose(map_id: String, director: BattleDirector) -> void:
	var state := director.state
	match map_id:
		"map_test_escort":
			_place_assassin(state, "unit_rebel_soldier_1", "unit_healer")
		"map_test_defend":
			# An enemy already inside the zone when the first player phase ends = block lose.
			var foe: UnitState = state.units["unit_rebel_soldier_2"]
			foe.pos = Vector2i(2, 2)
		"map_test_retrieve", "map_test_capture":
			# Protagonist-adjacent one-shot: critical unit down (a reproducible defeat).
			var foe_id := "unit_rebel_soldier_1" if not state.units.has("unit_rebel_soldier_2") else "unit_rebel_soldier_2"
			_place_assassin(state, foe_id, "unit_swordsman")
		"map_test_evacuate":
			# Evacuee down: beastwoman (must_survive) adjacent one-shot.
			_place_assassin(state, "unit_rebel_soldier_1", "unit_beastwoman")


func _place_assassin(state: BattleState, foe_id: String, victim_id: String) -> void:
	var foe: UnitState = state.units[foe_id]
	# 100% hit / huge damage so the find-one kill is deterministic, no rng dependence.
	# Keeps the natural movement (a shortened reach produces infeasible stand cells:
	# MoveCommand.apply rejects them, so the assassin would wait forever).
	foe.skill = 500
	foe.power = 999
	foe.speed = 0
	foe.pos = state.units[victim_id].pos + Vector2i(1, 0)


func _run_win(map_id: String, director: BattleDirector) -> Dictionary:
	# Buff so the script forces the outcome: high damage/defense, tanks survive stray hits.
	_buff_player(director)
	match map_id:
		"map_test_escort":
			director.state.units["unit_healer"].max_hp += 500
			director.state.units["unit_healer"].hp = director.state.units["unit_healer"].max_hp
		"map_test_evacuate":
			director.state.units["unit_beastwoman"].max_hp += 900
			director.state.units["unit_beastwoman"].hp = director.state.units["unit_beastwoman"].max_hp
	await _play(director, func(st: BattleState, u: UnitState) -> Dictionary: return _win_actor(u, st, map_id))
	return _outcome(director)


func _run_lose(map_id: String, director: BattleDirector) -> Dictionary:
	_buff_player(director)
	_prep_lose(map_id, director)
	await _play(director, func(_state: BattleState, _unit: UnitState) -> Dictionary: return {})
	return _outcome(director)


func _buff_player(director: BattleDirector) -> void:
	for u in director.state.alive_units():
		if u.side != "player":
			continue
		u.max_hp += 500
		u.hp = u.max_hp
		u.power += 60
		u.defense += 20
		u.skill += 60
		u.speed = 0   # enemies always hit (avoid 0) — keeps every duel bounded


## Loop both sides like the real scene: player script / enemy AI / NPC walk.
func _play(director: BattleDirector, actor: Callable) -> void:
	var guard := 0
	while director.state.battle_over.is_empty() and guard < 600:
		guard += 1
		match director.state.phase:
			BattleState.PHASE_PLAYER:
				var acted := false
				for u in director.state.alive_units():
					if u.side != "player" or u.acted:
						continue
					var plan: Dictionary = actor.call(director.state, u)
					if plan.has("pickup"):
						acted = true if director.commit("pickup", {"unit_id": u.id}) else acted
						break
					if not plan.is_empty():
						director.commit_ai_plan(plan)
						acted = true
						break
				if not acted:
					director.end_player_phase()
			BattleState.PHASE_ENEMY:
				var ep := director.run_next_enemy_plan()
				if ep.is_empty():
					director.advance_after_enemy_phase()
				else:
					director.commit_ai_plan(ep)
			BattleState.PHASE_NPC:
				var np := director.run_next_npc_plan()
				if np.is_empty():
					director.advance_to_player_phase()
				else:
					director.commit_ai_plan(np)
		await get_tree().process_frame


func _outcome(director: BattleDirector) -> Dictionary:
	return {"status": String(director.state.battle_over.get("status", "none"))}


## Generic melee/ranged hunter: attack any reachable foe, else close on the nearest one.
func _hunt_plan(state: BattleState, unit: UnitState) -> Dictionary:
	var reach := MovementHandler.compute_move_cells(state, unit)
	if not reach.has(unit.pos):
		reach[unit.pos] = 0.0
	var best: Dictionary = {}
	var best_dist := 1 << 30
	for cell in reach:
		for foe in state.alive_units():
			if foe.side == unit.side or foe.side == "npc":
				continue
			var dist := RangeHandler.manhattan(cell, foe.pos)
			if dist >= unit.attack_range_min and dist <= unit.attack_range_max and dist < best_dist:
				best_dist = dist
				best = {"unit_id": unit.id, "move_cell": cell, "target_id": foe.id}
	if not best.is_empty():
		return best
	# Approach: move to the reachable cell nearest to the closest foe.
	var best_cell := unit.pos
	var approach := 1 << 30
	for cell in reach:
		for foe in state.alive_units():
			if foe.side == unit.side or foe.side == "npc":
				continue
			var d := RangeHandler.manhattan(cell, foe.pos)
			if d < approach:
				approach = d
				best_cell = cell
	return {"unit_id": unit.id, "move_cell": best_cell, "target_id": ""}


## Retrieve script: walk to the item, pick it up, walk the parcel back to the exit zone.
func _retrieve_plan(state: BattleState, unit: UnitState) -> Dictionary:
	var obj := _retrieve_objective(state)
	if obj.is_empty():
		return {}
	var exit_zone := Rect2i(
		int(obj.exit_zone_x), int(obj.exit_zone_y), int(obj.exit_zone_w), int(obj.exit_zone_h))
	if unit.carried_item != "":
		if exit_zone.has_point(unit.pos):
			return {}   # win already fires on the committing move
		var target := Vector2i(exit_zone.position + exit_zone.size / 2)
		return _step_toward(state, unit, target)
	# Not carrying: stand on the item cell to pick up, else approach it.
	var item_pos := item_ground_pos(state, ITEM_ID)
	if item_pos == unit.pos:
		return {"pickup": true}
	return _step_toward(state, unit, item_pos)


func _retrieve_objective(state: BattleState) -> Dictionary:
	for cfg in state.objectives_config:
		if String(cfg.get("type", "")) == "retrieve":
			return cfg.get("params", {})
	return {}


func item_ground_pos(state: BattleState, item_id: String) -> Vector2i:
	for key in state.item_ground:
		if String(state.item_ground[key]) == item_id:
			return Vector2i(key.split(",")[0].to_int(), key.split(",")[1].to_int())
	return Vector2i(-99, -99)


## Move plan toward the target cell, restricted to reachable cells only.
func _step_toward(state: BattleState, unit: UnitState, target: Vector2i) -> Dictionary:
	var reach := MovementHandler.compute_move_cells(state, unit)
	if not reach.has(unit.pos):
		reach[unit.pos] = 0.0
	var best_cell := unit.pos
	var best := RangeHandler.manhattan(unit.pos, target)
	for cell in reach:
		var d := RangeHandler.manhattan(cell, target)
		if d < best:
			best = d
			best_cell = cell
	return {"unit_id": unit.id, "move_cell": best_cell, "target_id": ""}
