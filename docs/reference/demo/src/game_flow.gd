extends Control
## Connects the authored Godot battle maps to the playable menu, story, and between-battle loop.

const BattleScene = preload("res://scenes/battle_demo.tscn")
const HomeMenuScene = preload("res://src/ui/home_menu.tscn")
const FlowBackdrop = preload("res://src/flow_backdrop.gd")
const NarrativeDialogueBoxScene = preload("res://src/ui/narrative_dialogue_box.tscn")
const BattleActionMenuScene = preload("res://src/ui/battle_action_menu.tscn")
const FLOW_PATH := "res://data/game_flow_demo.json"
const SHOP_PATH := "res://data/tuning/gold_shop.json"
const SAVE_PATH := "user://ceasefire_flow_demo.json"
const AUDIO_SETTINGS_PATH := "user://ceasefire_audio_settings.json"
const DISPLAY_SETTINGS_PATH := "user://ceasefire_display_settings.json"
const INK := Color("#07141a")
const PANEL := Color("#0b1d23")
const GOLD := Color("#dfbd80")
const MINT := Color("#a9d7c9")
const PALE := Color("#f3eddd")
const MUTED := Color("#a9b8b7")
const LINE := Color(0.72, 0.84, 0.81, 0.20)

var flow_data: Dictionary = {}
var save_path: String = SAVE_PATH
var audio_settings_path: String = AUDIO_SETTINGS_PATH
var audio_levels: Dictionary = {"Master": 100, "Music": 100, "SFX": 100}
var display_settings_path: String = DISPLAY_SETTINGS_PATH
var window_mode: String = "windowed"
var battle: Control
var backdrop: Control
var page: MarginContainer
var battle_toolbar: HBoxContainer
var action_menu: BattleActionMenu
var _modal_panel: PanelContainer = null
var _modal_panel_min_width: float = 0.0
var serif_font: Font
var screen: String = "home"
var map_index: int = 0
var tier: String = "Normal"
var pool: int = 0
var upgrades: Dictionary = {}
var item_loadout: Dictionary = {}
var shop_data: Dictionary = {}
var gold: int = 0
var battle_start_gold: int = 0
var rewarded_maps: Array[String] = []
var rewarded_factions: Array[String] = []
var shop_return: String = "prep"
var shop_item: String = ""
var trade_target: int = -1
var trade_own_slot: int = -1
var trade_target_slot: int = -1
var dead_ids: Array[String] = []
var selected_ids: Array[String] = []
var viewed_bond: bool = false
var support_points: int = 2 # Demo starts after this pair's C conversation.
var summary: Dictionary = {}
var aftermath_state: String = ""
var dialogue: Array = []
var dialogue_index: int = 0
var dialogue_box: NarrativeDialogueBox = null
var _dialogue_chapter_label: Label
var _dialogue_title_label: Label
var options_return: String = "home"
var bond_return: String = "progression"
var saved_checkpoint: String = "prep"
var pending_upgrade: Dictionary = {}
var pending_tier: String = "Normal"
var selected_progress_unit: String = "swordsman"
var selected_bond_character: String = "swordsman"
var selected_battle_unit: String = ""
var tier_switch_confirmed: bool = false


func _ready() -> void:
	_ensure_audio_buses()
	_load_audio_settings()
	_load_display_settings()
	var file := FileAccess.open(FLOW_PATH, FileAccess.READ)
	if file == null:
		push_error("Không đọc được dữ liệu luồng demo")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Dữ liệu luồng demo không hợp lệ")
		return
	flow_data = parsed
	var shop_file := FileAccess.open(SHOP_PATH, FileAccess.READ)
	if shop_file != null:
		var shop_parsed: Variant = JSON.parse_string(shop_file.get_as_text())
		if shop_parsed is Dictionary:
			shop_data = shop_parsed
	var system_serif := SystemFont.new()
	system_serif.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "Noto Serif"])
	serif_font = system_serif
	backdrop = FlowBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	battle = BattleScene.instantiate()
	battle.embedded_mode = true
	battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(battle)
	battle.battle_finished.connect(_on_battle_finished)
	battle.village_gold_changed.connect(_on_village_gold_changed)
	battle.action_menu_requested.connect(_open_action_menu)
	battle.combat_view_changed.connect(_on_combat_view_changed)
	page = MarginContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		page.add_theme_constant_override("margin_" + side, 48)
	add_child(page)
	battle_toolbar = HBoxContainer.new()
	battle_toolbar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	battle_toolbar.position = Vector2(-380, 20)
	battle_toolbar.add_child(_action_button("↶ Chọn mốc", _open_rewind, "secondary", 180))
	battle_toolbar.add_child(_action_button("Ⅱ Tạm dừng", _pause, "secondary", 180))
	add_child(battle_toolbar)
	action_menu = BattleActionMenuScene.instantiate() as BattleActionMenu
	action_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	action_menu.position = Vector2.ZERO
	add_child(action_menu)
	action_menu.action_chosen.connect(_choose_battle_action)
	action_menu.cancelled.connect(_cancel_action_menu)
	_show("home")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if screen in ["intro", "aftermath", "bond_scene"] and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if is_instance_valid(dialogue_box):
			dialogue_box.advance()
		get_viewport().set_input_as_handled()
	elif screen in ["pause", "rewind", "leave_confirm"] and event.keycode == KEY_ESCAPE:
		_show("battle")
		get_viewport().set_input_as_handled()
	elif screen == "squad_detail" and event.keycode == KEY_ESCAPE:
		_show("squad_list")
		get_viewport().set_input_as_handled()
	elif screen == "squad_list" and event.keycode == KEY_ESCAPE:
		_show("pause")
		get_viewport().set_input_as_handled()
	elif screen == "battle_items" and event.keycode == KEY_ESCAPE:
		_show("action_menu")
		get_viewport().set_input_as_handled()
	elif screen in ["trade_targets", "trade_offer"] and event.keycode == KEY_ESCAPE:
		_show("action_menu" if screen == "trade_targets" else "trade_targets")
		get_viewport().set_input_as_handled()
	elif screen == "options" and event.keycode == KEY_ESCAPE:
		_show(options_return)
		get_viewport().set_input_as_handled()


func _show(next_screen: String) -> void:
	screen = next_screen
	if is_instance_valid(action_menu):
		action_menu.hide_menu()
	var battle_overlay := next_screen in ["pause", "rewind", "leave_confirm", "squad_list", "squad_detail", "battle_items", "trade_targets", "trade_offer"] or (next_screen == "options" and options_return == "pause")
	battle.visible = next_screen in ["battle", "action_menu"] or battle_overlay
	battle.set_process_input(next_screen == "battle")
	page.visible = next_screen not in ["battle", "action_menu"]
	battle_toolbar.visible = next_screen == "battle" and not battle.combat_view.active
	var scenic := next_screen in ["intro", "aftermath", "bond_scene"]
	backdrop.mode = "vn_" + str(dialogue[dialogue_index].get("scene", "journey")) if scenic and not dialogue.is_empty() else ("battle" if battle.visible else "shell")
	backdrop.queue_redraw()
	var full_page := next_screen in ["intro", "aftermath", "bond_scene", "pause", "rewind", "leave_confirm", "squad_list", "squad_detail", "battle_items", "trade_targets", "trade_offer", "upgrade_confirm", "nightmare_confirm", "options"]
	for side in ["left", "top", "right", "bottom"]:
		var inset := 48
		if side == "top": inset = 36
		if side == "bottom": inset = 16
		page.add_theme_constant_override("margin_" + side, 0 if full_page else inset)
	if next_screen == "action_menu":
		_render_action_menu()
		return
	if next_screen == "battle":
		return
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	_modal_panel = null
	if next_screen in ["squad_list", "squad_detail"]:
		var squad_background := ColorRect.new()
		squad_background.color = PANEL
		squad_background.mouse_filter = Control.MOUSE_FILTER_STOP
		page.add_child(squad_background)
	match next_screen:
		"home": _render_home()
		"difficulty": _render_difficulty()
		"intro", "aftermath", "bond_scene": _render_dialogue()
		"prep": _render_prep()
		"summary": _render_summary()
		"bond": _render_bond()
		"bond_list": _render_bond_list()
		"progression": _render_progression()
		"shop": _render_shop()
		"shop_target": _render_shop_target()
		"options":
			if options_return == "home": _render_home()
			elif options_return == "prep": _render_prep()
			elif options_return == "progression": _render_progression()
			_render_options()
		"pause": _render_pause()
		"squad_list": _render_squad_list()
		"squad_detail": _render_squad_detail()
		"battle_items": _render_battle_items()
		"trade_targets": _render_trade_targets()
		"trade_offer": _render_trade_offer()
		"rewind": _render_rewind()
		"gameover": _render_gameover()
		"ending": _render_ending()
		"upgrade_confirm":
			_render_progression()
			_render_upgrade_confirm()
		"leave_confirm": _render_leave_confirm()
		"nightmare_confirm":
			_render_difficulty()
			_render_nightmare_confirm()
	# `_clamp_modal_panel` needs the panel's fully-settled size: autowrap Labels
	# (the body copy, zone eyebrow, etc.) only know their wrapped height once
	# Godot has run a real layout pass and assigned them an actual width — a
	# bare `call_deferred` fires before that pass completes and reads sizes
	# based on width 0, wildly overstating the panel's height. One process
	# frame is enough for the engine to settle the tree built above.
	if is_instance_valid(_modal_panel):
		await get_tree().process_frame
		_clamp_modal_panel(_modal_panel, _modal_panel_min_width)


func _layout(title: String, subtitle: String = "") -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(1180, 0)
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	content.add_child(_title(title, 55))
	if not subtitle.is_empty():
		content.add_child(_label(subtitle, 17, MUTED))
	return content


func _label(value: String, font_size: int = 20, color: Color = PALE) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_color_override("font_color", color)
	item.add_theme_font_size_override("font_size", font_size)
	return item


func _title(value: String, font_size: int = 54, color: Color = PALE) -> Label:
	var item := _label(value, font_size, color)
	item.add_theme_font_override("font", serif_font)
	item.autowrap_mode = TextServer.AUTOWRAP_OFF
	return item


