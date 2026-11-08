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
	await test_retrieve_rules()
	await test_objective_markers()
	await test_dual_restraint()
	await test_persistent_faction_kills()
	await test_bad_ending()
	await test_demo_starting_bond()
	await test_enemy_levels()
	await test_faction_state_across_chapters()
	await test_ai_pathing_regressions()
	await test_items_gold_and_shop()
	await test_enemy_ai_profiles()
	await test_persuasion_conditions()
	await test_battle_ui_gdd()
	await test_save_migration_v3()
	await test_no_permadeath_sit_out()
	await test_nightmare_lock()
	await test_aftermath_scenes()
	await test_autosave_after_aftermath()
	await test_camp_roster_menu()
	await test_ui_start_flow()
	await test_prep_screen_layout()
	await test_battle_hud_layout()
	await test_dialogue_vn_layout()
	await test_rewind()
	await test_bond_and_reconcile()
	await test_bond_cap()
	await test_bond_rules_d05()
	await test_bond_campaign()
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


## F-BOND (GDD F-BA3): +1 support point when a player unit PERFORMS an Attack/Heal with its
## partner cardinally adjacent to it; enemies, defenders, distance and the 2-per-map cap block it.
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
	assert_true(int(DataRegistry.rule("bond_points_combat_action", 0)) == 1 and int(DataRegistry.rule("bond_point_limit_per_pair_per_map", 0)) == 2, "bond F-BOND: +1 per action, 2 per map (GDD)")
	# The attacker's adjacent partner: +1 through the real attack command.
	AttackCommand.apply(state, attacker, "foe1")
	assert_true(int(state.bond_points.get("test_pair_d05", 0)) == 1, "bond F-BOND: attacking next to the partner earns 1")
	# Being attacked earns nothing (only the unit that performs the action counts).
	state.bond_points["test_pair_d05"] = 0
	BondSystem.reward_action(state, foe)
	assert_true(int(state.bond_points.get("test_pair_d05", 0)) == 0, "bond F-BOND: defending earns nothing")
	# Distant partner: no points.
	partner.pos = Vector2i(3, 3)
	BondSystem.reward_action(state, attacker)
	assert_true(int(state.bond_points.get("test_pair_d05", 0)) == 0, "bond F-BOND: partner not adjacent earns nothing")
	partner.pos = Vector2i(1, 0)
	# A pair whose other member is on the enemy side never earns.
	var cross := BondData.new()
	cross.id = "test_pair_cross"
	cross.unit_a = "attacker"
	cross.unit_b = "foe1"
	DataRegistry._cache["bonds"]["test_pair_cross"] = cross
	foe.pos = Vector2i(0, 1)
	BondSystem.reward_action(state, attacker)
	assert_true(not state.bond_points.has("test_pair_cross"), "bond F-BOND: enemy-side pair earns nothing")
	foe.pos = Vector2i(1, 1)
	# Map cap: three qualifying actions still give 2.
	state.bond_points["test_pair_d05"] = 0
	for i in 3:
		BondSystem.reward_action(state, attacker)
	assert_true(int(state.bond_points["test_pair_d05"]) == 2, "bond F-BOND: at most 2 points per pair per map")
	# A Heal counts the healer's adjacent partner too (through the real skill command).
	state.bond_points["test_pair_d05"] = 0
	partner.hp = 5
	SkillCommand.apply(state, attacker, "skill_heal", partner)
	assert_true(int(state.bond_points["test_pair_d05"]) == 1, "bond F-BOND: a Heal next to the partner earns 1")
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
	assert_true(CampScene.rank_index("B") > CampScene.rank_index("C"), "bond rank: index ordering beats string ordering")


## F-BOND scenes and S (GDD Core Rules 4a/4b): 2/5/9 points, only the next rank, chapter gate,
## both alive, surplus carries over; S only for whitelisted pairs, exclusive per character,
## confirmed before it locks.
func test_bond_campaign() -> void:
	await 0.0
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var knight_pair := DataRegistry.get_data("bonds", "bond_swordsman_knight")
	var beast_pair := DataRegistry.get_data("bonds", "bond_swordsman_beastwoman")
	var lancer_pair := DataRegistry.get_data("bonds", "bond_lancer_gunner")
	var routes := 0
	for pair in DataRegistry.all_bond_pairs():
		if String(pair.unit_a) == "unit_swordsman" and bool(pair.s_eligible):
			routes += 1
	assert_true(routes == 6 and not bool(lancer_pair.s_eligible), "bond data: 6 Swordsman S routes, Lancer x Gunner is not an S pair")
	assert_true(BondCampaign.next_rank(knight_pair) == "C" and BondCampaign.scene_state(knight_pair) == "need_points" and BondCampaign.points_missing(knight_pair) == 2, "bond: C needs 2 points")
	GameState.bond_points["bond_swordsman_knight"] = 2
	assert_true(BondCampaign.scene_state(knight_pair) == "ready", "bond: C ready at 2 points")
	BondCampaign.rank_up(knight_pair, "C")
	GameState.bond_points["bond_swordsman_knight"] = 7
	assert_true(BondCampaign.next_rank(knight_pair) == "B" and BondCampaign.scene_state(knight_pair) == "ready", "bond: only the next rank (B) opens, never a jump to A")
	BondCampaign.rank_up(knight_pair, "B")
	assert_true(BondCampaign.next_rank(knight_pair) == "A" and BondCampaign.points_missing(knight_pair) == 2, "bond: surplus points carry toward A (7 of 9)")
	# Story gate: enough points but the A scene waits for a later chapter.
	var later := ChapterData.new()
	later.id = "chapter_test_later"
	later.order = 99
	DataRegistry._cache["chapters"]["chapter_test_later"] = later
	knight_pair.scene_earliest_chapter = {"A": "chapter_test_later"}
	GameState.bond_points["bond_swordsman_knight"] = 9
	assert_true(BondCampaign.scene_state(knight_pair) == "waiting_story", "bond: points reached but waiting on the story")
	GameState.completed_chapters["chapter_test_later"] = true
	assert_true(BondCampaign.scene_state(knight_pair) == "ready", "bond: opens once the chapter is reached")
	GameState.completed_chapters.erase("chapter_test_later")
	knight_pair.scene_earliest_chapter = {}
	DataRegistry._cache["chapters"].erase("chapter_test_later")
	GameState.roster["unit_knight"]["alive"] = false
	assert_true(BondCampaign.scene_state(knight_pair) == "unavailable", "bond: a fallen member closes the scene")
	GameState.roster["unit_knight"]["alive"] = true
	assert_true(BondCampaign.s_state(knight_pair) == "not_yet", "bond S: not before the A scene")
	BondCampaign.rank_up(knight_pair, "A")
	assert_true(BondCampaign.s_state(knight_pair) == "available" and BondCampaign.s_state(lancer_pair) == "not_eligible", "bond S: available after A for a whitelisted pair only")
	# Beastwoman also at A: two candidates for the Swordsman.
	BondCampaign.rank_up(beast_pair, "C")
	BondCampaign.rank_up(beast_pair, "B")
	BondCampaign.rank_up(beast_pair, "A")
	assert_true(BondCampaign.s_state(beast_pair) == "available", "bond S: second candidate available before any lock")
	# Camp: the lock waits for confirmation; Cancel changes nothing.
	var camp := CampScene.new()
	add_child(camp)
	await get_tree().process_frame
	camp._confirm_lock_s(knight_pair)
	var dialog: ConfirmationDialog = null
	for child in camp.get_children():
		if child is ConfirmationDialog:
			dialog = child
	assert_true(dialog != null and GameState.s_pairs.is_empty(), "bond S: a confirmation is shown first, nothing locked yet")
	dialog.canceled.emit()
	assert_true(GameState.s_pairs.is_empty() and GameState.bond_rank_for("bond_swordsman_knight") == "A", "bond S: Cancel changes nothing")
	dialog.confirmed.emit()
	assert_true(GameState.bond_rank_for("bond_swordsman_knight") == "S" and String(GameState.s_pairs.get("unit_swordsman", "")) == "bond_swordsman_knight" and String(GameState.s_pairs.get("unit_knight", "")) == "bond_swordsman_knight", "bond S: confirm locks rank S with symmetric partners")
	assert_true(BondCampaign.s_state(knight_pair) == "locked" and BondCampaign.s_state(beast_pair) == "closed", "bond S: the other candidate is closed")
	assert_true(not BondCampaign.lock_s(beast_pair) and GameState.bond_rank_for("bond_swordsman_beastwoman") == "A", "bond S: a closed pair cannot lock, its A bonus stays")
	camp.queue_free()


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
	# Designer: no aftermath scene on a loss - straight to the Game Over screen.
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
	battle._on_left_click(hero.pos)                 # select: the GDD Action Menu (Rule 11) opens
	var menu_texts: Array = []
	for b in battle._action_menu.get_children():
		if b is Button and not b.is_queued_for_deletion():
			menu_texts.append((b as Button).text)
	assert_true(menu_texts.size() >= 2 and menu_texts[0] == "Attack" and menu_texts[-1] == "Wait", "forecast: the Action Menu lists Attack first and Wait last (GDD Rule 11, superseding D01's no-button flow) %s" % str(menu_texts))
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
	## F-OBJ timed Escort (GDD Core Rule 10, replaces the retired evacuate type): the NPC must
	## live through N enemy phases — or every enemy falls first; its death loses at once.
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	_spawn(state, "evacuee", "faction_npc", Vector2i(3, 3))
	_spawn(state, "hunter", "faction_e", Vector2i(5, 5))
	var esc := ObjectiveBase.create({"type": "escort", "params": {"npc_unit_id": "evacuee", "turns_required": 2}})
	esc.on_event(state, "player_phase_ended", {})
	assert_true(String(esc.evaluate(state)["status"]) == "ongoing" and int(state.objective_counters.get("escort_turns", 0)) == 0, "escort timed: player phases do not count")
	esc.on_event(state, "enemy_phase_ended", {})
	assert_true(String(esc.evaluate(state)["status"]) == "ongoing", "escort timed: 1/2 enemy phases")
	esc.on_event(state, "enemy_phase_ended", {})
	assert_true(String(esc.evaluate(state)["status"]) == "win", "escort timed: wins after 2 enemy phases")
	state.units["evacuee"].alive = false
	assert_true(String(esc.evaluate(state)["status"]) == "lose", "escort timed: the NPC's death loses")
	var state2: BattleState = _plain_map_enemy_state()
	_spawn(state2, "evacuee2", "faction_npc", Vector2i(3, 3))
	_spawn(state2, "hunter2", "faction_e", Vector2i(5, 5))
	var esc2 := ObjectiveBase.create({"type": "escort", "params": {"npc_unit_id": "evacuee2", "turns_required": 5}})
	assert_true(String(esc2.evaluate(state2)["status"]) == "ongoing", "escort timed: enemies left, ongoing")
	state2.units["hunter2"].alive = false
	assert_true(String(esc2.evaluate(state2)["status"]) == "win", "escort timed: defeating every enemy first also wins")
	var dest := ObjectiveBase.create({"type": "escort", "params": {"npc_unit_id": "evacuee2", "target_cell_x": 0, "target_cell_y": 0}})
	assert_true(String(dest.evaluate(state2)["status"]) == "ongoing", "escort destination: no enemies left still does not win")


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
	var faction := DataRegistry.get_faction("faction_rebel_ch01")
	var chip_text := (chip.get_child(1) as Label).text
	assert_true(chip_text == faction.display_name and not chip_text.contains("%"), "pressure: chip shows the faction name only, no number or word (AC-BUI32)")
	assert_true((chip.get_child(0) as ColorRect).color.is_equal_approx(faction.attitude_colors["safe"]), "pressure: no kills -> fully green")
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
	var one_kill := BattleScene.pressure_color(1.0 / 4.0, faction.attitude_colors)
	assert_true((chip.get_child(0) as ColorRect).color.is_equal_approx(one_kill), "pressure: one kill of four moves the bar toward yellow live")
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
	assert_true((chip.get_child(0) as ColorRect).color.is_equal_approx(faction.attitude_colors["safe"]), "pressure: rewind turns the bar back to green (AC-BUI34)")
	# F-PS4 lockstep: the ratio reaches 1.0 exactly at the threshold, and stays there.
	var st := director.state
	st.reconcile_state["faction_rebel_ch01"]["kills"] = 3
	assert_true(is_equal_approx(ReconcileSystem.kill_pressure_ratio(st, "faction_rebel_ch01"), 0.75), "pressure: 3 of 4 kills -> 0.75 (GDD example)")
	st.reconcile_state["faction_rebel_ch01"]["kills"] = 4
	assert_true(ReconcileSystem.kill_pressure_ratio(st, "faction_rebel_ch01") == 1.0, "pressure: threshold reached -> 1.0 (AC-PS14)")
	st.reconcile_state["faction_rebel_ch01"]["kills"] = 9
	assert_true(ReconcileSystem.kill_pressure_ratio(st, "faction_rebel_ch01") == 1.0, "pressure: clamped at 1.0 past the threshold")
	battle._refresh_reconcile_hud()
	await get_tree().process_frame
	chip = battle._reconcile_chip_box.get_child(0)
	assert_true((chip.get_child(0) as ColorRect).color.is_equal_approx(faction.attitude_colors["lost"]), "pressure: pinned fully red once unpersuadable")
	var saved_threshold: Variant = faction.reconcile["kill_threshold"]
	faction.reconcile["kill_threshold"] = 0
	st.reconcile_state["faction_rebel_ch01"]["kills"] = 0
	assert_true(ReconcileSystem.kill_pressure_ratio(st, "faction_rebel_ch01") == 1.0, "pressure: threshold 0 pins the ratio to 1.0 (AC-PS15)")
	faction.reconcile["kill_threshold"] = saved_threshold
	assert_true(not BattleScene.pressure_color(0.3, faction.attitude_colors).is_equal_approx(BattleScene.pressure_color(0.4, faction.attitude_colors)), "pressure: 0.3 and 0.4 give different colours, a gradient not bands (AC-BUI31)")
	assert_true(BattleScene.pressure_color(0.5, faction.attitude_colors).is_equal_approx(faction.attitude_colors["neutral"]), "pressure: 0.5 is yellow")
	st.reconcile_state["faction_rebel_ch01"]["evaluated"] = true
	st.reconcile_state["faction_rebel_ch01"]["persuaded"] = true
	battle._refresh_reconcile_hud()
	await get_tree().process_frame
	assert_true(not battle._reconcile_chip_box.get_child(0).visible, "pressure: hidden once the faction is persuaded (AC-BUI30)")
	main.queue_free()

	# PrepScreen carries the same warning when the map has a remnant faction (T12 detail).
	var prep := PrepScene.build(chapter)
	add_child(prep)
	await get_tree().process_frame
	assert_true(_has_label_containing(prep, "persuade the remnants"), "reconcile: prep screen shows the limit-kills note")
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
	## F-OBJ Seize (GDD Core Rule 14): only the end of each ENEMY phase counts; a player unit on
	## the point adds 1, an empty or enemy-held point resets to 0; N in a row wins before the
	## next player phase; killing every enemy does not win.
	var map := MapData.new()
	map.id = "seize_map"
	var rows_cap: Array[String] = ["......", "......", "......", "......"]
	map.terrain_rows = rows_cap
	map.deploy_cells = [Vector2i(0, 0)]
	map.objectives = [{"type": "seize", "params": {"control_x": 0, "control_y": 0, "hold_enemy_phases": 2}}]
	var director := BattleDirector.new()
	director.setup(map, {}, "normal")
	var holder := _spawn(director.state, "cap_p", "faction_p", Vector2i(0, 0), false, false, "player")
	var foe := _spawn(director.state, "cap_e", "faction_cap", Vector2i(5, 3), false, false, "enemy")
	director.end_player_phase()
	assert_true(int(director.state.objective_counters.get("seize_hold", 0)) == 0, "seize: the player phase end does not count")
	director.advance_after_enemy_phase()
	assert_true(int(director.state.objective_counters.get("seize_hold", 0)) == 1, "seize: held at the enemy phase end = 1")
	# The enemy takes the point: progress resets (and occupation alone is no defeat).
	holder.pos = Vector2i(5, 0)
	foe.pos = Vector2i(0, 0)
	director.advance_after_enemy_phase()
	assert_true(int(director.state.objective_counters.get("seize_hold", 0)) == 0 and director.state.battle_over.is_empty(), "seize: enemy on the point resets to 0, no defeat")
	foe.pos = Vector2i(5, 3)
	director.advance_after_enemy_phase()
	assert_true(int(director.state.objective_counters.get("seize_hold", 0)) == 0, "seize: an empty point keeps 0")
	# Another player unit can take over the hold.
	_spawn(director.state, "cap_p2", "faction_p", Vector2i(0, 0), false, false, "player")
	foe.alive = false
	assert_true(String(director.objectives[0].evaluate(director.state)["status"]) == "ongoing", "seize: killing every enemy does not win")
	director.advance_after_enemy_phase()
	director.advance_after_enemy_phase()
	assert_true(director.state.battle_over.get("status", "") == "win", "seize: two held enemy phases in a row win right away")



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
	var obj := ObjectiveBase.create({"type": "elimination", "params": {}})
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
	assert_true(UIBuilder.t("elimination") == "Tiêu diệt" and ObjectiveBase.create({"type": "elimination", "params": {}}).describe().begins_with("Tiêu diệt"), "i18n: objective names and descriptions translated")
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
	var levels: Dictionary = DataRegistry.rule("enemy_bonus_levels_by_difficulty", {})
	assert_true(is_equal_approx(float(table["nightmare"]), 1.0) and is_equal_approx(float(table["hard"]), 1.0), "difficulty: stat multiplier is 1.0 on every tier (superseded by levels)")
	assert_true(int(levels["story"]) == 0 and int(levels["normal"]) == 0 and int(levels["hard"]) == 2 and int(levels["nightmare"]) == 4, "difficulty: enemy bonus levels 0 / 0 / +2 / +4")
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
	var expect := UnitState.from_data(DataRegistry.get_unit("unit_rebel_commander"), Vector2i.ZERO, foe_n.level + 4)
	expect.apply_enemy_levels()
	assert_true(foe_x.level == foe_n.level + 4 and foe_x.power == expect.power and foe_x.max_hp == expect.max_hp and foe_x.defense == expect.defense, "difficulty: Nightmare enemy is 4 levels higher, stats from its growths")
	assert_true(foe_x.max_hp > foe_n.max_hp, "difficulty: the extra levels raise HP too (Fire Emblem style)")
	assert_true(nightmare.state.units["unit_swordsman"].power == normal.state.units["unit_swordsman"].power, "difficulty: player units never scaled")


