extends Control
class_name CampScene
## Between-battles lobby (F-UI step 7, UI doc screens 25-29). Three pages on the contour backdrop:
## - "bonds"     : characters grouped by nation, the selected character's relations (Support
##                 points, next scene, Watch scene / Lock S), entry to the bond list, "Squad →".
## - "bond_list" : every bond pair of this squad with its rank and Watch scene.
## - "squad"     : gold / difficulty / true-ending strip, companions (active units), the selected
##                 unit's profile (stats, EXP bar, items, bonds - read-only, F-ROSTER), Shop,
##                 Options (BetweenBattlesOptions: options, difficulty, save) and the chapter
##                 action (Prepare for battle / Retry chapter / Main menu when the data ends).
## The document's stat-upgrade parts are superseded (no stat pool since F-EXP).

signal next_chapter
signal retry_chapter
signal to_menu

var page := "bonds"
var _content: Control = null
var _selected_character := ""
var _selected_unit := ""
var _dialog: Control = null
var _scene_box: VBoxContainer = null


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var backdrop := ContourBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.size = UITheme.FRAME
	add_child(backdrop)
	show_page(page)


func show_page(p: String) -> void:
	page = p
	_detail_panel = null
	_scene_box = null
	if _content != null and is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.name = "Page_%s" % p
	_content.size = UITheme.FRAME
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	move_child(_content, 1)   # above the backdrop, under any open dialog
	match p:
		"squad":
			_build_squad_page()
		"bond_list":
			_build_bond_list_page()
		_:
			_build_bonds_page()
	var menu_btn := UIBuilder.button(_content, UIBuilder.t("Main menu"), 15)
	menu_btn.name = "MenuButton"
	menu_btn.position = Vector2(1084, 32)
	menu_btn.size = Vector2(148, 40)
	menu_btn.pressed.connect(func() -> void: to_menu.emit())


## Rebuilds the current page (after a bond scene, the shop, a lock...).
func _rebuild_bond_panel() -> void:
	show_page(page)


