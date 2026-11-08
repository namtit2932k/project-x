extends Control
class_name MenuScene
## Main menu: new campaign, continue (manual save between battles), options, quit.

signal new_game
## F4.3 (P-08): only connected in debug builds — opens the legacy ch01 campaign.
signal legacy_chapter
signal continue_game
## I18N: the language was switched in the options block; Main rebuilds the menu.
signal language_changed
signal test_battle(map_id: String)   # N12: debug-only quick battle entry per test map
var _test_maps_panel: Control = null

var _diff_button: Button


func _ready() -> void:
	UIBuilder.fill_screen(self)
	UIBuilder.background(self)

	var title := UIBuilder.title(self, "PROJECT X", 64)
	title.position = Vector2(48, 60)
	var sub := UIBuilder.label(self, UIBuilder.t("Tactical turn-based RPG - vertical slice build"), 18)
	sub.position = Vector2(52, 150)

	var box := UIBuilder.vbox(self, 10)
	box.position = Vector2(52, 210)
	box.custom_minimum_size = Vector2(330, 400)

	var new_btn := UIBuilder.button(box, UIBuilder.t("New campaign"), 24)
	new_btn.pressed.connect(func() -> void: _reset_options_and_emit("new"))
	if SaveService.has_save():
		var cont := UIBuilder.button(box, UIBuilder.t("Continue"), 24)
		cont.pressed.connect(func() -> void: _reset_options_and_emit("continue"))

	var diff := UIBuilder.button(box, UIBuilder.t("Difficulty: %s (switch)") % UIBuilder.t(GameState.difficulty.capitalize()), 20)
	diff.pressed.connect(_on_cycle_difficulty)
	_diff_button = diff

	if OS.is_debug_build():
		var test_btn := UIBuilder.button(box, UIBuilder.t("Test maps"), 20)
		test_btn.pressed.connect(_open_test_maps)
		var legacy_btn := UIBuilder.button(box, UIBuilder.t("Legacy chapter (ch01)"), 20)
		legacy_btn.pressed.connect(func() -> void: legacy_chapter.emit())

	var quit := UIBuilder.button(box, UIBuilder.t("Quit"), 20)
	quit.pressed.connect(func() -> void: get_tree().quit())

	# Options reuse the shared module (N08): identical behavior in the battle pause menu.
	var options := UIBuilder.panel(self, 860, 330, 372, 300)
	var obox := UIBuilder.vbox(options, 10)
	var opts := OptionsPanel.new()
	opts.language_changed.connect(func() -> void: language_changed.emit())
	obox.add_child(opts)


## Debug-only map picker (N12): one button per map_test_* entry in the registry.
## Selecting starts the battle straight away — no chapter loop, no story scene.
func _open_test_maps() -> void:
	if _test_maps_panel != null:
		_test_maps_panel.queue_free()
	var panel := UIBuilder.panel(self, 440, 90, 400, 420)
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


## F-DLOCK: the main menu is the only place Nightmare can be chosen (before New campaign).
func _on_cycle_difficulty() -> void:
	var order: Array[String] = GameState.DIFFICULTIES_ALL
	var idx := order.find(GameState.difficulty)
	GameState.difficulty = order[(idx + 1) % order.size()]
	if _diff_button != null:
		_diff_button.text = UIBuilder.t("Difficulty: %s (switch)") % UIBuilder.t(GameState.difficulty.capitalize())


		
