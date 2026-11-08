extends Control
class_name BadEndingScene
## F-BAD (designer, 08-11-2026): a victory while a remnant faction's pressure bar is red ends
## the run here. Names the factions, then Retry chapter (pre-battle state) or Main menu.
## Nothing from that battle is merged into the campaign (provisional, see AGENTS.md F-BAD).
## F-UI step 6: same end-of-run layout as the Game Over screen.

signal retry_pressed
signal menu_pressed

var _chapter: Resource


static func build(chapter: Resource) -> BadEndingScene:
	var scene := BadEndingScene.new()
	scene._chapter = chapter
	return scene


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var lines: Array = []
	lines.append_array(faction_lines(ResultStore.last_result))
	lines.append(UIBuilder.t("The campaign ends here. Retry the chapter to change the outcome."))
	var tag_text := UIBuilder.t("Bad ending")
	if _chapter != null:
		tag_text += " · " + String(_chapter.display_name)
	UIBuilder.verdict_screen(self, UIBuilder.t("Bad Ending"), lines, tag_text, [
		[UIBuilder.t("Main menu"), false, func() -> void: menu_pressed.emit()],
		[UIBuilder.t("Retry chapter"), true, func() -> void: retry_pressed.emit()],
	])


## One player-facing line per red faction (display name, never a kill count).
static func faction_lines(result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for faction_id in result.get("bad_ending_factions", []):
		var f := DataRegistry.get_faction(String(faction_id))
		var faction_name := String(f.display_name) if f != null else String(faction_id)
		lines.append(UIBuilder.t("%s will never accept the peace.") % faction_name)
	return lines