## F-OBJ markers: each objective reports what the map must show (zones, tiles, units, progress)
## and the map view draws them live.
func test_objective_markers() -> void:
	await 0.0
	var state: BattleState = _plain_map_enemy_state()
	_spawn(state, "boss", "faction_e", Vector2i(5, 5), false, false, "enemy")
	_spawn(state, "npc", "faction_npc", Vector2i(1, 1), false, false, "npc")
	var zone := ObjectiveBase.create({"type": "protect", "params": {"zone_x": 2, "zone_y": 2, "zone_w": 2, "zone_h": 1, "survive_enemy_phases": 2}})
	var zm: Array = zone.markers(state)
	assert_true(zm.size() == 1 and String(zm[0]["kind"]) == "zone" and zm[0]["rect"] == Rect2i(2, 2, 2, 1) and String(zm[0]["text"]) == "P 0/2", "markers: protect zone rect and progress")
	zone.on_event(state, "enemy_phase_ended", {})
	assert_true(String(zone.markers(state)[0]["text"]) == "P 1/2", "markers: progress updates live")
	var dest: Array = ObjectiveBase.create({"type": "escort", "params": {"npc_unit_id": "npc", "target_cell_x": 4, "target_cell_y": 0}}).markers(state)
	assert_true(dest.size() == 2 and String(dest[0]["unit_id"]) == "npc" and String(dest[1]["kind"]) == "goal" and dest[1]["cell"] == Vector2i(4, 0), "markers: escort NPC ring + goal tile")
	var timed: Array = ObjectiveBase.create({"type": "escort", "params": {"npc_unit_id": "npc", "turns_required": 3}}).markers(state)
	assert_true(timed.size() == 1 and String(timed[0]["text"]) == "0/3", "markers: timed escort shows the countdown on the NPC")
	var seize: Array = ObjectiveBase.create({"type": "seize", "params": {"control_x": 3, "control_y": 3, "hold_enemy_phases": 2}}).markers(state)
	assert_true(String(seize[0]["kind"]) == "point" and seize[0]["cell"] == Vector2i(3, 3) and String(seize[0]["text"]) == "0/2", "markers: seize point and hold progress")
	assert_true(ObjectiveBase.create({"type": "elimination", "params": {}}).markers(state).is_empty(), "markers: rout-all needs no marker")
	var boss_m: Array = ObjectiveBase.create({"type": "elimination", "params": {"target_unit_ids": ["boss"]}}).markers(state)
	assert_true(boss_m.size() == 1 and String(boss_m[0]["unit_id"]) == "boss", "markers: a named target gets a ring")
	var retrieve := ObjectiveBase.create({"type": "retrieve", "params": {"item_id": "item_border_relic", "exit_zone_x": 0, "exit_zone_y": 5}})
	state.item_ground["4,4"] = "item_border_relic"
	var rm: Array = retrieve.markers(state)
	assert_true(rm.size() == 2 and String(rm[0]["kind"]) == "exit" and String(rm[1]["kind"]) == "item" and rm[1]["cell"] == Vector2i(4, 4), "markers: retrieve exit + item on the ground")
	state.item_ground.clear()
	var hauler := _spawn(state, "hauler", "faction_p", Vector2i(4, 4), false, false, "player")
	hauler.carried_item = "item_border_relic"
	var rm2: Array = retrieve.markers(state)
	assert_true(rm2.size() == 2 and String(rm2[1]["unit_id"]) == "hauler", "markers: the carrier is marked once the item is taken")
	# The map view draws the markers of a real battle without errors.
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var map := DataRegistry.get_map("map_test_defend")
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	var view := BattleMapView.new()
	view.set_state(director.state, director.player_sides)
	view.set_objectives(director.objectives)
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(view.current_markers().size() == 1 and String(view.current_markers()[0]["kind"]) == "zone", "map view: the test map's protect zone is drawn")
	view.queue_free()


## F-DRS (GDD F-DRS1/F-DRS2): restraint score from the battle state at the end, and the
## victory-only bonus EXP for every living deployed unit.
func test_dual_restraint() -> void:
	await 0.0
	GameState.new_game()
	# F4: tests exercise the legacy ch01 data, not the demo campaign.
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_knight": map.deploy_cells[1]}, "normal")
	var state := director.state
	var r: Dictionary = DualRestraint.result(state)
	assert_true(bool(r["kill_restraint_eligible"]) and bool(r["zero_ally_deaths"]) and bool(r["low_kill_restraint"]) and bool(r["swift_clear_met"]), "drs: eligible ch01, clean start")
	assert_true(int(r["restraint_points_awarded"]) == 150 and int(r["bonus_exp"]) == 30, "drs: 50+50+25+25 = 150 points, 15+15 bonus EXP")
	for faction_id in state.reconcile_state:
		state.reconcile_state[faction_id]["kills"] = 3
	r = DualRestraint.result(state)
	assert_true(not bool(r["low_kill_restraint"]) and int(r["restraint_points_awarded"]) == 75 and int(r["bonus_exp"]) == 15, "drs: 3 kills > tolerance 2 -> 75 points, 15 EXP")
	state.turn = int(map.turn_par) + 1
	assert_true(not bool(DualRestraint.result(state)["swift_clear_met"]), "drs: past turn par is not a swift clear")
	state.turn = 1
	# Deaths only break the ally condition on a permadeath tier (GDD Core Rule 2).
	state.units["unit_knight"].alive = false
	assert_true(not DualRestraint.zero_ally_deaths(state), "drs: F-CAS - a fallen ally breaks zero_ally_deaths on Normal too")
	state.difficulty = "hard"
	assert_true(not DualRestraint.zero_ally_deaths(state), "drs: and on Hard")
	state.units["unit_knight"].alive = true
	state.difficulty = "normal"
	# A map with no persuadable faction: no kill / perfect terms, ceiling 75.
	var plain: BattleState = _plain_map_enemy_state()
	plain.reconcile_state.clear()
	var rp: Dictionary = DualRestraint.result(plain)
	assert_true(not bool(rp["kill_restraint_eligible"]) and int(rp["kill_points"]) == 0 and int(rp["perfect_bonus"]) == 0 and int(rp["restraint_points_awarded"]) <= 75, "drs: ineligible map caps at 75")
	# Victory: the squad gets the bonus EXP once, before the result's EXP lines are read.
	for faction_id in state.reconcile_state:
		state.reconcile_state[faction_id]["kills"] = 0
	for soldier_id in ["unit_rebel_soldier_1", "unit_rebel_soldier_2", "unit_rebel_soldier_3"]:
		state.units[soldier_id].alive = false
	director.commit("wait", {"unit_id": "unit_swordsman"})
	assert_true(String(state.battle_over.get("status", "")) == "win", "drs: setup victory")
	var locked: Dictionary = state.battle_over["restraint"]
	var expected_exp := int(locked["bonus_exp"])
	assert_true(expected_exp > 0 and int(state.units["unit_knight"].exp) == expected_exp, "drs: every living deployed unit got the bonus EXP (%d)" % expected_exp)
	assert_true(int(state.battle_over["exp"].get("unit_knight", 0)) == expected_exp, "drs: the result lists the bonus EXP for the post-battle screen")
	director._on_state_changed()
	assert_true(int(state.units["unit_knight"].exp) == expected_exp, "drs: the bonus is granted only once")
	# Post-battle shows the breakdown; Game Over shows the score as not awarded.
	ResultStore.last_result = state.battle_over
	var post := PostBattleScene.build(GameState.current_chapter())
	add_child(post)
	await get_tree().process_frame
	assert_true(_has_label_containing(post, "Restraint score: %d" % int(locked["restraint_points_awarded"])), "drs: post-battle shows the restraint score")
	post.queue_free()
	ResultStore.last_result = {"status": "lose", "restraint": {"restraint_points_awarded": 75}}
	var over := GameOverScene.build(null)
	add_child(over)
	await get_tree().process_frame
	assert_true(_has_label_containing(over, "not awarded"), "drs: Game Over marks the score as not awarded")
	over.queue_free()
	# Defeat: no bonus EXP.
	var lost := BattleDirector.new()
	lost.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_knight": map.deploy_cells[1]}, "normal")
	lost.state.units["unit_swordsman"].alive = false
	lost.commit("wait", {"unit_id": "unit_knight"})
	assert_true(String(lost.state.battle_over.get("status", "")) == "lose" and int(lost.state.units["unit_knight"].exp) == 0, "drs: no bonus EXP on a defeat")


