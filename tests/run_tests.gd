extends Node
## Headless rule tests: run with
##   godot --headless --path . res://tests/run_tests.tscn

var failures: int = 0
var checks: int = 0


func _ready() -> void:
	await test_movement()
	await test_critical_units_down()
	await test_combat_and_forecast()
	await test_objectives()
	await test_rewind()
	await test_bond_and_reconcile()
	await test_bond_cap()
	await test_bond_rules_d05()
	await test_campaign_merge_d06()
	await test_evacuate()
	await test_terrain_costs()
	await test_save_load()
	await test_prep_scene()
	await test_main_swap_battle()
	await test_mixed_side_squad()
	await test_attack_range_checks()
	await test_rewind_nested_restore()
	await test_rewind_player_frame()
	await test_rewind_rng_not_reset()
	await test_escort()
	await test_end_phase_enemy_acts()
	await test_second_move_blocked()
	await test_forecast_confirm_attack()
	await test_forecast_matches_execution()
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


## N05 (D05): bond points flow from combat participation + adjacency; distance, enemy side
## and the per-battle cap block them; rank scenes gate on the previous rank; S is exclusive.
func test_bond_rules_d05() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var pair := BondData.new()
	pair.id = "test_pair_d05"
	pair.unit_a = "attacker"
	pair.unit_b = "partner"
	DataRegistry._cache["bonds"]["test_pair_d05"] = pair
	var attacker := _spawn(state, "attacker", "faction_p", Vector2i(0, 0), false, false, "player")
	var partner := _spawn(state, "partner", "faction_p", Vector2i(1, 0), false, false, "player")
	var foe := _spawn(state, "foe1", "faction_e", Vector2i(1, 1), false, false, "enemy")
	# Adjacent partner on the attacking player unit: points flow.
	BondSystem.reward_combat_pairs(state, attacker, foe)
	assert_true(int(state.bond_points["test_pair_d05"]) == int(DataRegistry.rule("bond_points_combat_action", 2)), "bond D05: adjacent partner earns points on attack")
	# The player unit DEFENDING with an adjacent partner earns the same reward.
	state.bond_points["test_pair_d05"] = 0
	BondSystem.reward_combat_pairs(state, foe, attacker)
	assert_true(int(state.bond_points["test_pair_d05"]) == int(DataRegistry.rule("bond_points_combat_action", 2)), "bond D05: defending earns points too")
	# Distant partner: no points.
	state.bond_points["test_pair_d05"] = 0
	partner.pos = Vector2i(5, 5)
	BondSystem.reward_combat_pairs(state, attacker, foe)
	assert_true(int(state.bond_points["test_pair_d05"]) == 0, "bond D05: distant partner earns nothing")
	partner.pos = Vector2i(1, 0)
	# A pair whose two members fight on OPPOSING sides never earns: participant must be
	# player-side AND the partner must be player-side and adjacent.
	var cross := BondData.new()
	cross.id = "test_pair_cross"
	cross.unit_a = "attacker"
	cross.unit_b = "foe1"
	DataRegistry._cache["bonds"]["test_pair_cross"] = cross
	BondSystem.reward_combat_pairs(state, attacker, foe)
	assert_true(not state.bond_points.has("test_pair_cross"), "bond D05: enemy-side pair earns nothing")
	# Heal between pair members keeps its own explicit reward.
	state.bond_points["test_pair_d05"] = 0
	partner.hp = 5
	BondSystem.reward_heal(state, attacker, partner)
	# Per-battle cap: points stop at bond_point_limit_per_pair_per_map.
	state.bond_points["test_pair_d05"] = int(DataRegistry.rule("bond_point_limit_per_pair_per_map", 20)) - 1
	BondSystem.reward_combat_pairs(state, attacker, foe)
	var cap := int(DataRegistry.rule("bond_point_limit_per_pair_per_map", 20))
	assert_true(int(state.bond_points["test_pair_d05"]) == cap, "bond D05: points stop at the per-battle cap")
	BondSystem.reward_combat_pairs(state, attacker, foe)
	assert_true(int(state.bond_points["test_pair_d05"]) == cap, "bond D05: cap holds on repeat")
	DataRegistry._cache["bonds"].erase("test_pair_d05")
	DataRegistry._cache["bonds"].erase("test_pair_cross")
	# Damage-side bonus stat: with an unlocked-rank pair adjacent to the attacker, damage
	# grows by exactly the rank bonus; the bond never feeds accuracy with the default config.
	var base_dmg := CombatResolver._damage(state, attacker, foe)
	var hit_before_pair := CombatResolver._hit_pct(state, attacker, foe)
	var dmg_pair := BondData.new()
	dmg_pair.id = "test_pair_dmg"
	dmg_pair.unit_a = "attacker"
	dmg_pair.unit_b = "partner"
	DataRegistry._cache["bonds"]["test_pair_dmg"] = dmg_pair
	GameState.bond_ranks["test_pair_dmg"] = "C"
	var bonused_dmg := CombatResolver._damage(state, attacker, foe)
	assert_true(bonused_dmg == base_dmg + int(DataRegistry.rule("bond_bonus_by_rank", {}).get("C", 3)), "bond D05: adjacency bonus reaches damage (rank C)")
	assert_true(CombatResolver._hit_pct(state, attacker, foe) == hit_before_pair, "bond D05: accuracy untouched by the bond bonus")
	DataRegistry._cache["bonds"].erase("test_pair_dmg")
	GameState.bond_ranks.erase("test_pair_dmg")
	# Rank scene gating: B only after C watched/skipped (index compare, not strings).
	var camp := CampScene.new()
	var rank_pair := BondData.new()
	rank_pair.id = "test_rank_pair"
	GameState.bond_scenes_viewed.clear()
	GameState.s_pairs.clear()
	assert_true(camp._rank_scene_unlocked(rank_pair, "C"), "bond rank: C is the entry scene")
	assert_true(not camp._rank_scene_unlocked(rank_pair, "B"), "bond rank: B stays blocked before C is watched")
	GameState.bond_scenes_viewed["test_rank_pair"] = ["C"]
	assert_true(camp._rank_scene_unlocked(rank_pair, "B"), "bond rank: B unlocks after C watched")
	assert_true(CampScene.rank_index("B") > CampScene.rank_index("C"), "bond rank: index ordering beats string ordering")
	# S exclusivity: a member already locked into an S pair blocks a second S pair.
	var s_pair := BondData.new()
	s_pair.id = "test_s_pair"
	s_pair.unit_a = "attacker"
	s_pair.unit_b = "partner"
	GameState.s_pairs["partner"] = "other_pair"
	assert_true(not camp._s_pair_free(s_pair), "bond S: member already in an S pair blocks a second one")
	GameState.s_pairs.clear()
	assert_true(camp._s_pair_free(s_pair), "bond S: free again after clearing locks")
	camp.free()



