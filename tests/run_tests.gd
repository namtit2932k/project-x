extends Node
## Headless rule tests: run with
##   godot --headless --path . res://tests/run_tests.tscn

var failures: int = 0
var checks: int = 0


func _ready() -> void:
	await test_movement()
	await test_critical_units_down()
	await test_combat_and_forecast()
	await test_fe_formula()
	await test_class_passives()
	await test_bard_encore()
	await test_skill_target_selection()
	await test_heal_formula()
	await test_forecast_passive_notes()
	await test_i18n()
	await test_enemy_difficulty_scaling()
	await test_objectives()
	await test_rewind()
	await test_bond_and_reconcile()
	await test_bond_cap()
	await test_bond_rules_d05()
	await test_campaign_merge_d06()
	await test_game_over_screen()
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
	await test_capture_zones_contested()
	await test_reconcile_hud()
	await test_story_flags_and_ending()
	await test_pause_menu()
	await test_exp_and_levels()
	await test_exp_rewind_and_growth_table()
	await test_exp_merge_and_replay()
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
	# P-02: the adjacency bonus lands on EVERY configured target group (accuracy, avoid,
	# crit, damage). Damage grows by the rank bonus and accuracy now benefits too — the old
	# D05 "never feeds accuracy" expectation was superseded by P-02 (AGENTS.md (censored)).
	var base_dmg := CombatResolver._damage(state, attacker, foe)
	# F-CC-FE: Accuracy = hit_base(70) + skill*2(10) + hit_bonus, Avoid = foe.speed*2 = 12 (defaults).
	# hit_bonus -18 puts raw Hit at 50, clear of the 0/100 clamp, so the bond bonus stays visible.
	attacker.hit_bonus = -18
	var hit_base_no_pair := CombatResolver._hit_pct(state, attacker, foe)
	var dmg_pair := BondData.new()
	dmg_pair.id = "test_pair_dmg"
	dmg_pair.unit_a = "attacker"
	dmg_pair.unit_b = "partner"
	DataRegistry._cache["bonds"]["test_pair_dmg"] = dmg_pair
	GameState.bond_ranks["test_pair_dmg"] = "C"
	var bonused_dmg := CombatResolver._damage(state, attacker, foe)
	assert_true(bonused_dmg == base_dmg + int(DataRegistry.rule("bond_bonus_by_rank", {}).get("C", 3)), "bond P-02: adjacency bonus reaches damage (rank C)")
	assert_true(CombatResolver._hit_pct(state, attacker, foe) == hit_base_no_pair + int(DataRegistry.rule("bond_bonus_by_rank", {}).get("C", 3)), "bond P-02: accuracy now benefits from the adjacency bonus")
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



## N06 (D06): only a victory merges the battle outcome into the campaign, in ONE place
## (CampaignMerge). Designer (F-EXP): losing is a game over, so a defeat keeps no EXP either
## (action_exp_commits_on_defeat off by default; the flag-on path is still covered).
## Defeat writes no bond, no casualties, no defeats counter, and the camp hides "Next
## chapter" while the current chapter is still uncleared.
func test_campaign_merge_d06() -> void:
	await 0.0
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var chapter := GameState.current_chapter()
	var state: BattleState = _plain_map_enemy_state()
	var hero := _spawn(state, "unit_swordsman", "faction_p", Vector2i(0, 0), false, false, "player")
	hero.exp = 12
	state.bond_points = {"bond_swordsman_knight": 4}
	hero.alive = false
	# Default (designer: losing = game over): a defeat merges nothing at all, EXP included.
	var rules: Resource = DataRegistry.rules()
	assert_true(not bool(rules.get("action_exp_commits_on_defeat")), "campaign merge: defeat-keeps-EXP flag is off by default")
	CampaignMerge.merge(state, chapter, {"status": "lose"})
	assert_true(int(GameState.roster["unit_swordsman"]["exp"]) == 0, "campaign merge D06: defeat stores no EXP")
	# Optional flag-on path (GDD Dual Restraint edge case): only the EXP part would merge.
	rules.set("action_exp_commits_on_defeat", true)
	CampaignMerge.merge(state, chapter, {"status": "lose"})
	assert_true(int(GameState.roster["unit_swordsman"]["exp"]) == 12, "campaign merge (flag on): defeat keeps only the action EXP")
	rules.set("action_exp_commits_on_defeat", false)
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


## Designer (08-11-2026): a lost battle opens the Game Over screen with Retry chapter and
## Main menu — no results screen, no camp, nothing merged.
func test_game_over_screen() -> void:
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var chapter := GameState.current_chapter()
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	ResultStore.last_result = {"status": "lose", "reason": "critical_unit_down", "unit_id": "unit_swordsman"}
	main._show_post_battle(false)
	await get_tree().process_frame
	var over: GameOverScene = main._current as GameOverScene
	assert_true(over != null, "game over: a defeat opens the Game Over screen")
	assert_true(over != null and _find_button(over, "Retry chapter") != null and _find_button(over, "Main menu") != null, "game over: Retry chapter and Main menu offered")
	assert_true(GameOverScene.reason_text(ResultStore.last_result).contains("Swordsman"), "game over: names the fallen critical unit")
	assert_true(GameOverScene.reason_text({"status": "lose"}).contains("objective"), "game over: objective failure reason")
	assert_true(not GameState.completed_chapters.has(String(chapter.id)), "game over: chapter not completed")
	var retried := [false]
	over.retry_pressed.connect(func() -> void: retried[0] = true)
	_find_button(over, "Retry chapter").pressed.emit()
	assert_true(retried[0], "game over: Retry chapter button emits retry")
	main.queue_free()


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
	attacker.skill = 60   # F-CC1/F-CC3: Accuracy 120 vs Avoid 0 — certain hits for this routing test
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
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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
	# F-CC3 hit chances are low with real stats; this test checks click routing, so make hits certain.
	hero1.skill = 60
	hero2.skill = 60
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
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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
	attacker.skill = 60             # F-CC1/F-CC3: Accuracy=skill*2, comfortably over any Avoid below
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
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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


func test_reconcile_hud() -> void:
	## N10: chip per remnant faction, attitude flips on kills, feedback dialogue plays
	## on the transition, and rewind displays the restored attitude again.
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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
	assert_true(battle._reconcile_chip_box != null and battle._reconcile_chip_box.get_child_count() == 1, "reconcile: one chip for the remnant faction")
	assert_true(battle._reconcile_notice != null and battle._reconcile_notice.visible, "reconcile: battle-start limit-kills warning shown")
	var chip: VBoxContainer = battle._reconcile_chip_box.get_child(0)
	assert_true((chip.get_child(1) as Label).text.contains("Neutral"), "reconcile: chip starts Neutral (event not yet recorded, kills 0 is neutral per attitude() rules)")
	# Kill a rebel unit: the chip flips to Lost and its feedback dialogue appears
	# (transitions read the FactionData.feedback ids).
	var commander: UnitState = director.state.units["unit_rebel_commander"]
	var hero: UnitState = director.state.units["unit_swordsman"]
	commander.hp = 1
	commander.defense = 0     # deterministic kill for the chip test
	hero.skill = 60           # F-CC3: Accuracy 120+ makes the hit certain whatever the terrain
	commander.pos = hero.pos + Vector2i(1, 0)
	director.commit("attack", {"unit_id": hero.id, "target_id": commander.id})
	await get_tree().process_frame   # chip children are queue_free'd: one frame to settle
	chip = battle._reconcile_chip_box.get_child(0)
	assert_true((chip.get_child(1) as Label).text.contains("Lost"), "reconcile: kill flips the chip to Lost")
	var feedback_seen := [false]
	for child in battle.get_children():
		if child is CanvasLayer:
			for c in child.get_children():
				if c is DialoguePlayer:
					feedback_seen[0] = true
	assert_true(feedback_seen[0], "reconcile: feedback dialogue played on the attitude transition")
	# Rewind: the attitude is restored and the chip must show it again (display follows state).
	battle._on_rewind()
	await get_tree().process_frame   # rewind refreshes the HUD on a future-resolved signal
	chip = battle._reconcile_chip_box.get_child(0)
	assert_true((chip.get_child(1) as Label).text.contains("Neutral"), "reconcile: rewind restores the pre-kill chip")
	main.queue_free()

	# PrepScreen carries the same warning when the map has a remnant faction (T12 detail).
	var prep := PrepScene.build(chapter)
	add_child(prep)
	await get_tree().process_frame
	var found := [false]
	for label_child in prep.get_children():
		if label_child is PanelContainer:
			for line in label_child.get_children():
				if line is VBoxContainer:
					for text_node in line.get_children():
						if text_node is Label and String(text_node.text).find("persuade the remnants") >= 0:
							found[0] = true
	assert_true(found[0], "reconcile: prep screen shows the limit-kills note")
	prep.free()


