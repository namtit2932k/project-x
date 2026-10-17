extends Control
class_name CampScene
## Camp between battles: roster overview, bond scene playback (C/B/A/S), manual save,
## difficulty switch, next chapter. Story scene for chapter progress lives in main flow.

signal next_chapter
signal retry_chapter
signal to_menu

var _scene_box: VBoxContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.1, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIBuilder.label(self, "Camp - manage the squad", 40)
	title.position = Vector2(60, 40)

	# Roster panel.
	var roster_panel := UIBuilder.panel(self, 60, 130, 760, 560)
	var roster_box := UIBuilder.vbox(roster_panel, 6)
	UIBuilder.label(roster_box, "Roster", 24)
	for unit_id in GameState.roster:
		var ud := DataRegistry.get_unit(String(unit_id))
		var r: Dictionary = GameState.roster[unit_id]
		var status := "alive" if bool(r.alive) else "fallen"
		UIBuilder.label(roster_box, "%s | %s | Lv %d | exp %d | %s" % [ud.display_name, ud.class_id, int(r.level), int(r.exp), status], 16)

	# Bond panel (eligible designer pairs only).
	var bond_panel := UIBuilder.panel(self, 860, 130, 1000, 560)
	_scene_box = UIBuilder.vbox(bond_panel, 6)
	_rebuild_bond_panel()

	# D10: show the true-ending eligibility derived from finished chapters + persuade.
	var ending_word := "possible" if GameState.is_true_ending_eligible() else "locked"
	var ending_note := UIBuilder.label(self, "True ending: %s (every true-ending chapter finished, remnants persuaded)" % ending_word, 16)
	ending_note.position = Vector2(60, 700)

	var save_btn := UIBuilder.button(self, "Save", 22)
	save_btn.position = Vector2(60, 730)
	save_btn.size = Vector2(180, 50)
	save_btn.pressed.connect(_on_save)

	var diff_btn := UIBuilder.button(self, "Difficulty: %s (switch)" % GameState.difficulty, 20)
	diff_btn.position = Vector2(280, 730)
	diff_btn.size = Vector2(320, 50)
	diff_btn.pressed.connect(_on_cycle_difficulty)

	if String(ResultStore.last_result.get("status", "")) == "lose":
		# Defeat: the chapter was NOT advanced; the squad stays in camp to retry it.
		_add_retry_button()
	elif not GameState.has_next_chapter():
		var done_label := UIBuilder.label(self, "Campaign complete", 22)
		done_label.position = Vector2(1640, 690)
		var done_note := UIBuilder.label(self, "No further chapters in data yet.", 16)
		done_note.position = Vector2(1640, 720)
		var menu_after := UIBuilder.button(self, "Main menu", 22)
		menu_after.position = Vector2(1660, 730)
		menu_after.size = Vector2(200, 50)
		menu_after.pressed.connect(func() -> void: to_menu.emit())
	elif not GameState.completed_chapters.has(String(GameState.current_chapter().id)):
		# D06: "Next chapter" unlocks only after the CURRENT chapter was won (defensive
		# path: defeat banner rewind-rescue or a load made before any victory).
		_add_retry_button()
	else:
		var next_btn := UIBuilder.button(self, "Next chapter", 22)
		next_btn.position = Vector2(1660, 730)
		next_btn.size = Vector2(200, 50)
		next_btn.pressed.connect(func() -> void: next_chapter.emit())

	var menu_btn := UIBuilder.button(self, "Main menu", 22)
	menu_btn.position = Vector2(1660, 810)
	menu_btn.size = Vector2(200, 50)
	menu_btn.pressed.connect(func() -> void: to_menu.emit())


## Retry reopens the CURRENT chapter without any campaign-wide loss bookkeeping (D06:
## a defeat writes nothing, so the retry never counts as a defeat either).
func _add_retry_button() -> void:
	var retry_btn := UIBuilder.button(self, "Retry chapter", 22)
	retry_btn.position = Vector2(1660, 730)
	retry_btn.size = Vector2(200, 50)
	retry_btn.pressed.connect(func() -> void: retry_chapter.emit())


