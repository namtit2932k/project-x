extends Node
## Chapter loop controller: menu -> story scene -> prep -> battle -> post-battle -> camp -> next.
## Autoloads carry state between screens; no network of node paths, only signals.

const DIFFICULTY_UNLIMITED := -1

var _current: Node = null    # Control (menu/prep/camp) hoặc Node2D (battle)
var _battle_director: BattleDirector = null


func _ready() -> void:
	get_tree().root.theme = UITheme.shared()   # F-UI: one shared look for every screen
	_apply_options()
	_show_menu()


func _swap_to(screen: Node) -> void:   # dùm Node cho cả Control và Node2D screens
	if _current != null:
		_current.queue_free()
	_current = screen
	add_child(screen)


func _apply_options() -> void:
	OptionsPanel.apply_audio_and_window()   # one place for buses + window mode (F-UI step 2)


# ------------------------------------------------------------------ screens

func _show_menu() -> void:
	var menu := MenuScene.new()
	menu.new_game.connect(_on_new_game)
	menu.continue_game.connect(_on_continue_game)
	menu.test_battle.connect(_start_test_battle)
	# I18N: rebuild the menu in the new language (deferred: the old menu is still emitting).
	menu.language_changed.connect(func() -> void: call_deferred("_show_menu"))
	if OS.is_debug_build():
		menu.legacy_chapter.connect(_on_legacy_chapter)
	_swap_to(menu)


## F-UI step 2: New game -> difficulty screen -> (Nightmare confirm) -> the campaign starts.
func _on_new_game() -> void:
	var screen := DifficultyScene.new()
	screen.start_pressed.connect(_start_new_campaign)
	screen.back_pressed.connect(_show_menu)
	_swap_to(screen)


func _start_new_campaign(difficulty: String) -> void:
	GameState.difficulty = difficulty
	GameState.new_game()
	GameState.build_roster()
	_play_story_of_current_chapter()


## F4.3/P-08 (P01 temp decision): debug-only entry into the legacy ch01 campaign.
func _on_legacy_chapter() -> void:
	GameState.new_game()
	GameState.campaign_tag = "legacy"
	GameState.build_roster()
	_play_story_of_current_chapter()


func _on_continue_game() -> void:
	if not SaveService.load_campaign():
		GameState.build_roster()
	# Units added to data after the save was written come in as fresh roster members.
	GameState.merge_roster_with_data()
	_apply_options()   # saved volume/fullscreen re-apply on load
	_play_story_of_current_chapter()


func _play_story_of_current_chapter() -> void:
	var chapter := GameState.current_chapter()
	if chapter == null:
		push_error("No chapters in data/ - cannot start campaign.")
		_show_menu()
		return
	# Story scene first (reusable DialoguePlayer), then prep.
	if String(chapter.story_dialogue_id) != "":
		var dlg := DataRegistry.get_dialogue(String(chapter.story_dialogue_id))
		if dlg != null:
			var player := DialoguePlayer.build(dlg)
			_swap_to(player)
			player.finished.connect(func(_skipped: bool) -> void: _show_prep())
			return
	_show_prep()


func _show_prep() -> void:
	var chapter := GameState.current_chapter()
	var prep := PrepScene.build(chapter)
	prep.deploy_confirmed.connect(_start_battle)
	# F-UI step 3: Back returns to the lobby once the campaign has one, else to the menu.
	prep.back_pressed.connect(func() -> void:
		if GameState.completed_chapters.is_empty():
			_show_menu()
		else:
			_show_camp("squad"))
	_swap_to(prep)


func _start_battle(deploy: Dictionary) -> void:
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	_battle_director = BattleDirector.new()
	_battle_director.setup(map, deploy, GameState.difficulty)
	var battle := BattleScene.new()
	battle.setup(_battle_director)
	battle.battle_finished.connect(func(win: bool) -> void: _show_post_battle(win))
	battle.quit_to_menu.connect(_show_menu)   # N08: pause-quit skips merge and post-battle
	_swap_to(battle)


## N12: debug-only test-map battle — default squad straight onto the map, no chapter.
## The result never merges back into the campaign; after the battle, back to the menu.
func _start_test_battle(map_id: String) -> void:
	var map := DataRegistry.get_map(String(map_id))
	if map == null:
		push_error("Main: unknown test map %s" % map_id)
		return
	var deploy := {}
	var i := 0
	for unit_id in GameState.roster:
		if not bool(GameState.roster[unit_id].alive) or i >= map.deploy_cells.size():
			continue
		deploy[unit_id] = map.deploy_cells[i]
		i += 1
	_battle_director = BattleDirector.new()
	_battle_director.setup(map, deploy, GameState.difficulty)
	var battle := BattleScene.new()
	battle.setup(_battle_director)
	battle.battle_finished.connect(func(_win: bool) -> void: _show_menu())
	battle.quit_to_menu.connect(_show_menu)
	_swap_to(battle)


