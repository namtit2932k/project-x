extends Control
class_name DifficultyScene
## F-UI step 2 (UI doc "Chọn độ khó" + "Xác nhận Nightmare"): four tier cards before a new
## campaign, a summary bar with "Start the journey", and a confirmation for Nightmare (it can
## never be changed afterwards, F-DLOCK). Numbers come from rules_config, nothing is hardcoded.

signal start_pressed(difficulty: String)
signal back_pressed

const TIERS: Array[String] = ["story", "normal", "hard", "nightmare"]
const CATEGORY := {"story": "01 / STORY", "normal": "02 / BALANCED", "hard": "03 / HARSH", "nightmare": "04 / MERCILESS"}
const LINE := {
	"story": "Follow the story with many chances to fix mistakes.",
	"normal": "Enough challenge for every decision to matter.",
	"hard": "Fewer chances to fix mistakes; enemies are stronger.",
	"nightmare": "No rewinds. The enemy shows no mercy.",
}

var selected: String = "normal"
var _cards := {}
var _summary_title: Label = null
var _summary_detail: Label = null
var _confirm: Control = null


func _ready() -> void:
	UIBuilder.fill_screen(self)
	UIBuilder.background(self)
	if GameState.difficulty in TIERS:
		selected = GameState.difficulty
	var title := UIBuilder.title(self, UIBuilder.t("How do you want to fight?"), 40)
	title.position = Vector2(48, 28)
	var sub := UIBuilder.label(self, UIBuilder.t("Difficulty sets enemy strength, how often you can rewind and what happens when an ally falls."), 15)
	sub.position = Vector2(48, 90)
	var tag := UIBuilder.label(self, UIBuilder.t("NEW GAME / STEP 01"), 12)
	tag.add_theme_color_override("font_color", UITheme.ACCENT)
	tag.position = Vector2(48, 116)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.position = Vector2(48, 140)
	add_child(row)
	for tier in TIERS:
		_cards[tier] = _build_card(row, tier)
	var bar := UIBuilder.panel(self, 48, 404, 1184, 84)
	var bar_row := HBoxContainer.new()
	bar.add_child(bar_row)
	var text_box := UIBuilder.vbox(bar_row, 2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_title = UIBuilder.title(text_box, "", 22)
	_summary_detail = UIBuilder.label(text_box, "", 14)
	var start := UIBuilder.button(bar_row, UIBuilder.t("START THE JOURNEY →"), 16)
	start.name = "StartButton"
	start.custom_minimum_size = Vector2(260, 46)
	start.add_theme_stylebox_override("normal", _accent_box())
	start.add_theme_color_override("font_color", UITheme.BG)
	start.pressed.connect(_on_start)
	var back := UIBuilder.button(self, UIBuilder.t("← Back to menu"), 16)
	back.position = Vector2(48, 504)
	back.size = Vector2(1184, 44)
	back.pressed.connect(func() -> void: back_pressed.emit())
	select(selected)


func _build_card(parent: Control, tier: String) -> Button:
	var card := Button.new()
	card.name = "Card_%s" % tier
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(280, 248)
	card.pressed.connect(func() -> void: select(tier))
	parent.add_child(card)
	var box := UIBuilder.vbox(card, 6)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 12
	box.offset_right = -14
	box.offset_bottom = -12
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cat := UIBuilder.label(box, UIBuilder.t(String(CATEGORY[tier])), 12)
	cat.add_theme_color_override("font_color", UITheme.ACCENT)
	UIBuilder.title(box, UIBuilder.t(tier.capitalize()), 26)
	var line := UIBuilder.label(box, UIBuilder.t(String(LINE[tier])), 14)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(250, 0)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	UIBuilder.label(box, UIBuilder.t("REWIND %s") % rewind_text(tier), 12)
	UIBuilder.label(box, casualty_caption(tier), 12)
	for c in box.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## Highlights one card and refreshes the summary bar.
func select(tier: String) -> void:
	selected = tier
	for t in _cards:
		var card: Button = _cards[t]
		card.button_pressed = t == tier
		if t == tier:
			card.add_theme_stylebox_override("normal", _selected_box())
			card.add_theme_stylebox_override("pressed", _selected_box())
		else:
			card.remove_theme_stylebox_override("normal")
			card.remove_theme_stylebox_override("pressed")
	_summary_title.text = UIBuilder.t("Normal · recommended for a first run") if tier == "normal" else UIBuilder.t(tier.capitalize())
	_summary_detail.text = UIBuilder.t("Rewind %s · %s") % [rewind_text(tier), casualty_sentence(tier)]


func _on_start() -> void:
	if selected == "nightmare":
		_open_confirm()
		return
	start_pressed.emit(selected)


## UI doc "Xác nhận Nightmare": the choice is final for the whole campaign.
func _open_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		return
	_confirm = UIBuilder.modal(self)
	var box := UIBuilder.vbox(UIBuilder.centered_modal_panel(_confirm, 600, 260), 12)
	UIBuilder.title(box, UIBuilder.t("Choose Nightmare?"), 30)
	var text := UIBuilder.label(box, UIBuilder.t("Nightmare cannot be changed for the rest of this campaign: no rewinds, enemies are four levels stronger, and fallen allies sit out the next map."), 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var back := UIBuilder.button(buttons, UIBuilder.t("Back"), 16)
	back.custom_minimum_size = Vector2(160, 46)
	back.pressed.connect(close_confirm)
	var go := UIBuilder.button(buttons, UIBuilder.t("Start on Nightmare"), 16)
	go.name = "ConfirmNightmare"
	go.custom_minimum_size = Vector2(220, 46)
	go.add_theme_stylebox_override("normal", _accent_box())
	go.add_theme_color_override("font_color", UITheme.BG)
	go.pressed.connect(func() -> void:
		close_confirm()
		start_pressed.emit("nightmare"))


func close_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null


## "∞" or the number of rewinds the tier allows (rules_config.rewind_per_difficulty).
static func rewind_text(tier: String) -> String:
	var n := int(DataRegistry.rule("rewind_per_difficulty", {}).get(tier, 0))
	return "∞" if n < 0 else str(n)


static func casualty_caption(tier: String) -> String:
	match String(DataRegistry.rule("casualty_by_difficulty", {}).get(tier, "temp_injury")):
		"sit_out":
			return UIBuilder.t("FALLEN ALLIES SIT OUT THE NEXT MAP")
	return UIBuilder.t("FALLEN ALLIES RETURN AFTER THE BATTLE")


static func casualty_sentence(tier: String) -> String:
	match String(DataRegistry.rule("casualty_by_difficulty", {}).get(tier, "temp_injury")):
		"sit_out":
			return UIBuilder.t("fallen allies sit out the next map")
	return UIBuilder.t("fallen allies return after the battle")


static func _selected_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.SELECTED
	s.border_color = UITheme.ACCENT
	s.set_border_width_all(1)
	return s


static func _accent_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.ACCENT
	s.border_color = UITheme.ACCENT
	s.set_border_width_all(1)
	s.set_content_margin_all(10)
	return s