func _rebuild_bond_panel() -> void:
	for c in _scene_box.get_children():
		c.queue_free()
	UIBuilder.label(_scene_box, "Bonds (eligibility is designer data)", 24)
	for pair in DataRegistry.all_bond_pairs():
		var points := int(GameState.bond_points.get(String(pair.id), 0))
		var rank := GameState.bond_rank_for(String(pair.id))
		var ua := DataRegistry.get_unit(String(pair.unit_a))
		var ub := DataRegistry.get_unit(String(pair.unit_b))
		var line := "%s x %s | %d pts | rank %s" % [ua.display_name, ub.display_name, points, rank if rank != "" else "-"]
		var row := HBoxContainer.new()
		_scene_box.add_child(row)
		UIBuilder.label(row, line, 16)
		for rank_key in ["C", "B", "A"]:
			var threshold := int(pair.scene_thresholds.get(rank_key, 1 << 30))
			if points >= threshold and rank_index(GameState.bond_rank_for(String(pair.id))) < rank_index(rank_key) \
					and not GameState.bond_scenes_viewed.get(String(pair.id), []).has(rank_key) \
					and _rank_scene_unlocked(pair, rank_key):
				var btn := UIBuilder.button(row, "View %s scene" % rank_key, 14)
				btn.pressed.connect(func() -> void: _watch_bond_scene(pair, rank_key))
		# S rank: after A plus story milestone, both alive, one exclusive pair per character.
		var cur := GameState.bond_rank_for(String(pair.id))
		if rank_index(cur) >= rank_index("A") and _both_alive(pair) and _s_milestone_reached(pair) and _s_pair_free(pair):
			var s_btn := UIBuilder.button(row, "Lock S pair", 14)
			s_btn.pressed.connect(func() -> void: _lock_s(pair))


## Rank comparison by the configured order, never by string compare ("C" < "B" is wrong):
## "C"=0, "B"=1, "A"=2, "S"=3; unknown/missing = -1.
static func rank_index(rank: String) -> int:
	return GameState.BOND_RANKS.find(rank)


## D05: a rank's scene opens only after the previous rank's scene was watched or skipped
## (B after C, A after B); C is the entry scene.
func _rank_scene_unlocked(pair: Resource, rank_key: String) -> bool:
	var idx := rank_index(rank_key)
	if idx <= 0:
		return true
	var prev_rank: String = GameState.BOND_RANKS[idx - 1]
	return GameState.bond_scenes_viewed.get(String(pair.id), []).has(prev_rank)


## One exclusive S pair per character (GameState.s_pairs maps unit -> pair_id).
func _s_pair_free(pair: Resource) -> bool:
	return not GameState.s_pairs.has(String(pair.unit_a)) and not GameState.s_pairs.has(String(pair.unit_b))


func _both_alive(pair: Resource) -> bool:
	if not GameState.roster.has(pair.unit_a) or not GameState.roster.has(pair.unit_b):
		return false
	return bool(GameState.roster[pair.unit_a].alive) and bool(GameState.roster[pair.unit_b].alive)


func _s_milestone_reached(pair: Resource) -> bool:
	return GameState.completed_chapters.has(String(pair.s_milestone_chapter_id))


func _watch_bond_scene(pair: Resource, rank_key: String) -> void:
	var dlg := DataRegistry.get_dialogue(String(pair.scene_dialogue_ids.get(rank_key, "")))
	if dlg == null:
		push_warning("CampScene: missing bond dialogue for %s %s" % [pair.id, rank_key])
		_rank_up(pair, rank_key)
		return
	var player := DialoguePlayer.build(dlg)
	add_child(player)
	player.finished.connect(func(_skipped: bool) -> void: _rank_up(pair, rank_key))


func _rank_up(pair: Resource, rank_key: String) -> void:
	GameState.bond_ranks[String(pair.id)] = rank_key
	var viewed: Array = GameState.bond_scenes_viewed.get(String(pair.id), [])
	viewed.append(rank_key)
	GameState.bond_scenes_viewed[String(pair.id)] = viewed
	_rebuild_bond_panel()


func _lock_s(pair: Resource) -> void:
	GameState.bond_ranks[String(pair.id)] = "S"
	GameState.s_pairs[String(pair.unit_a)] = String(pair.id)
	GameState.s_pairs[String(pair.unit_b)] = String(pair.id)
	GameState.s_lock_unit = String(pair.unit_a)
	_rebuild_bond_panel()


func _on_save() -> void:
	SaveService.save_campaign()
	toast("Saved - manual saves sit between battles only.")


func _on_cycle_difficulty() -> void:
	var order: Array[String] = ["story", "normal", "hard", "nightmare"]
	var idx := order.find(GameState.difficulty)
	GameState.difficulty = order[(idx + 1) % order.size()]
	toast("Difficulty: %s (rewind %s / casualty %s)" % [GameState.difficulty, DataRegistry.rule("rewind_per_difficulty", {}).get(GameState.difficulty, "?"), DataRegistry.rule("casualty_by_difficulty", {}).get(GameState.difficulty, "?")])


func toast(text: String) -> void:
	var t := UIBuilder.label(self, text, 16)
	t.position = Vector2(60, 900)
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(func() -> void: t.queue_free())