func _eyebrow(value: String) -> Label:
	var item := _label(value.to_upper(), 13, GOLD)
	item.autowrap_mode = TextServer.AUTOWRAP_OFF
	return item


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _panel(child: Control, minimum: Vector2 = Vector2.ZERO, gold_border: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.11, 0.14, 0.93)
	style.border_color = GOLD if gold_border else LINE
	style.set_border_width_all(1)
	style.set_content_margin_all(23)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(child)
	return panel


func _action_button(caption: String, action: Callable, kind: String = "secondary", minimum_width: float = 195, disabled: bool = false) -> Button:
	var item := Button.new()
	item.text = caption
	item.custom_minimum_size = Vector2(minimum_width, 46)
	item.disabled = disabled
	item.add_theme_font_size_override("font_size", 16)
	item.add_theme_color_override("font_color", INK if kind == "primary" else PALE)
	item.add_theme_color_override("font_hover_color", INK if kind == "primary" else GOLD)
	item.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (GOLD if state != "hover" else Color("#f2d29b")) if kind == "primary" else (Color(0.07, 0.17, 0.20, 0.85) if state == "hover" else Color(0.02, 0.08, 0.10, 0.45))
		style.border_color = GOLD if state == "focus" or kind == "primary" else LINE
		style.set_border_width_all(1)
		style.set_content_margin_all(10)
		item.add_theme_stylebox_override(state, style)
	item.pressed.connect(action)
	return item


func _button(caption: String, action: Callable, disabled: bool = false) -> Button:
	return _action_button(caption, action, "secondary", 235, disabled)


func _render_home() -> void:
	var menu := HomeMenuScene.instantiate() as HomeMenu
	menu.configure(serif_font, FileAccess.file_exists(save_path))
	menu.new_game_requested.connect(_show.bind("difficulty"))
	menu.continue_requested.connect(_load_campaign)
	menu.options_requested.connect(_open_options.bind("home"))
	page.add_child(menu)


func _open_shop(return_to: String) -> void:
	shop_return = return_to
	if return_to in ["prep", "progression"]:
		saved_checkpoint = return_to
	_show("shop")


func _roster_items(id: String) -> Array:
	if item_loadout.has(id):
		return item_loadout[id]
	return battle.battle_data["unit_catalog"].get(id, {}).get("carried_items", [])


func _item_name(item_id: String) -> String:
	return str(battle.battle_data.get("items", {}).get(item_id, {}).get("name", item_id))


func _item_description(item_id: String) -> String:
	var item: Dictionary = battle.battle_data.get("items", {}).get(item_id, {})
	if item.get("type") == "Heal":
		return "Hồi %d HP" % int(item.get("heal_value", 0))
	return "%s +%d trong %d lượt" % [str(item.get("buff_stat", "")).to_upper(), int(item.get("buff_amount", 0)), int(item.get("buff_duration", 0))]


func _render_shop() -> void:
	var box := _layout("Cửa hàng", "Mua vật phẩm cho đồng đội; mỗi người mang tối đa 2 món.")
	box.add_child(_eyebrow("VÀNG HIỆN CÓ · %d" % gold))
	var prices: Dictionary = shop_data.get("prices", {})
	for item_id in ["potion", "vulnerary", "elixir", "vigor_tonic", "focus_tonic"]:
		var price := int(prices.get(item_id, 0))
		var caption := "%s  ·  %s                    %d vàng" % [_item_name(item_id), _item_description(item_id), price]
		box.add_child(_action_button(caption, _choose_shop_item.bind(item_id), "secondary", 760, gold < price))
	box.add_child(_action_button("← QUAY LẠI", _show.bind(shop_return), "secondary", 220))


func _choose_shop_item(item_id: String) -> void:
	if not shop_data.get("prices", {}).has(item_id):
		return
	shop_item = item_id
	_show("shop_target")


func _render_shop_target() -> void:
	var price := int(shop_data.get("prices", {}).get(shop_item, 0))
	var box := _layout("Chọn người nhận", "%s · %s · %d vàng" % [_item_name(shop_item), _item_description(shop_item), price])
	box.add_child(_eyebrow("VÀNG HIỆN CÓ · %d" % gold))
	var available_targets := 0
	for id in ["swordsman", "knight"]:
		var unit: Dictionary = battle.battle_data["unit_catalog"][id]
		var carried := _roster_items(id)
		if dead_ids.has(id) or carried.size() >= 2:
			continue
		available_targets += 1
		var names: Array[String] = []
		for carried_id in carried:
			names.append(_item_name(str(carried_id)))
		var caption := "%s · %d/2 món · %s" % [str(unit["name"]), carried.size(), ", ".join(PackedStringArray(names)) if not names.is_empty() else "Trống"]
		box.add_child(_action_button(caption, _purchase_item.bind(id), "secondary", 760, gold < price))
	if available_targets == 0:
		box.add_child(_label("Không có đồng đội nào còn chỗ mang vật phẩm.", 18, MUTED))
	box.add_child(_action_button("← CHỌN VẬT PHẨM", _show.bind("shop"), "secondary", 250))


func _purchase_item(id: String) -> void:
	var prices: Dictionary = shop_data.get("prices", {})
	if not prices.has(shop_item) or not battle.battle_data.get("items", {}).has(shop_item) or dead_ids.has(id):
		return
	var price := int(prices[shop_item])
	var carried: Array = _roster_items(id).duplicate()
	if gold < price or carried.size() >= 2:
		return
	carried.append(shop_item)
	item_loadout[id] = carried
	gold -= price
	_save_campaign()
	_show("shop")


func _render_difficulty() -> void:
	var box := _layout("Bạn muốn chiến đấu thế nào?", "Độ khó quyết định sức mạnh đối phương, số lần quay lại và hậu quả khi đồng đội gục ngã.")
	box.add_child(_eyebrow("Trò chơi mới / bước 01"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	box.add_child(cards)
	var tags := {"Story": "01 / CỐT TRUYỆN", "Normal": "02 / CÂN BẰNG", "Hard": "03 / KHẮC NGHIỆT", "Nightmare": "04 / KHÔNG KHOAN NHƯỢNG"}
	var descriptions := {"Story": "Đi theo câu chuyện với nhiều cơ hội sửa sai.", "Normal": "Đủ thử thách để từng quyết định có sức nặng.", "Hard": "Ít cơ hội sửa sai; mất mát có thể ở lại mãi.", "Nightmare": "Không quay lại. Đối phương không nương tay."}
	for name in ["Story", "Normal", "Hard", "Nightmare"]:
		cards.add_child(_tier_card(name, tags[name], descriptions[name]))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(_title("%s · %s" % [pending_tier, "đề xuất cho lần đầu" if pending_tier == "Normal" else "đã chọn"], 23, GOLD))
	var config: Dictionary = flow_data["difficulty"][pending_tier]
	var rewind_text := "không giới hạn" if config["rewind_unlimited"] else str(int(config["rewind_charges"]))
	details.add_child(_label("Quay lại %s · %s" % [rewind_text, "đồng đội tử trận vĩnh viễn" if config["permadeath"] else "đồng đội trở lại sau trận"], 15, MUTED))
	footer.add_child(details)
	footer.add_child(_action_button("BẮT ĐẦU HÀNH TRÌNH →", _start_selected_tier, "primary", 255))
	box.add_child(_panel(footer, Vector2(0, 102)))
	box.add_child(_action_button("← Quay lại menu", _show.bind("home"), "secondary", 180))


func _tier_card(name: String, index_label: String, description: String) -> Button:
	var item := Button.new()
	item.custom_minimum_size = Vector2(280, 248)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_stylebox_override("normal", _tier_card_style(name == pending_tier))
	item.add_theme_stylebox_override("hover", _tier_card_style(true))
	item.add_theme_stylebox_override("pressed", _tier_card_style(true))
	item.add_theme_stylebox_override("focus", _tier_card_style(true))
	item.pressed.connect(_select_tier.bind(name))
	var padding := MarginContainer.new()
	padding.set_anchors_preset(Control.PRESET_FULL_RECT)
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 20)
	item.add_child(padding)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 12)
	padding.add_child(content)
	content.add_child(_eyebrow(index_label))
	content.add_child(_gap(12))
	content.add_child(_title(name, 32))
	content.add_child(_label(description, 15, MUTED))
	content.add_spacer(false)
	var config: Dictionary = flow_data["difficulty"][name]
	content.add_child(_label("QUAY LẠI %s" % ("∞" if config["rewind_unlimited"] else str(int(config["rewind_charges"]))), 13, MINT))
	content.add_child(_label("TỬ TRẬN VĨNH VIỄN" if config["permadeath"] else "KHÔNG TỬ TRẬN", 12, PALE))
	return item


func _tier_card_style(chosen: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#243b39") if chosen else Color(0.035, 0.11, 0.14, 0.9)
	style.border_color = GOLD if chosen else LINE
	style.set_border_width_all(1)
	return style


## Narrower sibling of `_tier_card()` for the between-battle Options modal
## switcher (`design/ux/difficulty-switcher.md`). Renders tier name + two
## stacked capsule tags (rewind-charge count, permadeath state) read from
## `flow_data["difficulty"][name]`. The card for the active tier is disabled
## (no-op on activation) and marked with a gold border + ◆ glyph; it stays in
## the Tab/D-pad focus chain since Godot 4.7.2 does not clear `focus_mode` on
## a disabled Button (verified empirically during implementation).
func _tier_capsule_card(name: String) -> Button:
	var current := name == tier
	var item := Button.new()
	item.custom_minimum_size = Vector2(280, 194)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	item.focus_mode = Control.FOCUS_ALL
	item.disabled = current
	item.add_theme_color_override("font_disabled_color", PALE)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		item.add_theme_stylebox_override(state, _tier_capsule_card_style(current))
	if not current:
		item.pressed.connect(_change_tier.bind(name))
	var padding := MarginContainer.new()
	padding.set_anchors_preset(Control.PRESET_FULL_RECT)
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_top", 12)
	padding.add_theme_constant_override("margin_bottom", 10)
	item.add_child(padding)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	padding.add_child(content)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)
	header.add_child(_title(name, 28, PALE))
	header.add_spacer(false)
	if current:
		var marker := _label("◆", 20, GOLD)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(marker)
	var config: Dictionary = flow_data["difficulty"][name]
	var rewind_text := "∞ quay lại" if config["rewind_unlimited"] else "%d quay lại" % int(config["rewind_charges"])
	var permadeath_text := "Tử trận vĩnh viễn" if config["permadeath"] else "Không tử trận vĩnh viễn"
	var capsules := VBoxContainer.new()
	capsules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsules.add_theme_constant_override("separation", 4)
	content.add_child(capsules)
	capsules.add_child(_capsule_tag(rewind_text))
	capsules.add_child(_capsule_tag(permadeath_text))
	return item