## F-PSI / F-PS3: kills committed by earlier victories carry into later battles of the
## same faction (ratio, persuasion), are never rewound, and only a victory commits them.
func test_persistent_faction_kills() -> void:
	await 0.0
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	assert_true(GameState.faction_kill_counts.is_empty(), "kills: a new campaign starts with no committed kills")
	var fid := "faction_rebel_ch01"
	GameState.faction_kill_counts[fid] = 2
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_knight": map.deploy_cells[1]}, "normal")
	var state := director.state
	assert_true(int(state.reconcile_state[fid]["prior_kills"]) == 2 and ReconcileSystem.effective_kills(state, fid) == 2, "kills: earlier kills loaded at battle start")
	assert_true(is_equal_approx(ReconcileSystem.kill_pressure_ratio(state, fid), 0.5), "kills: 2 earlier kills of 4 -> the bar starts at 0.5")
	var snap := state.to_dict()
	state.reconcile_state[fid]["kills"] = 1
	assert_true(is_equal_approx(ReconcileSystem.kill_pressure_ratio(state, fid), 0.75), "kills: 2 earlier + 1 now -> 0.75 (GDD example)")
	state.from_dict(snap)
	assert_true(int(state.reconcile_state[fid]["prior_kills"]) == 2 and int(state.reconcile_state[fid]["kills"]) == 0, "kills: rewind restores this battle's kills only (AC-RW9)")
	# 2 earlier + 2 now reaches the threshold of 4: no persuasion even with the event met.
	state.reconcile_state[fid]["kills"] = 2
	ReconcileSystem.record_event(state, fid, "spared_commander")
	assert_true(not bool(ReconcileSystem.evaluate(state)[fid]["persuaded"]), "kills: earlier kills count toward the threshold (F-PS1)")
	state.reconcile_state[fid]["kills"] = 1
	assert_true(bool(ReconcileSystem.evaluate(state)[fid]["persuaded"]), "kills: 2 earlier + 1 now stays under 4 -> persuaded")
	# Dual Restraint still judges this battle only.
	assert_true(int(DualRestraint.result(state)["battle_kill_count"]) == 1, "kills: restraint score counts this battle's kills only")
	# Defeat commits nothing (designer: game over keeps nothing); a victory adds this battle's kills.
	CampaignMerge.merge(state, chapter, {"status": "lose"})
	assert_true(int(GameState.faction_kill_counts[fid]) == 2, "kills: a defeat commits no kills")
	CampaignMerge.merge(state, chapter, {"status": "win"})
	assert_true(int(GameState.faction_kill_counts[fid]) == 3, "kills: a victory adds this battle's kills (F-PS3)")
	var saved := GameState.to_dict().duplicate(true)   # a real save is written to disk first
	GameState.new_game()
	assert_true(GameState.faction_kill_counts.is_empty(), "kills: New campaign clears them")
	GameState.from_dict(saved)
	assert_true(int(GameState.faction_kill_counts.get(fid, 0)) == 3, "kills: saved and loaded with the campaign")
	saved.erase("faction_kill_counts")
	GameState.from_dict(saved)
	assert_true(GameState.faction_kill_counts.is_empty(), "kills: an old save without the field loads as 0")
	GameState.new_game()


## F-BAD: a victory while a faction's pressure bar is red plays the bad ending (dialogue,
## then the Bad Ending screen) instead of post-battle; nothing is merged.
func test_bad_ending() -> void:
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var fid := "faction_rebel_ch01"
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	# Win ch01 with 2 earlier + 2 battle kills (threshold 4): red at chapter end.
	GameState.faction_kill_counts[fid] = 2
	var director := BattleDirector.new()
	director.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_knight": map.deploy_cells[1]}, "normal")
	director.state.reconcile_state[fid]["kills"] = 2
	for soldier_id in ["unit_rebel_soldier_1", "unit_rebel_soldier_2", "unit_rebel_soldier_3"]:
		director.state.units[soldier_id].alive = false
	director.commit("wait", {"unit_id": "unit_swordsman"})
	var result: Dictionary = director.state.battle_over
	assert_true(String(result.get("status", "")) == "win" and Array(result.get("bad_ending_factions", [])) == [fid], "bad ending: the red faction is listed on the victory")
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	main._battle_director = director
	ResultStore.last_result = result
	main._show_post_battle(true)
	await get_tree().process_frame
	var dlg_player := main._current as DialoguePlayer
	assert_true(dlg_player != null, "bad ending: the bad-ending dialogue plays first")
	if dlg_player != null:
		dlg_player.finished.emit(true)
	await get_tree().process_frame
	var screen := main._current as BadEndingScene
	assert_true(screen != null, "bad ending: then the Bad Ending screen")
	assert_true(screen != null and _find_button(screen, "Retry chapter") != null and _find_button(screen, "Main menu") != null, "bad ending: Retry chapter and Main menu offered")
	assert_true(BadEndingScene.faction_lines(result)[0].contains(DataRegistry.get_faction(fid).display_name), "bad ending: names the faction, no numbers")
	assert_true(not GameState.completed_chapters.has(String(chapter.id)) and GameState.current_chapter() == chapter, "bad ending: chapter neither completed nor advanced")
	assert_true(int(GameState.faction_kill_counts[fid]) == 2, "bad ending: this battle's kills are not committed")
	main.queue_free()
	await get_tree().process_frame
	# Not red: the three fallen soldiers count as 3 kills of 4 (event missing too) - a plain victory.
	GameState.faction_kill_counts.clear()
	var clean := BattleDirector.new()
	clean.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_knight": map.deploy_cells[1]}, "normal")
	for soldier_id in ["unit_rebel_soldier_1", "unit_rebel_soldier_2", "unit_rebel_soldier_3"]:
		clean.state.units[soldier_id].alive = false
	clean.commit("wait", {"unit_id": "unit_swordsman"})
	assert_true(Array(clean.state.battle_over.get("bad_ending_factions", [])).is_empty(), "bad ending: a bar below red does not trigger it")
	GameState.new_game()


## P-11: the demo campaign starts with Swordsman x Knight at rank C / 2 points; the next
## scene (B) opens at 5 points; the legacy campaign gets no starting bond.
func test_demo_starting_bond() -> void:
	await 0.0
	var pid := "bond_demo_swordsman_knight"
	GameState.new_game()
	GameState.build_roster()   # demo campaign by default
	assert_true(GameState.bond_rank_for(pid) == "C" and int(GameState.bond_points.get(pid, 0)) == 2, "demo bond: new demo campaign starts at rank C with 2 points")
	assert_true(Array(GameState.bond_scenes_viewed.get(pid, [])) == ["C"], "demo bond: the C scene counts as seen")
	var pair := DataRegistry.get_data("bonds", pid)
	assert_true(BondCampaign.next_rank(pair) == "B" and BondCampaign.points_missing(pair) == 3, "demo bond: next scene is B, 3 points away (B at 5)")
	GameState.bond_points[pid] = 5
	assert_true(BondCampaign.scene_state(pair) == "ready", "demo bond: B opens at 5 points")
	BondCampaign.rank_up(pair, "B")
	GameState.merge_roster_with_data()   # what Continue runs after loading a save
	assert_true(GameState.bond_rank_for(pid) == "B" and int(GameState.bond_points[pid]) == 5, "demo bond: Continue keeps the saved rank, the start state only applies to a new campaign")
	GameState.bond_ranks[pid] = "C"
	# In battle the C rank gives the adjacency bonus to the two demo units.
	GameState.bond_points[pid] = 2
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_demo_swordsman": map.deploy_cells[0], "unit_demo_knight": map.deploy_cells[1]}, "normal")
	var sword: UnitState = director.state.units["unit_demo_swordsman"]
	director.state.units["unit_demo_knight"].pos = sword.pos + Vector2i(1, 0)
	assert_true(BondSystem._adjacency_bonus(director.state, sword) == int(DataRegistry.rule("bond_bonus_by_rank", {}).get("C", 3)), "demo bond: adjacent demo units get the rank C bonus in battle")
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	assert_true(GameState.bond_rank_for(pid) == "" and not GameState.bond_points.has(pid), "demo bond: the legacy campaign has no demo starting bond")
	GameState.new_game()


## F-ELV: demo enemies are level-1 templates plus fixed level gains from their class growths,
## applied before the difficulty multiplier; level-1 enemies (legacy ch01) are unchanged.
func test_enemy_levels() -> void:
	await 0.0
	GameState.new_game()
	GameState.build_roster()   # demo campaign
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_demo_swordsman": map.deploy_cells[0], "unit_demo_knight": map.deploy_cells[1]}, "normal")
	var guard: UnitState = null
	for u in director.state.units.values():
		if u.side == "enemy" and u.class_id == "class_guard":
			guard = u
			break
	assert_true(guard != null and guard.level == 5, "enemy level: demo guard is level 5")
	if guard != null:
		assert_true(guard.max_hp == 22 and guard.hp == 22 and guard.power == 8 and guard.skill == 5 and guard.speed == 6 and guard.luck == 3 and guard.defense == 5 and guard.resistance == 2, "enemy level: guard L5 = HP 22 Str 8 Skill 5 Spd 6 Luck 3 Def 5 Res 2 (F-ELV table)")
	var sword: UnitState = director.state.units["unit_demo_swordsman"]
	assert_true(sword.skill == 10 and director.state.units["unit_demo_knight"].skill == 6, "enemy level: demo Swordsman / Knight Skill on the roster scale (10 / 6)")
	assert_true(sword.level == 1 and sword.max_hp == 28, "enemy level: player units are never auto-levelled")
	# Commander: level 6 from its own template.
	var cmd := UnitState.from_data(DataRegistry.get_unit("unit_demo_commander"), Vector2i.ZERO)
	cmd.side = "enemy"
	cmd.apply_enemy_levels()
	assert_true(cmd.max_hp == 25 and cmd.power == 8 and cmd.skill == 7 and cmd.speed == 7 and cmd.luck == 6 and cmd.defense == 5 and cmd.resistance == 4, "enemy level: commander L6 = HP 25 Str 8 Skill 7 Spd 7 Luck 6 Def 5 Res 4")
	# A placement level overrides the template, and the result is deterministic.
	var lv9 := UnitState.from_data(DataRegistry.get_unit("unit_demo_guard"), Vector2i.ZERO, 9)
	lv9.apply_enemy_levels()
	assert_true(lv9.max_hp == 25 and lv9.power == 10 and lv9.skill == 6, "enemy level: placement level 9 -> HP 25 Str 10 Skill 6, same every time")
	# Hard / Nightmare add levels: guard L7 = HP 24 Str 9 Skill 6 Spd 7 Def 5; L9 = HP 25 Str 10 Skill 6 Spd 7 Def 6.
	for tier in ["hard", "nightmare"]:
		var tough := BattleDirector.new()
		tough.setup(map, {"unit_demo_swordsman": map.deploy_cells[0], "unit_demo_knight": map.deploy_cells[1]}, tier)
		var g: UnitState = tough.state.units[guard.id]
		if tier == "hard":
			assert_true(g.level == 7 and g.max_hp == 24 and g.power == 9 and g.skill == 6 and g.speed == 7 and g.defense == 5, "enemy level: Hard guard is L7 (HP 24 Str 9 Skill 6 Spd 7 Def 5)")
		else:
			assert_true(g.level == 9 and g.max_hp == 25 and g.power == 10 and g.skill == 6 and g.speed == 7 and g.defense == 6, "enemy level: Nightmare guard is L9 (HP 25 Str 10 Skill 6 Spd 7 Def 6)")
		assert_true(tough.state.units["unit_demo_swordsman"].level == 1, "enemy level: player units get no difficulty levels")
	# Hit chances land in the approved band (plain-ground numbers checked by formula).
	assert_true(CombatResolver._hit_pct(director.state, sword, guard) < 100 and CombatResolver._hit_pct(director.state, guard, sword) <= 75, "enemy level: no more near-certain hits both ways")
	# Legacy ch01 rebels are level 1: unchanged.
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var ch01 := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var legacy := BattleDirector.new()
	legacy.setup(ch01, {"unit_swordsman": ch01.deploy_cells[0]}, "normal")
	var rebel: UnitState = legacy.state.units["unit_rebel_soldier_1"]
	var fresh := UnitState.from_data(DataRegistry.get_unit("unit_rebel_soldier_1"), Vector2i.ZERO)
	assert_true(rebel.power == fresh.power and rebel.max_hp == fresh.max_hp and rebel.skill == fresh.skill, "enemy level: level-1 legacy enemies keep their stats")
	GameState.new_game()