func _show_post_battle(win: bool) -> void:
	var chapter := GameState.current_chapter()
	# F-BAD: a victory with a red faction is the bad ending; like a Game Over it keeps nothing.
	if win and not Array(ResultStore.last_result.get("bad_ending_factions", [])).is_empty():
		_show_bad_ending(chapter)
		return
	# F-AFTER: pick the aftermath scenes before the merge moves the pressure-continues count.
	var map := DataRegistry.get_map(String(chapter.map_id)) if chapter != null else null
	var scenes := Aftermath.scenes(ResultStore.last_result, chapter, map)
	# D06: the merge itself decides win/lose from the stored result; defeat touches nothing.
	CampaignMerge.merge(_battle_director.state if _battle_director != null else null, chapter, ResultStore.last_result)
	if not win:
		_show_game_over(chapter)   # F-AFTER 6b: no narrative on a loss
		return
	# Designer 09-11-2026 (UI doc order): the summary first, then the aftermath scenes.
	var post := PostBattleScene.build(chapter)
	post.continue_pressed.connect(func() -> void: _play_scene_queue(scenes, func() -> void: _after_aftermath(chapter)))
	_swap_to(post)


## F-AFTER Rule 7: each scene finishes before the next; then `done` (autosave + lobby).
func _play_scene_queue(scenes: Array, done: Callable) -> void:
	if scenes.is_empty():
		done.call()
		return
	var player := DialoguePlayer.build(scenes[0])
	var rest := scenes.slice(1)
	player.finished.connect(func(_skipped: bool) -> void: _play_scene_queue(rest, done))
	_swap_to(player)


func _after_aftermath(_chapter: Resource) -> void:
	# Advance the chapter NOW so any save stores the NEXT chapter: Continue resumes the story
	# from where the player actually is, never a replay.
	GameState.advance_chapter()
	# F-AUTOSAVE (GDD Save Rule 2a): the aftermath has resolved -> checkpoint +1 and autosave.
	GameState.campaign_checkpoint += 1
	ResultStore.last_result["autosaved"] = not SaveService.save_campaign().is_empty()
	_after_summary()
	if bool(ResultStore.last_result.get("autosaved", false)) and _current is CampScene:
		(_current as CampScene).toast(UIBuilder.t("Progress saved"))


## F-UI step 6: after the summary and its aftermath, the lobby - or the ending screen once the last chapter in
## data is won (the chapter id stays on it, see GameState.advance_chapter).
func _after_summary() -> void:
	if GameState.has_next_chapter() or not GameState.completed_chapters.has(String(GameState.current_chapter().id)):
		_show_camp()
	else:
		_show_ending()


func _show_ending() -> void:
	var ending := EndingScene.new()
	ending.squad_pressed.connect(func() -> void: _show_camp("squad"))
	ending.bonds_pressed.connect(func() -> void: _show_camp("bonds"))
	ending.menu_pressed.connect(_show_menu)
	_swap_to(ending)


## Designer (F-EXP, 08-11-2026): losing is a game over — Game Over screen with Retry chapter
## (same chapter, pre-battle roster) or Main menu; no results screen, no camp.
func _show_game_over(chapter: Resource) -> void:
	var over := GameOverScene.build(chapter)
	over.retry_pressed.connect(_on_retry_chapter)
	over.menu_pressed.connect(_show_menu)
	_swap_to(over)


## F-BAD: bad-ending dialogue (the first red faction's own, else the rules default), then
## the Bad Ending screen with Retry chapter / Main menu.
func _show_bad_ending(chapter: Resource) -> void:
	var factions: Array = ResultStore.last_result.get("bad_ending_factions", [])
	var dialogue_id := String(DataRegistry.rule("bad_ending_dialogue_id", ""))
	var f := DataRegistry.get_faction(String(factions[0])) if not factions.is_empty() else null
	if f != null and String(f.bad_ending_dialogue_id) != "":
		dialogue_id = String(f.bad_ending_dialogue_id)
	var dlg := DataRegistry.get_dialogue(dialogue_id) if dialogue_id != "" else null
	if dlg == null:
		_show_bad_ending_screen(chapter)
		return
	var player := DialoguePlayer.build(dlg)
	player.finished.connect(func(_skipped: bool) -> void: _show_bad_ending_screen(chapter))
	_swap_to(player)


func _show_bad_ending_screen(chapter: Resource) -> void:
	var screen := BadEndingScene.build(chapter)
	screen.retry_pressed.connect(_on_retry_chapter)
	screen.menu_pressed.connect(_show_menu)
	_swap_to(screen)


## F-UI step 7: the between-battles lobby, opened on its bond page (UI doc order) or the squad.
func _show_camp(page: String = "bonds") -> void:
	var camp := CampScene.new()
	camp.page = page
	camp.next_chapter.connect(_on_next_chapter)
	camp.retry_chapter.connect(_on_retry_chapter)
	camp.to_menu.connect(_show_menu)
	_swap_to(camp)


## Chapter was already advanced post-victory; "Next" just starts the (new) current one.
func _on_next_chapter() -> void:
	_play_story_of_current_chapter()


## Defeat replay of the same chapter (retry flow placeholder: campaign chapter retry).
func _on_retry_chapter() -> void:
	_play_story_of_current_chapter()


# ------------------------------------------------------------------ campaign merge

## Thin wrapper kept for callers/tests: the merge logic itself lives in the static
## CampaignMerge (src/core), not in the scene controller.
func _merge_battle_into_campaign(_win: bool) -> void:
	var chapter := GameState.current_chapter()
	CampaignMerge.merge(_battle_director.state if _battle_director != null else null, chapter, ResultStore.last_result)
