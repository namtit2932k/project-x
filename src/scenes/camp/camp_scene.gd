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
	if size.x < 1.0:   # under a plain Node the anchors give no rect: take the viewport's
		size = get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.1, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIBuilder.label(self, UIBuilder.t("Camp - manage the squad"), 40)
	title.position = Vector2(60, 40)

	# Roster panel.
	var roster_panel := UIBuilder.panel(self, 60, 130, 760, 560)
	var roster_box := UIBuilder.vbox(roster_panel, 6)
	UIBuilder.label(roster_box, UIBuilder.t("Roster"), 24)
	for unit_id in GameState.roster:
		var ud := DataRegistry.get_unit(String(unit_id))
		var r: Dictionary = GameState.roster[unit_id]
		var status := UIBuilder.t("alive") if bool(r.alive) else UIBuilder.t("fallen")
		var line := UIBuilder.t("%s | %s | Lv %d | exp %d | %s") % [ud.display_name, ud.class_id, int(r.level), int(r.exp), status]
		if not (r.get("items", []) as Array).is_empty():
			line += " | " + UIBuilder.t("Items: %s") % BattleScene.item_list_text(r.get("items", []))
		UIBuilder.label(roster_box, line, 16)

	# Bond panel (eligible designer pairs only).
	var bond_panel := UIBuilder.panel(self, 860, 130, 1000, 560)
	_scene_box = UIBuilder.vbox(bond_panel, 6)
	_rebuild_bond_panel()

	# D10: show the true-ending eligibility derived from finished chapters + persuade.
	var ending_word := UIBuilder.t("possible") if GameState.is_true_ending_eligible() else UIBuilder.t("locked")
	var ending_note := UIBuilder.label(self, UIBuilder.t("True ending: %s (every true-ending chapter finished, remnants persuaded)") % ending_word, 16)
	ending_note.position = Vector2(60, 700)

	var save_btn := UIBuilder.button(self, UIBuilder.t("Save"), 22)
	save_btn.position = Vector2(60, 730)
	save_btn.size = Vector2(180, 50)
	save_btn.pressed.connect(_on_save)

	# F-ITEM: campaign gold and the shop (when the campaign has one).
	var gold_label := UIBuilder.label(self, UIBuilder.t("Gold: %d") % GameState.gold, 20)
	gold_label.position = Vector2(880, 700)
	if bool(DataRegistry.rule("shop_enabled", false)):
		var shop_btn := UIBuilder.button(self, UIBuilder.t("Shop"), 22)
		shop_btn.position = Vector2(880, 730)
		shop_btn.size = Vector2(180, 50)
		shop_btn.pressed.connect(open_shop)

	var diff_btn := UIBuilder.button(self, UIBuilder.t("Difficulty: %s (switch)") % UIBuilder.t(GameState.difficulty.capitalize()), 20)
	diff_btn.position = Vector2(280, 730)
	diff_btn.size = Vector2(320, 50)
	diff_btn.pressed.connect(_on_cycle_difficulty)

	if String(ResultStore.last_result.get("status", "")) == "lose":
		# Defeat: the chapter was NOT advanced; the squad stays in camp to retry it.
		_add_retry_button()
	elif not GameState.has_next_chapter():
		var done_label := UIBuilder.label(self, UIBuilder.t("Campaign complete"), 22)
		done_label.position = Vector2(1640, 690)
		var done_note := UIBuilder.label(self, UIBuilder.t("No further chapters in data yet."), 16)
		done_note.position = Vector2(1640, 720)
		var menu_after := UIBuilder.button(self, UIBuilder.t("Main menu"), 22)
		menu_after.position = Vector2(1660, 730)
		menu_after.size = Vector2(200, 50)
		menu_after.pressed.connect(func() -> void: to_menu.emit())
	elif not GameState.completed_chapters.has(String(GameState.current_chapter().id)):
		# D06: UIBuilder.t("Next chapter") unlocks only after the CURRENT chapter was won (defensive
		# path: defeat banner rewind-rescue or a load made before any victory).
		_add_retry_button()
	else:
		var next_btn := UIBuilder.button(self, UIBuilder.t("Next chapter"), 22)
		next_btn.position = Vector2(1660, 730)
		next_btn.size = Vector2(200, 50)
		next_btn.pressed.connect(func() -> void: next_chapter.emit())

	var menu_btn := UIBuilder.button(self, UIBuilder.t("Main menu"), 22)
	menu_btn.position = Vector2(1660, 810)
	menu_btn.size = Vector2(200, 50)
	menu_btn.pressed.connect(func() -> void: to_menu.emit())