## N06 (D06): only a victory merges battle outcome into the campaign, in ONE place
## (CampaignMerge); defeat writes nothing (no EXP, no bond, no defeats counter) and the
## camp hides "Next chapter" while the current chapter is still uncleared.
func test_campaign_merge_d06() -> void:
	await 0.0
	GameState.new_game()
	GameState.build_roster()
	var chapter := GameState.current_chapter()
	var state: BattleState = _plain_map_enemy_state()
	var hero := _spawn(state, "unit_swordsman", "faction_p", Vector2i(0, 0), false, false, "player")
	hero.exp = 12
	state.bond_points = {"bond_swordsman_knight": 4}
	# Defeat: nothing merges, not even the dead unit's defeats counter.
	hero.alive = false
	CampaignMerge.merge(state, chapter, {"status": "lose"})
	assert_true(int(GameState.roster["unit_swordsman"]["exp"]) == 0, "campaign merge D06: defeat stores no EXP")
	assert_true(GameState.bond_points.is_empty(), "campaign merge D06: defeat stores no bond points")
	assert_true(int(GameState.roster["unit_swordsman"]["defeats"]) == 0, "campaign merge D06: defeat never counts a loss")
	assert_true(not GameState.completed_chapters.has(String(chapter.id)), "campaign merge D06: defeat does not complete the chapter")
	assert_true(bool(GameState.roster["unit_swordsman"]["alive"]), "campaign merge D06: roster untouched on defeat (retry replays pre-battle roster)")
	# Victory: EXP, casualties, bond, completion and reconcile all merge.
	GameState.completed_chapters.clear()
	hero.alive = true
	CampaignMerge.merge(state, chapter, {"status": "win"})
	assert_true(int(GameState.roster["unit_swordsman"]["exp"]) == 12, "campaign merge D06: win merges EXP")
	assert_true(int(GameState.bond_points.get("bond_swordsman_knight", 0)) == 4, "campaign merge D06: win merges bond points")
	assert_true(GameState.completed_chapters.has(String(chapter.id)), "campaign merge D06: win completes the chapter")
	# Camp UI: retry button while uncleared, "Next chapter" only after the chapter won.
	var second := ChapterData.new()
	second.id = "chapter_ch02"
	second.order = 2
	second.map_id = String(chapter.map_id)
	DataRegistry._cache["chapters"]["chapter_ch02"] = second
	GameState.completed_chapters.clear()
	ResultStore.last_result = {"status": "lose"}
	var camp := CampScene.new()
	add_child(camp)
	await get_tree().process_frame
	assert_true(_find_button(camp, "Retry chapter") != null and _find_button(camp, "Next chapter") == null, "camp D06: defeat shows Retry, hides Next chapter")
	ResultStore.last_result = {"status": "win"}
	GameState.completed_chapters[String(chapter.id)] = true
	var camp2 := CampScene.new()
	add_child(camp2)
	await get_tree().process_frame
	assert_true(_find_button(camp2, "Next chapter") != null and _find_button(camp2, "Retry chapter") == null, "camp D06: cleared chapter shows Next chapter")
	ResultStore.last_result = {"status": "win"}
	GameState.completed_chapters.clear()   # defensive gate: result win but chapter uncleared
	var camp3 := CampScene.new()
	add_child(camp3)
	await get_tree().process_frame
	assert_true(_find_button(camp3, "Next chapter") == null, "camp D06: Next chapter hidden while the current chapter is uncleared")
	DataRegistry._cache["chapters"].erase("chapter_ch02")
	camp.queue_free()
	camp2.queue_free()
	camp3.queue_free()