func test_pause_menu() -> void:
	## N08: Esc opens the pause menu, blocks map clicks and the enemy phase loop until
	## Resume; Quit-to-menu fires the dedicated signal (no merge path).
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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
	var hero: UnitState = director.state.units["unit_swordsman"]
	battle._toggle_pause()
	assert_true(battle.paused and battle._pause_menu != null, "pause: toggle opens the menu")
	battle._on_left_click(hero.pos)   # blocked while paused
	assert_true(battle.selected_unit_id == "", "pause: map clicks do nothing while paused")
	battle._on_end_phase()            # blocked: banner/phase machinery stalls
	assert_true(director.state.phase == BattleState.PHASE_PLAYER, "pause: end-of-phase refused while paused")
	# The enemy phase loop parks: start it with a foe ready, plan must not execute.
	var foe := _spawn(director.state, "pause_foe", "faction_rebel_ch01", hero.pos + Vector2i(3, 0), false, false, "enemy")
	director.state.phase = BattleState.PHASE_ENEMY
	# Fire-and-forget start: the coroutine parks on its pause gate until Resume.
	get_tree().create_timer(0.0).timeout.connect(battle._run_enemy_phase)
	await get_tree().create_timer(0.5).timeout
	assert_true(foe.acted == false, "pause: enemy plans stall while paused")
	# Resume: the parked loop resumes and the enemy acts through the director.
	battle._on_resume()
	assert_true(battle.paused == false, "pause: resume clears the flag")
	await get_tree().create_timer(1.2).timeout
	assert_true(foe.acted == true, "pause: after resume the enemy phase proceeds")
	# Quit signal wiring: dedicated path, not battle_finished.
	var quit_seen: Array = [false]
	battle.quit_to_menu.connect(func() -> void: quit_seen[0] = true)
	battle._pause_menu = null   # detached state: fire the pause quit lambda path
	battle.paused = false
	battle._toggle_pause()
	assert_true(battle._pause_menu != null, "pause: re-open works")
	battle._pause_menu.quit_to_menu.emit()
	assert_true(quit_seen[0], "pause: quit emits the dedicated signal (no merge)")
	main.queue_free()


func test_exp_and_levels() -> void:
	## F-EXP (GDD core-combat Core Rule 12, F-CC13/F-CC14, AC-CC78–84): a flat EXP per Attack
	## or Heal for the acting player unit only; ONE level-up resolution with class growth
	## rates, stat caps, HP heal on HP growth, and EXP discarded at the level cap.
	await 0.0
	assert_true(bool(DataRegistry.rule("exp_enabled", false)), "exp: on by default (F-EXP supersedes P-04)")
	var per_action := int(DataRegistry.rule("exp_per_action", 25))
	var per_level := int(DataRegistry.rule("exp_per_level", 100))
	var level_cap := int(DataRegistry.rule("level_cap", 20))
	assert_true(per_action == 25 and per_level == 100 and level_cap == 20, "exp: GDD numbers 25 / 100 / 20")
	var state: BattleState = _plain_map_enemy_state()
	# AC-CC78: a player Attack that misses still pays the flat amount; the enemy defender banks nothing.
	var striker := _spawn(state, "striker", "faction_p", Vector2i(0, 0), false, false, "player")
	striker.hit_bonus = -999          # deterministic miss (Hit% clamps to 0)
	var target := _spawn(state, "target", "faction_e", Vector2i(1, 0), false, false, "enemy")
	CombatResolver.execute(state, striker, target)
	assert_true(int(striker.exp) == per_action, "exp: a missed Attack still pays %d (got %d)" % [per_action, striker.exp])
	assert_true(int(target.exp) == 0, "exp: the enemy defender banks nothing")
	assert_true(int(state.exp_gained.get("striker", 0)) == per_action, "exp: result tracking records the action EXP")
	# AC-CC80 + only the acting unit earns: an enemy attacker earns nothing, the attacked player neither.
	var raider := _spawn(state, "raider", "faction_e", Vector2i(3, 0), false, false, "enemy")
	raider.hit_bonus = -999
	var guard := _spawn(state, "guard", "faction_p", Vector2i(4, 0), false, false, "player")
	CombatResolver.execute(state, raider, guard)
	assert_true(int(raider.exp) == 0, "exp: an enemy attacker never earns EXP")
	assert_true(int(guard.exp) == 0, "exp: being attacked (and countering) pays nothing")
	# AC-CC78: a kill pays exactly the same flat amount as a miss.
	var killer := _spawn(state, "killer", "faction_p", Vector2i(6, 0), false, false, "player")
	killer.power = 900
	killer.skill = 60                 # Accuracy 120 vs Avoid 0: certain hit
	killer.crit_bonus = -500
	var victim := _spawn(state, "victim", "faction_e", Vector2i(7, 0), false, false, "enemy")
	victim.hp = 1
	victim.speed = 0
	CombatResolver.execute(state, killer, victim)
	assert_true(not victim.alive, "exp: kill setup landed")
	assert_true(int(killer.exp) == per_action, "exp: a kill pays the same flat %d (got %d)" % [per_action, killer.exp])
	assert_true(int(victim.exp) == 0, "exp: the slain unit banks nothing")
	# F-CC13: a Heal pays the healer the same flat amount; the healed unit earns nothing.
	var healer := _spawn(state, "healer", "faction_p", Vector2i(0, 2), false, false, "player")
	var patient := _spawn(state, "patient", "faction_p", Vector2i(1, 2), false, false, "player")
	patient.hp = 5
	assert_true(SkillCommand.check(state, healer, "skill_heal", patient) == "", "exp: heal setup is legal")
	SkillCommand.apply(state, healer, "skill_heal", patient)
	assert_true(int(healer.exp) == per_action, "exp: a Heal pays the healer %d (got %d)" % [per_action, healer.exp])
	assert_true(int(patient.exp) == 0, "exp: the healed unit earns nothing")
	# Designer (08-11-2026): a unit that dies earns nothing, even for its own Attack.
	var doomed := _spawn(state, "doomed", "faction_p", Vector2i(3, 2), false, false, "player")
	doomed.hp = 1
	doomed.hit_bonus = -999
	var brute := _spawn(state, "brute", "faction_e", Vector2i(4, 2), false, false, "enemy")
	brute.power = 900
	brute.skill = 60
	brute.crit_bonus = -500
	CombatResolver.execute(state, doomed, brute)
	assert_true(not doomed.alive and int(doomed.exp) == 0, "exp: an attacker felled by the counter earns nothing")
	# Designer: a full-HP ally cannot be healed, so there is no Heal EXP from it either.
	var medic := _spawn(state, "medic", "faction_p", Vector2i(2, 3), false, false, "player")
	var fresh := _spawn(state, "fresh", "faction_p", Vector2i(1, 3), false, false, "player")
	assert_true(SkillCommand.check(state, medic, "skill_heal", fresh) == "Target already at full HP.", "heal: a full-HP ally cannot be healed")
	# The data flag still switches the whole mechanic off.
	var rules: Resource = DataRegistry.rules()
	var previous_exp_flag: bool = bool(rules.get("exp_enabled"))
	rules.set("exp_enabled", false)
	var idle := _spawn(state, "idle", "faction_p", Vector2i(0, 4), false, false, "player")
	ExpSystem.grant_action_exp(state, idle)
	rules.set("exp_enabled", previous_exp_flag)
	assert_true(int(idle.exp) == 0, "exp: exp_enabled = false grants nothing")

	# F-CC14 / AC-CC81: one gain can cross several levels; each level rolls every growth stat once.
	var state2: BattleState = _plain_map_enemy_state()
	var lev := _spawn(state2, "lev", "faction_p", Vector2i(0, 0), false, false, "player")
	lev.growths = {"str": 100, "speed": 0}
	lev.level = 5
	lev.exp = 95
	var power_before: int = lev.power
	var speed_before: int = lev.speed
	ExpSystem.resolve_level_up(state2, lev, 210)
	assert_true(lev.level == 8 and int(lev.exp) == 5, "levels: 95 + 210 EXP -> level 8, exp 5 (got L%d, %d)" % [lev.level, lev.exp])
	assert_true(lev.power == power_before + 3, "levels: 100%% growth grants str once per level (+3)")
	assert_true(lev.speed == speed_before, "levels: 0%% growth never grants speed")
	assert_true(int(lev.stat_bonus.get("str", 0)) == 3, "levels: this battle's stat_bonus records str+3")
	assert_true(state2.level_ups.size() == 3, "levels: three level-up entries recorded")
	# Legacy growth keys still resolve (atk -> power).
	var legacy := _spawn(state2, "legacy", "faction_p", Vector2i(1, 0), false, false, "player")
	legacy.growths = {"atk": 100}
	var legacy_power: int = legacy.power
	ExpSystem.resolve_level_up(state2, legacy, per_level)
	assert_true(legacy.power == legacy_power + 1, "levels: legacy 'atk' growth key raises power")
	# AC-CC83: an HP gain raises current HP too.
	var hurt := _spawn(state2, "hurt", "faction_p", Vector2i(2, 0), false, false, "player")
	hurt.growths = {"hp": 100}
	hurt.hp = 10
	ExpSystem.resolve_level_up(state2, hurt, per_level)
	assert_true(hurt.max_hp == 21 and hurt.hp == 11, "levels: HP growth raises max and current HP (%d/%d)" % [hurt.hp, hurt.max_hp])
	# AC-CC82: a success on a capped stat is wasted; the level still rises.
	var strong := _spawn(state2, "strong", "faction_p", Vector2i(3, 0), false, false, "player")
	strong.growths = {"str": 100}
	strong.power = int(DataRegistry.rule("stat_caps", {}).get("str", 30))
	var capped_power: int = strong.power
	ExpSystem.resolve_level_up(state2, strong, per_level)
	assert_true(strong.level == 2 and strong.power == capped_power, "levels: capped str roll is wasted, level still rises")
	assert_true(not strong.stat_bonus.has("str"), "levels: a wasted roll records no gain")
	# AC-CC84: reaching the level cap discards leftover EXP; a unit at the cap gains nothing more.
	var veteran := _spawn(state2, "veteran", "faction_p", Vector2i(4, 0), false, false, "player")
	veteran.growths = {}
	veteran.level = level_cap - 1
	ExpSystem.resolve_level_up(state2, veteran, per_level + 50)
	assert_true(veteran.level == level_cap and int(veteran.exp) == 0, "levels: leftover EXP at the cap is discarded (L%d, %d)" % [veteran.level, veteran.exp])
	var gained_before := int(state2.exp_gained.get("veteran", 0))
	ExpSystem.grant_action_exp(state2, veteran)
	assert_true(int(veteran.exp) == 0 and int(state2.exp_gained.get("veteran", 0)) == gained_before, "levels: a unit at the cap gains no EXP")
	# Enemies never earn EXP or level, whatever they are handed.
	var foe := _spawn(state2, "foe", "faction_e", Vector2i(5, 0), false, false, "enemy")
	foe.growths = {"str": 100}
	var foe_power: int = foe.power
	ExpSystem.resolve_level_up(state2, foe, per_level * 3)
	assert_true(foe.level == 1 and foe.power == foe_power and int(foe.exp) == 0, "levels: enemies never earn EXP or level")


