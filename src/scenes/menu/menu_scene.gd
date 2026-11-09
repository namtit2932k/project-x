extends Control
class_name MenuScene
## Main menu (F-UI step 2, UI doc "Menu chính"): the title and one card with exactly three
## entries - New game, Continue (disabled without a save), Options. No shop, no difficulty
## (chosen on the next screen), no Quit (closing the window quits). Debug builds add a small
## row outside the card for the test maps and the legacy chapter.

signal new_game
## F4.3 (P-08): only connected in debug builds — opens the legacy ch01 campaign.
signal legacy_chapter
signal continue_game
## I18N: the language was switched in the options dialog; Main rebuilds the menu.
signal language_changed
signal test_battle(map_id: String)   # N12: debug-only quick battle entry per test map
var _test_maps_panel: Control = null
var _options_dialog: Control = null
var _continue_button: Button = null


func _ready() -> void:
	UIBuilder.fill_screen(self)
	UIBuilder.background(self)

	var title := UIBuilder.title(self, "PROJECT", 84)
	title.position = Vector2(48, 210)
	var x := UIBuilder.title(self, "X", 84)
	x.position = Vector2(120, 300)
	x.add_theme_color_override("font_color", Color("a9d6c8"))
	var sub := UIBuilder.label(self, UIBuilder.t("Tactical turn-based RPG - vertical slice build"), 15)
	sub.add_theme_color_override("font_color", UITheme.MUTED)
	sub.position = Vector2(52, 420)

	# UI doc: card at least 398 x 242, buttons at least 330 x 64, padding 23.
	var card := UIBuilder.panel(self, 700, 239, 398, 242)
	var box := UIBuilder.vbox(card, 6)
	var new_btn := _menu_button(box, UIBuilder.t("New game"))
	new_btn.name = "NewGame"
	new_btn.pressed.connect(func() -> void: _reset_options_and_emit("new"))
	_continue_button = _menu_button(box, UIBuilder.t("Continue"))
	_continue_button.name = "Continue"
	_continue_button.disabled = not SaveService.has_save()
	_continue_button.pressed.connect(func() -> void: _reset_options_and_emit("continue"))
	var options_btn := _menu_button(box, UIBuilder.t("Options"))
	options_btn.name = "Options"
	options_btn.pressed.connect(open_options)

	if OS.is_debug_build():
		var debug_row := HBoxContainer.new()
		debug_row.name = "DebugRow"
		debug_row.add_theme_constant_override("separation", 8)
		debug_row.position = Vector2(48, 660)
		add_child(debug_row)
		UIBuilder.label(debug_row, UIBuilder.t("Debug:"), 14).add_theme_color_override("font_color", UITheme.MUTED)
		var test_btn := UIBuilder.button(debug_row, UIBuilder.t("Test maps"), 14)
		test_btn.pressed.connect(_open_test_maps)
		var legacy_btn := UIBuilder.button(debug_row, UIBuilder.t("Legacy chapter (ch01)"), 14)
		legacy_btn.pressed.connect(func() -> void: legacy_chapter.emit())


func _menu_button(parent: Control, text: String) -> Button:
	var b := UIBuilder.button(parent, text, 18)
	b.custom_minimum_size = Vector2(330, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## The three entries of the card, in order (tests read this).
func menu_entries() -> Array[String]:
	var out: Array[String] = []
	for b in find_children("*", "Button", true, false):
		if String(b.name) in ["NewGame", "Continue", "Options"]:
			out.append(String(b.name))
	return out


## Options dialog (UI doc "Tùy chọn từ menu"): window mode + three volumes + language.
func open_options() -> void:
	if _options_dialog != null and is_instance_valid(_options_dialog):
		return
	_options_dialog = UIBuilder.modal(self)
	var box := UIBuilder.vbox(UIBuilder.centered_modal_panel(_options_dialog, 600, 420), 10)
	var opts := OptionsPanel.new()
	opts.language_changed.connect(func() -> void: language_changed.emit())
	box.add_child(opts)
	var close := UIBuilder.button(box, UIBuilder.t("Close"), 16)
	close.custom_minimum_size = Vector2(195, 46)
	close.pressed.connect(close_options)


func close_options() -> void:
	if _options_dialog != null and is_instance_valid(_options_dialog):
		_options_dialog.queue_free()
	_options_dialog = null


## Debug-only map picker (N12): one button per map_test_* entry in the registry.
## Selecting starts the battle straight away — no chapter loop, no story scene.
func _open_test_maps() -> void:
	if _test_maps_panel != null:
		_test_maps_panel.queue_free()
	var panel := UIBuilder.centered_modal_panel(self, 400, 420)
	_test_maps_panel = panel
	var box := UIBuilder.vbox(panel, 8)
	UIBuilder.label(box, UIBuilder.t("Test maps (debug build only)"), 22)
	for map_id in DataRegistry.all_ids("maps"):
		if not String(map_id).begins_with("map_test_"):
			continue
		var map := DataRegistry.get_map(String(map_id))
		var btn := UIBuilder.button(box, map.display_name, 18)
		var chosen: String = String(map_id)
		btn.pressed.connect(func() -> void:
			_test_maps_panel = null
			panel.queue_free()
			test_battle.emit(chosen))


func _reset_options_and_emit(kind: String) -> void:
	OptionsPanel.apply_audio_and_window()
	if kind == "new":
		new_game.emit()
	else:
		continue_game.emit()
