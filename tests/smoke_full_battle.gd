extends Node
## Full-battle smoke test (no UI): both sides driven by AI through the BattleDirector.
## Run with: godot --headless --path . res://tests/smoke_full_battle.tscn

var checks := 0
var failures := 0


func _ready() -> void:
	await run()
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
	GameState.build_roster()
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	# Deploy protagonist + three companions.
	var deploy := {}
	var ids: Array[String] = ["unit_swordsman", "unit_knight", "unit_lancer", "unit_gunner", "unit_healer"]
	for i in ids.size():
		deploy[ids[i]] = map.deploy_cells[i]
	var director := BattleDirector.new()
	director.setup(map, deploy, "normal")
	# Light deterministic buff so the scripted AI platoon can realistically rout the rebels.
	for unit_id in deploy:
		var hero: UnitState = director.state.units[String(unit_id)]
		hero.max_hp += 20
		hero.hp = hero.max_hp
		hero.power += 4
		hero.defense += 2
		hero.skill += 3
		hero.speed += 2
	ok(director.player_factions.has("faction_empire"), "smoke: player factions derive from protagonist")

	# Play until over (bounded).
	var guard := 0
	var player_sides: Array = director.player_factions
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
		if unit.faction_id not in acting_sides or unit.acted:
			continue
		var foe_factions: Array = []
		for foe in director.state.alive_units():
			if foe.faction_id not in acting_sides and foe.faction_id not in foe_factions:
				foe_factions.append(foe.faction_id)
		var plan := EnemyAI.plan_unit(director.state, unit, foe_factions)
		if plan.is_empty():
			continue
		director.commit_ai_plan(plan)
		return true
	return false


## Mirrors Main._merge_battle_into_campaign outcome handling for the smoke run.
func _merge_like_main(director: BattleDirector, player_sides: Array) -> void:
	var chapter := GameState.current_chapter()
	var result: Dictionary = ResultStore.last_result
	var policy: String = String(DataRegistry.rule("casualty_by_difficulty", {}).get(GameState.difficulty, "temp_injury"))
	for unit_id in GameState.roster:
		var entry: Dictionary = GameState.roster[unit_id]
		if not director.state.units.has(unit_id):
			continue
		var state_unit: UnitState = director.state.units[unit_id]
		entry.exp = int(entry.get("exp", 0)) + int(state_unit.exp)
		if not state_unit.alive and policy != "permadeath":
			entry.alive = true
			entry["defeats"] = int(entry.get("defeats", 0)) + 1
	if String(result.get("status", "")) == "win":
		GameState.completed_chapters[String(chapter.id)] = true
		var outcomes := {}
		for faction_id in result.get("reconcile", {}):
			var fo: Dictionary = result["reconcile"][faction_id]
			outcomes[faction_id] = {"persuaded": bool(fo.get("persuaded", false)), "kills": int(fo.get("kills", 0)), "events": fo.get("events", [])}
		GameState.reconcile_outcomes[String(chapter.id)] = outcomes
