extends Control
class_name BetweenBattlesOptions
## F-UI (UI doc "Tùy chọn giữa các trận"): display + sound + language (OptionsPanel), the
## difficulty switch allowed between battles (Story / Normal / Hard; locked on Nightmare,
## F-DLOCK) and "Save progress". The content scrolls so Save and Close are always reachable
## (the document flags the old dialog for hiding Close at 1280 x 720).

signal closed

var _status: Label = null
var _tier_buttons := {}
var _panel: PanelContainer = null


func _ready() -> void:
	UIBuilder.fill_screen(self)
	var root := UIBuilder.modal(self)
	var panel := UIBuilder.centered_modal_panel(root, 680, 620)
	panel.name = "OptionsWindow"
	_panel = panel
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := UIBuilder.vbox(scroll, 10)
	box.custom_minimum_size = Vector2(620, 0)
	box.add_child(OptionsPanel.new())
	UIBuilder.label(box, UIBuilder.t("Between battles"), 14).add_theme_color_override("font_color", UITheme.ACCENT)
	UIBuilder.label(box, UIBuilder.t("Current difficulty: %s") % UIBuilder.t(GameState.difficulty.capitalize()), 18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	if GameState.camp_difficulty_choices().is_empty():
		UIBuilder.label(row, UIBuilder.t("Nightmare is locked for this campaign."), 15)
	for tier in GameState.camp_difficulty_choices():
		var b := UIBuilder.button(row, "%s\n%s" % [UIBuilder.t(tier.capitalize()), UIBuilder.t("Rewind %s · %s") % [DifficultyScene.rewind_text(tier), DifficultyScene.casualty_sentence(tier)]], 13)
		b.name = "Tier_%s" % tier
		b.custom_minimum_size = Vector2(196, 72)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # keeps the three tiers inside the dialog
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = tier == GameState.difficulty
		var chosen := String(tier)
		b.pressed.connect(func() -> void: set_difficulty(chosen))
		_tier_buttons[tier] = b
	_status = UIBuilder.label(box, "", 14)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var save := UIBuilder.button(buttons, UIBuilder.t("Save progress"), 16)
	save.name = "SaveProgress"
	save.custom_minimum_size = Vector2(195, 46)
	save.pressed.connect(save_progress)
	var close := UIBuilder.button(buttons, UIBuilder.t("Close"), 16)
	close.name = "Close"
	close.custom_minimum_size = Vector2(195, 46)
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	_recenter.call_deferred()


## Content wider than planned (long translations) must not push the window off-centre.
func _recenter() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.position = ((UITheme.FRAME - _panel.size) / 2.0).max(Vector2.ZERO)


## Story / Normal / Hard only, never on a Nightmare campaign; takes effect next battle.
func set_difficulty(tier: String) -> void:
	if not (tier in GameState.camp_difficulty_choices()):
		return
	GameState.difficulty = tier
	for t in _tier_buttons:
		(_tier_buttons[t] as Button).button_pressed = t == tier
	_status.text = UIBuilder.t("Difficulty: %s - applies from the next battle.") % UIBuilder.t(tier.capitalize())


func save_progress() -> void:
	_status.text = UIBuilder.t("Progress saved") if not SaveService.save_campaign().is_empty() else UIBuilder.t("Save failed")