## F-EXP: rewinding past a level-up undoes it completely (GDD Core Rule 12e), and growth
## comes from the GDD per-class table for every roster unit (base and demo layer).
func test_exp_rewind_and_growth_table() -> void:
	await 0.0
	var per_action := int(DataRegistry.rule("exp_per_action", 25))
	var state: BattleState = _plain_map_enemy_state()
	var climber := _spawn(state, "climber", "faction_p", Vector2i(0, 0), false, false, "player")
	climber.growths = {"str": 100, "hp": 100}
	climber.exp = 90
	var snapshot := state.to_dict()
	var power_snap: int = climber.power
	var max_hp_snap: int = climber.max_hp
	var hp_snap: int = climber.hp
	ExpSystem.resolve_level_up(state, climber, per_action)
	assert_true(climber.level == 2 and climber.power == power_snap + 1, "rewind exp: setup level-up happened")
	state.from_dict(snapshot)
	assert_true(climber.level == 1 and int(climber.exp) == 90, "rewind exp: level and EXP revert")
	assert_true(climber.power == power_snap and climber.max_hp == max_hp_snap and climber.hp == hp_snap, "rewind exp: level-up stat gains revert")
	assert_true(climber.stat_bonus.is_empty() and state.level_ups.is_empty() and state.exp_gained.is_empty(), "rewind exp: battle gains and logs revert")
	# GDD Authored Growth Rate Table rows, read from the class records.
	var sword_class := DataRegistry.get_battle_class("class_swordsman")
	assert_true(int(sword_class.growths.get("hp", 0)) == 65 and int(sword_class.growths.get("str", 0)) == 45 and int(sword_class.growths.get("res", 0)) == 20, "growth table: Swordsman row matches the GDD")
	var bard_class := DataRegistry.get_battle_class("class_bard")
	assert_true(int(bard_class.growths.get("str", -1)) == 0 and int(bard_class.growths.get("luck", 0)) == 65, "growth table: Bard row matches the GDD (Str 0, Luck 65)")
	# The class table wins over the legacy per-unit placeholder, and demo units read it too.
	var roster_sword := UnitState.from_data(DataRegistry.get_unit("unit_swordsman"), Vector2i(0, 0))
	assert_true(roster_sword.growths.size() == 8 and roster_sword.growths.has("str") and not roster_sword.growths.has("atk"), "growth table: roster Swordsman reads the 8-stat class table")
	var demo_sword := UnitState.from_data(DataRegistry.get_unit("unit_demo_swordsman"), Vector2i(0, 0))
	assert_true(demo_sword.growths.size() == 8, "growth table: demo Swordsman reads the class table (got %d stats)" % demo_sword.growths.size())


