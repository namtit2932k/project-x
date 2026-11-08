extends Control
class_name PostBattleScene
## Post-battle summary (F-UI step 6, UI doc "Victory summary"): serif title + subtitle, a big
## restraint-score card with its breakdown (left), a mission card and a squad card (right), one
## gold Continue button. Reads ResultStore.last_result set by the director. Shown after the
## aftermath scenes of a victory (F-AFTER); a loss goes to the Game Over screen instead.
## The document's "+N to the shared pool" line is superseded (no stat pool, F-EXP): the card
## names the bonus EXP the squad received instead.

signal continue_pressed

var _chapter: Resource
var _score_label: Label
var _squad_box: VBoxContainer
var _mission_box: VBoxContainer


static func build(chapter: Resource) -> PostBattleScene:
	var scene := PostBattleScene.new()
	scene._chapter = chapter
	return scene


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var backdrop := ContourBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.size = UITheme.FRAME
	add_child(backdrop)

	var result: Dictionary = ResultStore.last_result
	var won := String(result.get("status", "")) == "win"
	var title := UIBuilder.title(self, UIBuilder.t("Victory") if won else UIBuilder.t("Defeat"), 55)
	title.position = Vector2(48, 28)
	var chapter_name := String(_chapter.display_name) if _chapter != null else ""
	var subtitle := UIBuilder.tag(self, UIBuilder.t("Battle summary · %s") % chapter_name)
	subtitle.position = Vector2(48, 112)

	_build_score_card(result, won)
	_mission_box = _card(786, 144, 437, 240, "MissionCard")
	_fill_mission(_mission_box, result, won)
	_squad_box = _card(786, 398, 437, 138, "SquadCard")
	_fill_squad(_squad_box, result)

	# F-AUTOSAVE: the victory was saved right after its aftermath.
	if bool(result.get("autosaved", false)):
		var saved := UIBuilder.muted(self, UIBuilder.t("Progress saved"), 15)
		saved.position = Vector2(48, 562)
	var post := UIBuilder.primary_button(self, UIBuilder.t("Continue →"), 16)
	post.name = "ContinueButton"
	post.position = Vector2(938, 550)
	post.size = Vector2(290, 46)
	post.pressed.connect(func() -> void: continue_pressed.emit())