## Retry reopens the CURRENT chapter without any campaign-wide loss bookkeeping (D06:
## a defeat writes nothing, so the retry never counts as a defeat either).
func _add_retry_button() -> void:
	var retry_btn := UIBuilder.button(self, UIBuilder.t("Retry chapter"), 22)
	retry_btn.position = Vector2(1660, 730)
	retry_btn.size = Vector2(200, 50)
	retry_btn.pressed.connect(func() -> void: retry_chapter.emit())


func _rebuild_bond_panel() -> void:
	for c in _scene_box.get_children():
		c.queue_free()
	UIBuilder.label(_scene_box, UIBuilder.t("Bonds (eligibility is designer data)"), 24)
	for pair in DataRegistry.all_bond_pairs():
		var points := int(GameState.bond_points.get(String(pair.id), 0))
		var rank := GameState.bond_rank_for(String(pair.id))
		var ua := DataRegistry.get_unit(String(pair.unit_a))
		var ub := DataRegistry.get_unit(String(pair.unit_b))
		var line := UIBuilder.t("%s x %s | %d pts | rank %s") % [ua.display_name, ub.display_name, points, rank if rank != "" else "-"]
		var row := HBoxContainer.new()
		_scene_box.add_child(row)
		UIBuilder.label(row, line, 16)
		# F-BOND: the next scene opens on points + chapter gate + both alive (BondCampaign).
		var next := BondCampaign.next_rank(pair)
		match BondCampaign.scene_state(pair):
			"ready":
				var btn := UIBuilder.button(row, UIBuilder.t("View %s scene") % next, 14)
				btn.pressed.connect(func() -> void: _watch_bond_scene(pair, next))
			"need_points":
				UIBuilder.label(row, UIBuilder.t("%s scene: %d more pts") % [next, BondCampaign.points_missing(pair)], 14)
			"waiting_story":
				UIBuilder.label(row, UIBuilder.t("%s scene: waiting on the story") % next, 14)
		# F-BOND S: designer whitelist, exclusive per character, confirmed before it locks.
		match BondCampaign.s_state(pair):
			"available":
				var s_btn := UIBuilder.button(row, UIBuilder.t("Lock S pair"), 14)
				s_btn.pressed.connect(func() -> void: _confirm_lock_s(pair))
			"locked":
				UIBuilder.label(row, UIBuilder.t("S locked"), 14)
			"closed":
				UIBuilder.label(row, UIBuilder.t("S closed"), 14)


## Rank comparison by the configured order, never by string compare ("C" < "B" is wrong):
## "C"=0, "B"=1, "A"=2, "S"=3; unknown/missing = -1.
static func rank_index(rank: String) -> int:
	return GameState.BOND_RANKS.find(rank)


## One exclusive S pair per character (GameState.s_pairs maps unit -> pair_id).
func _s_pair_free(pair: Resource) -> bool:
	return not GameState.s_pairs.has(String(pair.unit_a)) and not GameState.s_pairs.has(String(pair.unit_b))


## F-BOND: confirmation first (both can never lock S with anyone else); Cancel changes nothing.
## Confirm re-checks and locks atomically (BondCampaign.lock_s), then the S scene plays.
func _confirm_lock_s(pair: Resource) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = UIBuilder.t("Lock S pair")
	dialog.dialog_text = UIBuilder.t("Lock this S pair? Both characters will never be able to lock S with anyone else.")
	dialog.ok_button_text = UIBuilder.t("Lock S pair")
	dialog.cancel_button_text = UIBuilder.t("Cancel")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: _lock_s(pair))
	dialog.popup_centered()


func _both_alive(pair: Resource) -> bool:
	return BondCampaign.both_alive(pair)


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
	BondCampaign.rank_up(pair, rank_key)
	_rebuild_bond_panel()


