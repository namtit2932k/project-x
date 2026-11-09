extends Control
class_name GameOverScene
## Game Over screen (designer, 08-11-2026): a lost battle ends here instead of the post-battle
## results + camp. Offers Retry chapter (same chapter, pre-battle roster) or Main menu.
## Reads the defeat reason from ResultStore.last_result; nothing is merged into the campaign.
## F-UI step 6: the UI doc's layout (title, reason, gold tag, Main menu + gold Retry).

signal retry_pressed
signal menu_pressed

var _chapter: Resource


static func build(chapter: Resource) -> GameOverScene:
	var scene := GameOverScene.new()
	scene._chapter = chapter
	return scene


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var tag_text := UIBuilder.t("The journey ends here")
	if _chapter != null:
		tag_text += " · " + String(_chapter.display_name)
	var column := UIBuilder.verdict_screen(self, UIBuilder.t("Game Over"), [reason_text(ResultStore.last_result) + " " + UIBuilder.t("The battle ends here.")], tag_text, [
		[UIBuilder.t("Main menu"), false, func() -> void: menu_pressed.emit()],
		[UIBuilder.t("Retry chapter"), true, func() -> void: retry_pressed.emit()],
	])
	var notes := UIBuilder.vbox(column, 4)
	notes.add_theme_constant_override("separation", 4)
	UIBuilder.muted(notes, UIBuilder.t("Progress from this battle is not kept."), 15)
	# F-DRS / GDD Battle UI: the restraint score still shows on a loss, marked as not awarded.
	var restraint: Dictionary = ResultStore.last_result.get("restraint", {})
	if not restraint.is_empty():
		UIBuilder.muted(notes, UIBuilder.t("Restraint score: %d (not awarded - battle lost)") % int(restraint.get("restraint_points_awarded", 0)), 15)


## Player-facing line for why the battle was lost (critical unit down or an objective failure).
static func reason_text(result: Dictionary) -> String:
	if String(result.get("reason", "")) == "critical_unit_down":
		var ud := DataRegistry.get_unit(String(result.get("unit_id", "")))
		var unit_name := String(ud.display_name) if ud != null else String(result.get("unit_id", "?"))
		return UIBuilder.t("%s has fallen.") % unit_name
	return UIBuilder.t("The mission objective failed.")