## Merge carries level + this battle's stat gains; the roster bonus replays onto the next
## battle without being counted again (F-EXP latent-bug fix: no triple counting).
func test_exp_merge_and_replay() -> void:
	await 0.0
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var chapter := GameState.current_chapter()
	var merge_state: BattleState = _plain_map_enemy_state()
	var merged_hero := _spawn(merge_state, "unit_swordsman", "faction_p", Vector2i(0, 0), false, false, "player")
	merged_hero.level = 2
	merged_hero.stat_bonus = {"atk": 2, "hp": 1}
	CampaignMerge.merge(merge_state, chapter, {"status": "win"})
	var roster_entry: Dictionary = GameState.roster["unit_swordsman"]
	assert_true(int(roster_entry["level"]) == 2, "merge: merged level stored")
	assert_true(int(roster_entry["stat_bonus"].get("atk", 0)) == 2, "merge: atk bonus stored")
	assert_true(int(roster_entry["stat_bonus"].get("hp", 0)) == 1, "merge: hp bonus stored")
	assert_true(not SaveService.save_campaign().is_empty(), "merge: save writes")
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	assert_true(SaveService.load_campaign(), "merge: load reads")
	assert_true(int(GameState.roster["unit_swordsman"]["stat_bonus"].get("atk", 0)) == 2, "merge: stat bonus survives save/load")
	# from_data replays the roster bonus onto the live stats without recording it as a new gain.
	var ud := DataRegistry.get_unit("unit_swordsman")
	var roster_level := int(GameState.roster["unit_swordsman"]["level"])
	var replayed := UnitState.from_data(ud, Vector2i(0, 0), roster_level)
	var base_atk: int = int(ud.base_stat("atk", 0))
	assert_true(int(replayed.power) == base_atk + 2, "from_data: roster atk bonus applied (power %d)" % replayed.power)
	assert_true(replayed.stat_bonus.is_empty(), "from_data: the roster bonus is not copied into this battle's gains")
	# Next battle with one new str gain: the roster total becomes atk+2 and str+1, not a multiple.
	var second_state: BattleState = _plain_map_enemy_state()
	second_state.units["unit_swordsman"] = replayed
	replayed.apply_stat_gain("str", 1)
	CampaignMerge.merge(second_state, chapter, {"status": "win"})
	var carried: Dictionary = GameState.roster["unit_swordsman"]["stat_bonus"]
	assert_true(int(carried.get("atk", 0)) == 2 and int(carried.get("str", 0)) == 1, "merge: roster adds only the new gain (atk %d, str %d)" % [int(carried.get("atk", 0)), int(carried.get("str", 0))])
	var replayed_again := UnitState.from_data(ud, Vector2i(0, 0), roster_level)
	assert_true(int(replayed_again.power) == base_atk + 3, "from_data: atk+2 and str+1 both reach power (power %d)" % replayed_again.power)

func test_story_flags_and_ending() -> void:
	## N07: DialoguePlayer writes set_flag into GameState, the flag round-trips through
	## SaveService, and the true-ending check follows completed chapters + persuade.
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	assert_true(GameState.is_true_ending_eligible() == false, "true ending: locked while the chapter is not finished")
	# set_flag through the reusable DialoguePlayer: a line with set_flag writes the flag.
	var dlg := DialogueData.new()
	dlg.id = "dlg_test_flag"
	dlg.lines = [{"speaker": "Narrator", "text": "The peace envoy is recorded.", "set_flag": "flag_test_call"}]
	var player := DialoguePlayer.build(dlg)
	add_child(player)
	await get_tree().process_frame
	player._finish(false)
	assert_true(GameState.story_flags.get("flag_test_call", false) == true, "dialogue: set_flag writes the story flag")
	# Round-trip through the manual save (flags survive save/load).
	GameState.completed_chapters["chapter_ch01"] = true
	var ok_save: bool = not SaveService.save_campaign().is_empty()
	assert_true(ok_save, "story flags: save writes successfully")
	GameState.story_flags.clear()
	var loaded: bool = SaveService.load_campaign()
	assert_true(loaded, "story flags: load reads successfully")
	assert_true(GameState.story_flags.get("flag_test_call", false) == true, "story flags: flag survives save/load round-trip")
	# True ending: ch01 finished but the remnant was not persuaded → still locked.
	GameState.reconcile_outcomes = {"chapter_ch01": {"faction_rebel_ch01": {"persuaded": false}}}
	assert_true(GameState.is_true_ending_eligible() == false, "true ending: un-persuaded remnant locks it")
	GameState.reconcile_outcomes = {"chapter_ch01": {"faction_rebel_ch01": {"persuaded": true}}}
	assert_true(GameState.is_true_ending_eligible() == true, "true ending: all true-ending chapters done + remnants persuaded")
	# Camp screen shows the state without crashing headless.
	GameState.current_chapter_id = "chapter_ch01"
	var camp := CampScene.new()
	add_child(camp)
	await get_tree().process_frame
	var found_note := [false]
	for c in camp.get_children():
		if c is Label and String(c.text).find("True ending:") == 0:
			found_note[0] = true
	assert_true(found_note[0], "true ending: camp shows the eligibility note")
	camp.queue_free()
	GameState.completed_chapters.clear()   # keep global test state clean


func test_capture_zones_contested() -> void:
	## N09: hold over the ENEMY phase too (enemy_phase_ended), multiple zones, and the
	## contested rule: an enemy standing inside a zone resets the streak.
	var map := MapData.new()
	map.id = "capture_map"
	var rows_cap: Array[String] = ["......", "......", "......", "......"]
	map.terrain_rows = rows_cap
	map.deploy_cells = [Vector2i(0, 0)]
	map.objectives = [{"type": "capture", "params": {
		"zones": [{"x": 0, "y": 0, "w": 2, "h": 2}], "turns_required": 2,
	}}]
	var director := BattleDirector.new()
	director.setup(map, {}, "normal")
	var holder := _spawn(director.state, "cap_p", "faction_p", Vector2i(0, 0), false, false, "player")
	var foe := _spawn(director.state, "cap_e", "faction_cap", Vector2i(5, 3), false, false, "enemy")
	# Turn 1: player ends the phase inside the zone → streak 1; the enemy phase leaves it
	# held (enemy outside), so enemy_phase_ended must NOT clear the streak.
	director.end_player_phase()
	var streak1: int = int(director.state.objective_counters.get("capture_streak", -1))
	assert_true(streak1 == 1, "capture: player end of phase sets streak 1 (streak=%d)" % streak1)
	director.advance_after_enemy_phase()
	streak1 = int(director.state.objective_counters.get("capture_streak", -1))
	assert_true(streak1 == 1, "capture: enemy_phase_ended keeps a held streak (streak=%d)" % streak1)
	# Turn 2 prep: the enemy walks INTO the zone during its phase → enemy_phase_ended
	# (contested_rule default) resets the streak to 0 instead of advancing.
	foe.pos = Vector2i(0, 1)
	director.state.phase = BattleState.PHASE_ENEMY   # simulate entering the enemy end again
	director.advance_after_enemy_phase()
	var streak2: int = int(director.state.objective_counters.get("capture_streak", -1))
	assert_true(streak2 == 0, "capture: enemy inside the zone resets the streak (streak=%d)" % streak2)
	# No player in the zone at the enemy end also resets (holder evacuates then returns).
	holder.pos = Vector2i(5, 0)
	director.state.phase = BattleState.PHASE_ENEMY
	director.advance_after_enemy_phase()
	streak2 = int(director.state.objective_counters.get("capture_streak", -1))
	assert_true(streak2 == 0, "capture: empty zone at enemy end keeps streak 0 (streak=%d)" % streak2)
	holder.pos = Vector2i(0, 0)                       # back in the zone
	foe.pos = Vector2i(5, 3)                          # enemy leaves; the zone is uncontestested
	# Turn 2 win: player end 1 → enemy end holds → player end 2 → win.
	director.state.phase = BattleState.PHASE_PLAYER
	director.end_player_phase()
	director.advance_after_enemy_phase()
	director.advance_to_player_phase()
	assert_true(int(director.state.objective_counters.get("capture_streak", 0)) == 1, "capture: held turn count recovered to 1")
	director.end_player_phase()
	assert_true(director.state.battle_over.get("status", "") == "win", "capture: two full held turns win the map")
	# Legacy single-zone params keep working alongside zones[].
	var map_legacy := MapData.new()
	map_legacy.id = "capture_legacy"
	map_legacy.terrain_rows = rows_cap
	map_legacy.deploy_cells = [Vector2i(0, 0)]
	map_legacy.objectives = [{"type": "capture", "params": {
		"zone_x": 0, "zone_y": 0, "zone_w": 1, "zone_h": 1, "turns_required": 1,
	}}]
	var director_legacy := BattleDirector.new()
	director_legacy.setup(map_legacy, {}, "normal")
	_spawn(director_legacy.state, "leg_p", "faction_p", Vector2i(0, 0), false, false, "player")
	director_legacy.end_player_phase()
	assert_true(director_legacy.state.battle_over.get("status", "") == "win", "capture: legacy zone params still work")


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
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
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


