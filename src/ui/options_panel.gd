extends VBoxContainer
class_name OptionsPanel
## Shared options block (N08): volume + fullscreen, built once for MenuScene and the
## battle pause menu. Reads/writes GameState.options; applying never hardcodes defaults.

signal options_applied


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	UIBuilder.label(self, "Options", 20)
	UIBuilder.label(self, "Volume", 16)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = float(GameState.options.get("volume", 0.8))
	volume_slider.value_changed.connect(_on_volume)
	add_child(volume_slider)
	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.button_pressed = bool(GameState.options.get("fullscreen", false))
	fullscreen_check.toggled.connect(_on_fullscreen)
	add_child(fullscreen_check)


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
