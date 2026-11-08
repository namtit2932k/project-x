extends Control
class_name PauseMenu
## In-battle pause (N08): Esc opens it, blocking map input and the phase loops until
## Resume. Options reuse the shared OptionsPanel, never a copy. Quit warns that the
## in-battle progress is lost and only the last manual save remains.

signal resumed
signal quit_to_menu


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var window_panel := UIBuilder.panel(self, 760, 220, 400, 420)
	var box := UIBuilder.vbox(window_panel, 14)
	UIBuilder.label(box, UIBuilder.t("Paused"), 32)
	var resume := UIBuilder.button(box, UIBuilder.t("Resume"), 24)
	resume.pressed.connect(_on_resume)
	box.add_child(OptionsPanel.new())
	var quit := UIBuilder.button(box, UIBuilder.t("Quit to menu"), 24)
	quit.pressed.connect(_confirm_quit)


func _on_resume() -> void:
	resumed.emit()
	queue_free()


## Confirmation spells out D11: no mid-battle save, only the last manual save survives.
func _confirm_quit() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = UIBuilder.t("Quit to menu")
	dialog.dialog_text = UIBuilder.t("Current battle progress will be lost. Only your latest manual save is kept. Quit anyway?")
	dialog.ok_button_text = UIBuilder.t("Quit")
	dialog.cancel_button_text = UIBuilder.t("Back to battle")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: quit_to_menu.emit())
	dialog.popup_centered()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_resume()   # Esc again = Resume