## A bordered card whose content scrolls when it runs longer than the card.
func _card(x: float, y: float, w: float, h: float, card_name: String) -> VBoxContainer:
	var p := UIBuilder.panel(self, x, y, w, h)
	p.name = card_name
	p.size = Vector2(w, h)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(w - 40, h - 38)
	p.add_child(scroll)
	var box := UIBuilder.vbox(scroll, 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


## F-DRS1 score breakdown (display only) and the F-DRS2 bonus EXP the squad received.
func _build_score_card(result: Dictionary, won: bool) -> void:
	var r: Dictionary = result.get("restraint", {})
	var box := _card(48, 144, 715, 392, "ScoreCard")
	UIBuilder.tag(box, UIBuilder.t("Restraint score"))
	var desc := UIBuilder.muted(box, UIBuilder.t("Mission complete. The result is recorded when the battle ends.") if won else UIBuilder.t("Mission not complete. This battle's score is not awarded."), 16)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_label = UIBuilder.title(box, str(int(r.get("restraint_points_awarded", 0))), 88)
	_score_label.name = "ScoreValue"
	_score_label.add_theme_color_override("font_color", UITheme.ACCENT)
	var bonus := int(r.get("bonus_exp", 0))
	UIBuilder.tag(box, UIBuilder.t("Bonus EXP +%d to every deployed unit") % bonus if bonus > 0 else UIBuilder.t("No bonus EXP this battle"))
	box.add_child(HSeparator.new())
	if r.is_empty():
		return
	_score_row(box, UIBuilder.t("No ally lost"), bool(r.get("zero_ally_deaths", false)), int(r.get("ally_points", 0)))
	if bool(r.get("kill_restraint_eligible", false)):
		_score_row(box, UIBuilder.t("Few kills of the holdout faction · %d / limit %d") % [int(r.get("battle_kill_count", 0)), int(DataRegistry.rule("drs_kill_tolerance", 2))], bool(r.get("low_kill_restraint", false)), int(r.get("kill_points", 0)))
		_score_row(box, UIBuilder.t("Perfect restraint"), int(r.get("perfect_bonus", 0)) > 0, int(r.get("perfect_bonus", 0)))
	_score_row(box, UIBuilder.t("Swift clear · turn %d / par %d") % [int(result.get("turn", 0)), int(result.get("turn_par", 0))], bool(r.get("swift_clear_met", false)), int(r.get("swift_bonus", 0)))
	UIBuilder.muted(box, UIBuilder.t("Points are counted after a victory."), 14)


## One breakdown row: condition on the left, "+N" (gold when met, muted "—" when not) on the right.
func _score_row(box: Control, text: String, met: bool, points: int) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var name_label := UIBuilder.label(row, text, 17)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not met:
		name_label.add_theme_color_override("font_color", UITheme.MUTED)
	var value := UIBuilder.label(row, "+%d" % points if met else "—", 17)
	value.custom_minimum_size = Vector2(90, 0)
	value.add_theme_color_override("font_color", UITheme.ACCENT if met else UITheme.MUTED)


func _fill_mission(box: VBoxContainer, result: Dictionary, won: bool) -> void:
	UIBuilder.tag(box, UIBuilder.t("Mission"))
	if _chapter != null:
		UIBuilder.title(box, String(_chapter.display_name), 26)
	for r in result.get("results", []):
		var line := UIBuilder.muted(box, "%s · %s" % [UIBuilder.t(String(r["id"])), str(r["progress"])], 15)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pair(box, UIBuilder.t("Result"), UIBuilder.t("Complete") if won else UIBuilder.t("Not complete"))
	if int(result.get("turn", 0)) > 0:
		_pair(box, UIBuilder.t("Turn ended"), "%d / %d" % [int(result.get("turn", 0)), int(result.get("turn_par", 0))])
	# Reconcile outcome per holdout faction (never the kill count against a threshold).
	for faction_id in result.get("reconcile", {}):
		var f := DataRegistry.get_faction(String(faction_id))
		var fo: Dictionary = result["reconcile"][faction_id]
		_pair(box, String(f.display_name) if f != null else String(faction_id), UIBuilder.t("persuaded") if bool(fo.get("persuaded", false)) else UIBuilder.t("not persuaded"))
	# F-ITEM: the gold this victory paid.
	var gold: Dictionary = result.get("gold", {})
	if not gold.is_empty():
		_pair(box, UIBuilder.t("Gold"), "+%d" % int(gold.get("total", 0)))
		UIBuilder.muted(box, UIBuilder.t("Victory %d · retrieve %d · persuasion %d · villages %d") % [int(gold.get("victory", 0)), int(gold.get("retrieve", 0)), int(gold.get("persuasion", 0)), int(gold.get("villages", 0))], 13)


## "LABEL   VALUE" in gold capitals, as on the document's mission card.
func _pair(box: Control, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	UIBuilder.tag(row, key, 14)
	var v := UIBuilder.tag(row, value, 14)
	v.add_theme_color_override("font_color", UITheme.TEXT)


func _fill_squad(box: VBoxContainer, result: Dictionary) -> void:
	UIBuilder.tag(box, UIBuilder.t("Squad"))
	var names: Array[String] = []
	for entry in result.get("squad", []):
		names.append(_unit_name(String(entry["unit_id"])))
	if not names.is_empty():
		var names_label := UIBuilder.label(box, " · ".join(names), 20)
		names_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for line in squad_lines(result):
		var l := UIBuilder.muted(box, line, 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Squad status (F-CAS: who fell and whether they sit out the next map), then EXP and level-ups.
static func squad_lines(result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var policy := String(DataRegistry.rule("casualty_by_difficulty", {}).get(GameState.difficulty, ""))
	var fallen := false
	for entry in result.get("squad", []):
		if not bool(entry.get("alive", true)):
			fallen = true
			var who := _unit_name(String(entry["unit_id"]))
			lines.append(UIBuilder.t("%s fell and sits out the next map.") % who if policy == "sit_out" else UIBuilder.t("%s fell and is back for the next map.") % who)
	if not fallen and not Array(result.get("squad", [])).is_empty():
		lines.append(UIBuilder.t("The whole squad came back."))
	var exp_parts: Array[String] = []
	for unit_id in result.get("exp", {}):
		exp_parts.append("%s +%d" % [_unit_name(String(unit_id)), int(result["exp"][unit_id])])
	if not exp_parts.is_empty():
		lines.append(UIBuilder.t("EXP: %s") % ", ".join(exp_parts))
	for lu in result.get("level_ups", []):
		var gains_text := ""
		for stat_id in lu["gains"]:
			gains_text += "%s+%d " % [stat_id, int(lu["gains"][stat_id])]
		lines.append(UIBuilder.t("LEVEL UP: %s -> Lv %d (%s)") % [_unit_name(String(lu["unit_id"])), int(lu["level"]), gains_text.strip_edges()])
	return lines


static func _unit_name(unit_id: String) -> String:
	var ud := DataRegistry.get_unit(unit_id)
	return String(ud.display_name) if ud != null else unit_id
