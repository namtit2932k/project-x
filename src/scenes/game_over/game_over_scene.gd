extends Control
class_name GameOverScene
## Game Over screen (designer, 08-11-2026): a lost battle ends here instead of the post-battle
## results + camp. Offers Retry chapter (same chapter, pre-battle roster) or Main menu.
## Reads the defeat reason from ResultStore.last_result; nothing is merged into the campaign.

signal retry_pressed
signal menu_pressed

var _chapter: Resource


static func build(chapter: Resource) -> GameOverScene:
	var scene := GameOverScene.new()
	scene._chapter = chapter
	return scene


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := UIBuilder.vbox(UIBuilder.panel(self, 460, 260, 1000, 520), 16)
	UIBuilder.label(box, UIBuilder.t("Game Over"), 64)
	if _chapter != null:
		UIBuilder.label(box, UIBuilder.t("Chapter: %s") % _chapter.display_name, 22)
	UIBuilder.label(box, reason_text(ResultStore.last_result), 22)
	UIBuilder.label(box, UIBuilder.t("Progress from this battle is not kept."), 18)

	var retry := UIBuilder.button(box, UIBuilder.t("Retry chapter"), 26)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	var menu := UIBuilder.button(box, UIBuilder.t("Main menu"), 26)
	menu.pressed.connect(func() -> void: menu_pressed.emit())


## Player-facing line for why the battle was lost (critical unit down or an objective failure).
static func reason_text(result: Dictionary) -> String:
	if String(result.get("reason", "")) == "critical_unit_down":
		var ud := DataRegistry.get_unit(String(result.get("unit_id", "")))
		var unit_name := String(ud.display_name) if ud != null else String(result.get("unit_id", "?"))
		return UIBuilder.t("%s has fallen.") % unit_name
	return UIBuilder.t("The mission objective failed.")
