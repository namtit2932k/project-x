extends Control
class_name PostBattleScene
## Post-battle result: objective outcome, casualties per difficulty policy, kills per faction,
## reconcile outcomes, EXP earned. Reads ResultStore.last_result set by the director.

signal continue_pressed

var _chapter: Resource


static func build(chapter: Resource) -> PostBattleScene:
	var scene := PostBattleScene.new()
	scene._chapter = chapter
	return scene


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var result: Dictionary = ResultStore.last_result
	var title := UIBuilder.label(self, UIBuilder.t("Victory") if result.get("status", "") == "win" else UIBuilder.t("Defeat"), 54)
	title.position = Vector2(60, 40)

	var box := UIBuilder.vbox(UIBuilder.panel(self, 60, 150, 1000, 640), 10)
	UIBuilder.label(box, UIBuilder.t("Chapter: %s") % _chapter.display_name, 22)

	UIBuilder.label(box, UIBuilder.t("Objectives:"), 20)
	for r in result.get("results", []):
		UIBuilder.label(box, "- %s -> %s (%s)" % [UIBuilder.t(String(r["id"])), str(r["progress"]), UIBuilder.t(str(r["status"]))], 16)

	UIBuilder.label(box, UIBuilder.t("Casualty policy (%s): %s") % [UIBuilder.t(GameState.difficulty.capitalize()), UIBuilder.t(String(DataRegistry.rule("casualty_by_difficulty", {}).get(GameState.difficulty, "?")))], 16)

	# Kills per faction (reconcile-relevant bookkeeping).
	UIBuilder.label(box, UIBuilder.t("Kills by faction (threshold hidden):"), 20)
	for faction_id in result.get("reconcile", {}):
		var f := DataRegistry.get_faction(String(faction_id))
		var fo: Dictionary = result["reconcile"][faction_id]
		UIBuilder.label(box, UIBuilder.t("- %s: %d kills -> %s") % [f.display_name if f != null else faction_id, int(fo.get("kills", 0)), UIBuilder.t("persuaded") if bool(fo.get(UIBuilder.t("persuaded"), false)) else UIBuilder.t("not persuaded")], 16)

	# T11 remedial + D08: exp from the result (player side only), level-ups with stat gains.
	UIBuilder.label(box, UIBuilder.t("EXP earned:"), 20)
	for unit_id in result.get("exp", {}):
		var ud := DataRegistry.get_unit(String(unit_id))
		UIBuilder.label(box, "- %s +%d" % [ud.display_name if ud != null else unit_id, int(result["exp"][unit_id])], 16)
	for lu in result.get("level_ups", []):
		var gains_text := ""
		for stat_id in lu["gains"]:
			gains_text += "%s+%d " % [stat_id, int(lu["gains"][stat_id])]
		var lu_ud := DataRegistry.get_unit(String(lu["unit_id"]))
		UIBuilder.label(box, UIBuilder.t("LEVEL UP: %s -> Lv %d (%s)") % [lu_ud.display_name if lu_ud != null else String(lu["unit_id"]), int(lu["level"]), gains_text], 16)

	_render_restraint(box, result.get("restraint", {}))

	var post := UIBuilder.button(self, UIBuilder.t("Continue"), 24)
	post.position = Vector2(60, 840)
	post.size = Vector2(220, 56)
	post.pressed.connect(func() -> void: continue_pressed.emit())


## F-DRS1 score breakdown (display only) and the F-DRS2 bonus EXP the squad received.
func _render_restraint(box: Control, r: Dictionary) -> void:
	if r.is_empty():
		return
	UIBuilder.label(box, UIBuilder.t("Restraint score: %d") % int(r.get("restraint_points_awarded", 0)), 20)
	UIBuilder.label(box, UIBuilder.t("- No ally lost: %s (+%d)") % [_yes_no(bool(r.get("zero_ally_deaths", false))), int(r.get("ally_points", 0))], 16)
	if bool(r.get("kill_restraint_eligible", false)):
		UIBuilder.label(box, UIBuilder.t("- Few kills of the holdout faction (%d, limit %d): %s (+%d)") % [int(r.get("battle_kill_count", 0)), int(DataRegistry.rule("drs_kill_tolerance", 2)), _yes_no(bool(r.get("low_kill_restraint", false))), int(r.get("kill_points", 0))], 16)
		UIBuilder.label(box, UIBuilder.t("- Perfect restraint: +%d") % int(r.get("perfect_bonus", 0)), 16)
	UIBuilder.label(box, UIBuilder.t("- Swift clear (turn par): %s (+%d)") % [_yes_no(bool(r.get("swift_clear_met", false))), int(r.get("swift_bonus", 0))], 16)
	if int(r.get("bonus_exp", 0)) > 0:
		UIBuilder.label(box, UIBuilder.t("Bonus EXP +%d to every deployed unit") % int(r.get("bonus_exp", 0)), 16)


static func _yes_no(flag: bool) -> String:
	return UIBuilder.t("yes") if flag else UIBuilder.t("no")