## A single pill-style capsule tag used inside `_tier_capsule_card()` — stacked
## vertically per `production/ui/difficulty-switcher/visual-design.md` §3
## rather than the new-game picker's side-by-side wrap, to keep 24px text on
## at most two lines without overflowing the card.
func _capsule_tag(value: String) -> PanelContainer:
	var tag := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = LINE
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	tag.add_theme_stylebox_override("panel", style)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _label(value, 24, Color("#d4e2db"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(240, 0)
	tag.add_child(label)
	return tag


func _tier_capsule_card_style(current: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#2b3935") if current else Color("#0a1b21")
	style.border_color = GOLD if current else LINE
	style.set_border_width_all(1)
	return style


func _select_tier(name: String) -> void:
	pending_tier = name
	_show("difficulty")


func _start_selected_tier() -> void:
	if pending_tier == "Nightmare":
		_show("nightmare_confirm")
	else:
		_begin_campaign(pending_tier)


func _render_nightmare_confirm() -> void:
	_modal("XÁC NHẬN LỰA CHỌN", "Nightmare là lựa chọn cố định.", "Không có lượt quay lại; đồng đội tử trận sẽ mất vĩnh viễn. Sau khi bắt đầu, bạn không thể đổi độ khó trong chiến dịch này.", "Vẫn bắt đầu", _begin_campaign.bind("Nightmare"), "Chọn lại", _show.bind("difficulty"))


func _begin_campaign(chosen_tier: String) -> void:
	map_index = 0
	tier = chosen_tier
	pool = 0
	upgrades.clear()
	item_loadout.clear()
	gold = 0
	rewarded_maps.clear()
	rewarded_factions.clear()
	dead_ids.clear()
	viewed_bond = false
	support_points = 2
	selected_ids.clear()
	dialogue = flow_data["intro"]
	dialogue_index = 0
	_show("intro")


func _render_dialogue() -> void:
	if dialogue.is_empty():
		return
	# page is a MarginContainer, which force-fills every direct child to its
	# content rect — a free-floating stage is required so back/heading below
	# can use absolute .position instead of being stretched and overridden.
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(stage)
	var heading := VBoxContainer.new()
	heading.position = Vector2(116, 130)
	heading.custom_minimum_size = Vector2(880, 170)
	heading.add_theme_constant_override("separation", 14)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(heading)
	var line: Dictionary = dialogue[dialogue_index]
	var chapter := str(line.get("year", "Sau trận · Cảnh mẫu" if screen == "aftermath" else "Bond scene · Cảnh mẫu"))
	var title := str(line.get("title", "Con đường yên tiếng" if screen == "aftermath" else "Kiếm sĩ & Kỵ sĩ"))
	_dialogue_chapter_label = _eyebrow(chapter)
	heading.add_child(_dialogue_chapter_label)
	_dialogue_title_label = _title(title, 72)
	_dialogue_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(_dialogue_title_label)
	dialogue_box = NarrativeDialogueBoxScene.instantiate()
	dialogue_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(dialogue_box)
	dialogue_box.scene_finished.connect(_end_dialogue, CONNECT_ONE_SHOT)
	dialogue_box.advanced.connect(_on_dialogue_advanced)
	var data := NarrativeSceneData.new()
	data.lines = dialogue
	data.is_severance = false
	dialogue_box.load_scene_data(data)


func _on_dialogue_advanced() -> void:
	dialogue_index += 1
	if dialogue_index >= dialogue.size():
		return
	var line: Dictionary = dialogue[dialogue_index]
	backdrop.mode = "vn_" + str(line.get("scene", "journey"))
	backdrop.queue_redraw()
	if is_instance_valid(_dialogue_chapter_label) and line.has("year"):
		_dialogue_chapter_label.text = str(line["year"]).to_upper()
	if is_instance_valid(_dialogue_title_label) and line.has("title"):
		_dialogue_title_label.text = str(line["title"])


func _end_dialogue() -> void:
	match screen:
		"intro": _show("prep")
		"aftermath":
			map_index += 1
			saved_checkpoint = "progression"
			_save_campaign()
			_show("bond")
		"bond_scene":
			viewed_bond = true
			_save_campaign()
			_show(bond_return)


func _current_map() -> Dictionary:
	return battle.battle_data["maps"][map_index]


func _available_deployments() -> Array:
	var result: Array = []
	for deployment in _current_map()["deployments"]:
		var unit: Dictionary = battle.battle_data["unit_catalog"][deployment["template"]]
		if unit["side"] == "player" and bool(unit.get("controllable", true)) and not dead_ids.has(str(deployment["id"])):
			result.append(deployment)
	return result


func _prepare_selection() -> void:
	selected_ids.clear()
	for deployment in _available_deployments():
		selected_ids.append(str(deployment["id"]))


func _render_prep() -> void:
	if selected_ids.is_empty():
		_prepare_selection()
	var current := _current_map()
	var box := _layout("Chuẩn bị ra trận")
	var top := HBoxContainer.new()
	top.add_child(_eyebrow("TRƯỚC TRẬN · VÍ DỤ %02d" % [map_index + 1]))
	top.add_spacer(false)
	top.add_child(_eyebrow("ĐỘI HÌNH / NHIỆM VỤ · %s" % tier))
	top.add_child(_action_button("TÙY CHỌN", _open_options.bind("prep"), "secondary", 145))
	box.add_child(top)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 25)
	box.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 9)
	left.add_child(_eyebrow("NHIỆM VỤ"))
	left.add_child(_title(_mission_name(str(current["objective_type"]), current.has("escort_goal"), current.has("protect_zone")), 30))
	left.add_child(_label(str(current["objective_text"]), 16, MUTED))
	if current.has("escort_goal"):
		left.add_child(_label("Người đưa tin là NPC trên bản đồ, không chọn vào đội hình.", 16, GOLD))
	elif current["objective_type"] == "Retrieve":
		left.add_child(_label("Ai lấy tài liệu sẽ chỉ được di chuyển cho tới khi về an toàn.", 16, GOLD))
	elif current["objective_type"] == "Seize":
		left.add_child(_label("Một quân phải giữ điểm qua 2 lượt địch liên tiếp; bỏ trống sẽ tính lại.", 16, GOLD))
	if not current.get("villages", []).is_empty():
		left.add_child(_label("Có làng trên bản đồ: đưa quân tới trước địch và chọn Vào làng.", 16, GOLD))
	left.add_child(_label("GIỚI HẠN %d QUÂN     ·     BẢN ĐỒ %d × %d" % [int(current["map_deploy_cap"]), int(current["width"]), int(current["height"])], 13, GOLD))
	left.add_child(HSeparator.new())
	var roster_head := HBoxContainer.new()
	var roster_title := _title("Chọn đội hình", 27)
	roster_title.custom_minimum_size.x = 300
	roster_head.add_child(roster_title)
	roster_head.add_spacer(false)
	roster_head.add_child(_title("%d / %d" % [selected_ids.size(), int(current["map_deploy_cap"])], 26, GOLD))
	left.add_child(roster_head)
	for deployment in _available_deployments():
		var id := str(deployment["id"])
		var unit: Dictionary = battle.battle_data["unit_catalog"][deployment["template"]]
		var required: bool = id == "swordsman" or id == str(current.get("protect_unit_id", ""))
		var mark := "✓" if selected_ids.has(id) else "+"
		var caption := "%s   %s                                      %s\n        HP %d  ·  Di chuyển %d%s" % [_unit_symbol(id), unit["name"], mark, int(unit["hp"]) + int(upgrades.get(id, {}).get("hp", 0)), int(unit["move"]), "  ·  Bắt buộc" if required else ""]
		var row := _action_button(caption, _toggle_deployment_click.bind(id), "secondary", 0, required)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 58
		row.add_theme_color_override("font_disabled_color", PALE)
		if selected_ids.has(id):
			var selected_style := StyleBoxFlat.new()
			selected_style.bg_color = Color("#30483f")
			selected_style.border_color = GOLD
			selected_style.set_border_width_all(1)
			selected_style.set_content_margin_all(12)
			row.add_theme_stylebox_override("normal", selected_style)
			row.add_theme_stylebox_override("disabled", selected_style)
		left.add_child(row)
	left.add_child(_label("Quân chưa chọn vẫn ở lại đội hình. NPC nhiệm vụ luôn có mặt trên bản đồ." if current.has("protect_unit_id") or current.has("escort_unit_id") else "Quân chưa chọn vẫn ở lại đội hình.", 14, MUTED))
	var roster_panel := _panel(left, Vector2(695, 390))
	roster_panel.get_theme_stylebox("panel").set_content_margin_all(18)
	columns.add_child(roster_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.add_child(_eyebrow("XEM TRƯỚC BẢN ĐỒ · %d × %d" % [int(current["width"]), int(current["height"])]))
	right.add_child(_map_preview(current))
	var preview_legend := "● Quân mình     ● NPC vàng     ○ Vị trí trống     ● Quân địch" if current.has("protect_unit_id") or current.has("escort_unit_id") else "● Quân mình     ○ Vị trí trống     ● Quân địch"
	right.add_child(_label(preview_legend, 13, MUTED))
	if current.has("escort_goal"):
		right.add_child(_label("◆ Ô đích vàng — đưa NPC tới đây để thắng", 13, GOLD))
	elif current.has("protect_zone"):
		right.add_child(_label("■ Vùng vàng — không để địch bước vào", 13, GOLD))
	elif current["objective_type"] == "Retrieve":
		right.add_child(_label("◆ Vàng: tài liệu     ◆ Xanh: ô trở về", 13, GOLD))
	elif current["objective_type"] == "Seize":
		right.add_child(_label("◆ Điểm vàng — đứng giữ qua 2 lượt địch", 13, GOLD))
	var map_panel := _panel(right, Vector2(440, 390))
	map_panel.get_theme_stylebox("panel").set_content_margin_all(18)
	columns.add_child(map_panel)
	var footer := HBoxContainer.new()
	footer.add_child(_action_button("← TRỞ LẠI", _show.bind("intro"), "secondary", 160))
	footer.add_spacer(false)
	footer.add_child(_action_button("ĐỘI HÌNH & NÂNG CHỈ SỐ", _show.bind("progression"), "secondary", 255))
	footer.add_child(_action_button("CỬA HÀNG", _open_shop.bind("prep"), "secondary", 160))
	footer.add_child(_action_button("BẮT ĐẦU TRẬN →", _start_battle, "primary", 220, selected_ids.is_empty() or selected_ids.size() > int(current["map_deploy_cap"])))
	box.add_child(footer)


func _unit_symbol(id: String) -> String:
	match id:
		"swordsman": return "⚔"
		"knight": return "♞"
	return "◆"


func _mission_name(objective: String, has_destination: bool = false, has_zone: bool = false) -> String:
	match objective:
		"Elimination": return "Tiêu diệt"
		"Protect": return "Giữ vị trí" if has_zone else "Bảo vệ"
		"Escort": return "Hộ tống" if has_destination else "Ngừng truy kích"
		"Retrieve": return "Thu hồi"
		"Seize": return "Chiếm cứ điểm"
	return objective


func _toggle_deployment_click(id: String) -> void:
	_toggle_deployment(not selected_ids.has(id), id)


func _map_preview(map_info: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = int(map_info["width"])
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	for y in int(map_info["height"]):
		for x in int(map_info["width"]):
			var tile := PanelContainer.new()
			tile.custom_minimum_size = Vector2(37, 37)
			var symbol: String = str(map_info["terrain"][y]).substr(x, 1)
			var style := StyleBoxFlat.new()
			style.bg_color = Color("#60796b") if symbol == "." else (Color("#315e54") if symbol == "F" else (Color("#98774e") if symbol == "V" else Color("#375d71")))
			tile.add_theme_stylebox_override("panel", style)
			var marker := ""
			var marker_color := MINT
			if map_info.has("protect_zone"):
				var zone: Dictionary = map_info["protect_zone"]
				if x >= int(zone["x"]) and y >= int(zone["y"]) and x < int(zone["x"]) + int(zone["width"]) and y < int(zone["y"]) + int(zone["height"]):
					style.bg_color = Color("#96794a")
			if map_info.has("escort_goal") and int(map_info["escort_goal"]["x"]) == x and int(map_info["escort_goal"]["y"]) == y:
				marker = "◆"
				marker_color = GOLD
			if map_info.has("item_tile") and int(map_info["item_tile"]["x"]) == x and int(map_info["item_tile"]["y"]) == y:
				marker = "◆"
				marker_color = GOLD
			if map_info.has("return_tile") and int(map_info["return_tile"]["x"]) == x and int(map_info["return_tile"]["y"]) == y:
				marker = "◆"
				marker_color = MINT
			if map_info.has("control_point") and int(map_info["control_point"]["x"]) == x and int(map_info["control_point"]["y"]) == y:
				marker = "◆"
				marker_color = GOLD
			for deployment in map_info["deployments"]:
				if int(deployment["x"]) == x and int(deployment["y"]) == y:
					var unit: Dictionary = battle.battle_data["unit_catalog"][deployment["template"]]
					marker = "●" if unit["side"] == "enemy" or selected_ids.has(str(deployment["id"])) or not bool(unit.get("controllable", true)) else "○"
					marker_color = Color("#b97165") if unit["side"] == "enemy" else (GOLD if not bool(unit.get("controllable", true)) else MINT)
			if not marker.is_empty():
				var dot := _label(marker, 24, marker_color)
				dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				tile.add_child(dot)
			grid.add_child(tile)
	return grid


func _toggle_deployment(enabled: bool, id: String) -> void:
	if enabled and not selected_ids.has(id):
		selected_ids.append(id)
	elif not enabled:
		selected_ids.erase(id)
	_show("prep")


func _start_battle() -> void:
	var settings: Dictionary = flow_data["difficulty"][tier].duplicate(true)
	settings["tier"] = tier
	battle.battle_data["difficulty"] = settings
	battle.stat_upgrades = upgrades.duplicate(true)
	battle.starting_items = item_loadout.duplicate(true)
	battle_start_gold = gold
	battle.load_example(map_index, selected_ids)
	if viewed_bond:
		for pair in battle.map_data.get("bonds", []):
			if pair["a"] == "swordsman" and pair["b"] == "knight":
				pair["level"] = 2
	battle.combat.setup(battle.battle_data, battle.map_data, battle.units)
	_show("battle")


func _on_village_gold_changed(total: int) -> void:
	gold = battle_start_gold + total


func _open_action_menu() -> void:
	if battle.selected >= 0 and battle.outcome.is_empty():
		_show("action_menu")


func _render_action_menu() -> void:
	if battle.selected < 0:
		_show("battle")
		return
	var unit: Dictionary = battle.units[battle.selected]
	var size := int(battle.battle_data["tile_size"])
	var anchor := Vector2(44 + int(unit["x"]) * size + size / 2, 92 + int(unit["y"]) * size + size / 2)
	action_menu.show_for_unit(str(unit["name"]), battle.legal_actions(), anchor)


func _choose_battle_action(action: String) -> void:
	if not battle.legal_actions().has(action):
		_show("action_menu")
		return
	match action:
		"Attack", "Heal":
			battle.pending_action = action
			battle.preview_target = -1
			battle.message = "Chọn mục tiêu %s. Esc để trở lại menu." % ("tấn công" if action == "Attack" else "hồi máu")
			battle.queue_redraw()
			_show("battle")
		"Use Item": _open_battle_items()
		"Visit":
			_visit_village()
			_show("battle")
		"Trade": _open_trade()
		"Wait":
			battle._finish_action("%s chờ." % str(battle.units[battle.selected]["name"]))
			_show("battle")


func _cancel_action_menu() -> void:
	if battle.cancel_action_menu():
		_show("battle")
	else:
		battle.message = "Đã trao đổi đồ; hãy chọn một hành động để kết thúc lượt."
		battle.queue_redraw()
		_show("action_menu")


func _visit_village() -> void:
	if not battle.visit_village():
		battle.message = "Chỉ quân đang đứng trên làng chưa được thăm mới có thể Vào làng."
		battle.queue_redraw()


func _on_battle_finished(result: Dictionary, state: String, finished_map_index: int) -> void:
	if finished_map_index != map_index:
		return
	summary = result
	aftermath_state = state
	for unit in battle.units:
		if unit["id"] == "swordsman" and int(unit["hp"]) <= 0:
			_show("gameover")
			return
	if bool(result["won"]):
		var reward_key := str(map_index)
		if not rewarded_maps.has(reward_key):
			gold += int(shop_data.get("gold_per_victory", 15))
			if str(battle.map_data.get("objective_type", "")) == "Retrieve":
				gold += int(shop_data.get("gold_item_retrieve_bonus", 15))
			var faction_id := str(battle.map_data.get("faction", {}).get("id", ""))
			if bool(result.get("persuaded", false)) and not faction_id.is_empty() and not rewarded_factions.has(faction_id):
				gold += int(shop_data.get("gold_per_persuasion", 20))
				rewarded_factions.append(faction_id)
			rewarded_maps.append(reward_key)
		for unit in battle.units:
			if unit.get("side") == "player" and bool(unit.get("controllable", true)):
				item_loadout[str(unit["id"])] = unit.get("carried_items", []).duplicate()
		support_points += int(battle.support_progress.get("knight|swordsman", 0))
		pool += int(result["points"])
		if bool(flow_data["difficulty"][tier]["permadeath"]):
			for unit in battle.units:
				if unit["side"] == "player" and int(unit["hp"]) <= 0 and not dead_ids.has(str(unit["id"])):
					dead_ids.append(str(unit["id"]))
	_show("summary")


func _on_combat_view_changed(active: bool) -> void:
	if screen == "battle":
		battle_toolbar.visible = not active


func _render_summary() -> void:
	var won := bool(summary.get("won", false))
	var box := _layout("Chiến thắng" if won else "Thất bại")
	box.add_child(_eyebrow("TỔNG KẾT TRẬN · %s" % str(battle.map_data["title"])))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	box.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 17)
	left.add_child(_eyebrow("ĐIỂM KIỀM CHẾ"))
	left.add_child(_label("Nhiệm vụ hoàn thành. Kết quả được ghi nhận sau khi trận đấu kết thúc." if won else "Nhiệm vụ chưa hoàn thành. Điểm trận này không được cộng vào quỹ chung.", 16, MUTED))
	left.add_child(_title(str(summary.get("points", 0)) if won else "0", 82, GOLD))
	left.add_child(_eyebrow("ĐIỂM TÍNH ĐƯỢC     ·     +%d VÀO QUỸ CHUNG" % (int(summary.get("points", 0)) if won else 0)))
	left.add_child(HSeparator.new())
	var scoring: Dictionary = battle.battle_data["scoring"]
	left.add_child(_report_line("Không có đồng đội tử trận", int(scoring["ally_points"]) if summary.get("zero_ally_deaths", false) else 0))
	if summary.get("eligible", false):
		left.add_child(_report_line("Kiềm chế · %d địch tử trận" % int(summary["kills"]), int(scoring["kill_points"]) if summary["low_kill"] else 0))
		left.add_child(_report_line("Hoàn hảo", int(scoring["perfect_points"]) if summary["low_kill"] and summary["zero_ally_deaths"] else 0))
	left.add_child(_report_line("Hoàn thành nhanh · lượt %d / mốc %d" % [battle.turn_number, int(battle.map_data["turn_par"])], int(scoring["swift_points"]) if summary.get("swift", false) else 0))
	left.add_child(_label("Điểm được cộng sau chiến thắng." if won else "Thử lại để hoàn thành mục tiêu.", 14, MUTED))
	columns.add_child(_panel(left, Vector2(715, 390)))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 14)
	var mission := VBoxContainer.new()
	mission.add_theme_constant_override("separation", 12)
	mission.add_child(_eyebrow("NHIỆM VỤ"))
	mission.add_child(_title(_mission_name(str(battle.map_data["objective_type"]), battle.map_data.has("escort_goal"), battle.map_data.has("protect_zone")), 29))
	mission.add_child(_label(str(battle.map_data["objective_text"]), 16, MUTED))
	mission.add_child(_label("KẾT QUẢ     %s" % ("HOÀN THÀNH" if won else "CHƯA HOÀN THÀNH"), 14, GOLD))
	mission.add_child(_label("LƯỢT KẾT THÚC     %d / %d" % [battle.turn_number, int(battle.map_data["turn_par"])], 14, PALE))
	side.add_child(_panel(mission, Vector2(438, 240)))
	var team := VBoxContainer.new()
	team.add_child(_eyebrow("ĐỘI THAM CHIẾN"))
	var names: Array[String] = []
	for unit in battle.units:
		if unit["side"] == "player" and bool(unit.get("controllable", true)):
			names.append(str(unit["name"]))
	team.add_child(_label(" · ".join(names), 21, PALE))
	team.add_child(_label("Toàn đội trở về sau trận." if summary.get("zero_ally_deaths", false) else "Có đồng đội đã ngã xuống.", 14, MUTED))
	side.add_child(_panel(team, Vector2(438, 125)))
	columns.add_child(side)
	var footer := HBoxContainer.new()
	footer.add_spacer(false)
	if won:
		footer.add_child(_action_button("TIẾP TỤC CÂU CHUYỆN →", _begin_aftermath, "primary", 290))
	else:
		footer.add_child(_action_button("← CHUẨN BỊ LẠI", _show.bind("prep"), "secondary", 220))
		footer.add_child(_action_button("THỬ LẠI →", _start_battle, "primary", 220))
	box.add_child(footer)


func _report_line(caption: String, points: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var description := _label(caption, 17, PALE)
	description.custom_minimum_size.x = 540
	description.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(description)
	var score := _label("+%d" % points, 18, GOLD)
	score.custom_minimum_size.x = 68
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(score)
	return row


func _begin_aftermath() -> void:
	dialogue = []
	var authored: Array = battle.map_data.get("aftermath_lines", {}).get(aftermath_state, [])
	if authored.is_empty():
		dialogue = flow_data["generic_aftermath"]
	else:
		for text_line in authored:
			dialogue.append({"speaker": "Lời dẫn", "text": str(text_line)})
	dialogue_index = 0
	_show("aftermath")


func _render_bond() -> void:
	var box := _layout("Hội thoại bond", "Phối hợp ở ô kề để tích điểm Support. Chọn xem cảnh đã mở để tăng hạng; mốc truyện chỉ khóa thời điểm mở.")
	box.add_child(_eyebrow("NHÂN VẬT · 12 CLASS"))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)
	var groups := VBoxContainer.new()
	groups.add_theme_constant_override("separation", 14)
	for faction in ["empire", "kingdom"]:
		var cast_box := VBoxContainer.new()
		cast_box.add_theme_constant_override("separation", 4)
		cast_box.add_child(_title("Đế quốc Vật lý" if faction == "empire" else "Vương quốc Pháp thuật", 23, GOLD))
		var cast_row := GridContainer.new()
		cast_row.columns = 3
		cast_row.add_theme_constant_override("h_separation", 4)
		cast_row.add_theme_constant_override("v_separation", 4)
		cast_box.add_child(cast_row)
		for person in flow_data.get("cast", []):
			if person["faction"] != faction:
				continue
			var id := str(person["id"])
			var enabled := id in ["swordsman", "knight"] and not dead_ids.has(id)
			var actor := _action_button(str(person["name"]), _select_bond_char.bind(id), "secondary", 190, not enabled)
			actor.custom_minimum_size = Vector2(190, 42)
			actor.add_theme_font_size_override("font_size", 14)
			cast_row.add_child(actor)
		groups.add_child(_panel(cast_box, Vector2(700, 170)))
	columns.add_child(groups)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 16)
	detail.add_child(_eyebrow("QUAN HỆ"))
	detail.add_child(_title("Kiếm sĩ" if selected_bond_character == "swordsman" else "Kỵ sĩ", 34))
	detail.add_child(HSeparator.new())
	var unlocked := _bond_scene_ready()
	var status := "đã xem" if viewed_bond else ("! cảnh mới" if unlocked else ("chờ diễn biến truyện" if map_index < 1 and support_points >= 5 else "chưa đủ điểm"))
	detail.add_child(_title("Kiếm sĩ  ×  Kỵ sĩ", 24, MINT))
	detail.add_child(_label("Bond cấp %d · %s" % [2 if viewed_bond else 1, status], 16, GOLD))
	detail.add_child(_label("Điểm Support: %d / 5 để mở cảnh B" % support_points, 14, MUTED))
	detail.add_child(_action_button("XEM HỘI THOẠI →", _begin_bond_scene, "primary", 270, not unlocked and not viewed_bond))
	detail.add_spacer(false)
	detail.add_child(_action_button("DANH SÁCH BOND ĐÃ CÓ", _show.bind("bond_list"), "secondary", 270))
	columns.add_child(_panel(detail, Vector2(440, 294)))
	var footer := HBoxContainer.new()
	footer.add_spacer(false)
	footer.add_child(_action_button("ĐỘI HÌNH & NÂNG CHỈ SỐ →", _show.bind("ending" if map_index >= battle.battle_data["maps"].size() else "progression"), "primary", 300))
	box.add_child(footer)


