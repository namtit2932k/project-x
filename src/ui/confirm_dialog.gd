extends Control
class_name ConfirmDialog
## F-UI: the themed yes / no dialog (UI doc "Leave confirm" look): dimmed screen, opaque
## gold-bordered window, serif title, message, Cancel + gold Confirm. Replaces Godot's
## ConfirmationDialog, whose separate window ignored the game theme. Mouse only (F-NOESC).
## Used by the camp S lock and the pause menu's Quit to menu.

signal confirmed
signal canceled

const WIDTH := 620.0

var title_text := ""
var message := ""
var ok_text := ""
var cancel_text := ""
var _window: PanelContainer = null


static func build(p_title: String, p_message: String, p_ok: String, p_cancel: String) -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d.title_text = p_title
	d.message = p_message
	d.ok_text = p_ok
	d.cancel_text = p_cancel
	return d


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var root := UIBuilder.modal(self)
	_window = UIBuilder.centered_modal_panel(root, WIDTH, 120)   # grows to its content, re-centred below
	_window.name = "ConfirmWindow"
	var box := UIBuilder.vbox(_window, 14)
	UIBuilder.title(box, title_text, 30)
	var text := UIBuilder.label(box, message, 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var cancel := UIBuilder.button(row, cancel_text, 16)
	cancel.name = "CancelButton"
	cancel.custom_minimum_size = Vector2(195, 46)
	cancel.pressed.connect(_cancel)
	var ok := UIBuilder.primary_button(row, ok_text)
	ok.name = "ConfirmButton"
	ok.custom_minimum_size = Vector2(195, 46)
	ok.pressed.connect(_ok)
	_recenter.call_deferred()


## A long message makes the window taller than planned: keep it centred in the frame.
func _recenter() -> void:
	if _window != null and is_instance_valid(_window):
		_window.position = ((UITheme.FRAME - _window.size) / 2.0).max(Vector2.ZERO)


func _ok() -> void:
	confirmed.emit()
	queue_free()


func _cancel() -> void:
	canceled.emit()
	queue_free()
