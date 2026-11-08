extends Node
## Automated playtest of the 6 demo maps (no UI): both sides are bots driven through the real
## BattleDirector, many seeds per map, two player styles and two difficulties. Prints a table
## and writes docs/playtest/demo_maps_report.md. Developer tool, not a pass/fail test.
## Run with: godot --headless --path . res://tools/playtest_demo_maps.tscn
##
## Player bot: one "runner" (the Knight) walks to the objective tile on Retrieve / Seize maps;
## everyone else fights. Styles: "aggressive" attacks any enemy in reach; "restrained" never
## attacks a unit of a tracked holdout faction (counters still happen when attacked).

const SEEDS := 25
const STYLES := ["aggressive", "restrained"]
const DIFFICULTIES := ["normal", "hard"]
const TURN_CAP := 30

var _hits := {}   # side -> {n, hit_sum, dmg_sum}


func _ready() -> void:
	var rows: Array = []
	GameState.new_game()
	GameState.build_roster()   # demo campaign (Swordsman + Knight, starting bond C)
	for chapter in DataRegistry.chapters_sorted("demo"):
		var map := DataRegistry.get_map(String(chapter.map_id))
		for difficulty in DIFFICULTIES:
			for style in STYLES:
				rows.append(_run_config(map, difficulty, style))
	var report := _report(rows)
	print(report)
	var out_dir := ProjectSettings.globalize_path("res://docs/playtest")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("demo_maps_report.md"), FileAccess.WRITE)
	if f != null:
		f.store_string(report)
		f.close()
	get_tree().quit(0)


func _run_config(map: Resource, difficulty: String, style: String) -> Dictionary:
	var agg := {"map": String(map.id), "turn_par": int(map.turn_par), "difficulty": difficulty, "style": style,
		"win": 0, "lose": 0, "stalled": 0, "bad_ending": 0, "turns": 0, "par_met": 0, "kos": 0,
		"restraint": 0, "protagonist_down": 0, "objective_fail": 0, "kills": 0}
	_hits = {"player": {"n": 0, "hit": 0.0, "dmg": 0}, "enemy": {"n": 0, "hit": 0.0, "dmg": 0}}
	for s in SEEDS:
		GameState.faction_kill_counts.clear()
		GameState.faction_states.clear()
		var director := BattleDirector.new()
		var deploy := {"unit_demo_swordsman": map.deploy_cells[0], "unit_demo_knight": map.deploy_cells[1]}
		director.setup(map, deploy, difficulty, 1000 + s)
		var result := _play(director, style)
		var status := String(result.get("status", ""))
		if status == "win":
			agg["win"] += 1
			if not Array(result.get("bad_ending_factions", [])).is_empty():
				agg["bad_ending"] += 1
			agg["restraint"] += int(result.get("restraint", {}).get("restraint_points_awarded", 0))
		elif status == "lose":
			agg["lose"] += 1
			if String(result.get("reason", "")) == "critical_unit_down":
				agg["protagonist_down"] += 1
			else:
				agg["objective_fail"] += 1
		else:
			agg["stalled"] += 1
		agg["turns"] += director.state.turn
		if status == "win" and director.state.turn <= int(map.turn_par):
			agg["par_met"] += 1
		for u in director.state.units.values():
			if u.side == "player" and not u.alive:
				agg["kos"] += 1
		for fid in director.state.reconcile_state:
			agg["kills"] += int(director.state.reconcile_state[fid].get("kills", 0))
	agg["hits"] = _hits.duplicate(true)
	return agg


func _play(director: BattleDirector, style: String) -> Dictionary:
	var guard := 0
	while director.state.battle_over.is_empty() and director.state.turn <= TURN_CAP and guard < 2000:
		guard += 1
		match director.state.phase:
			BattleState.PHASE_PLAYER:
				if not _player_step(director, style):
					director.end_player_phase()
			BattleState.PHASE_ENEMY:
				var plan := director.run_next_enemy_plan()
				if plan.is_empty():
					director.advance_after_enemy_phase()
				else:
					_commit(director, plan, "enemy")
			BattleState.PHASE_NPC:
				var walk := director.run_next_npc_plan()
				if walk.is_empty():
					director.advance_to_player_phase()
				else:
					director.commit("move", {"unit_id": String(walk["unit_id"]), "cell": walk["move_cell"]})
					if not director.state.units[String(walk["unit_id"])].acted:
						director.commit("wait", {"unit_id": String(walk["unit_id"])})
	return director.state.battle_over


## One player unit acts; false when every player unit has acted.
func _player_step(director: BattleDirector, style: String) -> bool:
	var state := director.state
	for unit in state.alive_units():
		if unit.side != "player" or unit.acted:
			continue
		var goal := _runner_goal(director, unit)
		var plan: Dictionary
		if goal != Vector2i(-1, -1):
			plan = _walk_plan(state, unit, goal)
			# Standing on the seize point already: hit an adjacent enemy without leaving it.
			if plan["move_cell"] == unit.pos and unit.pos == goal:
				var fight := EnemyAI.plan_unit(state, unit, ["enemy"])
				if fight.get("move_cell", Vector2i(-1, -1)) == unit.pos and String(fight.get("target_id", "")) != "" and _may_attack(state, fight, style):
					plan = fight
		else:
			plan = EnemyAI.plan_unit(state, unit, ["enemy"])
			if not _may_attack(state, plan, style):
				plan = {"unit_id": unit.id, "move_cell": unit.pos, "wait": true}
		if plan.is_empty():
			plan = {"unit_id": unit.id, "move_cell": unit.pos, "wait": true}
		_commit(director, plan, "player")
		return true
	return false