func _select_bond_char(id: String) -> void:
	selected_bond_character = id
	_show("bond")


func _render_bond_list() -> void:
	var box := _layout("Danh sách bond đã có", "Các quan hệ đã mở trong đội hình hiện tại.")
	box.add_child(_eyebrow("QUAN HỆ TRONG ĐỘI"))
	var list := VBoxContainer.new()
	list.add_child(_title("Kiếm sĩ  ×  Kỵ sĩ", 28))
	list.add_child(_label("Cấp %d · %s" % [2 if viewed_bond else 1, "Đã xem" if viewed_bond else ("! Cảnh mới" if _bond_scene_ready() else "Chưa mở")], 16, GOLD))
	list.add_child(_action_button("Xem cảnh", _begin_bond_scene, "secondary", 185, not _bond_scene_ready() and not viewed_bond))
	box.add_child(_panel(list, Vector2(700, 130)))
	box.add_child(_action_button("← Hội thoại bond", _show.bind("bond"), "secondary", 210))


func _begin_bond_scene() -> void:
	if not _bond_scene_ready() and not viewed_bond:
		return
	bond_return = "bond"
	dialogue = flow_data["bond_scene"]
	dialogue_index = 0
	_show("bond_scene")


func _bond_scene_ready() -> bool:
	return not viewed_bond and map_index >= 1 and support_points >= 5 and not dead_ids.has("swordsman") and not dead_ids.has("knight")