## F-PAS: the 12 class passives from the GDD catalog, each at its trigger point.
func test_class_passives() -> void:
	await 0.0
	# Swordsman disarming_strike: a landed hit puts Def -3 on the target for 2 of its turns.
	var s1: BattleState = _plain_map_enemy_state()
	var sword := _spawn(s1, "sword", "faction_p", Vector2i(0, 0), false, false, "player")
	sword.passive_id = "disarming_strike"
	sword.skill = 60
	sword.crit_bonus = -500
	var dummy := _spawn(s1, "dummy", "faction_e", Vector2i(1, 0), false, false, "enemy")
	dummy.can_attack = false
	CombatResolver.execute(s1, sword, dummy)
	assert_true(dummy.active_debuffs.has("defense") and int(dummy.active_debuffs["defense"]["amount"]) == 3 and int(dummy.active_debuffs["defense"]["turns_remaining"]) == 2, "passive swordsman: Def -3 for 2 turns on hit")
	assert_true(dummy.eff("defense") == dummy.defense - 3, "passive swordsman: formulas read the debuffed Def")
	PassiveSystem.on_unit_acted(dummy)
	assert_true(dummy.active_debuffs.has("defense"), "passive swordsman: 1 turn left after the target's first action")
	PassiveSystem.on_unit_acted(dummy)
	assert_true(not dummy.active_debuffs.has("defense"), "passive swordsman: debuff gone after 2 of the target's turns")

	# Knight iron_retaliation: healthy and survives -> 4 damage back; under 50% HP -> nothing.
	var s2: BattleState = _plain_map_enemy_state()
	var striker := _spawn(s2, "striker", "faction_p", Vector2i(0, 0), false, false, "player")
	striker.hit_bonus = -999
	var knight := _spawn(s2, "knight", "faction_e", Vector2i(1, 0), false, false, "enemy")
	knight.passive_id = "iron_retaliation"
	knight.can_attack = false
	var strikes: Array = CombatResolver.execute(s2, striker, knight)
	assert_true(striker.hp == 16 and String(strikes[-1].get("effect", "")) == "thorns", "passive knight: 4 thorns damage to the attacker")
	knight.hp = 9
	CombatResolver.execute(s2, striker, knight)
	assert_true(striker.hp == 16, "passive knight: no thorns below 50%% HP")

	# Lumberjack battle_bloodlust: heal floor(damage * 0.3) on a landed hit.
	var s3: BattleState = _plain_map_enemy_state()
	var jack := _spawn(s3, "jack", "faction_p", Vector2i(0, 0), false, false, "player")
	jack.passive_id = "battle_bloodlust"
	jack.skill = 60
	jack.crit_bonus = -500
	jack.power = 20
	jack.hp = 10
	var log := _spawn(s3, "log", "faction_e", Vector2i(1, 0), false, false, "enemy")
	log.can_attack = false
	log.max_hp = 50
	log.hp = 50
	CombatResolver.execute(s3, jack, log)
	assert_true(jack.hp == 15, "passive lumberjack: 17 damage heals 5 (hp %d)" % jack.hp)

	# Lancer twin_lance_strike: equal Speed still strikes twice.
	var s4: BattleState = _plain_map_enemy_state()
	var lance := _spawn(s4, "lance", "faction_p", Vector2i(0, 0), false, false, "player")
	var foe4 := _spawn(s4, "foe4", "faction_e", Vector2i(1, 0), false, false, "enemy")
	assert_true(_attacker_strikes(CombatResolver.forecast(s4, lance, foe4)) == 1, "passive lancer: setup, equal Speed normally strikes once")
	lance.passive_id = "twin_lance_strike"
	assert_true(_sides(CombatResolver.forecast(s4, lance, foe4)) == ["attacker", "attacker", "counter"], "passive lancer: two strikes back to back, then the counter")
	lance.speed = 20
	assert_true(_sides(CombatResolver.forecast(s4, lance, foe4)) == ["attacker", "attacker", "counter"], "passive lancer: never a third strike with a Speed edge")

	# Gunner cover_piercing_shot: from exactly max range the defender's forest Avoid is ignored.
	var s5: BattleState = _plain_map_enemy_state()
	var gunner := _spawn(s5, "gunner", "faction_p", Vector2i(2, 0), false, false, "player")
	gunner.attack_range_max = 2
	var hidden := _spawn(s5, "hidden", "faction_e", Vector2i(2, 2), false, false, "enemy")   # forest tile
	var hit_plain := CombatResolver._hit_pct(s5, gunner, hidden)
	gunner.passive_id = "cover_piercing_shot"
	var hit_pierce := CombatResolver._hit_pct(s5, gunner, hidden)
	assert_true(hit_pierce - hit_plain == s5.terrain_avoid_at(hidden.pos) and hit_pierce > hit_plain, "passive gunner: forest Avoid ignored at max range (%d -> %d)" % [hit_plain, hit_pierce])
	gunner.pos = Vector2i(2, 1)
	assert_true(not PassiveSystem.ignores_terrain(gunner, hidden) and CombatResolver._hit_pct(s5, gunner, hidden) == hit_plain, "passive gunner: an adjacent shot keeps the defender's terrain Avoid")

	# Wyvern Knight survival_instinct: first lethal hit leaves 1 HP, the second one kills.
	var s6: BattleState = _plain_map_enemy_state()
	var slayer := _spawn(s6, "slayer", "faction_p", Vector2i(0, 0), false, false, "player")
	slayer.skill = 60
	slayer.power = 50
	slayer.crit_bonus = -500
	var wyvern := _spawn(s6, "wyvern", "faction_e", Vector2i(1, 0), false, false, "enemy")
	wyvern.passive_id = "survival_instinct"
	wyvern.can_attack = false
	CombatResolver.execute(s6, slayer, wyvern)
	assert_true(wyvern.alive and wyvern.hp == 1 and wyvern.miracle_used, "passive wyvern: survives the first lethal hit at 1 HP")
	CombatResolver.execute(s6, slayer, wyvern)
	assert_true(not wyvern.alive, "passive wyvern: only once per battle")
	# Designer: any death counts — also when the Wyvern Knight attacks and falls to the counter.
	var s6b: BattleState = _plain_map_enemy_state()
	var rider := _spawn(s6b, "rider", "faction_p", Vector2i(0, 0), false, false, "player")
	rider.passive_id = "survival_instinct"
	rider.hit_bonus = -999
	rider.hp = 3
	var wall := _spawn(s6b, "wall", "faction_e", Vector2i(1, 0), false, false, "enemy")
	wall.skill = 60
	wall.power = 50
	wall.crit_bonus = -500
	CombatResolver.execute(s6b, rider, wall)
	assert_true(rider.alive and rider.hp == 1 and rider.miracle_used, "passive wyvern: revived at 1 HP after dying to a counter")
	# ...and from thorns damage.
	var s6c: BattleState = _plain_map_enemy_state()
	var rider2 := _spawn(s6c, "rider2", "faction_p", Vector2i(0, 0), false, false, "player")
	rider2.passive_id = "survival_instinct"
	rider2.hit_bonus = -999
	rider2.hp = 2
	var spikes := _spawn(s6c, "spikes", "faction_e", Vector2i(1, 0), false, false, "enemy")
	spikes.passive_id = "iron_retaliation"
	spikes.can_attack = false
	CombatResolver.execute(s6c, rider2, spikes)
	assert_true(rider2.alive and rider2.hp == 1, "passive wyvern: revived after lethal thorns damage")

	# Beastwoman feral_regeneration: +5 HP after its own Attack, hit or miss.
	var s7: BattleState = _plain_map_enemy_state()
	var beast := _spawn(s7, "beast", "faction_p", Vector2i(0, 0), false, false, "player")
	beast.passive_id = "feral_regeneration"
	beast.hit_bonus = -999
	beast.hp = 10
	var prey := _spawn(s7, "prey", "faction_e", Vector2i(1, 0), false, false, "enemy")
	prey.can_attack = false
	CombatResolver.execute(s7, beast, prey)
	assert_true(beast.hp == 15, "passive beastwoman: heals 5 after attacking (hp %d)" % beast.hp)

	# Magician fragile_magic_circle: full HP at phase start -> +5 on the first strike only.
	var s8: BattleState = _plain_map_enemy_state()
	var mage := _spawn(s8, "mage", "faction_p", Vector2i(0, 0), false, false, "player")
	mage.passive_id = "fragile_magic_circle"
	mage.speed = 20
	var target8 := _spawn(s8, "target8", "faction_e", Vector2i(1, 0), false, false, "enemy")
	target8.can_attack = false
	PassiveSystem.on_phase_started(s8, "player")
	var plan8: Dictionary = CombatResolver.forecast(s8, mage, target8)
	assert_true(mage.fragile_circle_ready and int(plan8["sequence"][0]["damage"]) == int(plan8["sequence"][1]["damage"]) + 5, "passive magician: +5 on the first strike only (forecast shows it)")
	CombatResolver.execute(s8, mage, target8)
	assert_true(not mage.fragile_circle_ready, "passive magician: flag spent by the Attack")
	mage.hp = 10
	PassiveSystem.on_phase_started(s8, "player")
	assert_true(not mage.fragile_circle_ready, "passive magician: no burst when the phase starts below full HP")

	# Bard inspiring_melody: +3 Avoid to each adjacent ally, bond not needed.
	var s9: BattleState = _plain_map_enemy_state()
	var bard := _spawn(s9, "bard", "faction_p", Vector2i(0, 0), false, false, "player")
	bard.passive_id = "inspiring_melody"
	var buddy := _spawn(s9, "buddy", "faction_p", Vector2i(1, 0), false, false, "player")
	var foe9 := _spawn(s9, "foe9", "faction_e", Vector2i(2, 0), false, false, "enemy")
	var avoid_near := CombatResolver._avoid(s9, foe9, buddy)
	bard.pos = Vector2i(0, 4)
	assert_true(avoid_near - CombatResolver._avoid(s9, foe9, buddy) == 3, "passive bard: adjacent ally gets +3 Avoid")

	# Healer devoted_mentor: healing another ally gives that ally +10 EXP.
	var s10: BattleState = _plain_map_enemy_state()
	var mentor := _spawn(s10, "mentor", "faction_p", Vector2i(0, 0), false, false, "player")
	mentor.passive_id = "devoted_mentor"
	var pupil := _spawn(s10, "pupil", "faction_p", Vector2i(1, 0), false, false, "player")
	pupil.hp = 5
	SkillCommand.apply(s10, mentor, "skill_heal", pupil)
	assert_true(int(pupil.exp) == 10 and int(mentor.exp) == int(DataRegistry.rule("exp_per_action", 25)), "passive healer: healed ally +10 EXP, healer its own 25")

	# Magic Swordsman extended_reach: +1 max range at >= 75% HP.
	var s11: BattleState = _plain_map_enemy_state()
	var reach := _spawn(s11, "reach", "faction_p", Vector2i(0, 0), false, false, "player")
	reach.passive_id = "extended_reach"
	_spawn(s11, "far2", "faction_e", Vector2i(2, 0), false, false, "enemy")
	assert_true(reach.attack_max() == 2 and RangeHandler.compute_targets_from_position(s11, reach).has("far2"), "passive magic swordsman: range 2 at full HP")
	reach.hp = 14
	assert_true(reach.attack_max() == 1 and not RangeHandler.compute_targets_from_position(s11, reach).has("far2"), "passive magic swordsman: back to range 1 below 75%% HP")

	# Assassin silent_assassination: no counter from a target that has not acted yet.
	var s12: BattleState = _plain_map_enemy_state()
	var shade := _spawn(s12, "shade", "faction_p", Vector2i(0, 0), false, false, "player")
	shade.passive_id = "silent_assassination"
	var mark := _spawn(s12, "mark", "faction_e", Vector2i(1, 0), false, false, "enemy")
	assert_true(not bool(CombatResolver.forecast(s12, shade, mark)["can_counter"]), "passive assassin: Ready target cannot counter")
	mark.acted = true
	assert_true(bool(CombatResolver.forecast(s12, shade, mark)["can_counter"]), "passive assassin: a target that already acted counters normally")

	# Rewind carries the passive state.
	var snap := s6.to_dict()
	wyvern.miracle_used = false
	dummy.active_debuffs = {"defense": {"amount": 3, "turns_remaining": 2}}
	var snap1 := s1.to_dict()
	dummy.active_debuffs = {}
	s1.from_dict(snap1)
	s6.from_dict(snap)
	assert_true(wyvern.miracle_used and dummy.active_debuffs.has("defense"), "passive rewind: debuffs and the once-per-battle flag are restored")