## F-FST: faction state is campaign-wide - Engaged after a victory, Persuaded is terminal and
## a later battle ignores that faction (no tracking, no chip, no bad ending); saved with the game.
func test_faction_state_across_chapters() -> void:
	await 0.0
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var fid := "faction_rebel_ch01"
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	assert_true(GameState.faction_state(fid) == "unengaged", "faction state: unengaged before the first battle")
	# Victory without persuasion -> Engaged.
	var d1 := BattleDirector.new()
	d1.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	CampaignMerge.merge(d1.state, chapter, {"status": "win", "reconcile": {fid: {"persuaded": false, "kills": 1}}})
	assert_true(GameState.faction_state(fid) == "engaged" and not GameState.is_faction_terminal(fid), "faction state: a victory without persuasion leaves it Engaged")
	# A defeat writes nothing.
	CampaignMerge.merge(d1.state, chapter, {"status": "lose", "reconcile": {fid: {"persuaded": true}}})
	assert_true(GameState.faction_state(fid) == "engaged", "faction state: a defeat changes nothing")
	# Persuaded on a later victory -> terminal.
	CampaignMerge.merge(d1.state, chapter, {"status": "win", "reconcile": {fid: {"persuaded": true, "kills": 0}}})
	assert_true(GameState.faction_state(fid) == "persuaded" and GameState.is_faction_terminal(fid), "faction state: persuaded is terminal")
	# Next battle with that faction: not tracked at all.
	var d2 := BattleDirector.new()
	d2.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	assert_true(not d2.state.reconcile_state.has(fid), "faction state: a persuaded faction is not tracked in later battles")
	var soldier: UnitState = d2.state.units["unit_rebel_soldier_1"]
	soldier.alive = false
	ReconcileSystem.record_kill(d2.state, soldier)
	assert_true(not bool(DualRestraint.result(d2.state)["kill_restraint_eligible"]) and ReconcileSystem.unpersuadable_factions(d2.state).is_empty(), "faction state: no kill term, no bad ending from a persuaded faction")
	# It stays persuaded whatever happens next.
	CampaignMerge.merge(d2.state, chapter, {"status": "win", "reconcile": {}})
	assert_true(GameState.faction_state(fid) == "persuaded", "faction state: terminal states never change")
	# The battle HUD shows no chip and the prep screen no kill warning for it.
	var battle := BattleScene.new()
	battle.setup(d2)
	add_child(battle)
	await get_tree().process_frame
	assert_true(battle._reconcile_chip_box == null, "faction state: no pressure chip for a persuaded faction")
	battle.queue_free()
	var prep := PrepScene.build(chapter)
	add_child(prep)
	await get_tree().process_frame
	assert_true(not _has_label_containing(prep, "persuade the remnants"), "faction state: no kill warning on the prep screen")
	prep.free()
	# True ending: persuaded later still counts, even if the chapter outcome said no.
	GameState.completed_chapters[String(chapter.id)] = true
	GameState.reconcile_outcomes[String(chapter.id)] = {fid: {"persuaded": false}}
	assert_true(GameState.is_true_ending_eligible(), "faction state: persuaded later counts for the true ending")
	# Saved and loaded; old saves read as Unengaged.
	var saved := GameState.to_dict().duplicate(true)
	GameState.new_game()
	assert_true(GameState.faction_state(fid) == "unengaged", "faction state: New campaign resets it")
	GameState.from_dict(saved)
	assert_true(GameState.faction_state(fid) == "persuaded", "faction state: saved and loaded with the campaign")
	saved.erase("faction_states")
	GameState.from_dict(saved)
	assert_true(GameState.faction_states.is_empty(), "faction state: an old save loads as Unengaged")
	GameState.new_game()


## Playtest regressions: (1) enemy AI picks its standing cell among cells it can reach, so it
## moves and attacks in the same turn; (2) NPC / enemy approach follows real paths around
## water instead of freezing at the bank (demo_02 escort was unwinnable).
func test_ai_pathing_regressions() -> void:
	await 0.0
	GameState.new_game()
	GameState.build_roster()
	var maps := DataRegistry.chapters_sorted("demo")
	var m1 := DataRegistry.get_map(String(maps[0].map_id))
	var d1 := BattleDirector.new()
	d1.setup(m1, {"unit_demo_swordsman": m1.deploy_cells[0], "unit_demo_knight": m1.deploy_cells[1]}, "normal", 7)
	var sword: UnitState = d1.state.units["unit_demo_swordsman"]
	var enemy: UnitState = null
	for u in d1.state.units.values():
		if u.side == "enemy":
			enemy = u
			break
	sword.pos = enemy.pos + Vector2i(-3, 0)
	var plan := EnemyAI.plan_unit(d1.state, enemy, ["player"])
	var reach := MovementHandler.compute_move_cells(d1.state, enemy)
	assert_true(String(plan.get("target_id", "")) == sword.id and (plan["move_cell"] == enemy.pos or reach.has(plan["move_cell"])), "ai: enemy plans a reachable standing cell and attacks in the same turn")
	assert_true(d1.commit_ai_plan(plan) and enemy.pos == plan["move_cell"], "ai: the planned move is legal and happens")
	# demo_02: the messenger walks around the water band toward its goal.
	var m2 := DataRegistry.get_map(String(maps[1].map_id))
	var d2 := BattleDirector.new()
	d2.setup(m2, {"unit_demo_swordsman": m2.deploy_cells[0], "unit_demo_knight": m2.deploy_cells[1]}, "normal", 7)
	var npc: UnitState = d2.state.units["messenger"]
	var goal: Vector2i = d2._npc_goals()["messenger"]
	var field := MovementHandler.distance_field(d2.state, npc, goal)
	var start_cost := float(field.get(npc.pos, INF))
	for turn in 6:
		npc.acted = false
		var walk := NpcAI.plan_walk(d2.state, npc, goal)
		if walk["move_cell"] != npc.pos:
			npc.pos = walk["move_cell"]
	assert_true(float(field.get(npc.pos, INF)) < start_cost - 4.0, "ai: the escort NPC keeps making progress around the water (path cost %.1f -> %.1f)" % [start_cost, float(field.get(npc.pos, INF))])
	# Designer 08-11-2026: the escort walks through a player unit standing on its path, not vice versa.
	var blocker: UnitState = d2.state.units["unit_demo_swordsman"]
	npc.pos = Vector2i(5, 4)
	blocker.pos = Vector2i(6, 4)
	npc.acted = false
	var through := NpcAI.plan_walk(d2.state, npc, goal)
	assert_true(through["move_cell"] == Vector2i(7, 4), "ai: the escort NPC walks through our unit on its path (5,4) -> (7,4)")
	assert_true(not MovementHandler._passable(d2.state, blocker, npc.pos, false), "ai: our units still cannot walk through the NPC")


## F-ITEM: carried items, Use Item (heal / buff), Trade, Visit, villages destroyed by enemies,
## victory gold, the shop, saves and rewind.
func test_items_gold_and_shop() -> void:
	GameState.new_game()
	GameState.build_roster()   # demo campaign: the Swordsman starts with two tonics
	assert_true(Array(GameState.roster["unit_demo_swordsman"]["items"]) == ["item_vigor_tonic", "item_focus_tonic"], "items: roster units start with their data items")
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var d := BattleDirector.new()
	d.setup(map, {"unit_demo_swordsman": map.deploy_cells[0], "unit_demo_knight": map.deploy_cells[1]}, "normal")
	var st := d.state
	var sword: UnitState = st.units["unit_demo_swordsman"]
	var knight: UnitState = st.units["unit_demo_knight"]
	assert_true(sword.items.size() == 2, "items: the battle unit carries the roster items")
	# Buff item: +5 Skill, applied now, counted from the unit's next actions (3 of them).
	var skill_before := sword.eff("skill")
	assert_true(d.commit("use_item", {"unit_id": sword.id, "item_id": "item_focus_tonic"}), "items: Use Item commits")
	assert_true(sword.acted and not sword.items.has("item_focus_tonic") and sword.items.size() == 1, "items: the item is consumed and the action spent")
	assert_true(sword.eff("skill") == skill_before + 5 and int(sword.active_buffs["skill"]["turns_remaining"]) == 3, "items: Skill +5 for 3 later actions (the using action does not count)")
	assert_true(not d.commit("use_item", {"unit_id": sword.id, "item_id": "item_vigor_tonic"}), "items: one action per phase")
	for i in 3:
		PassiveSystem.on_unit_acted(sword)
	assert_true(sword.eff("skill") == skill_before and not sword.active_buffs.has("skill"), "items: the buff ends after 3 more actions")
	# Heal item: fixed amount, capped, and allowed at full HP (still consumed).
	knight.items = ["item_potion", "item_potion"]
	knight.hp = knight.max_hp - 4
	assert_true(d.commit("use_item", {"unit_id": knight.id, "item_id": "item_potion"}) and knight.hp == knight.max_hp and knight.items == ["item_potion"], "items: a potion heals up to max HP and is consumed")
	d.clear_acted_flags()
	assert_true(d.commit("use_item", {"unit_id": knight.id, "item_id": "item_potion"}) and knight.items.is_empty(), "items: using a potion at full HP is allowed and still consumes it (GDD edge case)")
	# Buffs overwrite, never stack.
	d.clear_acted_flags()
	sword.items = ["item_vigor_tonic", "item_vigor_tonic"]
	var pow_before := sword.eff("power")
	d.commit("use_item", {"unit_id": sword.id, "item_id": "item_vigor_tonic"})
	d.clear_acted_flags()
	d.commit("use_item", {"unit_id": sword.id, "item_id": "item_vigor_tonic"})
	assert_true(sword.eff("power") == pow_before + 5, "items: a second tonic on the same stat overwrites, never stacks")
	# Trade: free, once per phase, adjacent squad allies, capacity respected.
	d.clear_acted_flags()
	sword.active_buffs.clear()
	sword.items = ["item_elixir"]
	knight.items = ["item_potion"]
	knight.pos = sword.pos + Vector2i(0, 1)
	assert_true(d.commit("trade", {"unit_id": sword.id, "partner_id": knight.id, "give_item": "item_elixir", "take_item": "item_potion"}), "items: swap commits")
	assert_true(sword.items == ["item_potion"] and knight.items == ["item_elixir"] and not sword.acted, "items: Trade swaps and does not end the action")
	assert_true(not d.commit("trade", {"unit_id": sword.id, "partner_id": knight.id, "give_item": "item_potion", "take_item": ""}), "items: only one Trade per phase")
	d.clear_acted_flags()
	knight.items = ["item_elixir", "item_potion"]
	assert_true(not d.commit("trade", {"unit_id": sword.id, "partner_id": knight.id, "give_item": "item_potion", "take_item": ""}), "items: no gift into a full bag")
	assert_true(BattleScene.trade_options(st, sword, knight).size() == 4, "items: the trade menu lists only legal trades (2 takes + 2 swaps, no gift into a full bag)")
	knight.pos = sword.pos + Vector2i(3, 0)
	assert_true(not d.commit("trade", {"unit_id": sword.id, "partner_id": knight.id, "give_item": "item_potion", "take_item": "item_elixir"}), "items: Trade needs an adjacent ally")
	# Visit: the demo_01 village at (3,2) gives 10 gold once; rewind restores it.
	d.clear_acted_flags()
	var vcell := Vector2i(3, 2)
	assert_true(not st.open_village_at(vcell).is_empty(), "items: demo_01 has an open village")
	sword.pos = vcell
	var snap := st.to_dict()
	assert_true(d.commit("visit", {"unit_id": sword.id}) and st.gold_earned == 10 and sword.acted, "items: Visit claims 10 gold and spends the action")
	assert_true(st.open_village_at(vcell).is_empty(), "items: the village is inert after the visit")
	st.from_dict(snap)
	assert_true(not st.open_village_at(vcell).is_empty() and st.gold_earned == 0, "items: rewind restores the village and the gold")
	# An enemy ending its move on an open village destroys it.
	var raider: UnitState = null
	for u in st.units.values():
		if u.side == "enemy":
			raider = u
			break
	sword.pos = Vector2i(1, 2)
	raider.pos = vcell + Vector2i(1, 0)
	MoveCommand.apply(st, raider, vcell)
	assert_true(String(st.villages["3,2"]["state"]) == "destroyed", "items: an enemy destroys the village it reaches")
	# An item village needs a free slot.
	st.villages["3,2"] = {"gold": 0, "item_id": "item_potion", "state": "open"}
	raider.pos = Vector2i(9, 7)
	sword.pos = vcell
	sword.acted = false
	sword.items = ["item_potion", "item_elixir"]
	assert_true(VisitCommand.check(st, sword) != "", "items: an item village is blocked while the bag is full (D-B8)")
	# Victory gold: 15 + village gold; merged with the items as they ended the battle.
	sword.items = ["item_elixir"]
	st.villages["3,2"] = {"gold": 10, "item_id": "", "state": "open"}
	d.commit("visit", {"unit_id": sword.id})
	for u in st.units.values():
		if u.side == "enemy":
			u.alive = false
	d.commit("wait", {"unit_id": knight.id})
	var gold: Dictionary = st.battle_over.get("gold", {})
	assert_true(String(st.battle_over.get("status", "")) == "win" and int(gold.get("victory", 0)) == 15 and int(gold.get("villages", 0)) == 10 and int(gold.get("total", 0)) == 25, "items: victory pays 15 + village 10 = 25")
	CampaignMerge.merge(st, GameState.current_chapter(), {"status": "lose", "gold": gold})
	assert_true(GameState.gold == 0, "items: a defeat keeps no gold (designer game-over rule)")
	CampaignMerge.merge(st, GameState.current_chapter(), st.battle_over)
	assert_true(GameState.gold == 25 and Array(GameState.roster["unit_demo_swordsman"]["items"]) == ["item_elixir"], "items: the victory merges 25 gold and the items left in the bag")
	# Retrieve bonus and persuasion reward.
	var fake := BattleState.new()
	fake.objectives_config = [{"type": "retrieve", "params": {}}]
	var g2 := GoldRewards.on_victory(fake, {"faction_x": {"persuaded": true}})
	assert_true(int(g2["total"]) == 15 + 15 + 20, "items: Retrieve win + one persuasion = 15 + 15 + 20 = 50")
	# Shop: catalog, affordability, free slot, dead units, never negative.
	GameState.gold = 25
	assert_true(Shop.catalog().size() == 5 and Shop.price_of("item_elixir") == 30, "shop: five items, elixir costs 30")
	assert_true(not Shop.can_buy("item_elixir"), "shop: an unaffordable item cannot be bought")
	GameState.roster["unit_demo_knight"]["items"] = []
	assert_true(not Shop.buy("item_elixir", "unit_demo_knight") and GameState.gold == 25, "shop: a refused purchase changes nothing")
	assert_true(Shop.buy("item_potion", "unit_demo_knight") and GameState.gold == 15 and Array(GameState.roster["unit_demo_knight"]["items"]).has("item_potion"), "shop: buying a potion pays 10 and fills a slot")
	GameState.roster["unit_demo_knight"]["items"] = ["item_potion", "item_potion"]
	assert_true(not ("unit_demo_knight" in Shop.eligible_units()), "shop: a unit with a full bag is not offered")
	GameState.roster["unit_demo_swordsman"]["alive"] = false
	assert_true(not ("unit_demo_swordsman" in Shop.eligible_units()), "shop: a fallen unit is not offered")
	GameState.roster["unit_demo_swordsman"]["alive"] = true
	# Save round trip.
	var saved := GameState.to_dict().duplicate(true)
	GameState.new_game()
	assert_true(GameState.gold == 0, "items: New campaign resets gold")
	GameState.from_dict(saved)
	assert_true(GameState.gold == 15 and Array(GameState.roster["unit_demo_knight"]["items"]).size() == 2, "items: gold and bags are saved")
	# Camp shop UI renders the catalog with prices.
	var camp := CampScene.new()
	add_child(camp)
	await get_tree().process_frame
	camp.open_shop()
	await get_tree().process_frame
	assert_true(_has_label_containing(camp, "10") or _find_button_containing(camp, "10"), "shop: the camp shop lists prices")
	camp.queue_free()
	GameState.new_game()


