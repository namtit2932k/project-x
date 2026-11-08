extends VBoxContainer
class_name OptionsPanel
## Shared options block (N08), used by the main-menu Options dialog and the battle pause menu.
## F-UI step 2 (UI doc): window mode, three volume sliders (master / music / effects) and the
## UI language. Reads / writes GameState.options; apply_audio_and_window() pushes them to the OS.

signal options_applied
## I18N: the player switched the UI language (MenuScene rebuilds itself on it).
signal language_changed

## Option key -> audio bus. "volume" stays the master key so older saves keep their setting.
const VOLUME_BUSES := {"volume": "Master", "volume_music": "Music", "volume_sfx": "SFX"}
const VOLUME_LABELS := {"volume": "Master volume", "volume_music": "Music", "volume_sfx": "Effects"}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	UIBuilder.label(self, UIBuilder.t("Options"), 20)
	UIBuilder.label(self, UIBuilder.t("Display"), 14).add_theme_color_override("font_color", UITheme.ACCENT)
	var mode_row := HBoxContainer.new()
	add_child(mode_row)
	var mode_label := UIBuilder.label(mode_row, UIBuilder.t("Window mode"), 16)
	mode_label.custom_minimum_size = Vector2(150, 0)
	var mode := OptionButton.new()
	mode.name = "WindowMode"
	mode.add_item(UIBuilder.t("Windowed"), 0)
	mode.add_item(UIBuilder.t("Fullscreen"), 1)
	mode.select(1 if bool(GameState.options.get("fullscreen", false)) else 0)
	mode.item_selected.connect(func(index: int) -> void: _on_fullscreen(index == 1))
	mode_row.add_child(mode)
	UIBuilder.label(self, UIBuilder.t("Sound"), 14).add_theme_color_override("font_color", UITheme.ACCENT)
	for key in VOLUME_BUSES:
		var row := HBoxContainer.new()
		add_child(row)
		var l := UIBuilder.label(row, UIBuilder.t(String(VOLUME_LABELS[key])), 16)
		l.custom_minimum_size = Vector2(150, 0)
		var slider := HSlider.new()
		slider.name = "Slider_%s" % key
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(180, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value = float(GameState.options.get(key, 0.8))
		var option_key := String(key)
		slider.value_changed.connect(func(value: float) -> void: set_volume(option_key, value))
		row.add_child(slider)
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


## One volume option (0..1) changed: store it and apply.
func set_volume(key: String, value: float) -> void:
	GameState.options[key] = clampf(value, 0.0, 1.0)
	apply_audio_and_window()
	options_applied.emit()


func _on_volume(value: float) -> void:
	set_volume("volume", value)


func _on_fullscreen(pressed: bool) -> void:
	GameState.options["fullscreen"] = pressed
	apply_audio_and_window()
	options_applied.emit()


## Single place that pushes GameState.options to the OS (bus volumes + window mode).
static func apply_audio_and_window() -> void:
	for key in VOLUME_BUSES:
		var bus := _ensure_bus(String(VOLUME_BUSES[key]))
		var value := float(GameState.options.get(key, 0.8))
		AudioServer.set_bus_mute(bus, value <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(value, 0.05, 1.0)))
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(GameState.options.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


## Index of the named bus, created (routed to Master) when the project has none yet.
static func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	return index