## F-PAS: Bard has no weapon and no Attack/counter; Diễn Tấu (Encore) refreshes an adjacent ally
## that already acted. Healer cannot Attack either (Heal weapon).
func test_bard_encore() -> void:
	await 0.0
	var bard_unit := UnitState.from_data(DataRegistry.get_unit("unit_bard"), Vector2i(0, 0))
	assert_true(bard_unit.weapon_id == "" and not bard_unit.can_attack and bard_unit.passive_id == "inspiring_melody" and bard_unit.skill_ids.has("skill_encore"), "bard data: no weapon, cannot attack, aura passive, Encore skill")
	assert_true(not UnitState.from_data(DataRegistry.get_unit("unit_healer"), Vector2i(0, 0)).can_attack, "healer data: a Heal weapon cannot attack")
	var sword_unit := UnitState.from_data(DataRegistry.get_unit("unit_swordsman"), Vector2i(0, 0))
	assert_true(sword_unit.can_attack and sword_unit.passive_id == "disarming_strike", "swordsman data: attacks, carries disarming_strike")
	var state: BattleState = _plain_map_enemy_state()
	var bard := _spawn(state, "bard", "faction_p", Vector2i(2, 2), false, false, "player")
	bard.can_attack = false
	bard.passive_id = "inspiring_melody"
	bard.skill_ids.append("skill_encore")
	var tired := _spawn(state, "tired", "faction_p", Vector2i(3, 2), false, false, "player")
	tired.acted = true
	tired.moved = true
	var fresh := _spawn(state, "fresh", "faction_p", Vector2i(1, 2), false, false, "player")
	var bard2 := _spawn(state, "bard2", "faction_p", Vector2i(2, 1), false, false, "player")
	bard2.skill_ids.append("skill_encore")
	bard2.acted = true
	var foe := _spawn(state, "foe", "faction_e", Vector2i(2, 3), false, false, "enemy")
	assert_true(RangeHandler.compute_targets_from_position(state, bard).is_empty(), "bard: threatens nothing")
	assert_true(AttackCommand.check(state, bard, "foe") == "This unit cannot attack.", "bard: Attack refused")
	assert_true(not RangeHandler.can_counter(state, bard, foe.pos), "bard: never counterattacks")
	assert_true(SkillCommand.check(state, bard, "skill_encore", fresh) == "Target has not acted yet.", "encore: not on a Ready ally")
	assert_true(SkillCommand.check(state, bard, "skill_encore", bard2) == "Encore cannot target another Encore user.", "encore: no Bard chains")
	assert_true(SkillCommand.check(state, bard, "skill_encore", foe) != "", "encore: not on an enemy")
	var director := director_for(state)
	assert_true(director.commit("skill", {"unit_id": "bard", "skill_id": "skill_encore", "target_id": "tired"}), "encore: commit through the director")
	assert_true(not tired.acted and not tired.moved and bard.acted, "encore: target gets Move + Action back, Bard is spent")
	assert_true(int(bard.exp) == int(DataRegistry.rule("exp_per_action", 25)), "encore: Bard earns the flat action EXP")
	# Debuff countdown runs on the director's Ready -> Acted hook.
	fresh.active_debuffs = {"defense": {"amount": 3, "turns_remaining": 2}}
	director.commit("wait", {"unit_id": "fresh"})
	assert_true(int(fresh.active_debuffs["defense"]["turns_remaining"]) == 1, "debuff: counts down when its unit acts")