func _find_button_containing(root: Node, text: String) -> bool:
	if root is Button and String((root as Button).text).contains(text):
		return true
	for child in root.get_children():
		if _find_button_containing(child, text):
			return true
	return false


## F-AI: StandardAggressive targets the nearest (ties x+y) with carrier / priority overrides,
## Raiders beeline onto reachable villages, Protect/Persuade picks Protect / Flee / Cornered /
## Rally / Hold, and the Restraint Rule stops its strikes (and counters) at 1 HP.
func test_enemy_ai_profiles() -> void:
	await 0.0
	GameState.new_game()
	GameState.build_roster()
	var maps := DataRegistry.chapters_sorted("demo")
	# ---- demo_01: StandardAggressive guard_2 and the Raider guard_1 (village at (3,2)).
	var m1 := DataRegistry.get_map(String(maps[0].map_id))
	var d1 := BattleDirector.new()
	d1.setup(m1, {"unit_demo_swordsman": m1.deploy_cells[0], "unit_demo_knight": m1.deploy_cells[1]}, "normal")
	var s1 := d1.state
	var sword: UnitState = s1.units["unit_demo_swordsman"]
	var knight: UnitState = s1.units["unit_demo_knight"]
	var guard: UnitState = s1.units["guard_2"]
	var raider: UnitState = s1.units["guard_1"]
	assert_true(guard.ai_profile == "StandardAggressive" and raider.ai_profile == "Raider", "ai: profiles come from the unit data")
	raider.pos = Vector2i(9, 7)
	guard.pos = Vector2i(8, 5)
	sword.pos = Vector2i(8, 3)    # distance 2, x+y 11
	knight.pos = Vector2i(7, 6)   # distance 2, x+y 13
	var plan := EnemyAI.plan_unit(s1, guard, ["player", "npc"])
	assert_true(String(plan["target_id"]) == sword.id, "ai: StandardAggressive picks the nearest target, ties by lowest x+y")
	guard.priority_target_id = knight.id
	assert_true(String(EnemyAI.plan_unit(s1, guard, ["player", "npc"])["target_id"]) == knight.id, "ai: a reachable priority target wins (D-B7)")
	guard.priority_target_id = ""
	sword.pos = Vector2i(1, 1)
	knight.pos = Vector2i(1, 6)
	var approach := EnemyAI.plan_unit(s1, guard, ["player", "npc"])
	assert_true(String(approach["target_id"]) == "" and approach["move_cell"] != guard.pos, "ai: nothing reachable -> walk toward the nearest")
	# Raider: the village (3,2) is 3 tiles away -> beeline onto it, attack whoever is in range there.
	raider.pos = Vector2i(6, 2)
	sword.pos = Vector2i(3, 1)
	var raid := EnemyAI.plan_unit(s1, raider, ["player", "npc"])
	assert_true(raid["move_cell"] == Vector2i(3, 2) and String(raid["target_id"]) == sword.id, "ai: the Raider moves onto the reachable village and attacks from it")
	d1.state.phase = BattleState.PHASE_ENEMY
	d1.commit_ai_plan(raid)
	assert_true(String(s1.villages["3,2"]["state"]) == "destroyed", "ai: reaching the village destroys it")
	raider.acted = false
	raider.alive = true            # the counter may have felled it (random seed): bring it back
	raider.hp = raider.max_hp
	raider.pos = Vector2i(9, 0)
	var fallback := EnemyAI.plan_unit(s1, raider, ["player", "npc"])
	assert_true(fallback["move_cell"] != Vector2i(3, 2) and not fallback.has("ai_context"), "ai: no village left -> the Raider plays StandardAggressive")
	# ---- demo_03: the commander is ProtectPersuade and the key unit.
	var m3 := DataRegistry.get_map(String(maps[2].map_id))
	var d3 := BattleDirector.new()
	d3.setup(m3, {"unit_demo_swordsman": m3.deploy_cells[0], "unit_demo_knight": m3.deploy_cells[1]}, "normal")
	var s3 := d3.state
	var sw: UnitState = s3.units["unit_demo_swordsman"]
	var kn: UnitState = s3.units["unit_demo_knight"]
	var cmd: UnitState = s3.units["commander"]
	var p1: UnitState = s3.units["pursuer_1"]
	var p2: UnitState = s3.units["pursuer_2"]
	assert_true(ProtectPersuadeAI.is_governed(s3, cmd) and ProtectPersuadeAI.key_unit(s3, p1) == cmd, "ai: the commander is governed and resolves as the key unit")
	# Hold: nobody threatens it.
	sw.pos = Vector2i(0, 0)
	kn.pos = Vector2i(0, 7)
	var hold := EnemyAI.plan_unit(s3, cmd, ["player", "npc"])
	assert_true(String(hold["ai_context"]) == "hold" and hold["move_cell"] == cmd.pos, "ai: not threatened -> Hold in place")
	# Flee: threatened with a way out.
	sw.pos = Vector2i(5, 3)
	var flee := EnemyAI.plan_unit(s3, cmd, ["player", "npc"])
	var threats := ProtectPersuadeAI.player_threats(s3)
	assert_true(String(flee["ai_context"]) == "flee" and not threats[sw.id].has(flee["move_cell"]), "ai: threatened with an escape -> Flee to an unthreatened tile")
	# Cornered: threatened and unable to move.
	var mv := cmd.move_range
	cmd.move_range = 0
	var cornered := EnemyAI.plan_unit(s3, cmd, ["player", "npc"])
	assert_true(String(cornered["ai_context"]) == "cornered" and cornered["move_cell"] == cmd.pos and String(cornered["target_id"]) == "", "ai: no escape -> Cornered (no move, no attack)")
	cmd.move_range = mv
	# Protect Key Unit: a governed guard blocks next to the wounded, threatened commander.
	p1.ai_profile = "ProtectPersuade"
	cmd.hp = int(floor(0.3 * cmd.max_hp))
	sw.pos = Vector2i(6, 3)
	var protect := EnemyAI.plan_unit(s3, p1, ["player", "npc"])
	assert_true(String(protect["ai_context"]) == "protect" and protect["move_cell"] == Vector2i(7, 3) and String(protect["target_id"]) == sw.id, "ai: Protect Key Unit blocks on the tile toward the threat and attacks")
	cmd.hp = cmd.max_hp
	# Rally: an isolated, unthreatened governed unit walks back toward the key unit.
	p2.ai_profile = "ProtectPersuade"
	sw.pos = Vector2i(0, 0)
	kn.pos = Vector2i(0, 7)
	p1.pos = Vector2i(9, 0)
	p2.pos = Vector2i(9, 7)
	var rally := EnemyAI.plan_unit(s3, p2, ["player", "npc"])
	assert_true(String(rally["ai_context"]) == "rally" and RangeHandler.manhattan(rally["move_cell"], cmd.pos) < RangeHandler.manhattan(p2.pos, cmd.pos) and String(rally["target_id"]) == "", "ai: isolated -> Rally toward the key unit, no attack")
	# Restraint Rule: Hold-context strikes stop at 1 HP, crits included; counters too.
	sw.pos = cmd.pos + Vector2i(-1, 0)
	sw.hp = 3
	cmd.skill = 99
	cmd.power = 60
	cmd.ai_context = "hold"
	assert_true(int(CombatResolver.forecast(s3, cmd, sw)["sequence"][0]["damage"]) == 2, "ai: the forecast shows the restrained damage (HP 3 -> 2)")
	CombatResolver.execute(s3, cmd, sw)
	assert_true(sw.alive and sw.hp == 1, "ai: a restrained strike leaves the target at 1 HP")
	sw.hp = 3
	cmd.max_hp = 999
	cmd.hp = 999
	CombatResolver.execute(s3, sw, cmd)
	assert_true(sw.alive and sw.hp >= 1, "ai: its counter-attack is restrained too")
	cmd.ai_context = "protect"
	assert_true(not ProtectPersuadeAI.restrained(s3, cmd), "ai: Protect Key Unit fights at full force")
	cmd.ai_context = "hold"
	s3.difficulty = "nightmare"
	assert_true(not ProtectPersuadeAI.restrained(s3, cmd), "ai: no Restraint Rule on Nightmare")
	s3.difficulty = "normal"
	# Unpersuadable (red bar) -> back to StandardAggressive.
	s3.reconcile_state[cmd.faction_id]["kills"] = 99
	assert_true(not ProtectPersuadeAI.is_governed(s3, cmd) and not ProtectPersuadeAI.restrained(s3, cmd), "ai: an Unpersuadable faction's units fall back to StandardAggressive, unrestrained")
	GameState.new_game()


## F-PCOND: GDD persuasion conditions (F-PS2) on top of the kill gate.
func test_persuasion_conditions() -> void:
	await 0.0
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var fid := "faction_rebel_ch01"
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var d := BattleDirector.new()
	d.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	var st := d.state
	assert_true(String(ReconcileSystem.condition_for(st, fid).get("type", "")) == "named_unit_alive", "persuasion: ch01 uses named_unit_alive (migrated from required_events)")
	assert_true(int(st.reconcile_state[fid]["deployed"]) == 4, "persuasion: 4 rebels deployed at battle start")
	# named_unit_alive: commander alive + 3 kills < 4 -> persuaded; commander dead -> not.
	st.reconcile_state[fid]["kills"] = 3
	assert_true(bool(ReconcileSystem.evaluate(st)[fid]["persuaded"]), "persuasion: commander alive and under the kill gate -> persuaded")
	st.units["unit_rebel_commander"].alive = false
	st.reconcile_state[fid]["kills"] = 1
	var r: Dictionary = ReconcileSystem.evaluate(st)[fid]
	assert_true(not bool(r["persuaded"]) and not bool(r["condition_met"]), "persuasion: the named unit died -> not persuaded")
	st.units["unit_rebel_commander"].alive = true
	# The kill gate still applies on its own.
	st.reconcile_state[fid]["kills"] = 4
	assert_true(not bool(ReconcileSystem.evaluate(st)[fid]["persuaded"]), "persuasion: kill gate reached -> not persuaded even with the commander alive")
	# units_spared_pct via a map override: 4 deployed, threshold 0.5.
	var saved_faction: Dictionary = map.faction.duplicate(true)
	map.faction = {"faction_id": fid, "persuasion_condition": {"type": "units_spared_pct", "threshold": 0.5}}
	st.reconcile_state[fid]["kills"] = 2
	st.units["unit_rebel_soldier_1"].alive = false
	st.units["unit_rebel_soldier_2"].alive = false
	assert_true(String(ReconcileSystem.condition_for(st, fid)["type"]) == "units_spared_pct" and bool(ReconcileSystem.evaluate(st)[fid]["persuaded"]), "persuasion: 2 of 4 alive = 0.5 >= 0.5 -> persuaded (map override)")
	st.units["unit_rebel_soldier_3"].alive = false
	st.reconcile_state[fid]["kills"] = 3
	assert_true(not bool(ReconcileSystem.evaluate(st)[fid]["persuaded"]), "persuasion: 1 of 4 alive = 0.25 < 0.5 -> not persuaded")
	map.faction = saved_faction
	# Feedback attitude follows the live condition: safe at the start, neutral after one kill.
	var d2 := BattleDirector.new()
	d2.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "normal")
	assert_true(ReconcileSystem.attitude(d2.state, fid) == "safe", "persuasion: no kills and the commander alive -> safe")
	d2.state.reconcile_state[fid]["kills"] = 1
	assert_true(ReconcileSystem.attitude(d2.state, fid) == "neutral", "persuasion: one kill, condition still holding -> neutral (not lost)")
	# Validator (AC-PS9b): a bad condition record is a data error, never a silent runtime false.
	var validator: Node = load("res://tools/validate_data.gd").new()   # not added to the tree: no _ready run
	validator._check_persuasion_condition("test", fid, {"type": "named_unit_alive", "unit_id": "unit_does_not_exist"})
	validator._check_persuasion_condition("test", fid, {"type": "named_unit_alive", "unit_id": "unit_swordsman"})
	validator._check_persuasion_condition("test", fid, {"type": "units_spared_pct", "threshold": 1.5})
	validator._check_persuasion_condition("test", fid, {"type": "talk_to_boss"})
	assert_true(validator.errors == 4, "persuasion: validator rejects unknown unit, wrong faction, threshold > 1 and unknown type (%d errors)" % validator.errors)
	validator.errors = 0
	validator._check_persuasion_condition("test", fid, {"type": "named_unit_alive", "unit_id": "unit_rebel_commander"})
	validator._check_persuasion_condition("test", fid, {"type": "units_spared_pct", "threshold": 0.5})
	assert_true(validator.errors == 0, "persuasion: validator accepts valid conditions")
	validator.free()
	GameState.new_game()


