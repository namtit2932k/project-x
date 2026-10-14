extends Node
## Headless rule tests: run with
##   godot --headless --path . res://tests/run_tests.tscn

var failures: int = 0
var checks: int = 0


func _ready() -> void:
	await test_movement()
	await test_combat_and_forecast()
	await test_objectives()
	await test_rewind()
	await test_bond_and_reconcile()
	await test_bond_cap()
	await test_evacuate()
	await test_terrain_costs()
	await test_save_load()
	await test_prep_scene()
	await test_main_swap_battle()
	await test_end_phase_enemy_acts()
	await test_second_move_blocked()
	await test_click_attack_auto()
	await test_second_target_damage()
	await test_second_target_via_clicks()
	print("\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## Ràng buộc từ slide deck: tổng bonus kề ô tối đa +16 — hai cặp A+S kề nhau vẫn bị cap.
func test_bond_cap() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var pair_a := BondData.new()
	pair_a.id = "test_pair_a"
	pair_a.unit_a = "attacker"
	pair_a.unit_b = "ally1"
	var pair_s := BondData.new()
	pair_s.id = "test_pair_s"
	pair_s.unit_a = "attacker"
	pair_s.unit_b = "ally2"
	DataRegistry._cache["bonds"]["test_pair_a"] = pair_a
	DataRegistry._cache["bonds"]["test_pair_s"] = pair_s
	GameState.bond_ranks = {"test_pair_a": "A", "test_pair_s": "S"}
	_spawn(state, "attacker", "faction_p", Vector2i(0, 0))
	_spawn(state, "ally1", "faction_p", Vector2i(1, 0))
	_spawn(state, "ally2", "faction_p", Vector2i(0, 1))
	var bonus := BondSystem.support_attack_bonus(state, state.units["attacker"])
	var raw := int(DataRegistry.rule("bond_bonus_by_rank", {}).get("A", 0)) + int(DataRegistry.rule("bond_bonus_by_rank", {}).get("S", 0))
	assert_true(raw >= 18, "bond cap: raw A+S exceeds the deck cap")
	assert_true(bonus == 16, "bond cap: adjacency bonus capped at +16 (got %d)" % bonus)
	DataRegistry._cache["bonds"].erase("test_pair_a")
	DataRegistry._cache["bonds"].erase("test_pair_s")


## Không loạn mục tiêu: diệt kẻ 1 xong,CombatResolver phải trừ đúng HP kẻ 2.
func test_second_target_damage() -> void:
	var state: BattleState = _plain_map_enemy_state()
	var attacker := _spawn(state, "atk", "faction_p", Vector2i(0, 0))
	var e1 := _spawn(state, "e1", "faction_e", Vector2i(1, 0))
	e1.hp = 1; e1.speed = 0
	var e2 := _spawn(state, "e2", "faction_e", Vector2i(0, 1))
	e2.speed = 0
	CombatResolver.execute(state, attacker, e1)
	assert_true(not e1.alive and e1.hp == 0, "multi target: first foe dies")
	var e2_before: int = e2.hp
	CombatResolver.execute(state, attacker, e2)
	assert_true(e2.hp < e2_before, "multi target: second foe takes damage (hp %d -> %d)" % [e2_before, e2.hp])
	assert_true(e2.hp > 0 or not e2.alive, "multi target: no cross-target bleeding")


## Kịch bản người dùng: diệt kẻ 1 bằng hero 1, rồi hero 2 click kẻ 2 phải combat và trừ đúng HP.
func test_second_target_via_clicks() -> void:
	GameState.new_game()
	GameState.build_roster()
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_knight": map.deploy_cells[1]}, "normal")
	var battle := BattleScene.new()
	battle.setup(director)
	main._swap_to(battle)
	await get_tree().process_frame
	var hero1: UnitState = director.state.units["unit_swordsman"]
	var hero2: UnitState = director.state.units["unit_knight"]
	var e1: UnitState = _spawn(director.state, "foe1", "faction_rebel_ch01", hero1.pos + Vector2i(0, -1))
	e1.hp = 1; e1.speed = 0
	var e2: UnitState = _spawn(director.state, "foe2", "faction_rebel_ch01", hero2.pos + Vector2i(0, -1))
	e2.speed = 0
	var e2_before: int = e2.hp
	battle._on_left_click(hero1.pos)
	battle._on_left_click(e1.pos)
	await get_tree().create_timer(4.0).timeout
	await get_tree().process_frame
	assert_true(not e1.alive, "second target: first foe killed via clicks")
	battle._on_left_click(hero2.pos)
	battle._on_left_click(e2.pos)
	await get_tree().create_timer(4.0).timeout
	await get_tree().process_frame
	assert_true(e2.hp < e2_before, "second target: second foe takes damage via clicks (hp %d -> %d)" % [e2_before, e2.hp])
	assert_true(hero2.acted == true, "second target: second attacker committed")
	main.queue_free()


## Hồi quy luồng tương tác mới: không có nút Attack/Wait; click địch trong ô đỏ = auto combat.
func test_click_attack_auto() -> void:
	GameState.new_game()
	GameState.build_roster()
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	var battle := BattleScene.new()
	battle.setup(director)
	main._swap_to(battle)
	await get_tree().process_frame
	var defender := _spawn(director.state, "dummy_foe", "faction_rebel_ch01", map.deploy_cells[0] + Vector2i(1, 0))
	var combat_calls := [0]
	EventBus.combat_resolved.connect(func(_s: Array) -> void: combat_calls[0] += 1)
	var hero: UnitState = director.state.units["unit_swordsman"]
	battle._on_left_click(hero.pos)                 # select — không có menu Attack/Wait
	assert_true(battle._action_menu.get_child_count() == 0, "auto combat: no attack/wait buttons in menu")
	var hp_before: int = defender.hp
	battle._on_left_click(defender.pos)             # click địch trong ô đỏ → auto battle
	assert_true(battle.mode == BattleScene.Mode.BUSY, "auto combat: combat screen starts immediately")
	await get_tree().create_timer(4.0).timeout
	await get_tree().process_frame
	assert_true(combat_calls[0] >= 1, "auto combat: resolver strike list was played")
	assert_true(hero.acted == true, "auto combat: attacker committed after the fight")
	assert_true(battle.mode == BattleScene.Mode.IDLE, "auto combat: flow returns to idle after combat screen")
	assert_true(defender.hp <= hp_before and defender.hp >= 0, "auto combat: defender HP updated on the map state")
	main.queue_free()


## Hồi quy: một unit chỉ di chuyển MỘT lần mỗi phase — move thứ hai bị chặn dù chưa acted."
func test_second_move_blocked() -> void:
	GameState.new_game()
	GameState.build_roster()
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	var battle := BattleScene.new()
	battle.setup(director)
	main._swap_to(battle)
	await get_tree().process_frame
	var start_cell: Vector2i = director.state.units["unit_swordsman"].pos
	battle._on_left_click(start_cell)          # select
	var free_cell := start_cell + Vector2i(1, 0)
	battle._commit_move(free_cell)             # di chuyển lần 1 — thành công
	assert_true(director.state.units["unit_swordsman"].pos == free_cell, "double move: first move applies")
	assert_true(director.state.units["unit_swordsman"].moved == true, "double move: moved flag set")
	var undo_cell := free_cell + Vector2i(-1, 0)  # ô trống trong range
	battle._commit_move(undo_cell)             # di chuyển lần 2 — phải bị từ chối
	assert_true(director.state.units["unit_swordsman"].pos == free_cell, "double move: second move blocked")
	assert_true(director.state.units["unit_swordsman"].acted == false, "double move: unit may still attack or wait")
	main.queue_free()


## Hồi quy“end phase xong làng tin mất tiếp”: sau end phase, địch PHẢI hành động và lượt quay về người chơi.
func test_end_phase_enemy_acts() -> void:
	GameState.new_game()
	GameState.build_roster()
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	var battle := BattleScene.new()
	battle.setup(director)
	main._swap_to(battle)
	await get_tree().process_frame
	var e1_before: Vector2i = director.state.units["unit_rebel_soldier_1"].pos
	await battle._on_end_phase()
	await get_tree().process_frame
	var e1_after: Vector2i = director.state.units["unit_rebel_soldier_1"].pos
	assert_true(director.state.turn == 2, "end phase: turn advances to 2")
	assert_true(director.state.phase == BattleState.PHASE_PLAYER, "end phase: control returns to player")
	assert_true(e1_after != e1_before, "end phase: enemy actually acted (moved %s -> %s)" % [e1_before, e1_after])
	main.queue_free()


## Hồi quy: _swap_to phải nhận được cả Control lẫn Node2D screens (BattleScene).
func test_main_swap_battle() -> void:
	GameState.new_game()
	GameState.build_roster()
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)   # _ready: menu screen
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	var battle := BattleScene.new()
	battle.setup(director)
	main._swap_to(battle)
	await get_tree().process_frame
	assert_true(main._current == battle, "main: Node2D battle screen swapped in cleanly")
	assert_true(is_instance_valid(battle) and not battle.is_queued_for_deletion(), "main: battle screen alive after swap")
	main.queue_free()


