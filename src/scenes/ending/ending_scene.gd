extends Control
class_name EndingScene
## F-UI step 6 (UI doc "End of the six example chapters"): shown when the summary of the last
## chapter in data is closed. Squad / Bonds lead to the camp (the lobby's own tabs come with
## F-UI step 7), Main menu is the gold default. The campaign was already autosaved (F-AUTOSAVE).

signal squad_pressed
signal bonds_pressed
signal menu_pressed


func _ready() -> void:
	UIBuilder.fill_screen(self)
	UIBuilder.verdict_screen(self, UIBuilder.t("End of the demo"), [UIBuilder.t("The example chapters are complete. The full campaign is still being built.")], "", [
		[UIBuilder.t("Squad"), false, func() -> void: squad_pressed.emit()],
		[UIBuilder.t("View bonds"), false, func() -> void: bonds_pressed.emit()],
		[UIBuilder.t("Main menu"), true, func() -> void: menu_pressed.emit()],
	])