## Designer (08-11-2026): the player picks the Heal / Encore target. Skill button -> highlighted
## targets -> left click commits, right click cancels with nothing spent.
func test_skill_target_selection() -> void:
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var director := BattleDirector.new()
	# deploy cells: (2,8) (3,8) (4,8) (5,8) (2,9) (3,9): healer at (3,8) with the swordsman, knight and
	# bard all adjacent (the demo staff heals at range 1 only, F-HEAL).
	director.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_healer": map.deploy_cells[1], "unit_knight": map.deploy_cells[2], "unit_bard": map.deploy_cells[5]}, "normal")
	var battle := BattleScene.new()
	battle.setup(director)
	main._swap_to(battle)
	await get_tree().process_frame
	var healer: UnitState = director.state.units["unit_healer"]
	var sword: UnitState = director.state.units["unit_swordsman"]
	var knight: UnitState = director.state.units["unit_knight"]
	var bard: UnitState = director.state.units["unit_bard"]
	sword.hp = sword.max_hp - 12
	knight.hp = knight.max_hp - 20   # the most hurt: the old auto-pick would have chosen the Knight
	var knight_hp: int = knight.hp
	var sword_hp: int = sword.hp
	battle._on_left_click(healer.pos)
	battle._use_skill("skill_heal")
	assert_true(battle.mode == BattleScene.Mode.SKILL_TARGET and battle._skill_targets.has("unit_swordsman") and battle._skill_targets.has("unit_knight"), "skill target: Heal lists every hurt ally in range")
	battle._on_right_click(healer.pos)
	assert_true(battle.mode != BattleScene.Mode.SKILL_TARGET and not healer.acted and sword.hp == sword_hp, "skill target: right click cancels, nothing spent")
	battle._use_skill("skill_heal")
	assert_true(battle.heal_preview_text(healer, sword, "skill_heal").contains("+12 HP"), "heal preview: shows the real gain before commit (%s)" % battle.heal_preview_text(healer, sword, "skill_heal"))
	battle._on_left_click(sword.pos)
	assert_true(sword.hp == sword.max_hp and knight.hp == knight_hp and healer.acted, "skill target: Heal lands on the clicked ally (the Swordsman), not the most hurt one")
	# Encore: the Bard picks the healer (adjacent, already acted).
	battle._on_left_click(bard.pos)
	battle._use_skill("skill_encore")
	assert_true(battle.mode == BattleScene.Mode.SKILL_TARGET and battle._skill_targets.has("unit_healer"), "skill target: Encore lists the adjacent ally that acted")
	battle._on_left_click(healer.pos)
	assert_true(not healer.acted and bard.acted, "skill target: Encore refreshes the clicked ally")
	main.queue_free()


## F-HEAL (GDD F-CC9): Heal = healer Mag + staff heal_might, capped at max HP, range from the
## staff's heal_range, no Hit/Crit roll; the skill's own power is only a no-weapon fallback.
func test_heal_formula() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var healer := _spawn(state, "medic", "faction_p", Vector2i(0, 0), false, false, "player")
	healer.weapon_id = "weapon_healing_staff"   # heal_might 8, heal_range [1, 2]
	healer.magic = 12
	var skill := DataRegistry.get_data("skills", "skill_heal")
	assert_true(CombatResolver.heal_amount(healer, skill) == 20, "heal: Mag 12 + heal_might 8 = 20")
	var patient := _spawn(state, "patient", "faction_p", Vector2i(2, 0), false, false, "player")
	patient.max_hp = 50
	patient.hp = 20
	assert_true(SkillCommand.check(state, healer, "skill_heal", patient) == "", "heal: range 2 allowed by the staff's heal_range")
	var far := _spawn(state, "far", "faction_p", Vector2i(3, 0), false, false, "player")
	far.hp = 5
	assert_true(SkillCommand.check(state, healer, "skill_heal", far) != "", "heal: range 3 is out of the staff's heal_range")
	var seed_before := state.rng().state
	SkillCommand.apply(state, healer, "skill_heal", patient)
	assert_true(patient.hp == 40, "heal: 20 HP restored (hp %d)" % patient.hp)
	assert_true(state.rng().state == seed_before, "heal: no Hit/Crit roll (RNG untouched)")
	var nearly := _spawn(state, "nearly", "faction_p", Vector2i(1, 1), false, false, "player")
	nearly.hp = nearly.max_hp - 3
	var preview := CombatResolver.heal_preview(healer, nearly, skill)
	assert_true(int(preview["raw"]) == 20 and int(preview["gain"]) == 3 and int(preview["hp_after"]) == nearly.max_hp, "heal: capped at max HP (raw 20, gain 3)")
	var plain := _spawn(state, "plain", "faction_p", Vector2i(0, 2), false, false, "player")
	assert_true(CombatResolver.heal_amount(plain, skill) == int(skill.power), "heal: no Heal weapon falls back to the skill's power")


## F-PAS preview: forecast() lists the passive side effects of the exchange as notes, and the
## forecast panel renders them under the owning side.
func test_forecast_passive_notes() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	var jack := _spawn(state, "jack", "faction_p", Vector2i(0, 0), false, false, "player")
	jack.passive_id = "battle_bloodlust"
	jack.power = 20                     # 20 - 3 Def = 17 damage -> 5 HP per hit
	var knight := _spawn(state, "knight", "faction_e", Vector2i(1, 0), false, false, "enemy")
	knight.passive_id = "iron_retaliation"
	var fc: Dictionary = CombatResolver.forecast(state, jack, knight)
	var steal := _note_of(fc, "lifesteal")
	assert_true(String(steal.get("owner", "")) == "attacker" and int(steal.get("value", -1)) == 5, "preview: lifesteal 5 HP per hit on the attacker side")
	assert_true(String(steal.get("name", "")) == "Battle Bloodlust", "preview: passive name key from the catalog")
	var thorns := _note_of(fc, "thorns_damage")
	assert_true(String(thorns.get("owner", "")) == "defender" and int(thorns.get("value", -1)) == 4, "preview: thorns 4 on the defender side")
	knight.hp = 9
	assert_true(_note_of(CombatResolver.forecast(state, jack, knight), "thorns_damage").is_empty(), "preview: no thorns note below 50%% HP")
	# Survive-once while unused; Bard aura on the side that gets it; an active debuff.
	var s2: BattleState = _plain_map_enemy_state()
	var shade := _spawn(s2, "shade", "faction_p", Vector2i(0, 0), false, false, "player")
	shade.passive_id = "silent_assassination"
	var wyvern := _spawn(s2, "wyvern", "faction_e", Vector2i(1, 0), false, false, "enemy")
	wyvern.passive_id = "survival_instinct"
	wyvern.active_debuffs = {"defense": {"amount": 3, "turns_remaining": 1}}
	var bard := _spawn(s2, "bard", "faction_e", Vector2i(2, 0), false, false, "enemy")
	bard.passive_id = "inspiring_melody"
	var fc2: Dictionary = CombatResolver.forecast(s2, shade, wyvern)
	assert_true(not _note_of(fc2, "suppress_retaliation").is_empty(), "preview: no-counter note while the target is Ready")
	assert_true(String(_note_of(fc2, "survive_once").get("owner", "")) == "defender", "preview: survive-once note while unused")
	var aura := _note_of(fc2, "adjacency_aura_avoid")
	assert_true(String(aura.get("owner", "")) == "defender" and int(aura.get("value", 0)) == 3, "preview: Bard aura +3 Avoid on the defender")
	assert_true(int(_note_of(fc2, "active_debuff").get("turns", 0)) == 1, "preview: active debuff with turns left")
	wyvern.miracle_used = true
	assert_true(_note_of(CombatResolver.forecast(s2, shade, wyvern), "survive_once").is_empty(), "preview: no survive-once note once used")
	# The panel renders the notes as text, under the right column.
	assert_true(ForecastPanel.note_text(steal).contains("[Battle Bloodlust]") and ForecastPanel.note_text(steal).contains("5 HP per hit"), "preview text: %s" % ForecastPanel.note_text(steal))
	var panel := ForecastPanel.build(fc, jack, knight)
	assert_true(_has_label_containing(panel, "Battle Bloodlust"), "preview panel: lifesteal line rendered")
	panel.free()


