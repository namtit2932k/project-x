extends Node
## Full-battle smoke test (no UI): both sides driven by AI through the BattleDirector.
## Run with: godot --headless --path . res://tests/smoke_full_battle.tscn

var checks := 0
var failures := 0


func _ready() -> void:
	await run()
	await run_d03_scenarios()
	print("\nsmoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func run() -> void:
	GameState.new_game()
	# F4: this smoke plays the legacy ch01 campaign (unit ids and scripted outcomes).
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	# Deploy protagonist + companions (mixed Empire + Kingdom roster on the player side).
	var deploy := {}
	var ids: Array[String] = ["unit_swordsman", "unit_knight", "unit_lancer", "unit_gunner", "unit_healer"]
	for i in ids.size():
		deploy[ids[i]] = map.deploy_cells[i]
	var director := BattleDirector.new()
	director.setup(map, deploy, "normal")
	ok(director.state.units["unit_healer"].side == "player", "smoke: kingdom healer deployed on the player side")
	ok(director.state.units["unit_rebel_commander"].side == "enemy", "smoke: rebels are enemy side")
	# Light deterministic buff so the scripted AI platoon can realistically rout the rebels.
	for unit_id in deploy:
		var hero: UnitState = director.state.units[String(unit_id)]
		hero.max_hp += 20
		hero.hp = hero.max_hp
		hero.power += 4
		hero.defense += 2
		hero.skill += 3
		hero.speed += 2
	ok(director.player_sides.has("player"), "smoke: player side separated from factions")

	# Play until over (bounded).
	var guard := 0
	var player_sides: Array = director.player_sides
	while director.state.battle_over.is_empty() and guard < 600:
		guard += 1
		if director.state.phase == BattleState.PHASE_PLAYER:
			var did := _ai_step(director, player_sides)
			if not did:
				director.end_player_phase()
		elif director.state.phase == BattleState.PHASE_ENEMY:
			var plan := director.run_next_enemy_plan()
			if plan.is_empty():
				director.advance_after_enemy_phase()
			else:
				director.commit_ai_plan(plan)
		elif director.state.phase == BattleState.PHASE_NPC:
			director.advance_to_player_phase()

	ok(not director.state.battle_over.is_empty(), "smoke: battle reached an end state")
	ok(String(director.state.battle_over.get("status", "")) == "win", "smoke: battle won by AI pressure (status=%s)" % String(director.state.battle_over.get("status", "none")))
	ok(director.state.reconcile_state.has("faction_rebel_ch01"), "smoke: reconcile tracked for remnant faction")
	var kills := int(director.state.reconcile_state["faction_rebel_ch01"]["kills"])
	ok(kills == 4, "smoke: 4 rebels defeated (kills=%d)" % kills)
	ok(bool(director.state.reconcile_state["faction_rebel_ch01"].get("evaluated", false)), "smoke: reconcile evaluated at battle end")

	# Rewind sanity inside a real battle history.
	ok(director.rewind.has_frames(), "smoke: snapshots were pushed during committed commands")
	ok(director.rewind_budget == 5, "smoke: normal difficulty rewind budget = 5")

	# Mimic campaign merge (same logic path as main).
	_merge_like_main(director, player_sides)
	var roster: Dictionary = GameState.roster
	var squad_alive := true
	for unit_id in ["unit_swordsman", "unit_knight", "unit_lancer", "unit_gunner", "unit_healer"]:
		squad_alive = squad_alive and bool(roster[unit_id].alive)
	ok(squad_alive, "smoke: squad casualties recorded (temp_injury restores the roster)")
	ok(GameState.completed_chapters.has(String(chapter.id)), "smoke: chapter completion recorded in campaign")


## One AI action for the given side; returns false when the side has no unit left to act.
func _ai_step(director: BattleDirector, acting_sides: Array) -> bool:
	for unit in director.state.alive_units():
		if unit.side not in acting_sides or unit.acted:
			continue
		var foe_sides: Array = []
		for foe in director.state.alive_units():
			if foe.side not in acting_sides and foe.side not in foe_sides:
				foe_sides.append(foe.side)
		var plan := EnemyAI.plan_unit(director.state, unit, foe_sides)
		if plan.is_empty():
			continue
		director.commit_ai_plan(plan)
		return true
	return false


## N03 (D03): two un-buffed ch01 scenarios through the real director.
## 1) Win while the commander is spared -> persuaded = true.
## 2) Win while the commander is also slain -> persuaded = false.
func run_d03_scenarios() -> void:
	GameState.new_game()
	# F4: these scenarios run on the legacy ch01 data.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var scenario: Dictionary = await _run_ch01_scenario(true)
	ok(scenario.has("done"), "smoke spared: scenario reached a battle end state")
	ok(String(scenario["status"]) == "win", "smoke spared: battle won while sparing the commander")
	ok(bool(scenario["commander_alive"]), "smoke spared: commander survived the battle")
	ok(int(scenario["kills"]) == 3, "smoke spared: only three soldiers fell (kills=3)")
	ok(bool(scenario["persuaded"]), "smoke spared: reconcile persuaded with the spared commander (events + kills 3/4)")
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	scenario = await _run_ch01_scenario(false)
	ok(String(scenario["status"]) == "win", "smoke rout: battle won by rout")
	ok(not bool(scenario["commander_alive"]), "smoke rout: commander slain")
	ok(int(scenario["kills"]) == 4, "smoke rout: all four rebels fell (kills=4)")
	ok(not bool(scenario["persuaded"]), "smoke rout: reconcile lost when the commander was killed (threshold 4)")


## Scripted player-side play: friendly = true avoids attacking the priority targets (the
## commander) so he is spared; rout considers every enemy unit winnable.
func _run_ch01_scenario(protect: bool, seed_value: int = -1) -> Dictionary:
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var deploy := {}
	var ids: Array[String] = ["unit_swordsman", "unit_knight", "unit_lancer", "unit_gunner", "unit_healer"]
	for i in ids.size():
		deploy[ids[i]] = map.deploy_cells[i]
	var director := BattleDirector.new()
	director.setup(map, deploy, "normal", seed_value)
	# The rout branch must actually reach the distant commander before the win fires
	# (the ch01 objective only needs the three soldiers), so mirror the main-run buff.
	if not protect:
		for unit_id in deploy:
			var hero: UnitState = director.state.units[String(unit_id)]
			hero.max_hp += 20
			hero.hp = hero.max_hp
			hero.power += 6
			hero.defense += 2
			hero.skill += 3
			hero.speed += 2
	var guard := 0
	while director.state.battle_over.is_empty() and guard < 900:
		guard += 1
		if director.state.phase == BattleState.PHASE_PLAYER:
			var stepped := false
			for unit in director.state.alive_units():
				if unit.side != "player" or unit.acted:
					continue
				var plan := _priority_plan(director.state, unit, protect)
				if plan.is_empty():
					continue
				director.commit_ai_plan(plan)
				stepped = true
				break
			if not stepped:
				director.advance_after_enemy_phase()
				director.advance_to_player_phase()   # no npc setup on ch01: straight to next turn
				continue
		elif director.state.phase == BattleState.PHASE_ENEMY:
			var plan2 := director.run_next_enemy_plan()
			if plan2.is_empty():
				director.advance_after_enemy_phase()
				director.advance_to_player_phase()
			else:
				director.commit_ai_plan(plan2)
		else:
			director.advance_to_player_phase()
		await get_tree().process_frame
	var out := {"done": not director.state.battle_over.is_empty()}
	out["status"] = String(director.state.battle_over.get("status", "lose"))
	var cmd: UnitState = director.state.units.get("unit_rebel_commander", null)
	out["commander_alive"] = cmd != null and cmd.alive
	var rebel_state: Dictionary = director.state.reconcile_state.get("faction_rebel_ch01", {})
	out["kills"] = int(rebel_state.get("kills", -1))
	out["persuaded"] = bool(rebel_state.get("persuaded", false))
	return out


## Convenience wrapper matching the smoke loop style used by run().
func _priority_plan(state: BattleState, unit: UnitState, protect: bool) -> Dictionary:
	var reach := MovementHandler.compute_move_cells(state, unit)
	if not reach.has(unit.pos):
		reach[unit.pos] = 0.0
	var targets: Array = []
	var avoid: Array = []
	if protect:
		avoid = ["unit_rebel_commander"]
		targets = ["unit_rebel_soldier_1", "unit_rebel_soldier_2", "unit_rebel_soldier_3"]
	else:
		# Rout: hunt the commander first so he falls before the three-soldier win fires.
		var commander: UnitState = state.units.get("unit_rebel_commander", null)
		if commander != null and commander.alive:
			targets = ["unit_rebel_commander"]
		else:
			targets = ["unit_rebel_soldier_1", "unit_rebel_soldier_2", "unit_rebel_soldier_3"]
	# Attack options from reachable cells; prefer priority list, then avoid-list members.
	var best: Dictionary = {}
	var best_dist := 1 << 30
	for group in [targets, avoid]:
		for cell in reach:
			for foe in state.alive_units():
				if foe.side != "enemy" or not group.has(foe.id):
					continue
				var dist := RangeHandler.manhattan(cell, foe.pos)
				if dist >= unit.attack_range_min and dist <= unit.attack_range_max and dist < best_dist:
					best_dist = dist
					best = {"unit_id": unit.id, "move_cell": cell, "target_id": foe.id}
		if not best.is_empty():
			return best
	# Approach: minimise distance to the nearest priority target.
	var best_cell: Vector2i = unit.pos
	var approach_best := 1 << 30
	for cell in reach:
		for foe in state.alive_units():
			if foe.side != "enemy" or (protect and foe.id == "unit_rebel_commander"):
				continue
			if not targets.has(foe.id):
				continue
			var d := RangeHandler.manhattan(cell, foe.pos)
			if d < approach_best:
				approach_best = d
				best_cell = cell
	return {"unit_id": unit.id, "move_cell": best_cell, "target_id": ""}


## Uses the same campaign merge as Main (CampaignMerge, D06) for the smoke run.
func _merge_like_main(director: BattleDirector, _player_sides: Array) -> void:
	var chapter := GameState.current_chapter()
	CampaignMerge.merge(director.state, chapter, ResultStore.last_result)