func _may_attack(state: BattleState, plan: Dictionary, style: String) -> bool:
	var target_id := String(plan.get("target_id", ""))
	if style != "restrained" or target_id == "" or not state.units.has(target_id):
		return true
	return not state.reconcile_state.has(String(state.units[target_id].faction_id))


## Retrieve: the Knight fetches the item, then heads for the exit. Seize: the Knight holds the point.
func _runner_goal(director: BattleDirector, unit: UnitState) -> Vector2i:
	if unit.template_id != "unit_demo_knight":
		return Vector2i(-1, -1)
	for obj in director.objectives:
		var kind: String = obj.identify()
		var p: Dictionary = obj._params
		if kind == "seize":
			return Vector2i(int(p.get("control_x", 0)), int(p.get("control_y", 0)))
		if kind == "retrieve":
			if unit.carried_item == String(p.get("item_id", "")):
				return Vector2i(int(p.get("exit_zone_x", 0)), int(p.get("exit_zone_y", 0)))
			for key in director.state.item_ground:
				if String(director.state.item_ground[key]) == String(p.get("item_id", "")):
					var xy := String(key).split(",")
					return Vector2i(int(xy[0]), int(xy[1]))
	return Vector2i(-1, -1)


func _walk_plan(state: BattleState, unit: UnitState, goal: Vector2i) -> Dictionary:
	var reach := MovementHandler.compute_move_cells(state, unit)
	return {"unit_id": unit.id, "move_cell": MovementHandler.closest_by_path(state, unit, reach.keys(), goal), "wait": true}


## Same path as commit_ai_plan, but records the forecast of every attack actually made.
func _commit(director: BattleDirector, plan: Dictionary, side: String) -> void:
	var state := director.state
	var unit: UnitState = state.units[String(plan["unit_id"])]
	var move_cell: Variant = plan.get("move_cell", unit.pos)
	if move_cell is Vector2i and move_cell != unit.pos:
		if not director.commit("move", {"unit_id": unit.id, "cell": move_cell}):
			director.commit("wait", {"unit_id": unit.id})
			return
	if unit.acted:
		return   # e.g. picking up the Retrieve item ends the action
	var target_id := String(plan.get("target_id", ""))
	if target_id != "" and state.units.has(target_id) and state.units[target_id].alive:
		var fc := CombatResolver.forecast(state, unit, state.units[target_id])
		if director.commit("attack", {"unit_id": unit.id, "target_id": target_id}):
			var first: Dictionary = fc["sequence"][0]
			var h: Dictionary = _hits[side if side == "player" else "enemy"]
			h["n"] += 1
			h["hit"] += float(first.get("hit_pct", 0))
			h["dmg"] += int(first.get("damage", 0))
			return
	director.commit("wait", {"unit_id": unit.id})


func _report(rows: Array) -> String:
	var lines: Array[String] = []
	lines.append("# Demo maps automated playtest")
	lines.append("")
	lines.append("Generated by `tools/playtest_demo_maps.tscn` - %d seeds per row, bots on both sides (see the tool header). " % SEEDS
		+ "Win%% / lose%% / stalled (no result by turn %d); turns = average final turn; par = wins within turn_par; " % TURN_CAP
		+ "KO = player units down per battle; kills = holdout-faction kills per battle; bad = wins that end in the bad ending (F-BAD); "
		+ "restraint = average score on wins; hit/dmg = average forecast Hit%% and damage of the first strike of each attack made.")
	lines.append("")
	lines.append("| Map | Diff | Style | Win | Lose (hero / obj.) | Stall | Turns (par) | Par met | KO | Kills | Bad end | Restraint | Player hit / dmg | Enemy hit / dmg |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for r in rows:
		var n := float(SEEDS)
		var hp: Dictionary = r["hits"]["player"]
		var he: Dictionary = r["hits"]["enemy"]
		var wins := maxi(int(r["win"]), 1)
		lines.append("| %s | %s | %s | %d%% | %d%% (%d / %d) | %d | %.1f (%d) | %d%% | %.2f | %.2f | %d | %d | %s | %s |" % [
			String(r["map"]).replace("map_", ""), r["difficulty"], r["style"],
			int(round(100.0 * r["win"] / n)), int(round(100.0 * r["lose"] / n)), r["protagonist_down"], r["objective_fail"], r["stalled"],
			r["turns"] / n, r["turn_par"], int(round(100.0 * r["par_met"] / n)), r["kos"] / n, r["kills"] / n,
			r["bad_ending"], int(round(float(r["restraint"]) / wins)),
			_hit_text(hp), _hit_text(he)])
	return "\n".join(lines) + "\n"


func _hit_text(h: Dictionary) -> String:
	if int(h["n"]) == 0:
		return "-"
	return "%d%% / %.1f" % [int(round(h["hit"] / h["n"])), float(h["dmg"]) / h["n"]]