func _note_of(forecast: Dictionary, effect_type: String) -> Dictionary:
	for note in forecast.get("notes", []):
		if String(note.get("effect_type", "")) == effect_type:
			return note
	return {}


func _has_label_containing(root: Node, text: String) -> bool:
	if root is Label and String((root as Label).text).contains(text):
		return true
	for child in root.get_children():
		if _has_label_containing(child, text):
			return true
	return false


## I18N: the UI ships in English and Vietnamese. Every key used in code exists in
## data/i18n/strings.csv with both texts, and switching the language changes what screens show.
func test_i18n() -> void:
	await 0.0
	var table: Dictionary = DataRegistry.i18n_table()
	assert_true(DataRegistry.i18n_locales().has("en") and DataRegistry.i18n_locales().has("vi"), "i18n: en and vi columns loaded")
	var missing: Array = []
	var re := RegEx.new()
	re.compile('(?:UIBuilder\\.t|_t)\\("((?:[^"\\\\]|\\\\.)*)"\\)')
	for path in _gd_files("res://src"):
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			var key := m.get_string(1).replace("\\\"", "\"")
			if not table.has(key):
				missing.append("%s: %s" % [path.get_file(), key])
	assert_true(missing.is_empty(), "i18n: every t() key in src/ has a row (missing: %s)" % str(missing))
	assert_true(GameState.language() == "en" and UIBuilder.t("Retry chapter") == "Retry chapter", "i18n: English by default")
	GameState.set_language("vi")
	assert_true(UIBuilder.t("Retry chapter") == "Chơi lại chương", "i18n: Vietnamese text after switching")
	assert_true(UIBuilder.t("eliminate") == "Tiêu diệt" and ObjectiveBase.create({"type": "eliminate", "params": {}}).describe().begins_with("Tiêu diệt"), "i18n: objective names and descriptions translated")
	var note := {"owner": "attacker", "name": "Battle Bloodlust", "effect_type": "lifesteal", "value": 5}
	assert_true(ForecastPanel.note_text(note) == "[Hút Máu Chiến Trận] khi trúng: hồi 5 HP mỗi đòn (nhiều hơn khi chí mạng)", "i18n: forecast note in Vietnamese (%s)" % ForecastPanel.note_text(note))
	var over := GameOverScene.build(null)
	add_child(over)
	await get_tree().process_frame
	assert_true(_find_button(over, "Chơi lại chương") != null and _find_button(over, "Menu chính") != null, "i18n: Game Over buttons in Vietnamese")
	over.queue_free()
	GameState.new_game()
	assert_true(GameState.language() == "vi", "i18n: the language survives a new campaign")
	GameState.set_language("en")
	assert_true(UIBuilder.t("Retry chapter") == "Retry chapter" and ForecastPanel.note_text(note).begins_with("[Battle Bloodlust]"), "i18n: back to English")


func _gd_files(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path + "/" + f)
	for sub in dir.get_directories():
		out.append_array(_gd_files(dir_path + "/" + sub))
	return out


## F-DIFF (GDD F-DS2, AC-DS2/AC-DS4): enemy Str/Mag/Skill/Speed/Def/Res x multiplier at deploy,
## floored; HP and Luck never scaled; player units never scaled.
func test_enemy_difficulty_scaling() -> void:
	await 0.0
	var table: Dictionary = DataRegistry.rule("enemy_stat_multiplier_by_difficulty", {})
	assert_true(is_equal_approx(float(table["nightmare"]), 1.15) and is_equal_approx(float(table["hard"]), 1.08) and is_equal_approx(float(table["normal"]), 1.0) and is_equal_approx(float(table["story"]), 1.0), "difficulty: GDD multipliers 1.15 / 1.08 / 1.0 / 1.0")
	var u := UnitState.new()
	u.power = 10; u.magic = 10; u.skill = 10; u.speed = 10; u.defense = 10; u.resistance = 10; u.luck = 10
	u.max_hp = 30; u.hp = 30
	u.apply_enemy_scaling(1.2)
	assert_true(u.power == 12 and u.magic == 12 and u.skill == 12 and u.speed == 12 and u.defense == 12 and u.resistance == 12, "difficulty: AC-DS4 six stats scaled to 12")
	assert_true(u.luck == 10 and u.max_hp == 30 and u.hp == 30, "difficulty: AC-DS4 Luck and HP unchanged")
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var normal := BattleDirector.new()
	normal.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	var nightmare := BattleDirector.new()
	nightmare.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "nightmare")
	var foe_n: UnitState = normal.state.units["unit_rebel_commander"]
	var foe_x: UnitState = nightmare.state.units["unit_rebel_commander"]
	assert_true(foe_x.power == int(floor(foe_n.power * 1.15)) and foe_x.defense == int(floor(foe_n.defense * 1.15)), "difficulty: Nightmare enemy stats x1.15, floored")
	assert_true(foe_x.max_hp == foe_n.max_hp and foe_x.luck == foe_n.luck, "difficulty: enemy HP and Luck unscaled on Nightmare")
	assert_true(nightmare.state.units["unit_swordsman"].power == normal.state.units["unit_swordsman"].power, "difficulty: player units never scaled")


func _sides(plan: Dictionary) -> Array:
	var out: Array = []
	for entry in plan["sequence"]:
		out.append(String(entry["side"]))
	return out


func _attacker_strikes(plan: Dictionary) -> int:
	var n := 0
	for entry in plan["sequence"]:
		if String(entry["side"]) == "attacker":
			n += 1
	return n


## F-CC-FE: Fire Emblem tuning — hit_base 70, full Luck in Avoid and crit evade, crit ×3, one roll.
func test_fe_formula() -> void:
	await 0.0
	assert_true(int(DataRegistry.rule("hit_base", 0)) == 70, "FE formula: provisional hit_base is 70")
	var state: BattleState = _plain_map_enemy_state()
	var a := _spawn(state, "fe_a", "faction_p", Vector2i(0, 0), false, false, "player")
	a.skill = 10
	a.luck = 8
	var d := _spawn(state, "fe_d", "faction_e", Vector2i(1, 0), false, false, "enemy")
	d.speed = 9
	d.luck = 2
	# Accuracy = 70 + 10*2 + 8*0.5 = 94; Avoid = 9*2 + 2*1 = 20 -> Hit 74.
	assert_true(CombatResolver._hit_pct(state, a, d) == 74, "FE formula: Hit = 70 + Skill*2 + Luck/2 - (Speed*2 + Luck) (got %d)" % CombatResolver._hit_pct(state, a, d))
	# Crit = 10*0.5 - 2*1 = 3.
	assert_true(CombatResolver._crit_pct(state, a, d) == 3, "FE formula: Crit = Skill/2 - defender Luck (got %d)" % CombatResolver._crit_pct(state, a, d))
	# Crit damage x3: certain hit + certain crit, damage 10 - 3 = 7 -> 21.
	var b := _spawn(state, "fe_b", "faction_p", Vector2i(0, 2), false, false, "player")
	b.power = 10
	b.skill = 60
	b.crit_bonus = 500
	var t := _spawn(state, "fe_t", "faction_e", Vector2i(1, 2), false, false, "enemy")
	t.max_hp = 50
	t.hp = 50
	var strikes: Array = CombatResolver.execute(state, b, t)
	assert_true(bool(strikes[0]["crit"]) and int(strikes[0]["damage"]) == 21, "FE formula: crit damage is x3 (got %d)" % int(strikes[0]["damage"]))


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
