extends Node
## Chapter loop controller: menu -> story scene -> prep -> battle -> post-battle -> camp -> next.
## Autoloads carry state between screens; no network of node paths, only signals.

const DIFFICULTY_UNLIMITED := -1

var _current: Node = null    # Control (menu/prep/camp) hoặc Node2D (battle)
var _battle_director: BattleDirector = null


func _ready() -> void:
	_apply_options()
	_show_menu()


func _swap_to(screen: Node) -> void:   # dùm Node cho cả Control và Node2D screens
	if _current != null:
		_current.queue_free()
	_current = screen
	add_child(screen)


func _apply_options() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(GameState.options.get("volume", 0.8)), 0.05, 1.0)))
	if bool(GameState.options.get("fullscreen", false)) and not DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ------------------------------------------------------------------ screens

func _show_menu() -> void:
	var menu := MenuScene.new()
	menu.new_game.connect(_on_new_game)
	menu.continue_game.connect(_on_continue_game)
	_swap_to(menu)


func _on_new_game() -> void:
	GameState.new_game()
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
	_swap_to(prep)


func _start_battle(deploy: Dictionary) -> void:
	var chapter := GameState.current_chapter()
	var map := DataRegistry.get_map(String(chapter.map_id))
	_battle_director = BattleDirector.new()
	_battle_director.setup(map, deploy, GameState.difficulty)
	var battle := BattleScene.new()
	battle.setup(_battle_director)
	battle.battle_finished.connect(func(win: bool) -> void: _show_post_battle(win))
	_swap_to(battle)


func _show_post_battle(win: bool) -> void:
	var chapter := GameState.current_chapter()
	# D06: the merge itself decides win/lose from the stored result; defeat touches nothing.
	CampaignMerge.merge(_battle_director.state if _battle_director != null else null, chapter, ResultStore.last_result)
	var post := PostBattleScene.build(chapter)
	post.continue_pressed.connect(_show_camp)
	if win:
		# Advance the chapter NOW so saving at camp stores the NEXT chapter: Continue
		# resumes the story from where the player actually is, never a replay.
		GameState.advance_chapter()
	_swap_to(post)


func _show_camp() -> void:
	var camp := CampScene.new()
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