func _find_button(root: Node, text: String) -> Button:
	if root is Button and String(root.text) == text:
		return root
	for child in root.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


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
	var e1: UnitState = _spawn(director.state, "foe1", "faction_rebel_ch01", hero1.pos + Vector2i(0, -1), false, false, "enemy")
	e1.hp = 1; e1.speed = 0
	var e2: UnitState = _spawn(director.state, "foe2", "faction_rebel_ch01", hero2.pos + Vector2i(0, -1), false, false, "enemy")
	e2.speed = 0
	var e2_before: int = e2.hp
	battle._on_left_click(hero1.pos)
	battle._on_left_click(e1.pos)
	battle._confirm_forecast()   # D01: forecast opens on the red-cell click, Confirm commits
	await get_tree().create_timer(4.0).timeout
	await get_tree().process_frame
	assert_true(not e1.alive, "second target: first foe killed via clicks")
	battle._on_left_click(hero2.pos)
	battle._on_left_click(e2.pos)
	battle._confirm_forecast()
	await get_tree().create_timer(4.0).timeout
	await get_tree().process_frame
	assert_true(e2.hp < e2_before, "second target: second foe takes damage via clicks (hp %d -> %d)" % [e2_before, e2.hp])
	assert_true(hero2.acted == true, "second target: second attacker committed")
	main.queue_free()