func _render_progression() -> void:
	var box := _layout("Đội hình & nâng chỉ số", "Xem đồng đội đã gia nhập và dùng điểm kiềm chế để nâng một chỉ số.")
	box.add_child(_eyebrow("GIỮA CÁC TRẬN"))
	var pool_row := HBoxContainer.new()
	pool_row.add_child(_eyebrow("QUỸ ĐIỂM CHUNG · %d ĐIỂM ĐỔI +1 CHỈ SỐ" % int(flow_data["upgrade"]["cost"])))
	pool_row.add_spacer(false)
	pool_row.add_child(_title(str(pool), 34, GOLD))
	var pool_panel := _panel(pool_row, Vector2(0, 60), true)
	pool_panel.get_theme_stylebox("panel").set_content_margin_all(12)
	box.add_child(pool_panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	box.add_child(columns)
	var roster := VBoxContainer.new()
	roster.add_theme_constant_override("separation", 10)
	roster.add_child(_eyebrow("ĐÃ GIA NHẬP · 2 / 12"))
	roster.add_child(_title("Đồng đội", 28))
	for id in ["swordsman", "knight"]:
		var unit: Dictionary = battle.battle_data["unit_catalog"][id]
		var caption := "%s   %s%s" % [_unit_symbol(id), str(unit["name"]), " · đã hy sinh" if dead_ids.has(id) else ""]
		var roster_button := _action_button(caption, _select_progress_unit.bind(id), "secondary", 0, dead_ids.has(id))
		roster_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		roster_button.custom_minimum_size.y = 62
		roster.add_child(roster_button)
	roster.add_spacer(false)
	roster.add_child(_label("Chỉ đồng đội còn hoạt động mới có thể nhận điểm.", 14, MUTED))
	var roster_panel := _panel(roster, Vector2(350, 340))
	roster_panel.get_theme_stylebox("panel").set_content_margin_all(18)
	columns.add_child(roster_panel)
	if selected_progress_unit == "messenger":
		selected_progress_unit = "swordsman"
	if dead_ids.has(selected_progress_unit):
		selected_progress_unit = "swordsman"
	var id := selected_progress_unit
	var unit: Dictionary = battle.battle_data["unit_catalog"][id]
	var profile := VBoxContainer.new()
	profile.add_theme_constant_override("separation", 14)
	profile.add_child(_eyebrow("HỒ SƠ NHÂN VẬT"))
	profile.add_child(_title(str(unit["name"]), 30))
	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 9)
	stats.add_theme_constant_override("v_separation", 9)
	profile.add_child(stats)
	for stat in flow_data["upgrade"]["stats"]:
		var stat_name := str(stat)
		var value := int(unit[stat_name]) + int(upgrades.get(id, {}).get(stat_name, 0))
		var cap: int = int(flow_data["upgrade"]["hp_cap"] if stat_name == "hp" else flow_data["upgrade"]["stat_cap"])
		var control := _action_button("%s  %d  +" % [stat_name.to_upper(), value], _request_upgrade.bind(id, stat_name), "secondary", 168, pool < int(flow_data["upgrade"]["cost"]) or value >= cap)
		control.custom_minimum_size.y = 65
		stats.add_child(control)
	profile.add_child(_label("Chọn một chỉ số để xem xác nhận. Điểm chưa dùng được giữ lại.", 14, MUTED))
	var profile_panel := _panel(profile, Vector2(805, 340))
	profile_panel.get_theme_stylebox("panel").set_content_margin_all(18)
	columns.add_child(profile_panel)
	var footer := HBoxContainer.new()
	footer.add_child(_action_button("← HỘI THOẠI BOND", _show.bind("bond"), "secondary", 230))
	footer.add_spacer(false)
	footer.add_child(_action_button("TÙY CHỌN", _open_options.bind("progression"), "secondary", 145))
	footer.add_child(_action_button("CỬA HÀNG", _open_shop.bind("progression"), "secondary", 160))
	if map_index < battle.battle_data["maps"].size():
		footer.add_child(_action_button("CHUẨN BỊ TRẬN →", _enter_prep, "primary", 220))
	box.add_child(footer)