## F-BUI: HP bands / pulse, enemy threat tint, bond and buff indicators, rewind pips and the
## rewind point screen, the GDD Action Menu order, and the read-only Squad View.
func test_battle_ui_gdd() -> void:
	GameState.new_game()
	GameState.build_roster()   # demo: Swordsman x Knight start at rank C
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_demo_swordsman": map.deploy_cells[0], "unit_demo_knight": map.deploy_cells[1]}, "normal")
	var st := director.state
	var sword: UnitState = st.units["unit_demo_swordsman"]
	var knight: UnitState = st.units["unit_demo_knight"]
	# F-BUI1 / F-BUI2.
	assert_true(BattleMapView.hp_band_color(0.9) == BattleMapView.hp_band_color(0.67) and BattleMapView.hp_band_color(0.66) == BattleMapView.hp_band_color(0.33) and BattleMapView.hp_band_color(0.32) != BattleMapView.hp_band_color(0.33), "ui: three HP bands split at 66% / 33% (33-66 inclusive yellow)")
	assert_true(BattleMapView.hp_pulses(0.25) and not BattleMapView.hp_pulses(0.26), "ui: the HP bar pulses at 25% or less")
	# Rule 5: adjacent rank-C partners show one link each.
	knight.pos = sword.pos + Vector2i(1, 0)
	var links := BondSystem.active_partners(st, sword)
	assert_true(links.size() == 1 and String(links[0]["rank"]) == "C", "ui: the Swordsman shows one rank-C bond link next to the Knight")
	var battle := BattleScene.new()
	battle.setup(director)
	add_child(battle)
	await get_tree().process_frame
	# Rule 2: the enemy threat range is tinted during the Player Phase.
	assert_true(not battle.map_view.threat_cells.is_empty(), "ui: enemy threat ranges are shown in the Player Phase")
	var foe: UnitState = st.units["guard_2"]
	assert_true(RangeHandler.threat_cells(st, foe).has(foe.pos + Vector2i(-2, 0)), "ui: the threat range covers move + weapon reach")
	# Rule 6: pips = charges.
	battle._refresh_rewind_button()
	await get_tree().process_frame
	assert_true(battle._rewind_pips.get_child_count() == director.rewind_budget, "ui: one rewind pip per charge (%d)" % director.rewind_budget)
	# Rule 11: menu order after selecting the Swordsman (tonics carried, Knight adjacent).
	var entries := BattleScene.action_menu_entries(st, sword, {})
	var kinds: Array = []
	for e in entries:
		kinds.append(String(e["kind"]))
	assert_true(kinds == ["use_item", "use_item", "trade", "wait"], "ui: menu without targets = Use Item x2, Trade, Wait in GDD order %s" % str(kinds))
	var with_target := BattleScene.action_menu_entries(st, sword, {"guard_2": foe.pos})
	assert_true(String(with_target[0]["kind"]) == "attack", "ui: Attack comes first when a target is in range")
	var trade_labels := BattleScene.trade_options(st, sword, knight)
	assert_true(String(trade_labels[0]["label"]).contains("receives:"), "ui: trade options read as a before/after preview (Rule 1)")
	# Rewind point screen: after two actions there are rewind points; picking one costs one use.
	director.commit("use_item", {"unit_id": sword.id, "item_id": "item_vigor_tonic"})
	director.commit("wait", {"unit_id": knight.id})
	var points := director.rewind.player_frames()
	assert_true(points.size() >= 2 and battle.rewind_point_label(points[0]).contains("Turn"), "ui: the rewind screen lists the points with turn and action")
	var uses := director.rewind_uses_left
	battle.open_rewind_picker()
	await get_tree().process_frame
	assert_true(battle._rewind_picker != null, "ui: the Rewind button opens the point screen")
	battle._rewind_to(points[-1])
	assert_true(director.rewind_uses_left == uses - 1 and sword.items.size() == 2 and not sword.acted, "ui: rewinding to the oldest point costs exactly one use and restores it")
	battle.queue_free()
	await get_tree().process_frame
	# Rule 13: Squad View from the pause menu, read-only, fallen units greyed.
	knight.alive = false
	sword.active_buffs["power"] = {"amount": 5, "turns_remaining": 2}
	var pause := PauseMenu.new()
	pause.battle_state = st
	add_child(pause)
	await get_tree().process_frame
	pause.open_squad_view()
	await get_tree().process_frame
	assert_true(_has_label_containing(pause, "Fallen") or _find_button_containing(pause, "Fallen"), "ui: the squad list marks the fallen Knight")
	var lines := SquadView.detail_lines(st, sword)
	var joined := "\n".join(lines)
	assert_true(joined.contains("HP ") and joined.contains("Str ") and joined.contains("power +5 (2 turns)") and joined.contains("Items:") and joined.contains("Traits: updating"), "ui: the unit detail shows stats, current HP, buffs, items and the traits placeholder")
	var hp_before := sword.hp
	pause._squad_view.show_detail(sword.id)
	await get_tree().process_frame
	assert_true(sword.hp == hp_before and sword.alive, "ui: the Squad View changes nothing")
	pause.queue_free()
	GameState.new_game()


## F-SAVE: saves are written at version 3; a v2 legacy save that carries leaked demo units and
## an unknown unit loads with those roster entries dropped and everything else intact.
func test_save_migration_v3() -> void:
	await 0.0
	assert_true(SaveService.SAVE_VERSION == 3 and 2 in SaveService.READABLE_VERSIONS, "save: version 3, older versions still readable")
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	var legacy_count := GameState.roster.size()
	var gs := GameState.to_dict().duplicate(true)
	gs["roster"]["unit_demo_swordsman"] = {"level": 1, "exp": 0, "alive": true, "defeats": 0}
	gs["roster"]["unit_removed_long_ago"] = {"level": 3, "exp": 0, "alive": true, "defeats": 0}
	gs["roster"]["unit_swordsman"]["stat_bonus"] = {"atk": 2, "skl": 1}   # old stat keys
	gs.erase("gold")
	gs.erase("faction_states")
	SaveService.write_save({"save_version": 2, "game_state": gs})
	GameState.new_game()
	assert_true(SaveService.load_campaign(), "save: a v2 save loads")
	assert_true(not GameState.roster.has("unit_demo_swordsman") and not GameState.roster.has("unit_removed_long_ago") and GameState.roster.size() == legacy_count, "save: leaked demo units and removed units are dropped, the legacy squad stays")
	assert_true(GameState.gold == 0 and GameState.faction_states.is_empty() and Array(GameState.roster["unit_swordsman"].get("items", [])) is Array, "save: new fields default")
	var with_bonus := UnitState.from_data(DataRegistry.get_unit("unit_swordsman"), Vector2i.ZERO)
	var saved_bonus: Dictionary = GameState.roster["unit_swordsman"]["stat_bonus"]
	GameState.roster["unit_swordsman"]["stat_bonus"] = {}
	var without := UnitState.from_data(DataRegistry.get_unit("unit_swordsman"), Vector2i.ZERO)
	GameState.roster["unit_swordsman"]["stat_bonus"] = saved_bonus
	assert_true(with_bonus.power == without.power + 2 and with_bonus.skill == without.skill + 1, "save: old-key stat bonuses (atk / skl) still apply (W9)")
	var resaved := SaveService.save_campaign()
	assert_true(int(resaved.get("save_version", 0)) == 3, "save: the next save is written at version 3")
	# A current (v3) save is not migrated: nothing is dropped from it.
	assert_true(SaveService.migrate(3).is_empty(), "save: a v3 save needs no migration")
	GameState.new_game()


## F-CAS: no permadeath. On Hard / Nightmare a unit that fell in a won battle sits out the next
## map only; Story / Normal bring it straight back; defeats keep the resting state for a retry.
func test_no_permadeath_sit_out() -> void:
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	GameState.difficulty = "hard"
	assert_true(String(DataRegistry.rule("casualty_by_difficulty", {})["hard"]) == "sit_out" and String(DataRegistry.rule("casualty_by_difficulty", {})["nightmare"]) == "sit_out", "casualty: Hard / Nightmare sit out instead of permadeath")
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var d := BattleDirector.new()
	d.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_knight": map.deploy_cells[1]}, "hard")
	d.state.units["unit_knight"].alive = false
	CampaignMerge.merge(d.state, chapter, {"status": "win"})
	assert_true(bool(GameState.roster["unit_knight"]["alive"]) and GameState.is_resting("unit_knight"), "casualty: the fallen Knight stays on the roster but rests")
	# Prep screen: the Knight cannot be picked for the next map.
	var prep := PrepScene.build(chapter)
	add_child(prep)
	await get_tree().process_frame
	assert_true(prep._checks.has("unit_knight") and prep._checks["unit_knight"].disabled and String(prep._checks["unit_knight"].text).contains("resting"), "casualty: the resting Knight is disabled on the prep screen")
	prep.free()
	# A defeat merges nothing: still resting for the retry.
	CampaignMerge.merge(d.state, chapter, {"status": "lose"})
	assert_true(GameState.is_resting("unit_knight"), "casualty: a lost battle keeps the Knight resting for the retry")
	# The next won map (without the Knight) frees it.
	var d2 := BattleDirector.new()
	d2.setup(map, {"unit_swordsman": map.deploy_cells[0]}, "hard")
	CampaignMerge.merge(d2.state, chapter, {"status": "win"})
	assert_true(not GameState.is_resting("unit_knight"), "casualty: after sitting out one map the Knight is pickable again")
	# Story / Normal: back straight away.
	GameState.difficulty = "normal"
	var d3 := BattleDirector.new()
	d3.setup(map, {"unit_swordsman": map.deploy_cells[0], "unit_knight": map.deploy_cells[1]}, "normal")
	d3.state.units["unit_knight"].alive = false
	CampaignMerge.merge(d3.state, chapter, {"status": "win"})
	assert_true(not GameState.is_resting("unit_knight") and bool(GameState.roster["unit_knight"]["alive"]), "casualty: on Normal the fallen unit is back for the next battle")
	# Old saves: a dead roster unit comes back on load.
	GameState.roster["unit_knight"]["alive"] = false
	var notes := SaveService.migrate(3)
	assert_true(bool(GameState.roster["unit_knight"]["alive"]) and notes.size() == 1, "casualty: a save with a dead unit brings it back (no permadeath)")
	GameState.difficulty = "normal"
	GameState.new_game()


## F-DLOCK (GDD Difficulty Rule 2): Nightmare only at New campaign and permanent; the camp
## switches Story / Normal / Hard only.
func test_nightmare_lock() -> void:
	GameState.new_game()
	GameState.difficulty = "hard"
	assert_true(GameState.camp_difficulty_choices() == ["story", "normal", "hard"], "difficulty: the camp offers Story / Normal / Hard")
	assert_true(GameState.next_camp_difficulty() == "story", "difficulty: Hard -> Story in the camp cycle, never Nightmare")
	GameState.difficulty = "nightmare"
	assert_true(GameState.camp_difficulty_choices().is_empty() and GameState.next_camp_difficulty() == "nightmare", "difficulty: a Nightmare campaign cannot switch")
	var camp := CampScene.new()
	add_child(camp)
	await get_tree().process_frame
	assert_true(camp._diff_btn.disabled and camp._diff_btn.text.contains("locked"), "difficulty: the camp button is locked on Nightmare")
	camp._on_cycle_difficulty()
	assert_true(GameState.difficulty == "nightmare", "difficulty: pressing it changes nothing")
	camp.queue_free()
	GameState.difficulty = "normal"
	var camp2 := CampScene.new()
	add_child(camp2)
	await get_tree().process_frame
	camp2._on_cycle_difficulty()
	assert_true(GameState.difficulty == "hard" and camp2._diff_btn.text.contains("Hard") and not camp2._diff_btn.disabled, "difficulty: Normal -> Hard in the camp and the label follows")
	camp2._on_cycle_difficulty()
	assert_true(GameState.difficulty == "story", "difficulty: Hard wraps to Story, skipping Nightmare")
	camp2.queue_free()
	# The new-game difficulty screen still reaches Nightmare (after a confirmation).
	var picker := DifficultyScene.new()
	add_child(picker)
	await get_tree().process_frame
	var picked := [""]
	picker.start_pressed.connect(func(d: String) -> void: picked[0] = d)
	picker.select("nightmare")
	picker._on_start()
	assert_true(picked[0] == "" and picker._confirm != null, "difficulty: Nightmare asks for confirmation first")
	(picker._confirm.find_child("ConfirmNightmare", true, false) as Button).pressed.emit()
	assert_true(picked[0] == "nightmare", "difficulty: confirming starts on Nightmare")
	picker.queue_free()
	GameState.difficulty = "normal"
	GameState.new_game()