## N01 (D01): click địch trong ô đỏ mở ForecastPanel (chưa commit); Confirm → giao chiến;
## Cancel (chuột phải là Cancel) quay lại bước chọn và KHÔNG commit gì cả.
func test_forecast_confirm_attack() -> void:
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
	var defender := _spawn(director.state, "dummy_foe", "faction_rebel_ch01", map.deploy_cells[0] + Vector2i(1, 0), false, false, "enemy")
	var combat_calls := [0]
	EventBus.combat_resolved.connect(func(_s: Array) -> void: combat_calls[0] += 1)
	var hero: UnitState = director.state.units["unit_swordsman"]
	battle._on_left_click(hero.pos)                 # select — không có menu Attack/Wait
	assert_true(battle._action_menu.get_child_count() == 0, "forecast: no attack/wait buttons in menu")
	var hp_before: int = defender.hp
	battle._on_left_click(defender.pos)             # click địch trong ô đỏ → forecast, chưa commit
	assert_true(battle.mode == BattleScene.Mode.CONFIRM_ATTACK, "forecast: red-cell click opens the confirm state")
	assert_true(battle._forecast_panel != null, "forecast: panel is visible")
	assert_true(hero.acted == false and defender.hp == hp_before, "forecast: nothing committed before Confirm")
	# Cancel: quay lại bước chọn, vẫn giữ selection, không combat nào nổ ra.
	battle._on_right_click(defender.pos)
	assert_true(combat_calls[0] == 0, "forecast: cancel commits nothing")
	assert_true(battle.mode == BattleScene.Mode.UNIT_SELECTED, "forecast: cancel returns to the selection step")
	assert_true(hero.acted == false and defender.hp == hp_before, "forecast: cancel leaves state intact")
	# Confirm: cùng mục tiêu, cùng vị trí, giao chiến theo forecast đã xem.
	battle._on_left_click(defender.pos)
	battle._confirm_forecast()
	assert_true(battle._forecast_panel == null, "forecast: panel closes on Confirm")
	await get_tree().create_timer(4.0).timeout
	await get_tree().process_frame
	assert_true(combat_calls[0] >= 1, "forecast: resolver strike list was played after Confirm")
	assert_true(hero.acted == true, "forecast: attacker committed after Confirm")
	assert_true(battle.mode == BattleScene.Mode.IDLE, "forecast: flow returns to idle after combat screen")
	assert_true(defender.hp <= hp_before and defender.hp >= 0, "forecast: defender HP updated on the map state")
	main.queue_free()


## N01 (D01): số trong forecast của CombatResolver trùng với HP mất trên map khi hit là
## 100%/crit 0 — "preview = combat = HP". Forecast cũng phải chứa double attack cùng bonus
## bond vì nó gọi chính _strike_plan của execute().
func test_forecast_matches_execution() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var attacker := _spawn(state, "atk_f", "faction_p", Vector2i(0, 0), false, false, "player")
	attacker.power = 10
	attacker.defense = 2
	attacker.crit_bonus = -200      # deterministic: never crit
	attacker.speed = 0
	var defender := _spawn(state, "def_f", "faction_e", Vector2i(1, 0), false, false, "enemy")
	defender.speed = 0              # hit clamps at 100, no double for either side
	var forecast := CombatResolver.forecast(state, attacker, defender)
	assert_true(int(forecast["sequence"][0]["hit_pct"]) == 100, "forecast parity: deterministic hit 100 setup")
	var expected_dmg := int(forecast["sequence"][0]["damage"])
	assert_true(expected_dmg > 0, "forecast parity: damage is positive")
	var hp_before: int = defender.hp
	var strikes := CombatResolver.execute(state, attacker, defender)
	assert_true(strikes.size() >= 1 and bool(strikes[0]["hit"]), "forecast parity: first strike hits as previewed")
	assert_true(int(defender.hp) == hp_before - expected_dmg, "forecast parity: HP loss equals the forecast damage (%d)" % expected_dmg)
	# Double attack flows into the forecast (same _strike_plan as execution).
	attacker.speed = 10
	var forecast_double := CombatResolver.forecast(state, attacker, defender)
	var attacker_strikes := 0
	for entry in forecast_double["sequence"]:
		if String(entry["side"]) == "attacker":
			attacker_strikes += 1
	assert_true(attacker_strikes == 2, "forecast parity: double attack appears in the sequence")
	# The panel is a pure display built from the same dictionary.
	var panel := ForecastPanel.build(forecast, attacker, defender)
	assert_true(panel.get_child_count() > 0, "forecast panel: rendered without recalculation")
	panel.free()


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
	# D02: protagonist and must_survive units deploy checked + disabled (no manual unlock).
	assert_true(prep._checks.has("unit_swordsman") and prep._checks["unit_swordsman"].disabled, "prep: protagonist locked in deploy")
	assert_true(prep._checks.has("unit_beastwoman") and prep._checks["unit_beastwoman"].button_pressed and prep._checks["unit_beastwoman"].disabled, "prep: must_survive unit locked in deploy")
	prep.queue_free()