func _select_progress_unit(id: String) -> void:
	if not battle.battle_data["unit_catalog"].has(id) or not bool(battle.battle_data["unit_catalog"][id].get("controllable", true)):
		return
	selected_progress_unit = id
	_show("progression")


func _request_upgrade(id: String, stat: String) -> void:
	if not battle.battle_data["unit_catalog"].has(id) or not bool(battle.battle_data["unit_catalog"][id].get("controllable", true)):
		return
	pending_upgrade = {"id": id, "stat": stat}
	_show("upgrade_confirm")


func _render_upgrade_confirm() -> void:
	var id := str(pending_upgrade["id"])
	var stat := str(pending_upgrade["stat"])
	var unit_name := str(battle.battle_data["unit_catalog"][id]["name"])
	_modal("XÁC NHẬN PHÂN BỔ", "Nâng chỉ số?", "%s · %s +1. Tiêu %d điểm từ quỹ chung?" % [unit_name, stat.to_upper(), int(flow_data["upgrade"]["cost"])], "Dùng điểm", _confirm_upgrade, "Chọn lại", _show.bind("progression"))


func _confirm_upgrade() -> void:
	_buy_stat(str(pending_upgrade["id"]), str(pending_upgrade["stat"]))


func _buy_stat(id: String, stat: String) -> void:
	var cost := int(flow_data["upgrade"]["cost"])
	if pool < cost:
		return
	var base := int(battle.battle_data["unit_catalog"][id][stat])
	var bonus := int(upgrades.get(id, {}).get(stat, 0))
	var cap := int(flow_data["upgrade"]["hp_cap"] if stat == "hp" else flow_data["upgrade"]["stat_cap"])
	if base + bonus >= cap:
		return
	pool -= cost
	if not upgrades.has(id):
		upgrades[id] = {}
	upgrades[id][stat] = bonus + 1
	_show("progression")


func _enter_prep() -> void:
	selected_ids.clear()
	_show("prep")


func _open_options(from_screen: String) -> void:
	options_return = from_screen
	tier_switch_confirmed = false
	_show("options")


func _render_options() -> void:
	var box := _modal_shell("THIẾT LẬP BẢN THỬ", "Tùy chọn", "Thiết lập hiển thị, âm thanh và trò chơi.", 900)
	var display_zone := VBoxContainer.new()
	display_zone.add_theme_constant_override("separation", 8)
	box.add_child(display_zone)
	display_zone.add_child(_eyebrow("HIỂN THỊ"))
	_add_window_mode_selector(display_zone)
	var audio_zone := VBoxContainer.new()
	audio_zone.add_theme_constant_override("separation", 8)
	box.add_child(audio_zone)
	audio_zone.add_child(_eyebrow("ÂM THANH"))
	for bus_name in ["Master", "Music", "SFX"]:
		_add_audio_slider(audio_zone, bus_name)
	if options_return in ["prep", "progression"] and tier != "Nightmare":
		# Own tighter separation than `box`'s 18px modal-wide rhythm — the
		# post-switch state (3 cards + confirmation line) is the tallest
		# Options-modal content that exists, and at 18px throughout it pushes
		# "ĐÓNG" below the 720px canvas (production/qa/evidence/difficulty-switcher/
		# 02-post-switch-hard-confirmed.png). Scoped to this zone only so the
		# rest of the modal (and every other modal using `_modal_shell`) keeps
		# its normal rhythm.
		var zone := VBoxContainer.new()
		zone.add_theme_constant_override("separation", 6)
		box.add_child(zone)
		zone.add_child(HSeparator.new())
		zone.add_child(_eyebrow("GIỮA CÁC TRẬN"))
		zone.add_child(_label("Độ khó hiện tại: %s" % tier, 24, PALE))
		var tiers := HBoxContainer.new()
		tiers.add_theme_constant_override("separation", 16)
		zone.add_child(tiers)
		for name in ["Story", "Normal", "Hard"]:
			tiers.add_child(_tier_capsule_card(name))
		if tier_switch_confirmed:
			zone.add_child(_label("Áp dụng từ trận tiếp theo.", 24, GOLD))
		zone.add_child(_action_button("LƯU TIẾN ĐỘ", _manual_save, "secondary", 205))
	var actions := HBoxContainer.new()
	actions.add_spacer(false)
	actions.add_child(_action_button("ĐÓNG", _show.bind(options_return), "primary", 155))
	box.add_child(actions)


