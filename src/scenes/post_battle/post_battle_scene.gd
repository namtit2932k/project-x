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
	var title := UIBuilder.label(self, "Victory" if result.get("status", "") == "win" else "Defeat", 54)
	title.position = Vector2(60, 40)

	var box := UIBuilder.vbox(UIBuilder.panel(self, 60, 150, 1000, 640), 10)
	UIBuilder.label(box, "Chapter: %s" % _chapter.display_name, 22)

	UIBuilder.label(box, "Objectives:", 20)
	for r in result.get("results", []):
		UIBuilder.label(box, "- %s -> %s (%s)" % [r["id"], str(r["progress"]), str(r["status"])], 16)

	UIBuilder.label(box, "Casualty policy (%s): %s" % [GameState.difficulty, DataRegistry.rule("casualty_by_difficulty", {}).get(GameState.difficulty, "?")], 16)

	# Kills per faction (reconcile-relevant bookkeeping).
	UIBuilder.label(box, "Kills by faction (threshold hidden):", 20)
	for faction_id in result.get("reconcile", {}):
		var f := DataRegistry.get_faction(String(faction_id))
		var fo: Dictionary = result["reconcile"][faction_id]
		UIBuilder.label(box, "- %s: %d kills -> %s" % [f.display_name if f != null else faction_id, int(fo.get("kills", 0)), "persuaded" if bool(fo.get("persuaded", false)) else "not persuaded"], 16)

	UIBuilder.label(box, "EXP earned:", 20)
	for unit_id in result.get("exp", {}):
		var ud := DataRegistry.get_unit(String(unit_id))
		UIBuilder.label(box, "- %s +d%d" % [ud.display_name if ud != null else unit_id, int(result["exp"][unit_id])], 16)

	var post := UIBuilder.button(self, "Continue", 24)
	post.position = Vector2(60, 840)
	post.size = Vector2(220, 56)
	post.pressed.connect(func() -> void: continue_pressed.emit())