## Commits the S lock (re-validated) and plays the S scene; the scene id is recorded once watched.
func _lock_s(pair: Resource) -> void:
	if not BondCampaign.lock_s(pair):
		_rebuild_bond_panel()
		return
	var dlg := DataRegistry.get_dialogue(String(pair.scene_dialogue_ids.get("S", "")))
	if dlg == null:
		_mark_s_viewed(pair)
		return
	var player := DialoguePlayer.build(dlg)
	add_child(player)
	player.finished.connect(func(_skipped: bool) -> void: _mark_s_viewed(pair))


func _mark_s_viewed(pair: Resource) -> void:
	var viewed: Array = GameState.bond_scenes_viewed.get(String(pair.id), [])
	if not viewed.has("S"):
		viewed.append("S")
	GameState.bond_scenes_viewed[String(pair.id)] = viewed
	_rebuild_bond_panel()


func _on_save() -> void:
	SaveService.save_campaign()
	toast(UIBuilder.t("Saved - manual saves sit between battles only."))


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


# ------------------------------------------------------------ F-ITEM shop

var _shop_panel: Control = null


## Catalog browsing: every entry listed; the ones the squad cannot afford stay disabled.
func open_shop() -> void:
	close_shop()
	_shop_panel = UIBuilder.modal(self)
	var box := UIBuilder.vbox(UIBuilder.panel(_shop_panel, 560, 160, 800, 620), 8)
	UIBuilder.label(box, UIBuilder.t("Shop - gold: %d") % GameState.gold, 26)
	for entry in Shop.catalog():
		var item_id := String(entry["item_id"])
		var btn := UIBuilder.button(box, UIBuilder.t("%s - %s - %d gold") % [BattleScene.item_name(item_id), item_effect_text(entry["item"]), int(entry["price"])], 18)
		btn.disabled = not Shop.can_buy(item_id)
		btn.pressed.connect(func() -> void: _choose_buyer(item_id))
	var close := UIBuilder.button(box, UIBuilder.t("Close"), 18)
	close.pressed.connect(func() -> void: close_shop(); _refresh_after_shop())


## Target selection: living roster units with a free slot; picking one buys at once.
func _choose_buyer(item_id: String) -> void:
	close_shop()
	_shop_panel = UIBuilder.modal(self)
	var box := UIBuilder.vbox(UIBuilder.panel(_shop_panel, 560, 160, 800, 620), 8)
	UIBuilder.label(box, UIBuilder.t("Buy %s for whom?") % BattleScene.item_name(item_id), 24)
	var units := Shop.eligible_units()
	if units.is_empty():
		UIBuilder.label(box, UIBuilder.t("No unit has a free item slot."), 18)
	for unit_id in units:
		var ud := DataRegistry.get_unit(unit_id)
		var count := (GameState.roster[unit_id].get("items", []) as Array).size()
		var btn := UIBuilder.button(box, UIBuilder.t("%s (%d/%d items)") % [ud.display_name if ud != null else unit_id, count, int(DataRegistry.rule("max_item_slots", 2))], 18)
		btn.pressed.connect(func() -> void: _buy(item_id, unit_id))
	var back := UIBuilder.button(box, UIBuilder.t("Cancel"), 18)
	back.pressed.connect(open_shop)


func _buy(item_id: String, unit_id: String) -> void:
	if Shop.buy(item_id, unit_id):
		var ud := DataRegistry.get_unit(unit_id)
		toast(UIBuilder.t("Bought %s for %s.") % [BattleScene.item_name(item_id), ud.display_name if ud != null else unit_id])
	open_shop()


func close_shop() -> void:
	if _shop_panel != null and is_instance_valid(_shop_panel):
		_shop_panel.queue_free()
	_shop_panel = null


## The roster and gold labels were built in _ready: rebuild the camp to show purchases.
func _refresh_after_shop() -> void:
	for child in get_children():
		child.queue_free()
	_ready()


static func item_effect_text(item: ItemData) -> String:
	if item == null:
		return ""
	if item.is_heal_item():
		return UIBuilder.t("restores %d HP") % int(item.heal_value)
	if item.is_buff_item():
		return UIBuilder.t("+%d %s for %d turns") % [int(item.buff_amount), String(item.buff_stat), int(item.buff_duration)]
	return ""