func _add_window_mode_selector(container: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	container.add_child(row)
	var caption := _label("Chế độ màn hình", 22, PALE)
	caption.custom_minimum_size.x = 205
	row.add_child(caption)
	var selector := OptionButton.new()
	selector.name = "WindowMode"
	selector.custom_minimum_size = Vector2(300, 46)
	selector.add_theme_font_size_override("font_size", 20)
	selector.add_item("Cửa sổ")
	selector.add_item("Toàn màn hình")
	selector.select(1 if window_mode == "fullscreen" else 0)
	selector.item_selected.connect(_set_window_mode)
	row.add_child(selector)


func _load_display_settings() -> void:
	if FileAccess.file_exists(display_settings_path):
		var file := FileAccess.open(display_settings_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary and parsed.get("window_mode") in ["windowed", "fullscreen"]:
				window_mode = parsed["window_mode"]
	_apply_window_mode()


func _set_window_mode(index: int) -> void:
	if index not in [0, 1]:
		return
	window_mode = "fullscreen" if index == 1 else "windowed"
	_apply_window_mode()
	var file := FileAccess.open(display_settings_path, FileAccess.WRITE)
	if file == null:
		push_error("Không lưu được thiết lập hiển thị")
		return
	file.store_string(JSON.stringify({"window_mode": window_mode}))


func _apply_window_mode() -> void:
	var game_window := get_window()
	game_window.mode = Window.MODE_FULLSCREEN if window_mode == "fullscreen" else Window.MODE_WINDOWED
	if window_mode == "windowed":
		game_window.borderless = false


func _add_audio_slider(container: VBoxContainer, bus_name: String) -> void:
	var captions := {"Master": "Âm lượng tổng", "Music": "Nhạc", "SFX": "Hiệu ứng"}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	container.add_child(row)
	var caption := _label(captions[bus_name], 22, PALE)
	caption.custom_minimum_size.x = 205
	row.add_child(caption)
	var slider := HSlider.new()
	slider.name = "Audio%s" % bus_name
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = audio_levels[bus_name]
	slider.custom_minimum_size = Vector2(340, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "%s: %d%%" % [captions[bus_name], int(slider.value)]
	row.add_child(slider)
	var percentage := _label("%d%%" % int(slider.value), 22, GOLD)
	percentage.custom_minimum_size.x = 68
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percentage)
	slider.value_changed.connect(_set_audio_level.bind(bus_name, percentage))


func _ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var bus_index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_index, bus_name)
			AudioServer.set_bus_send(bus_index, &"Master")


func _load_audio_settings() -> void:
	if FileAccess.file_exists(audio_settings_path):
		var file := FileAccess.open(audio_settings_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for bus_name in audio_levels.keys():
					var saved_value: Variant = parsed.get(bus_name)
					if saved_value is int or saved_value is float:
						if is_finite(float(saved_value)):
							audio_levels[bus_name] = clampi(int(saved_value), 0, 100)
	for bus_name in audio_levels.keys():
		_apply_audio_level(bus_name)


func _set_audio_level(value: float, bus_name: String, percentage: Label) -> void:
	audio_levels[bus_name] = clampi(int(value), 0, 100)
	percentage.text = "%d%%" % audio_levels[bus_name]
	_apply_audio_level(bus_name)
	var file := FileAccess.open(audio_settings_path, FileAccess.WRITE)
	if file == null:
		push_error("Không lưu được thiết lập âm thanh")
		return
	file.store_string(JSON.stringify(audio_levels))


func _apply_audio_level(bus_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var level: int = audio_levels[bus_name]
	AudioServer.set_bus_mute(bus_index, level == 0)
	if level > 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(level) / 100.0))


func _change_tier(name: String) -> void:
	if tier == "Nightmare" or name == "Nightmare":
		return
	tier = name
	tier_switch_confirmed = true
	_show("options")


func _manual_save() -> void:
	saved_checkpoint = options_return
	_save_campaign()
	_show("options")


func _save_campaign() -> void:
	var data := {"version": 1, "checkpoint": saved_checkpoint, "map_index": map_index, "tier": tier, "pool": pool, "upgrades": upgrades, "item_loadout": item_loadout, "gold": gold, "rewarded_maps": rewarded_maps, "rewarded_factions": rewarded_factions, "dead_ids": dead_ids, "viewed_bond": viewed_bond, "support_points": support_points}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Không lưu được chiến dịch demo")
		return
	file.store_string(JSON.stringify(data))


func _load_campaign() -> void:
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		return
	var restored: Dictionary = parsed
	map_index = clampi(int(restored.get("map_index", 0)), 0, battle.battle_data["maps"].size())
	tier = str(restored.get("tier", "Normal"))
	if not flow_data["difficulty"].has(tier):
		tier = "Normal"
	pool = maxi(0, int(restored.get("pool", 0)))
	upgrades = restored.get("upgrades", {})
	item_loadout = restored.get("item_loadout", {})
	gold = maxi(0, int(restored.get("gold", 0)))
	rewarded_maps.clear()
	for rewarded in restored.get("rewarded_maps", []):
		rewarded_maps.append(str(rewarded))
	rewarded_factions.clear()
	for rewarded in restored.get("rewarded_factions", []):
		rewarded_factions.append(str(rewarded))
	dead_ids.clear()
	for id in restored.get("dead_ids", []):
		dead_ids.append(str(id))
	viewed_bond = bool(restored.get("viewed_bond", false))
	support_points = maxi(2, int(restored.get("support_points", 5 if viewed_bond else 2)))
	selected_ids.clear()
	saved_checkpoint = str(restored.get("checkpoint", "prep"))
	_show("ending" if map_index >= battle.battle_data["maps"].size() else ("progression" if saved_checkpoint == "progression" else "prep"))


func _pause() -> void:
	_show("pause")


func _open_battle_items() -> void:
	if battle.selected < 0 or not battle.outcome.is_empty():
		battle.message = "Chọn một quân xanh trước khi dùng vật phẩm."
		battle.queue_redraw()
		return
	var unit: Dictionary = battle.units[battle.selected]
	if unit.get("side") != "player" or not bool(unit.get("controllable", true)) or bool(unit.get("acted", false)) or int(unit.get("hp", 0)) <= 0 or battle.item_carrier_id == str(unit.get("id", "")):
		battle.message = "Quân này không thể dùng vật phẩm lúc này."
		battle.queue_redraw()
		return
	if unit.get("carried_items", []).is_empty():
		battle.message = "Quân này không mang vật phẩm."
		battle.queue_redraw()
		return
	if unit.get("carried_items", []).size() == 1:
		if battle.use_consumable(0):
			_show("battle")
		return
	_show("battle_items")


func _render_battle_items() -> void:
	if battle.selected < 0:
		_show("battle")
		return
	var unit: Dictionary = battle.units[battle.selected]
	var help_text := "Chọn một vật phẩm để dùng. Dùng vật phẩm sẽ kết thúc hành động."
	if str(battle.message).begins_with("HP đã đầy"):
		help_text = str(battle.message)
	var box := _modal_shell("VẬT PHẨM", str(unit["name"]), help_text, 560)
	var carried: Array = unit.get("carried_items", [])
	if carried.is_empty():
		box.add_child(_label("Không có vật phẩm mang theo.", 18, MUTED))
	for slot in carried.size():
		var item: Dictionary = battle.battle_data.get("items", {}).get(str(carried[slot]), {})
		var caption := str(item.get("name", carried[slot]))
		if item.get("type") == "Buff":
			caption += " · %s +%d / %d lượt" % [str(item.get("buff_stat", "")).to_upper(), int(item.get("buff_amount", 0)), int(item.get("buff_duration", 0))]
		elif item.get("type") == "Heal":
			caption += " · hồi %d HP" % int(item.get("heal_value", 0))
		box.add_child(_pause_button(caption, _use_battle_item.bind(slot)))
	box.add_child(_action_button("HỦY · VỀ HÀNH ĐỘNG", _show.bind("action_menu"), "secondary", 270))


func _use_battle_item(slot: int) -> void:
	if battle.use_consumable(slot):
		_show("battle")
	else:
		_show("battle_items")


func _open_trade() -> void:
	if battle.selected < 0 or not battle.outcome.is_empty():
		battle.message = "Chọn một quân xanh trước khi trao đổi."
		battle.queue_redraw()
		return
	var targets := _trade_targets()
	if targets.is_empty():
		battle.message = "Cần đồng đội sống đứng kề bên; mỗi quân chỉ trao đổi một lần mỗi lượt."
		battle.queue_redraw()
		return
	_show("trade_targets")


func _trade_targets() -> Array[int]:
	var targets: Array[int] = []
	for i in battle.units.size():
		if battle.can_trade(i):
			targets.append(i)
	return targets


func _render_trade_targets() -> void:
	var box := _modal_shell("TRAO ĐỔI", "Chọn đồng đội", "Chỉ quân đứng cạnh mới có thể trao đổi; hành động của quân đang chọn vẫn còn.", 600)
	for target in _trade_targets():
		var unit: Dictionary = battle.units[target]
		var names: Array[String] = []
		for item_id in unit.get("carried_items", []):
			names.append(_item_name(str(item_id)))
		box.add_child(_pause_button("%s · %s" % [str(unit["name"]), ", ".join(PackedStringArray(names)) if not names.is_empty() else "không mang đồ"], _choose_trade_target.bind(target)))
	box.add_child(_action_button("HỦY · VỀ HÀNH ĐỘNG", _show.bind("action_menu"), "secondary", 270))


func _choose_trade_target(target: int) -> void:
	if not battle.can_trade(target):
		_show("action_menu")
		return
	trade_target = target
	trade_own_slot = 0 if not battle.units[battle.selected].get("carried_items", []).is_empty() else -1
	trade_target_slot = 0 if not battle.units[target].get("carried_items", []).is_empty() else -1
	_show("trade_offer")


func _trade_slot_text(unit: Dictionary, slot: int) -> String:
	if slot < 0:
		return "Không đưa món nào"
	var carried: Array = unit.get("carried_items", [])
	return _item_name(str(carried[slot])) if slot < carried.size() else "Không đưa món nào"


func _render_trade_offer() -> void:
	if not battle.can_trade(trade_target):
		_show("action_menu")
		return
	var own: Dictionary = battle.units[battle.selected]
	var target: Dictionary = battle.units[trade_target]
	var box := _modal_shell("TRAO ĐỔI", "%s ↔ %s" % [str(own["name"]), str(target["name"])], "Chọn tối đa một món từ mỗi bên; bấm xác nhận để trao đổi.", 640)
	if own.get("carried_items", []).size() == 2:
		box.add_child(_pause_button("%s đưa: %s  ↻" % [str(own["name"]), _trade_slot_text(own, trade_own_slot)], _cycle_trade_slot.bind(true)))
	else:
		box.add_child(_label("%s đưa: %s" % [str(own["name"]), _trade_slot_text(own, trade_own_slot)], 18, PALE))
	if target.get("carried_items", []).size() == 2:
		box.add_child(_pause_button("%s đưa: %s  ↻" % [str(target["name"]), _trade_slot_text(target, trade_target_slot)], _cycle_trade_slot.bind(false)))
	else:
		box.add_child(_label("%s đưa: %s" % [str(target["name"]), _trade_slot_text(target, trade_target_slot)], 18, PALE))
	var own_after: Array[String] = []
	for i in own.get("carried_items", []).size():
		if i != trade_own_slot:
			own_after.append(_item_name(str(own["carried_items"][i])))
	if trade_target_slot >= 0:
		own_after.append(_trade_slot_text(target, trade_target_slot))
	var target_after: Array[String] = []
	for i in target.get("carried_items", []).size():
		if i != trade_target_slot:
			target_after.append(_item_name(str(target["carried_items"][i])))
	if trade_own_slot >= 0:
		target_after.append(_trade_slot_text(own, trade_own_slot))
	box.add_child(_label("SAU TRAO ĐỔI\n%s: %s\n%s: %s" % [str(own["name"]), ", ".join(PackedStringArray(own_after)) if not own_after.is_empty() else "Trống", str(target["name"]), ", ".join(PackedStringArray(target_after)) if not target_after.is_empty() else "Trống"], 16, MUTED))
	var valid := own_after.size() <= 2 and target_after.size() <= 2
	box.add_child(_action_button("XÁC NHẬN TRAO ĐỔI", _commit_trade, "primary", 280, not valid))
	box.add_child(_action_button("← CHỌN ĐỒNG ĐỘI", _show.bind("trade_targets"), "secondary", 250))


func _cycle_trade_slot(own_side: bool) -> void:
	var unit: Dictionary = battle.units[battle.selected if own_side else trade_target]
	var count: int = unit.get("carried_items", []).size()
	if own_side:
		trade_own_slot = (trade_own_slot + 2) % (count + 1) - 1
	else:
		trade_target_slot = (trade_target_slot + 2) % (count + 1) - 1
	_show("trade_offer")


func _commit_trade() -> void:
	if battle.trade_items(trade_target, trade_own_slot, trade_target_slot):
		_show("action_menu")
	else:
		_show("trade_targets")


func _render_pause() -> void:
	var box := _modal_shell("TRẬN ĐẤU TẠM DỪNG", "Tạm dừng", str(battle.map_data.get("objective_text", "")), 510)
	box.add_child(_pause_button("Tiếp tục trận", _show.bind("battle")))
	box.add_child(_pause_button("Tùy chọn", _open_options.bind("pause")))
	box.add_child(_pause_button("Xem Đội Hình", _show.bind("squad_list")))
	box.add_child(_pause_button("Rời trận", _show.bind("leave_confirm")))


func _battle_squad() -> Array[Dictionary]:
	var squad: Array[Dictionary] = []
	for unit in battle.units:
		if str(unit.get("side", "")) == "player" and bool(unit.get("controllable", true)):
			squad.append(unit)
	return squad


func _battle_unit(id: String) -> Dictionary:
	for unit in _battle_squad():
		if str(unit.get("id", "")) == id:
			return unit
	return {}


func _battle_unit_status(unit: Dictionary) -> String:
	if int(unit.get("hp", 0)) > 0:
		return ""
	return "Đã chết" if bool(battle.battle_data.get("difficulty", {}).get("permadeath", false)) else "Gục ngã"


func _render_squad_list() -> void:
	var box := _layout("Đội hình trong trận", "Xem thông tin quân đã triển khai. Trận đấu vẫn tạm dừng.")
	box.add_child(_eyebrow("ĐỒNG ĐỘI · %s" % str(battle.map_data.get("title", ""))))
	for unit in _battle_squad():
		var id := str(unit["id"])
		var status := _battle_unit_status(unit)
		var caption := "%s   %s · %s     HP %d / %d" % [_unit_symbol(id), str(unit["name"]), str(unit["class"]), int(unit["hp"]), int(unit["max_hp"])]
		if not status.is_empty():
			caption += "     · " + status
		var row := _action_button(caption, _open_squad_detail.bind(id), "secondary", 760)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 64
		if status == "Đã chết":
			for state in ["normal", "hover", "pressed"]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color(0.13, 0.15, 0.16, 0.95)
				style.border_color = Color(0.42, 0.46, 0.46, 0.7)
				style.set_border_width_all(1)
				style.set_content_margin_all(12)
				row.add_theme_stylebox_override(state, style)
			row.add_theme_color_override("font_color", MUTED.darkened(0.25))
			row.add_theme_color_override("font_hover_color", MUTED)
		box.add_child(row)
	box.add_child(_action_button("← VỀ TẠM DỪNG", _show.bind("pause"), "secondary", 260))


func _open_squad_detail(id: String) -> void:
	selected_battle_unit = id
	_show("squad_detail")


func _render_squad_detail() -> void:
	var unit := _battle_unit(selected_battle_unit)
	if unit.is_empty():
		_show("squad_list")
		return
	var status := _battle_unit_status(unit)
	var heading := str(unit["name"]) + (" · " + status if not status.is_empty() else "")
	var box := _layout(heading, "%s · Thông tin trong trận" % str(unit["class"]))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	box.add_child(columns)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 7)
	stats.add_child(_eyebrow("CHỈ SỐ"))
	stats.add_child(_label("HP     %d / %d" % [int(unit["hp"]), int(unit["max_hp"])], 22))
	for stat in ["str", "mag", "skill", "speed", "luck", "def", "res"]:
		stats.add_child(_label("%-6s  %d" % [stat.to_upper(), int(unit.get(stat, 0))], 20))
	columns.add_child(_panel(stats, Vector2(380, 0)))
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 12)
	details.add_child(_eyebrow("LIÊN KẾT"))
	var bonds: Array[String] = []
	for pair in battle.map_data.get("bonds", []):
		var partner_id := ""
		if str(pair.get("a", "")) == selected_battle_unit:
			partner_id = str(pair.get("b", ""))
		elif str(pair.get("b", "")) == selected_battle_unit:
			partner_id = str(pair.get("a", ""))
		if not partner_id.is_empty():
			var partner := _battle_unit(partner_id)
			if not partner.is_empty() and int(partner.get("hp", 0)) > 0 and int(unit["hp"]) > 0:
				bonds.append("%s · Hạng %d" % [str(partner["name"]), int(pair.get("level", 1))])
	details.add_child(_label("\n".join(PackedStringArray(bonds)) if not bonds.is_empty() else "Không có liên kết đang hoạt động.", 18, MUTED))
	details.add_child(_eyebrow("HIỆU ỨNG"))
	var buffs: Dictionary = unit.get("active_buffs", {})
	if buffs.is_empty():
		details.add_child(_label("Chưa có hiệu ứng.", 18, MUTED))
	else:
		for stat in buffs:
			var effect: Dictionary = buffs[stat]
			details.add_child(_label("%s +%d · còn %d lượt" % [str(stat), int(effect.get("amount", 0)), int(effect.get("turns_remaining", 0))], 18))
	details.add_child(_eyebrow("VẬT PHẨM MANG THEO"))
	var items: Array = unit.get("carried_items", [])
	var item_names := PackedStringArray()
	for item in items:
		item_names.append(str(battle.battle_data.get("items", {}).get(str(item), {}).get("name", str(item))))
	details.add_child(_label(", ".join(item_names) if not item_names.is_empty() else "Không có vật phẩm.", 18, MUTED))
	details.add_child(_eyebrow("ĐẶC ĐIỂM NHÂN VẬT"))
	details.add_child(_label("Đang cập nhật", 18, MUTED))
	columns.add_child(_panel(details, Vector2(580, 0)))
	box.add_child(_action_button("← QUAY LẠI", _show.bind("squad_list"), "secondary", 230))


