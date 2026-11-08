extends VBoxContainer
class_name OptionsPanel
## Shared options block (N08): volume + fullscreen, built once for MenuScene and the
## battle pause menu. Reads/writes GameState.options; applying never hardcodes defaults.

signal options_applied
## I18N: the player switched the UI language (MenuScene rebuilds itself on it).
signal language_changed


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	UIBuilder.label(self, UIBuilder.t("Options"), 20)
	UIBuilder.label(self, UIBuilder.t("Volume"), 16)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = float(GameState.options.get("volume", 0.8))
	volume_slider.value_changed.connect(_on_volume)
	add_child(volume_slider)
	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = UIBuilder.t("Fullscreen")
	fullscreen_check.button_pressed = bool(GameState.options.get("fullscreen", false))
	fullscreen_check.toggled.connect(_on_fullscreen)
	add_child(fullscreen_check)
	# I18N: one button cycles through GameState.LANGUAGES (names shown in their own language).
	var lang_btn := UIBuilder.button(self, _language_label(), 16)
	lang_btn.pressed.connect(func() -> void:
		var codes: Array = GameState.LANGUAGES.keys()
		var next: String = String(codes[(codes.find(GameState.language()) + 1) % codes.size()])
		GameState.set_language(next)
		lang_btn.text = _language_label()
		language_changed.emit())


static func _language_label() -> String:
	return UIBuilder.t("Language: %s") % String(GameState.LANGUAGES.get(GameState.language(), GameState.language()))


func _on_volume(value: float) -> void:
	GameState.options["volume"] = value
	apply_audio_and_window()


func _on_fullscreen(pressed: bool) -> void:
	GameState.options["fullscreen"] = pressed
	apply_audio_and_window()


## Single place that pushes GameState.options to the OS (bus volume + window mode).
static func apply_audio_and_window() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(GameState.options.get("volume", 0.8)), 0.05, 1.0)))
	if bool(GameState.options.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
