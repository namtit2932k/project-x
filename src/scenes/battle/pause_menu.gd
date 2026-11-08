extends Control
class_name PauseMenu
## In-battle pause (N08): the HUD Pause button opens it, blocking map input and the phase
## loops until Resume (mouse only, no Esc key - F-NOESC). Options reuse the shared OptionsPanel, never a copy. Quit warns that the
## in-battle progress is lost and only the last manual save remains.

signal resumed
signal quit_to_menu

## F-BUI Rule 13: the battle state the Squad View reads (null = no Squad button).
var battle_state: BattleState = null
var _squad_view: SquadView = null


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var window_panel := UIBuilder.centered_modal_panel(self, 460, 640)   # F-UI: opaque, fits the options block
	var box := UIBuilder.vbox(window_panel, 14)
	UIBuilder.label(box, UIBuilder.t("Paused"), 32)
	var resume := UIBuilder.button(box, UIBuilder.t("Resume"), 24)
	resume.pressed.connect(_on_resume)
	if battle_state != null:
		var squad := UIBuilder.button(box, UIBuilder.t("Squad"), 24)
		squad.pressed.connect(open_squad_view)
	box.add_child(OptionsPanel.new())
	var quit := UIBuilder.button(box, UIBuilder.t("Quit to menu"), 24)
	quit.pressed.connect(_confirm_quit)


## Read-only Squad View; closing it returns here (the pause menu stays open).
func open_squad_view() -> void:
	if _squad_view != null and is_instance_valid(_squad_view):
		return
	_squad_view = SquadView.build(battle_state)
	_squad_view.closed.connect(func() -> void: _squad_view = null)
	add_child(_squad_view)


func _on_resume() -> void:
	resumed.emit()
	queue_free()


## Confirmation spells out D11: no mid-battle save, only the last manual save survives.
## F-UI: the themed ConfirmDialog.
func _confirm_quit() -> void:
	var dialog := ConfirmDialog.build(UIBuilder.t("Quit to menu"), UIBuilder.t("Current battle progress will be lost. Only your latest manual save is kept. Quit anyway?"), UIBuilder.t("Quit"), UIBuilder.t("Back to battle"))
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: quit_to_menu.emit())
