extends Control
class_name BadEndingScene
## F-BAD (designer, 08-11-2026): a victory while a remnant faction's pressure bar is red ends
## the run here. Names the factions, then Retry chapter (pre-battle state) or Main menu.
## Nothing from that battle is merged into the campaign (provisional, see AGENTS.md F-BAD).

signal retry_pressed
signal menu_pressed

var _chapter: Resource


static func build(chapter: Resource) -> BadEndingScene:
	var scene := BadEndingScene.new()
	scene._chapter = chapter
	return scene


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := UIBuilder.vbox(UIBuilder.panel(self, 240, 110, 800, 500), 14)
	UIBuilder.label(box, UIBuilder.t("Bad Ending"), 64)
	if _chapter != null:
		UIBuilder.label(box, UIBuilder.t("Chapter: %s") % _chapter.display_name, 22)
	for line in faction_lines(ResultStore.last_result):
		UIBuilder.label(box, line, 22)
	UIBuilder.label(box, UIBuilder.t("The campaign ends here. Retry the chapter to change the outcome."), 18)

	var retry := UIBuilder.button(box, UIBuilder.t("Retry chapter"), 26)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	var menu := UIBuilder.button(box, UIBuilder.t("Main menu"), 26)
	menu.pressed.connect(func() -> void: menu_pressed.emit())


## One player-facing line per red faction (display name, never a kill count).
static func faction_lines(result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for faction_id in result.get("bad_ending_factions", []):
		var f := DataRegistry.get_faction(String(faction_id))
		var faction_name := String(f.display_name) if f != null else String(faction_id)
		lines.append(UIBuilder.t("%s will never accept the peace.") % faction_name)
	return lines