## N02 (D02): any critical unit down = immediate loss; regular units may fall freely.
func test_critical_units_down() -> void:
	await 0.0
	# Protagonist down loses.
	var state: BattleState = _plain_map_enemy_state()
	var director := director_for(state)
	var hero := _spawn(state, "hero", "faction_p", Vector2i(0, 0), true, false, "player")
	_spawn(state, "witness", "faction_p", Vector2i(2, 0), false, false, "player")   # waits, alive
	hero.alive = false
	director.commit("wait", {"unit_id": "witness"})   # triggers _on_state_changed
	assert_true(String(state.battle_over.get("status", "")) == "lose", "critical: protagonist down loses")
	# must_survive down loses.
	var state2: BattleState = _plain_map_enemy_state()
	var director2 := director_for(state2)
	_spawn(state2, "heroine", "faction_p", Vector2i(0, 0), false, false, "player")
	state2.units["heroine"].must_survive = true
	_spawn(state2, "guard", "faction_p", Vector2i(1, 0), false, false, "player")
	state2.units["heroine"].alive = false
	director2.commit("wait", {"unit_id": "guard"})
	assert_true(String(state2.battle_over.get("status", "")) == "lose", "critical: must_survive down loses")
	# Regular units never trigger the loss.
	var state3: BattleState = _plain_map_enemy_state()
	var director3 := director_for(state3)
	_spawn(state3, "guard2", "faction_p", Vector2i(0, 0), false, false, "player")
	state3.units["guard2"].alive = false
	_spawn(state3, "witness2", "faction_p", Vector2i(2, 0), false, false, "player")
	director3.commit("wait", {"unit_id": "witness2"})
	assert_true(state3.battle_over.is_empty(), "critical: regular unit down does not lose")


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
	# The path around the enemy (2,0)->(2,1)->(2,2) never crosses the occupied cell.
	assert_true(move_cells.has(Vector2i(2, 2)), "movement: reaches the far side around the enemy")
	# Move onto ally cell forbidden (can't end on occupied):
	assert_true(not move_cells.has(Vector2i(1, 0)), "movement: cannot end on ally tile")
	# Blocked wall at (1,1) thus leftmost column below only reachable around:
	assert_true(move_cells.has(Vector2i(0, 3)), "movement: around the wall")
	var reach_enemy := MovementHandler.compute_move_cells(state, enemy)
	assert_true(not reach_enemy.has(Vector2i(0, 0)), "movement: mover passes; enemy range blocked by walls")


func _spawn(state: BattleState, id: String, faction: String, pos: Vector2i, prot: bool = false, make_walls: bool = false, side: String = "") -> UnitState:
	var u := UnitState.new()
	u.id = id
	u.display_name = id
	u.faction_id = faction
	u.is_protagonist = prot
	# Derived control side by convention (tests never rely on faction for control).
	u.side = side if side != "" else ("enemy" if faction.ends_with("_e") or faction.ends_with("_test") else "npc" if faction.ends_with("_npc") else "player")
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


# ------------------------------------------------------------------ review fixes T01-T06

