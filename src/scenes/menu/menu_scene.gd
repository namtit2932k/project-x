extends Control
class_name MenuScene
## Main menu: new campaign, continue (manual save between battles), options, quit.

signal new_game
signal continue_game
signal options_changed

var _volume_slider: HSlider
var _fullscreen_check: CheckButton
var _diff_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIBuilder.label(self, "PROJECT X", 64)
	title.position = Vector2(60, 80)
	var sub := UIBuilder.label(self, "Tactical turn-based RPG - vertical slice build", 22)
	sub.position = Vector2(64, 160)

	var box := UIBuilder.vbox(self, 14)
	box.position = Vector2(64, 280)
	box.custom_minimum_size = Vector2(360, 400)

	var new_btn := UIBuilder.button(box, "New campaign", 24)
	new_btn.pressed.connect(func() -> void: _reset_options_and_emit("new"))
	if SaveService.has_save():
		var cont := UIBuilder.button(box, "Continue", 24)
		cont.pressed.connect(func() -> void: _reset_options_and_emit("continue"))

	var diff := UIBuilder.button(box, "Difficulty: %s (switch)" % GameState.difficulty, 20)
	diff.pressed.connect(_on_cycle_difficulty)
	_diff_button = diff

	var quit := UIBuilder.button(box, "Quit", 20)
	quit.pressed.connect(func() -> void: get_tree().quit())

	var options := UIBuilder.panel(self, 1500, 640, 360, 300)
	var obox := UIBuilder.vbox(options, 10)
	UIBuilder.label(obox, "Options", 20)
	UIBuilder.label(obox, "Volume", 16)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = float(GameState.options.get("volume", 0.8))
	_volume_slider.value_changed.connect(_on_volume)
	obox.add_child(_volume_slider)
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.button_pressed = bool(GameState.options.get("fullscreen", false))
	_fullscreen_check.toggled.connect(_on_fullscreen)
	obox.add_child(_fullscreen_check)


func _reset_options_and_emit(kind: String) -> void:
	_apply_audio_options()
	if kind == "new":
		new_game.emit()
	else:
		continue_game.emit()


func _on_cycle_difficulty() -> void:
	var order: Array[String] = ["story", "normal", "hard", "nightmare"]
	var idx := order.find(GameState.difficulty)
	GameState.difficulty = order[(idx + 1) % order.size()]
	if _diff_button != null:
		_diff_button.text = "Difficulty: %s (switch)" % GameState.difficulty


func _on_volume(value: float) -> void:
	GameState.options["volume"] = value


func _on_fullscreen(pressed: bool) -> void:
	GameState.options["fullscreen"] = pressed
	_apply_audio_options()


func _apply_audio_options() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(GameState.options.get("volume", 0.8)), 0.05, 1.0)))
	if bool(GameState.options.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