func _pause_button(caption: String, action: Callable) -> Button:
	var item := _action_button(caption, action, "secondary", 330)
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 64
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.31, 0.46, 0.44, 0.10) if state == "hover" else Color.TRANSPARENT
		style.border_color = LINE
		style.border_width_bottom = 1
		style.content_margin_left = 8
		item.add_theme_stylebox_override(state, style)
	return item


func _render_leave_confirm() -> void:
	_modal("RỜI TRẬN", "Rời trận đấu?", "Tiến độ trong trận chưa được lưu. Bạn sẽ quay lại bước chuẩn bị trước trận.", "Rời trận", _leave_battle, "Ở lại trận", _show.bind("battle"))


func _leave_battle() -> void:
	gold = battle_start_gold
	_enter_prep()


func _open_rewind() -> void:
	_show("rewind")


func _render_rewind() -> void:
	var charges := "∞" if battle.rewind_unlimited else str(battle.rewind_charges)
	var box := _modal_shell("THỜI GIAN TRONG TRẬN", "Chọn mốc Rewind", "Lượt %d · Rewind còn: %s. Mỗi lần quay lại dùng một lượt, bất kể khoảng cách." % [battle.turn_number, charges], 880)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	box.add_child(columns)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 420
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	columns.add_child(list)
	var shown := 0
	for index in range(battle.snapshots.size() - 2, -1, -1):
		var snapshot: Dictionary = battle.snapshots[index]
		if snapshot["phase"] != "Player":
			continue
		list.add_child(_action_button("Mốc %d · Lượt %d" % [index, int(snapshot["turn"])], _rewind_to.bind(index), "secondary", 420, not battle.rewind_unlimited and battle.rewind_charges <= 0))
		shown += 1
		if shown >= 6:
			break
	if shown == 0:
		list.add_child(_label("Chưa có mốc có thể quay lại.", 17, MUTED))
	var detail := VBoxContainer.new()
	detail.add_child(_eyebrow("MỐC SẼ KHÔI PHỤC"))
	detail.add_child(_title("Trước hành động", 27))
	detail.add_child(_label("Chọn một mốc bên trái để trở về trạng thái đó. Các hành động về sau sẽ bị bỏ.", 16, MUTED))
	columns.add_child(_panel(detail, Vector2(365, 185)))
	box.add_child(_action_button("HỦY · TRỞ VỀ TRẬN", _show.bind("battle"), "secondary", 245))


func _rewind_to(index: int) -> void:
	if battle.rewind_to_boundary(index):
		_show("battle")


func _render_gameover() -> void:
	var box := _layout("Game Over", "Nhân vật chính đã ngã xuống. Trận đấu kết thúc ngay tại đây.")
	box.add_child(_eyebrow("HÀNH TRÌNH KẾT THÚC"))
	var actions := HBoxContainer.new()
	actions.add_child(_action_button("VỀ MENU", _show.bind("home"), "secondary", 185))
	actions.add_child(_action_button("TẢI LẠI TRƯỚC TRẬN →", _start_battle, "primary", 270))
	box.add_child(actions)


func _render_ending() -> void:
	var box := _layout("Hết sáu màn demo", "Các màn ví dụ đã hoàn thành. Nội dung chiến dịch đầy đủ đang được xây dựng.")
	var actions := HBoxContainer.new()
	actions.add_child(_action_button("ĐỘI HÌNH", _show.bind("progression"), "secondary", 185))
	actions.add_child(_action_button("XEM BOND", _show.bind("bond"), "secondary", 185))
	actions.add_child(_action_button("VỀ MENU", _show.bind("home"), "primary", 185))
	box.add_child(actions)


func _modal_shell(kicker: String, title: String, body: String, minimum_width: float = 600) -> VBoxContainer:
	var tint := ColorRect.new()
	tint.color = Color(0.02, 0.06, 0.08, 0.82)
	tint.mouse_filter = Control.MOUSE_FILTER_STOP
	page.add_child(tint)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(minimum_width - 48, 0)
	content.add_theme_constant_override("separation", 18)
	content.add_child(_eyebrow(kicker))
	content.add_child(_title(title, 47))
	if not body.is_empty():
		content.add_child(_label(body, 16, MUTED))
	var panel := _panel(content, Vector2(minimum_width, 0), true)
	center.add_child(panel)
	_modal_panel = panel
	_modal_panel_min_width = minimum_width
	return content


## Keep tall modal content inside the viewport and allow internal scrolling.
## Called from `_show()` after the caller's layout has settled.
func _clamp_modal_panel(panel: PanelContainer, minimum_width: float) -> void:
	if not is_instance_valid(panel) or panel.get_child_count() == 0:
		return
	var content := panel.get_child(0)
	# No buffer: several modals (e.g. the post-switch Difficulty zone at base
	# scale) are already hand-tuned to fit within a few px of the canvas edge.
	# Only engage the scroll fallback once the panel would actually exceed it.
	var max_panel_height: float = get_viewport_rect().size.y
	if panel.size.y <= max_panel_height:
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(minimum_width - 48, max_panel_height - 46.0)
	panel.remove_child(content)
	scroll.add_child(content)
	panel.add_child(scroll)


func _modal(kicker: String, title: String, body: String, accept_text: String, accept: Callable, cancel_text: String, cancel: Callable) -> void:
	var box := _modal_shell(kicker, title, body)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.add_spacer(false)
	actions.add_child(_action_button(cancel_text, cancel, "secondary", 165))
	actions.add_child(_action_button(accept_text, accept, "primary", 170))
	box.add_child(actions)