## T01: mixed Empire+Kingdom squad on one player side: allies never appear as attack
## targets, ally pass-through works across factions, eliminate counts only enemy side.
func test_mixed_side_squad() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var emp := _spawn(state, "emp", "faction_empire", Vector2i(0, 0), false, false, "player")
	emp.attack_range_max = 2
	_spawn(state, "kin", "faction_kingdom", Vector2i(1, 0), false, false, "player")
	var foe := _spawn(state, "foe", "faction_rebel", Vector2i(1, 1), false, false, "enemy")
	var targets := RangeHandler.compute_targets_from_position(state, emp)
	assert_true(targets.has("foe"), "mixed squad: enemy is a valid target")
	assert_true(not targets.has("kin"), "mixed squad: cross-faction ally is never a target")
	# Pass-through over the cross-faction ally's cell (never an END cell).
	var pass_cells := MovementHandler.compute_move_cells(state, emp)
	assert_true(pass_cells.has(Vector2i(2, 0)), "mixed squad: walk-through cross-faction ally allowed")
	# Attack check must reject the ally by side, not by faction.
	var err := AttackCommand.check(state, state.units["emp"], "kin")
	assert_true(err == "Cannot attack an ally.", "mixed squad: AttackCommand rejects cross-faction ally")
	var cmd_err := AttackCommand.check(state, state.units["emp"], "foe")
	assert_true(cmd_err == "", "mixed squad: enemy of other side is attackable")
	# Eliminate counts only enemy-side units.
	var obj := ObjectiveBase.create({"type": "eliminate", "params": {}})
	assert_true(String(obj.evaluate(state)["status"]) == "ongoing", "mixed squad: eliminate ongoing while enemy alive")
	foe.alive = false
	assert_true(String(obj.evaluate(state)["status"]) == "win", "mixed squad: eliminate wins without touching player-side units")


## T02: attacks happen only inside real weapon range from the standing position; carrier
## move-only; refused AI move degrades to Wait instead of a free-range attack.
func test_attack_range_checks() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var melee := _spawn(state, "melee", "faction_p", Vector2i(0, 0), false, false, "player")
	melee.attack_range_min = 1
	melee.attack_range_max = 1
	var far := _spawn(state, "far", "faction_e", Vector2i(0, 3), false, false, "enemy")
	assert_true(director_commit_attack(state, melee, "far") == false, "range: melee cannot attack at distance 3")
	assert_true(melee.acted == false, "range: refused attack leaves the unit free to act")
	var adj := _spawn(state, "adj", "faction_e", Vector2i(1, 0), false, false, "enemy")
	assert_true(director_commit_attack(state, melee, "adj") == true, "range: melee attacks at distance 1")
	var ranged_attack := _spawn(state, "ranged", "faction_p", Vector2i(5, 0), false, false, "player")
	ranged_attack.attack_range_min = 1
	ranged_attack.attack_range_max = 2
	var target2 := _spawn(state, "t2", "faction_e", Vector2i(5, 2), false, false, "enemy")
	_spawn(state, "t3", "faction_e", Vector2i(5, 3), false, false, "enemy")
	assert_true(director_commit_attack(state, ranged_attack, "t2") == true, "range: ranged can attack at distance 2")
	var attacker_r3 := _spawn(state, "r3", "faction_p", Vector2i(9, 0), false, false, "player")
	attacker_r3.attack_range_min = 1
	attacker_r3.attack_range_max = 2
	var t3 := _spawn(state, "t3b", "faction_e", Vector2i(9, 3), false, false, "enemy")
	var hp3: int = t3.hp
	assert_true(director_commit_attack(state, attacker_r3, "t3b") == false and t3.hp == hp3, "range: ranged cannot attack at distance 3")
	# Carrier (retrieve objective) may only move.
	var carrier := _spawn(state, "carrier", "faction_p", Vector2i(0, 4), false, false, "player")
	carrier.carried_item = "item_border_relic"
	state.objectives_config = [{"type": "retrieve", "params": {"item_id": "item_border_relic", "exit_zone_x": 0, "exit_zone_y": 0}}]
	var foe1 := _spawn(state, "foe1b", "faction_e", Vector2i(1, 4), false, false, "enemy")
	assert_true(AttackCommand.check(state, carrier, "foe1b") == "Carrier may only move.", "range: carrier cannot attack")
	# AI: refused move falls back to Wait, no attack executed (snapshot omission aside).
	adj.hp = 999
	var ai := _spawn(state, "ai", "faction_e", Vector2i(4, 4), false, false, "enemy")
	var hero_before: int = melee.hp
	var plan := {"unit_id": ai.id, "move_cell": Vector2i(1, 0)}   # occupied by a player unit -> move refused
	plan["target_id"] = "melee"
	director_commit_ai(state, plan)
	assert_true(melee.hp == hero_before, "range: AI refused move (occupied target) does not attack from stale range")
	assert_true(ai.acted == true, "range: AI fallback ends the AI action as wait")