## F-AFTER: aftermath scene selection (GDD Narrative Rule 6) and the per-faction, per-encounter
## pressure-continues beat; Main plays the queue before the results screen.
func test_aftermath_scenes() -> void:
	GameState.new_game()
	GameState.build_roster()
	var chapters := DataRegistry.chapters_sorted("demo")
	var map1 := DataRegistry.get_map(String(chapters[0].map_id))
	var map3 := DataRegistry.get_map(String(chapters[2].map_id))
	var gen: Dictionary = DataRegistry.rule("aftermath_dialogue_ids", {})
	# 6d plain victory: no chapter post scene, no map "Victory" lines -> generic victory.
	var s := Aftermath.scenes({"status": "win"}, chapters[0], map1)
	assert_true(s.size() == 1 and String(s[0].id) == String(gen["victory"]), "aftermath: a plain victory plays the victory scene")
	# 6b dropped by the designer: no scene on a loss, with or without a fallen ally, even with map "Lost" lines.
	assert_true(Aftermath.scenes({"status": "lose", "restraint": {"zero_ally_deaths": false}}, chapters[0], map1).is_empty() and Aftermath.scenes({"status": "lose", "restraint": {"zero_ally_deaths": true}}, null, null).is_empty(), "aftermath: a loss plays no scene (designer)")
	# 6c: demo_03 river guard persuaded -> the map's "Persuaded" lines; engaged -> "Engaged".
	var persuaded := Aftermath.scenes({"status": "win", "reconcile": {"faction_river_guard": {"persuaded": true}}}, chapters[2], map3)
	assert_true(persuaded.size() >= 1 and String(persuaded[0].lines[0]["text"]) == String(map3.aftermath_lines["Persuaded"][0]), "aftermath: a persuaded faction plays its persuasion scene (map lines)")
	var engaged := Aftermath.scenes({"status": "win", "reconcile": {"faction_river_guard": {"persuaded": false}}}, chapters[2], map3)
	assert_true(String(engaged[0].lines[0]["text"]) == String(map3.aftermath_lines["Engaged"][0]), "aftermath: a still-engaged faction plays the pressure-continues beat")
	# Per-encounter beats: authored ids on the faction win, indexed by the saved counter.
	var f := DataRegistry.get_faction("faction_river_guard")
	f.engaged_dialogue_ids.assign(["dlg_aftermath_engaged", "dlg_aftermath_victory"])
	var first := Aftermath.scenes({"status": "win", "reconcile": {"faction_river_guard": {"persuaded": false}}}, chapters[2], map3)
	GameState.pressure_continues_count["faction_river_guard"] = 1
	var second := Aftermath.scenes({"status": "win", "reconcile": {"faction_river_guard": {"persuaded": false}}}, chapters[2], map3)
	GameState.pressure_continues_count["faction_river_guard"] = 7
	var later := Aftermath.scenes({"status": "win", "reconcile": {"faction_river_guard": {"persuaded": false}}}, chapters[2], map3)
	assert_true(String(first[0].id) == "dlg_aftermath_engaged" and String(second[0].id) == "dlg_aftermath_victory" and String(later[0].id) == "dlg_aftermath_victory", "aftermath: beat 1, beat 2, then the last one is reused")
	f.engaged_dialogue_ids.clear()
	# The victory merge counts the beat; a persuaded faction does not.
	GameState.pressure_continues_count.clear()
	var d := BattleDirector.new()
	d.setup(map3, {"unit_demo_swordsman": map3.deploy_cells[0], "unit_demo_knight": map3.deploy_cells[1]}, "normal")
	CampaignMerge.merge(d.state, chapters[2], {"status": "win", "reconcile": {"faction_river_guard": {"persuaded": false}}})
	assert_true(int(GameState.pressure_continues_count.get("faction_river_guard", 0)) == 1, "aftermath: an engaged victory advances the faction's beat counter")
	# Bad ending: no aftermath scene (it has its own).
	assert_true(Aftermath.scenes({"status": "win", "bad_ending_factions": ["faction_river_guard"], "reconcile": {}}, chapters[2], map3).is_empty(), "aftermath: the bad ending replaces the aftermath")
	# Legacy ch01 victory with its faction: faction scene, then the chapter's post-battle story scene.
	var ch01 := DataRegistry.get_chapter("chapter_ch01")
	var both := Aftermath.scenes({"status": "win", "reconcile": {"faction_rebel_ch01": {"persuaded": true}}}, ch01, DataRegistry.get_map(String(ch01.map_id)))
	assert_true(both.size() == 2 and String(both[0].id) == String(gen["persuaded"]) and String(both[1].id) == "dlg_ch01_post", "aftermath: faction scene, then the chapter's post-battle scene")
	# Main plays the queue, then the results screen.
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	main._battle_director = d
	ResultStore.last_result = {"status": "win", "results": [], "reconcile": {}}
	main._show_post_battle(true)
	await get_tree().process_frame
	assert_true(main._current is DialoguePlayer, "aftermath: Main plays the victory scene first")
	(main._current as DialoguePlayer).finished.emit(true)
	await get_tree().process_frame
	assert_true(main._current is PostBattleScene, "aftermath: then the results screen")
	main.queue_free()
	await get_tree().process_frame
	# Saved with the campaign.
	GameState.pressure_continues_count = {"faction_river_guard": 2}
	var saved := GameState.to_dict().duplicate(true)
	GameState.new_game()
	GameState.from_dict(saved)
	assert_true(int(GameState.pressure_continues_count.get("faction_river_guard", 0)) == 2, "aftermath: the beat counter is saved")
	GameState.new_game()


## F-AUTOSAVE: a victory autosaves once its aftermath has finished (checkpoint +1, next chapter
## stored); a defeat never autosaves.
func test_autosave_after_aftermath() -> void:
	GameState.new_game()
	GameState.build_roster()
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	var d := BattleDirector.new()
	d.setup(map, {"unit_demo_swordsman": map.deploy_cells[0], "unit_demo_knight": map.deploy_cells[1]}, "normal")
	if SaveService.has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.SAVE_PATH))
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	main._battle_director = d
	# Defeat: straight to Game Over, no save.
	ResultStore.last_result = {"status": "lose", "restraint": {"zero_ally_deaths": true}}
	main._show_post_battle(false)
	await get_tree().process_frame
	assert_true(main._current is GameOverScene and not SaveService.has_save(), "autosave: a defeat does not save")
	# Victory: nothing is written while the aftermath scene is still playing...
	ResultStore.last_result = {"status": "win", "results": [], "reconcile": {}}
	main._show_post_battle(true)
	await get_tree().process_frame
	assert_true(main._current is DialoguePlayer and not SaveService.has_save(), "autosave: not while the aftermath plays")
	(main._current as DialoguePlayer).finished.emit(true)
	await get_tree().process_frame
	# ...and once it has finished, the next chapter and checkpoint 1 are on disk.
	var saved := SaveService.read_save()
	assert_true(SaveService.has_save() and int(saved.get("save_version", 0)) == 3, "autosave: written after the aftermath")
	var gs: Dictionary = saved.get("game_state", {})
	assert_true(int(gs.get("campaign_checkpoint", 0)) == 1 and String(gs.get("current_chapter_id", "")) != String(chapter.id), "autosave: checkpoint 1 and the next chapter are stored")
	assert_true(main._current is PostBattleScene and _has_label_containing(main._current, "Progress saved"), "autosave: the results screen says progress was saved")
	main.queue_free()
	GameState.new_game()


## F-ROSTER: camp Roster Browsing (active units only, empty state) and the read-only Unit Detail
## with level, EXP n/100, stats, items and bonds (AC-RPM1/8/11/12).
func test_camp_roster_menu() -> void:
	GameState.new_game()
	GameState.build_roster()   # demo: Swordsman + Knight, bond C
	GameState.roster["unit_demo_swordsman"]["level"] = 7
	GameState.roster["unit_demo_swordsman"]["exp"] = 42
	GameState.roster["unit_demo_knight"]["rest"] = 1
	assert_true(CampScene.active_roster_ids() == ["unit_demo_swordsman"], "roster: resting units are not browsable (AC-RPM1)")
	var camp := CampScene.new()
	add_child(camp)
	await get_tree().process_frame
	assert_true(_find_button_containing(camp, "EXP 42/100") and _has_label_containing(camp, "Resting this map"), "roster: the row shows EXP 42/100 and the resting line names the Knight")
	assert_true(not _has_label_containing(camp, "Lancer x Gunner"), "roster: the demo camp lists only its own bond pairs")
	var before := GameState.to_dict().duplicate(true)
	camp.open_unit_detail("unit_demo_swordsman")
	await get_tree().process_frame
	var joined := "\n".join(CampScene.unit_detail_lines("unit_demo_swordsman"))
	assert_true(joined.contains("Level 7") and joined.contains("EXP 42/100") and joined.contains("Str ") and joined.contains("(C)"), "roster: Unit Detail shows level 7, EXP 42/100, stats and the rank-C bond (AC-RPM11)")
	var bar: ProgressBar = camp._detail_panel.find_child("ExpBar", true, false)
	assert_true(bar != null and int(bar.value) == 42 and int(bar.max_value) == 100, "roster: the EXP bar reads 42 of 100")
	camp.close_unit_detail()
	assert_true(GameState.to_dict() == before, "roster: the menu writes nothing (AC-RPM12)")
	camp.queue_free()
	GameState.roster["unit_demo_swordsman"]["rest"] = 1
	var camp2 := CampScene.new()
	add_child(camp2)
	await get_tree().process_frame
	assert_true(_has_label_containing(camp2, "No active units"), "roster: an empty roster says so (AC-RPM8)")
	camp2.queue_free()
	GameState.new_game()