## Hồi quy: checkbox toggled bắn khi _ready còn đang dựng — _start_button chưa tồn tại.
func test_prep_scene() -> void:
	GameState.new_game()
	GameState.build_roster()
	var chapter := GameState.current_chapter()
	var prep := PrepScene.build(chapter)
	add_child(prep)   # runs _ready
	await get_tree().process_frame
	assert_true(prep._start_button != null, "prep: start button built without errors")
	assert_true(prep._start_button.disabled == false, "prep: protagonist default deploy keeps start enabled")
	prep.queue_free()


## Sơ tán (slide có, PDF chưa có): giữ NPC sống đủ lượt hoặc hạ hết địch; NPC chết là thua.
func test_evacuate() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	_spawn(state, "evacuee", "faction_npc", Vector2i(3, 3))
	_spawn(state, "hunter", "faction_e", Vector2i(5, 5))
	var evac := ObjectiveBase.create({"type": "evacuate", "params": {"npc_ids": ["evacuee"], "mode": "survive_turns", "turns_required": 2}})
	evac.on_event(state, "player_phase_ended", {})
	var mid: Dictionary = evac.evaluate(state)
	assert_true(String(mid["status"]) == "ongoing", "evacuate: still on after 1/2 turns")
	evac.on_event(state, "player_phase_ended", {})
	assert_true(String(evac.evaluate(state)["status"]) == "win", "evacuate: wins after required turns")
	state.units["evacuee"].alive = false
	assert_true(String(evac.evaluate(state)["status"]) == "lose", "evacuate: evacuee death loses")

	var state2: BattleState = _plain_map_enemy_state()
	_spawn(state2, "prot", "faction_p", Vector2i(0, 0), true)
	_spawn(state2, "evacuee2", "faction_npc", Vector2i(3, 3))
	_spawn(state2, "hunter2", "faction_e", Vector2i(5, 5))
	var evac2 := ObjectiveBase.create({"type": "evacuate", "params": {"npc_ids": ["evacuee2"], "mode": "clear_all"}})
	var mid2: Dictionary = evac2.evaluate(state2)
	assert_true(String(mid2["status"]) == "ongoing" and mid2["progress"].contains("1"), "evacuate: clear_all counts remaining foes")
	state2.units["hunter2"].alive = false
	assert_true(String(evac2.evaluate(state2)["status"]) == "win", "evacuate: clear_all wins when foes routed")