## T03: rewind restores NESTED containers (counters, reconcile kills, bond points, items)
## and never double-counts a kill after restore.
func test_rewind_nested_restore() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	state.reconcile_state["faction_test"] = {"kills": 0, "events": [], "evaluated": false, "persuaded": false}
	state.objective_counters = {"defend_turns": 1}
	state.bond_points = {"pair_x": 1}
	state.item_ground = {"1,1": "item_border_relic"}
	var snap_before := state.to_dict()
	# Diverge from the snapshot.
	var foe := _spawn(state, "victim", "faction_test", Vector2i(3, 3), false, false, "enemy")
	foe.alive = false
	ReconcileSystem.record_kill(state, foe)
	ReconcileSystem.record_event(state, "faction_test", "spared_boss")
	state.objective_counters["defend_turns"] = 4
	state.bond_points["pair_x"] = 7
	state.item_ground["2,2"] = "item_border_relic"
	# The stored snapshot stays untouched by later mutations (deep copy out).
	assert_true(int(snap_before["reconcile_state"]["faction_test"]["kills"]) == 0, "rewind: snapshot dict is isolated from live state")
	# Restore.
	var stack := SnapshotStack.new()
	state.from_dict(snap_before)
	assert_true(int(state.reconcile_state["faction_test"]["kills"]) == 0, "rewind: nested reconcile kills restored")
	assert_true(int(state.objective_counters["defend_turns"]) == 1, "rewind: objective counters restored")
	assert_true(int(state.bond_points["pair_x"]) == 1, "rewind: bond points restored")
	assert_true(not state.item_ground.has("2,2") and String(state.item_ground.get("1,1", "")) == "item_border_relic", "rewind: ground items restored")
	# Kill counted again after restore of the SAME death must stay at 1, not 2.
	var foe_again := _spawn(state, "victim2", "faction_test", Vector2i(0, 3), false, false, "enemy")
	foe_again.death_recorded = false
	ReconcileSystem.record_kill(state, foe_again)
	assert_true(int(state.reconcile_state["faction_test"]["kills"]) == 1, "rewind: no double kill count after restore")


## T03: restoration targets only PLAYER-phase frames; turning to player state pushes a
## turn_start frame so rewinding at the top of turn 2 never leaves the battle in NPC phase.
## N04 (D04): RNG is not snapshot-restored; a rewind continues the same sequence.
func test_rewind_rng_not_reset() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var before: Array = [state.rng().randi(), state.rng().randi()]
	var d := state.to_dict()
	state.from_dict(d)
	var after := [state.rng().randi(), state.rng().randi()]
	assert_true(before != after, "rewind rng: restore does not reset the random sequence")


func test_rewind_player_frame() -> void:
	await 0.0
	GameState.new_game()
	GameState.build_roster()
	var map := DataRegistry.get_map("map_ch01")
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	director.commit("move", {"unit_id": "unit_swordsman", "cell": map.deploy_cells[0]})
	director.commit("wait", {"unit_id": "unit_swordsman"})
	director.advance_after_enemy_phase()
	director.advance_to_player_phase()
	assert_true(director.state.turn == 2, "rewind flow: turn advanced to 2")
	var frame := director.rewind.find_last_player_frame()
	assert_true(frame >= 0, "rewind flow: a player frame exists")
	assert_true(int(director.rewind.frames[frame]["snapshot"]["phase"]) == BattleState.PHASE_PLAYER, "rewind flow: the newest player frame is PLAYER phase")
	assert_true(director.rewind.find_last_player_frame() == director.rewind.frames.size() - 1, "rewind flow: turn_start snapshot is the newest frame")
	director.use_rewind(frame)
	assert_true(director.state.phase == BattleState.PHASE_PLAYER, "rewind flow: restore never lands in enemy/NPC phase")