## F-UI step 2: 3-entry main menu, difficulty cards with rules-driven text, options with window
## mode and three volume buses, and the New game -> difficulty -> story flow.
func test_ui_start_flow() -> void:
	GameState.new_game()
	if SaveService.has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.SAVE_PATH))
	var menu := MenuScene.new()
	add_child(menu)
	await get_tree().process_frame
	assert_true(menu.menu_entries() == ["NewGame", "Continue", "Options"], "start: the card has exactly New game / Continue / Options %s" % str(menu.menu_entries()))
	assert_true(menu._continue_button.disabled, "start: Continue is disabled without a save")
	assert_true(not _find_button_containing(menu, "Shop") and not _find_button_containing(menu, "Difficulty"), "start: no shop and no difficulty on the menu")
	menu.open_options()
	await get_tree().process_frame
	var mode: OptionButton = menu._options_dialog.find_child("WindowMode", true, false)
	var music: HSlider = menu._options_dialog.find_child("Slider_volume_music", true, false)
	var sfx: HSlider = menu._options_dialog.find_child("Slider_volume_sfx", true, false)
	assert_true(mode != null and mode.item_count == 2 and music != null and sfx != null, "start: options show window mode and the music / effects sliders")
	music.value = 0.3
	assert_true(is_equal_approx(float(GameState.options["volume_music"]), 0.3) and AudioServer.get_bus_index("Music") != -1, "start: the music slider stores its option and drives a Music bus")
	sfx.value = 0.0
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "start: effects at 0 mute the SFX bus")
	sfx.value = 0.8
	menu.close_options()
	menu.queue_free()
	# Options survive a new campaign.
	GameState.new_game()
	assert_true(is_equal_approx(float(GameState.options["volume_music"]), 0.3), "start: New campaign keeps the player's options")
	# Difficulty cards: rules-driven text, Normal recommended.
	var picker := DifficultyScene.new()
	add_child(picker)
	await get_tree().process_frame
	assert_true(picker._cards.size() == 4 and DifficultyScene.rewind_text("story") == "∞" and DifficultyScene.rewind_text("hard") == "3", "start: four cards, rewinds from rules (Story ∞, Hard 3)")
	assert_true(DifficultyScene.casualty_caption("hard").contains("SIT OUT") and DifficultyScene.casualty_caption("normal").contains("RETURN"), "start: casualty text follows F-CAS, no permanent death")
	picker.select("normal")
	assert_true(picker._summary_title.text.contains("recommended"), "start: Normal is recommended for a first run")
	picker.queue_free()
	# Main: New game opens the difficulty screen; Start begins the campaign on that tier.
	var main: Node = load("res://src/scenes/main/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	main._on_new_game()
	await get_tree().process_frame
	assert_true(main._current is DifficultyScene, "start: New game opens the difficulty screen")
	(main._current as DifficultyScene).select("hard")
	(main._current as DifficultyScene)._on_start()
	await get_tree().process_frame
	assert_true(GameState.difficulty == "hard" and not GameState.roster.is_empty() and not (main._current is DifficultyScene), "start: Start begins a Hard campaign and moves on to the story")
	main.queue_free()
	GameState.difficulty = "normal"
	GameState.new_game()


## F-UI step 3: prep screen per the UI document - mission + squad column, map preview with
## markers, count, Back, Shop and Options (difficulty switch + save) entries.
func test_prep_screen_layout() -> void:
	GameState.new_game()
	GameState.build_roster()   # demo campaign: shop on
	GameState.gold = 20
	var chapter := GameState.current_chapter()
	var prep := PrepScene.build(chapter)
	add_child(prep)
	await get_tree().process_frame
	assert_true(prep.find_child("MissionPanel", true, false) != null and prep.find_child("PreviewPanel", true, false) != null, "prep: mission column and map preview column")
	assert_true(prep._count_label.text == "1 / 2" and prep._preview.picked == 1, "prep: the protagonist is picked -> 1 / 2, one filled deploy tile")
	(prep._checks["unit_demo_knight"] as Button).button_pressed = true
	assert_true(prep._count_label.text == "2 / 2" and prep._preview.picked == 2 and String((prep._checks["unit_demo_knight"] as Button).text).begins_with("✓"), "prep: picking the Knight -> 2 / 2 and a check mark")
	assert_true(not prep._preview._markers.is_empty() or prep._preview._state.units.size() > 0, "prep: the preview knows the map's units and markers")
	var deploys := [{}]
	prep.deploy_confirmed.connect(func(d: Dictionary) -> void: deploys[0] = d)
	prep._on_start()
	assert_true(deploys[0].size() == 2, "prep: Start battle deploys the picked squad")
	prep.open_shop()
	await get_tree().process_frame
	assert_true(prep._dialog is ShopDialog and _find_button_containing(prep._dialog, "10"), "prep: the Shop opens from the prep screen")
	prep.open_options()
	await get_tree().process_frame
	assert_true(prep._dialog is BetweenBattlesOptions and prep._dialog.find_child("SaveProgress", true, false) != null and prep._dialog.find_child("Close", true, false) != null, "prep: Options has Save progress and Close")
	var opts: BetweenBattlesOptions = prep._dialog
	opts.set_difficulty("hard")
	assert_true(GameState.difficulty == "hard", "prep: the difficulty can be switched between battles")
	opts.set_difficulty("nightmare")
	assert_true(GameState.difficulty == "hard", "prep: never to Nightmare")
	var backs := [0]
	prep.back_pressed.connect(func() -> void: backs[0] += 1)
	prep.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return String((b as Button).text).contains("BACK"))[0].pressed.emit()
	assert_true(backs[0] == 1, "prep: Back is offered")
	for terrain in DataRegistry.rule("terrain_glyphs", {}).values():
		assert_true(BattleMapView.TERRAIN_COLORS.has(String(terrain)), "prep: terrain %s has a map colour (no magenta)" % terrain)
	prep.queue_free()
	GameState.difficulty = "normal"
	GameState.new_game()


## F-UI step 4: battle HUD per the UI document - map fills the frame, objective box, unit card,
## terrain box, small controls, action menu panel next to the unit, camera on large maps.
func test_battle_hud_layout() -> void:
	GameState.new_game()
	GameState.build_roster()
	var map := DataRegistry.get_map(String(GameState.current_chapter().map_id))
	var director := BattleDirector.new()
	director.setup(map, {"unit_demo_swordsman": map.deploy_cells[0], "unit_demo_knight": map.deploy_cells[1]}, "normal")
	var battle := BattleScene.new()
	battle.setup(director)
	add_child(battle)
	await get_tree().process_frame
	var mv := battle.map_view
	assert_true(mv.cell_px >= 48.0 and mv.cell_px * director.state.width <= 1280.0 and mv.cell_px * director.state.height <= 720.0, "hud: the map scales up to fill the frame (cell %d px)" % int(mv.cell_px))
	assert_true(battle._turn_label.text.contains("1") and battle._objective_box.visible, "hud: the objective box shows the turn")
	assert_true(not _has_label_containing(battle, "Click unit: move range"), "hud: no permanent instruction line")
	var sword: UnitState = director.state.units["unit_demo_swordsman"]
	battle.hover_cell = sword.pos
	battle._update_hover_info()   # checked at once: _process re-reads the (headless) mouse each frame
	assert_true(battle._unit_card.visible and _has_label_containing(battle._unit_card, sword.display_name), "hud: hovering a unit shows its card")
	assert_true(battle._terrain_box.visible and battle._terrain_box.get_child_count() > 0, "hud: the hovered tile shows the terrain box")
	assert_true(BattleScene.terrain_box_lines("forest")[1].contains("+"), "hud: the terrain box lists the Def / Avoid bonus")
	battle._select_unit(sword)
	await get_tree().process_frame
	var panel: PanelContainer = battle._action_panel
	var r := Rect2(panel.position, panel.size)
	assert_true(panel.visible and panel.size.x >= 280.0 and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(r), "hud: the action menu is a >= 280 wide panel inside the frame")
	var first_btn: Button = battle._action_menu.get_child(0)
	assert_true(first_btn.custom_minimum_size.y >= 44.0, "hud: 44 px action rows")
	var flipped := BattleScene.action_menu_position(Vector2(1240, 300), 72.0, Vector2(280, 200))
	assert_true(flipped.x + 280.0 <= 1264.0 and flipped.x < 1240.0, "hud: the menu flips to the left at the right edge")
	# Camera: a map larger than the frame follows the focused unit.
	mv.cell_px = 100.0
	mv.focus_cell(Vector2i(director.state.width - 1, 0))
	var right_cell := mv.cell_to_global(Vector2i(director.state.width - 1, 0))
	assert_true(right_cell.x > 0.0 and right_cell.x < 1280.0, "hud: focusing a far tile scrolls it into view")
	battle.queue_free()
	GameState.new_game()


## F-UI step 5: visual-novel dialogue - tag + title, bottom box inside 7-93 % / 504-692, gold
## speaker, progress dots that follow the lines, Skip.
func test_dialogue_vn_layout() -> void:
	var dlg := DialogueData.new()
	dlg.id = "dlg_bond_test_c"
	dlg.display_name = "Swordsman & Knight"
	dlg.lines = [{"speaker": "Knight", "text": "One."}, {"speaker": "Swordsman", "text": "Two."}, {"speaker": "Knight", "text": "Three - a long line that has to wrap onto a second row inside the box without pushing the box past the bottom of the frame at all."}]
	var player := DialoguePlayer.build(dlg)
	add_child(player)
	await get_tree().process_frame
	assert_true(player._tag_label.text == "BOND SCENE" and player._title_label.text == "Swordsman & Knight", "dialogue: bond tag and the scene title")
	var r := Rect2(player._box.position, player._box.size)
	assert_true(r.position.x >= 89.0 and r.end.x <= 1191.0 and r.position.y >= 503.0 and r.end.y <= 693.0, "dialogue: the box sits at x 7-93 %%, y 504-692 (%s)" % str(r))
	assert_true(player._name_label.text == "KNIGHT" and player._dots.text == "●○○", "dialogue: gold capital speaker and progress dots")
	player._advance()
	assert_true(player._name_label.text == "SWORDSMAN" and player._dots.text == "○●○" and player._text_label.text == "Two.", "dialogue: advancing moves the text and the dots")
	player._advance()
	await get_tree().process_frame
	var r2 := Rect2(player._box.position, player._box.size)
	assert_true(r2.end.y <= 693.0 and player._dots.text == "○○●", "dialogue: a two-row line keeps the box inside the frame (%s)" % str(r2))
	assert_true(DialoguePlayer.progress_text(4, 12) == "5 / 12" and DialoguePlayer.progress_text(0, 1) == "" and DialoguePlayer.scene_tag(DataRegistry.get_dialogue("dlg_aftermath_victory")) == "AFTERMATH", "dialogue: long scenes count, aftermath tag")
	var skipped := [false]
	player.finished.connect(func(s: bool) -> void: skipped[0] = s)
	(player.find_child("SkipButton", true, false) as Button).pressed.emit()
	assert_true(skipped[0], "dialogue: Skip finishes the scene as skipped")


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
	assert_true(ObjectiveBase.TYPES == ["elimination", "protect", "escort", "retrieve", "seize"], "objectives: exactly the five GDD types")
	assert_true(ObjectiveBase.create({"type": "evacuate", "params": {}}) == null, "objectives: retired evacuate type is gone")
	var state: BattleState = _plain_map_enemy_state()
	var enemy1 := _spawn(state, "e1", "faction_e", Vector2i(4, 4), false)
	var enemy2 := _spawn(state, "e2", "faction_e", Vector2i(5, 5), false)
	var obj := ObjectiveBase.create({"type": "elimination", "params": {}})
	assert_true(obj.evaluate(state).get("status", "") == "ongoing", "elimination: ongoing while enemies alive")
	enemy1.alive = false
	enemy2.alive = false
	assert_true(obj.evaluate(state).get("status", "") == "win", "elimination: win when all down")
	# Protect (zone): an enemy inside loses at once; N enemy phases without a breach win.
	var state2: BattleState = _plain_map_enemy_state()
	_spawn(state2, "intruder", "faction_e", Vector2i(4, 4), false)
	var zone_cfg := {"type": "protect", "params": {"zone_x": 3, "zone_y": 3, "zone_w": 2, "zone_h": 2, "survive_enemy_phases": 2}}
	assert_true(ObjectiveBase.create(zone_cfg).evaluate(state2).get("status", "") == "lose", "protect zone: an enemy inside loses")
	var state3: BattleState = _plain_map_enemy_state()
	_spawn(state3, "far_foe", "faction_e", Vector2i(0, 5), false)
	var safe := ObjectiveBase.create(zone_cfg)
	safe.on_event(state3, "player_phase_ended", {})
	assert_true(safe.evaluate(state3).get("status", "") == "ongoing", "protect zone: player phases do not count")
	safe.on_event(state3, "enemy_phase_ended", {})
	safe.on_event(state3, "enemy_phase_ended", {})
	assert_true(safe.evaluate(state3).get("status", "") == "win", "protect zone: two enemy phases without a breach win")
	# Protect (unit): its death loses; living through N enemy phases wins.
	var state4: BattleState = _plain_map_enemy_state()
	var vip := _spawn(state4, "vip", "faction_p", Vector2i(1, 1), false, false, "player")
	var guard := ObjectiveBase.create({"type": "protect", "params": {"unit_id": "vip", "survive_enemy_phases": 1}})
	assert_true(guard.evaluate(state4).get("status", "") == "ongoing", "protect unit: ongoing at start")
	guard.on_event(state4, "enemy_phase_ended", {})
	assert_true(guard.evaluate(state4).get("status", "") == "win", "protect unit: survives the enemy phase -> win")
	vip.alive = false
	assert_true(guard.evaluate(state4).get("status", "") == "lose", "protect unit: its death loses")


## F-OBJ Retrieve (GDD Core Rule 13): ending a move on the item picks it up and ends the action;
## the carrier only moves (no attack, no counter); its death loses; reaching the exit wins.
func test_retrieve_rules() -> void:
	await 0.0
	var map := MapData.new()
	map.id = "retrieve_map"
	var rows: Array[String] = ["......", "......", "......", "......", "......", "......"]
	map.terrain_rows = rows
	map.deploy_cells = [Vector2i(0, 0)]
	map.objectives = [{"type": "retrieve", "params": {"item_id": "item_border_relic", "exit_zone_x": 0, "exit_zone_y": 5}}]
	var director := BattleDirector.new()
	director.setup(map, {}, "normal")
	var state := director.state
	state.item_ground["2,0"] = "item_border_relic"
	var runner := _spawn(state, "runner", "faction_p", Vector2i(1, 0), false, false, "player")
	assert_true(director.commit("move", {"unit_id": "runner", "cell": Vector2i(2, 0)}), "retrieve: move onto the item")
	assert_true(runner.carried_item == "item_border_relic" and runner.acted and not state.item_ground.has("2,0"), "retrieve: ending the move on the item picks it up and ends the action")
	var foe := _spawn(state, "chaser", "faction_e", Vector2i(3, 0), false, false, "enemy")
	assert_true(not RangeHandler.can_counter(state, runner, foe.pos), "retrieve: the carrier never counterattacks")
	assert_true(AttackCommand.check(state, runner, "chaser") != "", "retrieve: the carrier cannot attack")
	var plan := EnemyAI.plan_unit(state, foe, ["player"])
	assert_true(String(plan.get("target_id", "")) == "runner", "retrieve: enemies go for the carrier")
	assert_true(String(director.objectives[0].evaluate(state)["status"]) == "ongoing", "retrieve: ongoing while the item is out")
	runner.pos = Vector2i(0, 5)
	assert_true(String(director.objectives[0].evaluate(state)["status"]) == "win", "retrieve: the carrier at the exit wins")
	runner.pos = Vector2i(2, 2)
	runner.take_damage(999)
	assert_true(String(director.objectives[0].evaluate(state)["status"]) == "lose" and runner.carried_item == "item_border_relic", "retrieve: the carrier's death loses (the item does not drop)")



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