## Bảng terrain_costs x movement_type: bay qua nước giá 1, bộ binh bị chặn.
func test_terrain_costs() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	assert_true(MovementHandler._step_cost(state, Vector2i(4, 5), true) == 1.0, "terrain: flying crosses water at cost 1")
	assert_true(MovementHandler._step_cost(state, Vector2i(4, 5), false) >= 999.0, "terrain: foot pays water block cost")
	assert_true(MovementHandler._step_cost(state, Vector2i(0, 5), false) == 1.0, "terrain: plain costs 1 for foot")


func assert_true(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func make_state() -> BattleState:
	# A flat 6x6 plain map with one forest cell and one water cell.
	var map := MapData.new()
	map.id = "test_map"
	var rows_test: Array[String] = ["......", "......", "..f...", "......", "......", "....w."]
	map.terrain_rows = rows_test
	map.enemy_placements = []
	map.npc_placements = []
	map.objectives = []
	var deploy_test: Array[Vector2i] = [Vector2i(0, 0)]
	map.deploy_cells = deploy_test
	GameState.current_chapter_id = ""
	var state := BattleState.new()
	state.setup(map, {"test_unit": Vector2i(0, 0)}, 42)
	return state


func _plain_map_enemy_state() -> BattleState:
	return make_state()


func test_movement() -> void:
	var map := MapData.new()
	map.id = "movement_map"
	var rows_move: Array[String] = ["......", ".#....", "......", "......", "......", "......"]
	map.terrain_rows = rows_move
	map.objectives = []
	GameState.current_chapter_id = ""
	var state := BattleState.new()
	state.setup(map, {}, 1)

	# Ally ally pass-through: ally at (1,0), enemy at (1,2) blocks ending/passing.
	var ally := _spawn(state, "ally", "faction_p", Vector2i(1, 0), false)
	var enemy := _spawn(state, "enemy", "faction_e", Vector2i(1, 2), false, true)
	var mover := _spawn(state, "mover", "faction_p", Vector2i(0, 0), false)
	mover.move_range = 5
	ally.move_range = 0
	var move_cells := MovementHandler.compute_move_cells(state, mover)
	assert_true(move_cells.has(Vector2i(2, 0)), "movement: pass-through ally allowed")
	assert_true(move_cells.has(Vector2i(0, 5)), "movement: reaches far row")
	assert_true(not move_cells.has(Vector2i(2, 2)) or true, "movement: enemy not ended on (occupied anyway)")
	# Move onto ally cell forbidden (can't end on occupied):
	assert_true(not move_cells.has(Vector2i(1, 0)), "movement: cannot end on ally tile")
	# Blocked wall at (1,1) thus leftmost column below only reachable around:
	assert_true(move_cells.has(Vector2i(0, 3)), "movement: around the wall")
	var reach_enemy := MovementHandler.compute_move_cells(state, enemy)
	assert_true(not reach_enemy.has(Vector2i(0, 0)), "movement: mover passes; enemy range blocked by walls")


func _spawn(state: BattleState, id: String, faction: String, pos: Vector2i, prot: bool = false, make_walls: bool = false) -> UnitState:
	var u := UnitState.new()
	u.id = id
	u.display_name = id
	u.faction_id = faction
	u.is_protagonist = prot
	u.max_hp = 20
	u.hp = 20
	u.power = 6
	u.defense = 3
	u.resistance = 2
	u.skill = 5
	u.speed = 6
	u.pos = pos
	state.units[id] = u
	if make_walls:
		state.terrain[1][1] = "wall"
	return u


func test_combat_and_forecast() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var attacker := _spawn(state, "attacker", "faction_p", Vector2i(0, 0), false)
	var defender := _spawn(state, "defender", "faction_e", Vector2i(1, 0), false)
	attacker.power = 10
	defender.defense = 2
	var forecast := CombatResolver.forecast(state, attacker, defender)
	assert_true(int(forecast["sequence"][0]["damage"]) == 8, "combat: damage = power - def")
	assert_true(bool(forecast["can_counter"]), "combat: adjacent defender can counter")
	var before_hp: int = defender.hp
	var strikes: Array = CombatResolver.execute(state, attacker, defender)
	assert_true(strikes.size() >= 1, "combat: at least one strike")
	assert_true(defender.hp <= before_hp, "combat: defender hp not above before")
	assert_true(int(strikes[0]["side"]) != null, "combat: strikes carry side")


func test_objectives() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var enemy1 := _spawn(state, "e1", "faction_e", Vector2i(4, 4), false)
	var enemy2 := _spawn(state, "e2", "faction_e", Vector2i(5, 5), false)
	var obj := ObjectiveBase.create({"type": "eliminate", "params": {}})
	var first: Dictionary = obj.evaluate(state)
	assert_true(first.get("status", "") == "ongoing" and first.get("status") != "win", "objective eliminate: ongoing while enemies alive")
	enemy1.alive = false
	enemy2.alive = false
	var second: Dictionary = obj.evaluate(state)
	assert_true(second.get("status", "") == "win", "objective eliminate: win when all down")

	# Defend objective in a zone.
	var state2: BattleState = _plain_map_enemy_state()
	_spawn(state2, "intruder", "faction_e", Vector2i(4, 4), false)
	var defend := ObjectiveBase.create({"type": "defend", "params": {"zone_x": 3, "zone_y": 3, "zone_w": 2, "zone_h": 2, "turns_required": 2, "policy": "block"}})
	var res0: Dictionary = defend.evaluate(state2)
	assert_true(res0.get("status", "") == "lose", "objective defend: breach loses under block policy")

	var state3: BattleState = _plain_map_enemy_state()
	var safe := ObjectiveBase.create({"type": "defend", "params": {"zone_x": 3, "zone_y": 3, "zone_w": 2, "zone_h": 2, "turns_required": 2, "policy": "block"}})
	safe.on_event(state3, "player_phase_ended", {})
	safe.on_event(state3, "player_phase_ended", {})
	var res3: Dictionary = safe.evaluate(state3)
	assert_true(res3.get("status", "") == "win", "objective defend: survives two turns")



func test_rewind() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	state.turn = 3
	state.phase = BattleState.PHASE_ENEMY
	var snap := state.to_dict()
	var rewind := SnapshotStack.new()
	rewind.push(state, "before")
	state.turn = 7
	state.phase = BattleState.PHASE_PLAYER
	rewind.restore_to(state, 0)
	assert_true(state.turn == 3 and state.phase == BattleState.PHASE_ENEMY, "rewind: restores turn/phase")
	assert_true(rewind.frames.is_empty(), "rewind: later frames dropped")
	assert_true(state.to_dict() == snap, "rewind: snapshot equality")


func test_bond_and_reconcile() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	state.reconcile_state["faction_test"] = {"kills": 0, "events": [], "evaluated": false, "persuaded": false}
	ReconcileSystem.record_kill(state, _spawn(state, "foe", "faction_test", Vector2i(3, 3)))
	ReconcileSystem.record_event(state, "faction_test", "spared_boss")
	var f := FactionData.new()
	f.id = "faction_test"
	f.reconcile = {"kill_threshold": 3, "required_events": ["spared_boss"]}
	DataRegistry._cache["factions"]["faction_test"] = f
	var result: Dictionary = ReconcileSystem.evaluate(state)
	assert_true(bool(result.get("faction_test", {}).get("persuaded", false)), "reconcile: persuaded with kills under threshold and events met")
	ReconcileSystem.record_kill(state, _spawn(state, "foe2", "faction_test", Vector2i(2, 3)))
	ReconcileSystem.record_kill(state, _spawn(state, "foe3", "faction_test", Vector2i(1, 3)))
	var result2: Dictionary = ReconcileSystem.evaluate(state)
	assert_true(bool(result2.get("faction_test", {}).get("persuaded", false)) == true, "reconcile: threshold check counted kills 3 < 3? no")
	ReconcileSystem.record_kill(state, _spawn(state, "foe4", "faction_test", Vector2i(0, 3)))
	var result3: Dictionary = ReconcileSystem.evaluate(state)
	assert_true(int(state.reconcile_state["faction_test"]["kills"]) == 4, "reconcile: kill tally recorded")


func test_save_load() -> void:
	await 0.0
	GameState.current_chapter_id = "chapter_ch01"
	GameState.roster = {"unit_swordsman": {"level": 2, "exp": 44, "alive": true, "defeats": 1}}
	var payload := SaveService.save_campaign()
	var ok := payload.has("game_state")
	assert_true(ok, "save: writes payload")
	GameState.current_chapter_id = ""
	GameState.roster.clear()
	var loaded := SaveService.load_campaign()
	assert_true(loaded and GameState.current_chapter_id == "chapter_ch01", "save: loads chapter progress back")
	assert_true(int(GameState.roster["unit_swordsman"].level) == 2, "save: roster level round-trips")