## T04: escort objective measures the REAL target cell and NpcAI walks the NPC there.
func test_escort() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var npc := _spawn(state, "escortee", "faction_npc", Vector2i(0, 0), false, false, "npc")
	state.npc_unit_ids = ["escortee"]
	var escort := ObjectiveBase.create({"type": "escort", "params": {"npc_unit_id": "escortee", "target_cell_x": 3, "target_cell_y": 3}})
	assert_true(String(escort.evaluate(state)["status"]) == "ongoing", "escort: ongoing away from the target")
	# A stale (0,0) answer would falsely WIN here; the real cell must be used.
	assert_true(npc.pos != escort.target_cell() and String(escort.evaluate(state)["status"]) != "win", "escort: no false win at (0,0)")
	var plan := NpcAI.plan_walk(state, npc, escort.target_cell())
	assert_true(not plan.is_empty() and String(plan["unit_id"]) == "escortee", "escort: NpcAI plans the walk")
	assert_true(MoveCommand.apply(state, npc, plan["move_cell"]), "escort: plan applies through the same move command")
	while npc.pos != escort.target_cell():
		var p := NpcAI.plan_walk(state, npc, escort.target_cell())
		assert_true(MoveCommand.apply(state, npc, p["move_cell"]), "escort: walking loop applies")
	assert_true(String(escort.evaluate(state)["status"]) == "win", "escort: win at the real destination")
	npc.alive = false
	assert_true(String(escort.evaluate(state)["status"]) == "lose", "escort: NPC down loses")


# ------------------------------------------------------------------ helpers

## Headless director wrapper for pure state tests (no scene): only wires objectives.
func director_for(state: BattleState) -> BattleDirector:
	var d := BattleDirector.new()
	d.state = state
	d.rewind = SnapshotStack.new()
	d.objectives = []
	for cfg in state.objectives_config:
		var obj := ObjectiveBase.create(cfg)
		if obj != null:
			d.objectives.append(obj)
	d.rewind_budget = -1
	d.rewind_uses_left = -1
	return d


func director_commit_attack(state: BattleState, unit: UnitState, target_id: String) -> bool:
	return director_for(state).commit("attack", {"unit_id": unit.id, "target_id": target_id})


func director_commit_ai(state: BattleState, plan: Dictionary) -> void:
	director_for(state).commit_ai_plan(plan)


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
	assert_true(String(strikes[0]["side"]) == "attacker", "combat: first strike is attacker side")


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
	assert_true(bool(result["faction_test"]["persuaded"]), "reconcile: persuaded with kills 1 < 3 and event met")
	# Kills reaching the threshold -> not persuaded.
	ReconcileSystem.record_kill(state, _spawn(state, "foe2", "faction_test", Vector2i(2, 3)))
	ReconcileSystem.record_kill(state, _spawn(state, "foe3", "faction_test", Vector2i(1, 3)))
	var result2: Dictionary = ReconcileSystem.evaluate(state)
	assert_true(not bool(result2["faction_test"]["persuaded"]), "reconcile: not persuaded when kills reach the threshold (3/3)")
	var result3: Dictionary = ReconcileSystem.evaluate(state)
	assert_true(result3["faction_test"]["persuaded"] == result2["faction_test"]["persuaded"], "reconcile: evaluate is idempotent (same data -> same result)")
	assert_true(int(state.reconcile_state["faction_test"]["kills"]) == 3, "reconcile: kill tally recorded")
	# A required event never recorded -> not persuaded (independent of kills).
	state.reconcile_state["faction_alone"] = {"kills": 0, "events": [], "evaluated": false, "persuaded": false}
	var f2 := FactionData.new()
	f2.id = "faction_alone"
	f2.reconcile = {"kill_threshold": 99, "required_events": ["surrender_flag"]}
	DataRegistry._cache["factions"]["faction_alone"] = f2
	ReconcileSystem.record_event(state, "faction_alone", "dialog_deal")   # wrong event key
	var result4: Dictionary = ReconcileSystem.evaluate(state)
	assert_true(result4["faction_alone"]["persuaded"] == false and result4["faction_alone"]["missing_events"].has("surrender_flag"), "reconcile: not persuaded when a required event is missing")


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