func _header(title_text: String, subtitle: String, tag_text: String) -> void:
	var title := UIBuilder.title(_content, title_text, 55)
	title.position = Vector2(48, 28)
	var sub := UIBuilder.muted(_content, subtitle, 17)
	sub.position = Vector2(48, 108)
	sub.size = Vector2(1184, 0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tag := UIBuilder.tag(_content, tag_text)
	tag.position = Vector2(48, 146)


func _card(x: float, y: float, w: float, h: float, card_name: String, separation: int = 8) -> VBoxContainer:
	var p := UIBuilder.panel(_content, x, y, w, h)
	p.name = card_name
	p.size = Vector2(w, h)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(w - 40, h - 38)
	p.add_child(scroll)
	var box := UIBuilder.vbox(scroll, separation)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


func _bottom_button(text: String, x: float, w: float, primary: bool, action: Callable) -> Button:
	var b := UIBuilder.primary_button(_content, text) if primary else UIBuilder.button(_content, text, 16)
	b.position = Vector2(x, 610)
	b.size = Vector2(w, 46)
	b.pressed.connect(action)
	return b


# ------------------------------------------------------------ bonds page (UI doc 25 / 28)

## Bond pairs of this campaign's roster (the demo campaign must not list the legacy pairs).
static func roster_pairs() -> Array[Resource]:
	var out: Array[Resource] = []
	for pair in DataRegistry.all_bond_pairs():
		if GameState.roster.has(String(pair.unit_a)) and GameState.roster.has(String(pair.unit_b)):
			out.append(pair)
	return out


static func pairs_of(unit_id: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for pair in roster_pairs():
		if String(pair.unit_a) == unit_id or String(pair.unit_b) == unit_id:
			out.append(pair)
	return out


## Roster unit ids grouped by nation (faction display name), in data order.
static func characters_by_nation() -> Dictionary:
	var groups := {}
	for unit_id in GameState.roster:
		var ud := DataRegistry.get_unit(String(unit_id))
		var f := DataRegistry.get_faction(String(ud.faction_id)) if ud != null else null
		var nation := String(f.display_name) if f != null else (String(ud.faction_id) if ud != null else "?")
		if not groups.has(nation):
			groups[nation] = []
		groups[nation].append(String(unit_id))
	return groups


func _build_bonds_page() -> void:
	_header(UIBuilder.t("Bond conversations"), UIBuilder.t("Fight on adjacent tiles to earn Support points. Watch an unlocked scene to raise the rank; story milestones only gate when a scene unlocks."), UIBuilder.t("Characters · %d") % GameState.roster.size())
	if _selected_character == "" or not GameState.roster.has(_selected_character):
		_selected_character = ""
		for unit_id in GameState.roster:
			if not pairs_of(String(unit_id)).is_empty():
				_selected_character = String(unit_id)
				break
	var groups := characters_by_nation()
	var y := 182.0
	for nation in groups:
		var ids: Array = groups[nation]
		var rows := ceili(ids.size() / 3.0)
		var h := 74.0 + rows * 46.0
		var card := UIBuilder.panel(_content, 48, y, 700, h)
		card.name = "Nation_%s" % nation
		var box := UIBuilder.vbox(card, 6)
		var heading := UIBuilder.title(box, String(nation), 24)
		heading.add_theme_color_override("font_color", UITheme.ACCENT)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		box.add_child(grid)
		for unit_id in ids:
			var ud := DataRegistry.get_unit(String(unit_id))
			var b := UIBuilder.button(grid, String(ud.display_name) if ud != null else String(unit_id), 15)
			b.name = "Char_%s" % unit_id
			b.custom_minimum_size = Vector2(212, 42)
			b.disabled = pairs_of(String(unit_id)).is_empty()   # only characters with bond content
			if String(unit_id) == _selected_character:
				b.add_theme_stylebox_override("normal", UITheme._box(UITheme.SELECTED, UITheme.ACCENT))
			var chosen := String(unit_id)
			b.pressed.connect(func() -> void:
				_selected_character = chosen
				show_page("bonds"))
		y += h + 14.0
	_build_relation_card()
	_bottom_button(UIBuilder.t("Squad →"), 928, 304, true, func() -> void: show_page("squad"))


func _build_relation_card() -> void:
	_scene_box = _card(772, 182, 460, 400, "RelationCard", 8)
	UIBuilder.tag(_scene_box, UIBuilder.t("Relations"))
	if _selected_character == "":
		UIBuilder.muted(_scene_box, UIBuilder.t("No bond pairs in this squad yet."), 16)
	else:
		var ud := DataRegistry.get_unit(_selected_character)
		UIBuilder.title(_scene_box, String(ud.display_name) if ud != null else _selected_character, 36)
		_scene_box.add_child(HSeparator.new())
		for pair in pairs_of(_selected_character):
			_pair_block(_scene_box, pair, true)
	var list_btn := UIBuilder.button(_scene_box, UIBuilder.t("Bond list"), 16)
	list_btn.name = "BondListButton"
	list_btn.custom_minimum_size = Vector2(0, 46)
	list_btn.pressed.connect(func() -> void: show_page("bond_list"))


## One pair: names, rank + state, Support progress, Watch scene / Lock S.
func _pair_block(box: VBoxContainer, pair: Resource, full: bool) -> void:
	UIBuilder.title(box, pair_title(pair), 24 if full else 26)
	UIBuilder.tag(box, pair_status(pair), 14)
	var progress := pair_progress(pair)
	if progress != "":
		UIBuilder.muted(box, progress, 14)
	var next := BondCampaign.next_rank(pair)
	if BondCampaign.scene_state(pair) == "ready":
		var btn := UIBuilder.primary_button(box, UIBuilder.t("Watch scene →"))
		btn.name = "Watch_%s" % pair.id
		btn.custom_minimum_size = Vector2(0, 46)
		btn.pressed.connect(func() -> void: _watch_bond_scene(pair, next))
	match BondCampaign.s_state(pair):
		"available":
			var s_btn := UIBuilder.button(box, UIBuilder.t("Lock S pair"), 15)
			s_btn.custom_minimum_size = Vector2(0, 42)
			s_btn.pressed.connect(func() -> void: _confirm_lock_s(pair))
		"locked":
			UIBuilder.muted(box, UIBuilder.t("S locked"), 14)
		"closed":
			UIBuilder.muted(box, UIBuilder.t("S closed"), 14)


static func pair_title(pair: Resource) -> String:
	var ua := DataRegistry.get_unit(String(pair.unit_a))
	var ub := DataRegistry.get_unit(String(pair.unit_b))
	return "%s  ×  %s" % [ua.display_name if ua != null else pair.unit_a, ub.display_name if ub != null else pair.unit_b]


## "Bond rank C · ! new scene" (the gold line of the document's relation card).
static func pair_status(pair: Resource) -> String:
	var rank := GameState.bond_rank_for(String(pair.id))
	var text := UIBuilder.t("Bond rank %s") % rank if rank != "" else UIBuilder.t("Not bonded yet")
	if BondCampaign.scene_state(pair) == "ready" or BondCampaign.s_state(pair) == "available":
		text += " · " + UIBuilder.t("! new scene")
	return text


static func pair_progress(pair: Resource) -> String:
	var next := BondCampaign.next_rank(pair)
	var points := int(GameState.bond_points.get(String(pair.id), 0))
	match BondCampaign.scene_state(pair):
		"ready", "need_points":
			return UIBuilder.t("Support points: %d / %d to unlock %s") % [mini(points, points + BondCampaign.points_missing(pair)), points + BondCampaign.points_missing(pair), next]
		"waiting_story":
			return UIBuilder.t("%s scene: waiting on the story") % next
		"unavailable":
			return UIBuilder.t("A member is not with the squad.")
		"max":
			return UIBuilder.t("Highest normal rank reached.")
	return ""


# ------------------------------------------------------------ bond list page (UI doc 26)

func _build_bond_list_page() -> void:
	_header(UIBuilder.t("Bond list"), UIBuilder.t("Relationships of the current squad."), UIBuilder.t("Relationships in the squad"))
	var pairs := roster_pairs()
	var h := minf(130.0 * maxf(pairs.size(), 1.0) + 40.0, 400.0)
	_scene_box = _card(48, 182, 1184, h, "BondListCard", 14)
	if pairs.is_empty():
		UIBuilder.muted(_scene_box, UIBuilder.t("No bond pairs in this squad yet."), 16)
	for pair in pairs:
		_pair_block(_scene_box, pair, false)
	var back := UIBuilder.button(_content, UIBuilder.t("← Bond conversations"), 16)
	back.position = Vector2(48, 182 + h + 14)
	back.size = Vector2(1184, 46)
	back.pressed.connect(func() -> void: show_page("bonds"))


# ------------------------------------------------------------ squad page (UI doc 29)

func _build_squad_page() -> void:
	var chapter := GameState.current_chapter()
	var tag_text := UIBuilder.t("Between battles")
	if chapter != null and not GameState.completed_chapters.has(String(chapter.id)):
		tag_text += " · " + UIBuilder.t("Next: %s") % String(chapter.display_name)
	_header(UIBuilder.t("Squad"), UIBuilder.t("See the companions who joined and get ready for the next battle."), tag_text)

	# Strip (the document's shared-pool bar): gold, difficulty, true-ending state.
	var strip := UIBuilder.panel(_content, 48, 182, 1184, 56)
	strip.name = "StatusStrip"
	strip.add_theme_stylebox_override("panel", UITheme._box(Color(UITheme.PANEL, 0.96), UITheme.ACCENT, 10))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 28)
	strip.add_child(srow)
	_strip_pair(srow, UIBuilder.t("Gold"), str(GameState.gold))
	_strip_pair(srow, UIBuilder.t("Difficulty"), UIBuilder.t(GameState.difficulty.capitalize()) + (" · " + UIBuilder.t("locked") if GameState.camp_difficulty_choices().is_empty() else ""))
	# D10: the true-ending eligibility derived from finished chapters + persuasion.
	var ending_word := UIBuilder.t("possible") if GameState.is_true_ending_eligible() else UIBuilder.t("locked")
	var ending_note := UIBuilder.muted(srow, UIBuilder.t("True ending: %s (every true-ending chapter finished, remnants persuaded)") % ending_word, 14)
	ending_note.name = "TrueEndingNote"

	# Companions (F-ROSTER Roster Browsing, GDD AC-RPM1: active units only).
	var active := active_roster_ids()
	var left := _card(48, 252, 350, 344, "CompanionsCard", 6)
	UIBuilder.tag(left, UIBuilder.t("Joined · %d") % GameState.roster.size())
	UIBuilder.title(left, UIBuilder.t("Companions"), 26)
	if active.is_empty():
		UIBuilder.muted(left, UIBuilder.t("No active units"), 16)
	if _selected_unit == "" or not active.has(_selected_unit):
		_selected_unit = active[0] if not active.is_empty() else ""
	for unit_id in active:
		var row := UIBuilder.button(left, roster_row_text(unit_id), 15)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.clip_text = true
		row.custom_minimum_size = Vector2(300, 48)
		row.tooltip_text = roster_row_text(unit_id)
		if unit_id == _selected_unit:
			row.add_theme_stylebox_override("normal", UITheme._box(UITheme.SELECTED, UITheme.ACCENT))
		var chosen := unit_id
		row.pressed.connect(func() -> void: open_unit_detail(chosen))
	var resting: Array[String] = []
	for unit_id in GameState.roster:
		if GameState.is_resting(String(unit_id)):
			var rud := DataRegistry.get_unit(String(unit_id))
			resting.append(rud.display_name if rud != null else String(unit_id))
	if not resting.is_empty():
		var rest_label := UIBuilder.muted(left, UIBuilder.t("Resting this map: %s") % ", ".join(resting), 14)
		rest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_profile()

	_bottom_button(UIBuilder.t("← Bond conversations"), 48, 260, false, func() -> void: show_page("bonds"))
	var x := 1232.0 - 260.0
	var action := _chapter_action()
	_bottom_button(String(action[0]), x, 260, true, action[1])
	x -= 164.0
	_bottom_button(UIBuilder.t("Options"), x, 160, false, open_options).name = "OptionsButton"
	# F-ITEM: the shop, when the campaign has one.
	if bool(DataRegistry.rule("shop_enabled", false)):
		x -= 164.0
		_bottom_button(UIBuilder.t("Shop"), x, 160, false, open_shop).name = "ShopButton"


## [text, callable] of the lobby's main action.
func _chapter_action() -> Array:
	var retry := [UIBuilder.t("Retry chapter"), func() -> void: retry_chapter.emit()]
	if String(ResultStore.last_result.get("status", "")) == "lose":
		return retry   # defeat: the chapter was NOT advanced (D06 writes nothing)
	var current := GameState.current_chapter()
	if current == null:
		return [UIBuilder.t("Main menu"), func() -> void: to_menu.emit()]
	if GameState.completed_chapters.has(String(current.id)):
		if not GameState.has_next_chapter():
			return [UIBuilder.t("Main menu"), func() -> void: to_menu.emit()]   # the data ends here
		return [UIBuilder.t("Prepare for battle →"), func() -> void: next_chapter.emit()]
	# After a victory the current chapter is the next, unplayed one: its predecessor is cleared.
	# Otherwise (a load before any victory, a rewind rescue) it is a replay (D06 defensive path).
	return [UIBuilder.t("Prepare for battle →"), func() -> void: next_chapter.emit()] if previous_chapter_cleared() else retry


static func previous_chapter_cleared() -> bool:
	var chapters := DataRegistry.chapters_sorted(GameState.campaign_tag)
	var idx := chapters.find(GameState.current_chapter())
	return idx > 0 and GameState.completed_chapters.has(String(chapters[idx - 1].id))

func _strip_pair(row: HBoxContainer, key: String, value: String) -> void:
	UIBuilder.tag(row, key, 14)
	var v := UIBuilder.title(row, value, 24)
	v.add_theme_color_override("font_color", UITheme.ACCENT)


# ------------------------------------------------------------ F-ROSTER profile

var _detail_panel: Control = null


## Roster units that can be browsed: alive and not resting (GDD: Active only).
static func active_roster_ids() -> Array[String]:
	var out: Array[String] = []
	for unit_id in GameState.roster:
		if bool(GameState.roster[unit_id].get("alive", true)) and not GameState.is_resting(String(unit_id)):
			out.append(String(unit_id))
	return out


static func roster_row_text(unit_id: String) -> String:
	var ud := DataRegistry.get_unit(unit_id)
	var r: Dictionary = GameState.roster[unit_id]
	return UIBuilder.t("%s · Lv %d · EXP %d/%d") % [ud.display_name if ud != null else unit_id, int(r.get("level", 1)), int(r.get("exp", 0)), int(DataRegistry.rule("exp_per_level", 100))]


## Unit Detail (read-only, F-ROSTER): selects the unit and shows it in the profile card.
func open_unit_detail(unit_id: String) -> void:
	if DataRegistry.get_unit(unit_id) == null or not GameState.roster.has(unit_id):
		return
	_selected_unit = unit_id
	show_page("squad")


func close_unit_detail() -> void:
	_selected_unit = ""
	if page == "squad":
		show_page("squad")


## The profile card: name, class / level, 4 x 2 stat tiles, EXP bar, move, items, bonds.
func _build_profile() -> void:
	var box := _card(414, 252, 818, 344, "ProfileCard", 8)
	_detail_panel = box.get_parent().get_parent() as Control
	UIBuilder.tag(box, UIBuilder.t("Profile"))
	if _selected_unit == "":
		return
	var ud := DataRegistry.get_unit(_selected_unit)
	var r: Dictionary = GameState.roster[_selected_unit]
	var u := UnitState.from_data(ud, Vector2i.ZERO, int(r.get("level", 1)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	UIBuilder.title(head, String(ud.display_name), 30)
	UIBuilder.muted(head, UIBuilder.t("Level %d") % int(r.get("level", 1)) + " · " + class_name_of(String(ud.class_id)), 15).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for pair in [["HP", u.max_hp], ["STR", u.power], ["MAG", u.magic], ["SKILL", u.skill], ["SPEED", u.speed], ["LUCK", u.luck], ["DEF", u.defense], ["RES", u.resistance]]:
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(180, 44)
		grid.add_child(tile)
		var l := UIBuilder.label(tile, "%s   %d" % [pair[0], int(pair[1])], 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 12)
	box.add_child(exp_row)
	UIBuilder.label(exp_row, UIBuilder.t("EXP %d/%d") % [int(r.get("exp", 0)), int(DataRegistry.rule("exp_per_level", 100))], 15)
	var bar := ProgressBar.new()
	bar.name = "ExpBar"
	bar.max_value = int(DataRegistry.rule("exp_per_level", 100))
	bar.value = int(r.get("exp", 0))
	bar.custom_minimum_size = Vector2(300, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	exp_row.add_child(bar)
	UIBuilder.label(exp_row, "Move %d" % u.move_range, 15)
	var lines := unit_detail_lines(_selected_unit)
	for line in lines.slice(lines.size() - 2):   # items, bonds
		var l2 := UIBuilder.muted(box, line, 14)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## The class display name (data), else its id.
static func class_name_of(class_id: String) -> String:
	var c := DataRegistry.get_data("classes", class_id)
	return String(c.display_name) if c != null and "display_name" in c and String(c.display_name) != "" else class_id


static func unit_detail_lines(unit_id: String) -> Array[String]:
	var ud := DataRegistry.get_unit(unit_id)
	var r: Dictionary = GameState.roster[unit_id]
	var u := UnitState.from_data(ud, Vector2i.ZERO, int(r.get("level", 1)))
	var lines: Array[String] = []
	lines.append("%s | %s" % [ud.display_name, ud.class_id])
	lines.append(UIBuilder.t("Level %d") % int(r.get("level", 1)))
	lines.append(UIBuilder.t("EXP %d/%d") % [int(r.get("exp", 0)), int(DataRegistry.rule("exp_per_level", 100))])
	lines.append("HP %d  Str %d  Mag %d  Skill %d" % [u.max_hp, u.power, u.magic, u.skill])
	lines.append("Spd %d  Luck %d  Def %d  Res %d  Move %d" % [u.speed, u.luck, u.defense, u.resistance, u.move_range])
	lines.append(UIBuilder.t("Items: %s") % (BattleScene.item_list_text(r.get("items", [])) if not (r.get("items", []) as Array).is_empty() else UIBuilder.t("none")))
	var bonds: Array[String] = []
	for pair_id in DataRegistry.all_ids("bonds"):
		var pair := DataRegistry.get_data("bonds", pair_id)
		if pair == null or (String(pair.unit_a) != unit_id and String(pair.unit_b) != unit_id):
			continue
		var rank := GameState.bond_rank_for(String(pair_id))
		if rank == "":
			continue
		var other_id := String(pair.unit_b) if String(pair.unit_a) == unit_id else String(pair.unit_a)
		var other := DataRegistry.get_unit(other_id)
		bonds.append("%s (%s)" % [other.display_name if other != null else other_id, rank])
	lines.append(UIBuilder.t("Bonds: %s") % (", ".join(bonds) if not bonds.is_empty() else UIBuilder.t("none")))
	return lines


# ------------------------------------------------------------ bond rules (F-BOND)

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
	# F-UI: the themed ConfirmDialog (it was Godot's unthemed ConfirmationDialog).
	var dialog := ConfirmDialog.build(UIBuilder.t("Lock S pair"), UIBuilder.t("Lock this S pair? Both characters will never be able to lock S with anyone else.") + "\n" + pair_title(pair), UIBuilder.t("Lock S pair"), UIBuilder.t("Cancel"))
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: _lock_s(pair))


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


# ------------------------------------------------------------ dialogs

## F-UI step 7: options, the Story / Normal / Hard switch (F-DLOCK) and Save progress.
func open_options() -> void:
	_close_dialog()
	var dialog := BetweenBattlesOptions.new()
	dialog.closed.connect(func() -> void:
		_dialog = null
		_rebuild_bond_panel())
	_dialog = dialog
	add_child(dialog)


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func toast(text: String) -> void:
	var t := UIBuilder.muted(self, text, 15)
	t.name = "Toast"
	t.position = Vector2(48, 676)
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(t.queue_free)   # bound to the label: dropped if the camp closes first


# ------------------------------------------------------------ F-ITEM shop

var _shop_panel: Control = null


## F-UI step 3: the shared ShopDialog (also opened from the prep screen).
func open_shop() -> void:
	close_shop()
	var dialog := ShopDialog.new()
	dialog.closed.connect(func() -> void:
		_shop_panel = null
		_rebuild_bond_panel())
	dialog.purchased.connect(func(item_id: String, unit_id: String) -> void:
		var ud := DataRegistry.get_unit(unit_id)
		toast(UIBuilder.t("Bought %s for %s.") % [BattleScene.item_name(item_id), ud.display_name if ud != null else unit_id]))
	_shop_panel = dialog
	add_child(dialog)


func close_shop() -> void:
	if _shop_panel != null and is_instance_valid(_shop_panel):
		_shop_panel.queue_free()
	_shop_panel = null


static func item_effect_text(item: ItemData) -> String:
	return ShopDialog.item_effect_text(item)
