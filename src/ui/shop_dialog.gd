extends Control
class_name ShopDialog
## F-ITEM shop as one reusable modal (F-UI step 3: opened from the prep screen and the camp).
## Two levels (GDD Gold/Shop States): catalog browsing, then the buyer; picking a buyer buys at
## once. Unaffordable entries stay listed but disabled. Rules live in Shop.

signal closed
signal purchased(item_id: String, unit_id: String)

var _panel: Control = null


func _ready() -> void:
	UIBuilder.fill_screen(self)
	show_catalog()


func show_catalog() -> void:
	_clear()
	_panel = UIBuilder.modal(self)
	var box := UIBuilder.vbox(UIBuilder.centered_modal_panel(_panel, 800, 560), 8)
	UIBuilder.title(box, UIBuilder.t("Shop - gold: %d") % GameState.gold, 30)
	for entry in Shop.catalog():
		var item_id := String(entry["item_id"])
		var btn := UIBuilder.button(box, UIBuilder.t("%s - %s - %d gold") % [BattleScene.item_name(item_id), item_effect_text(entry["item"]), int(entry["price"])], 16)
		btn.custom_minimum_size = Vector2(760, 46)
		btn.disabled = not Shop.can_buy(item_id)
		btn.pressed.connect(func() -> void: show_buyers(item_id))
	var close := UIBuilder.button(box, UIBuilder.t("Close"), 16)
	close.custom_minimum_size = Vector2(195, 46)
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free())


func show_buyers(item_id: String) -> void:
	_clear()
	_panel = UIBuilder.modal(self)
	var box := UIBuilder.vbox(UIBuilder.centered_modal_panel(_panel, 800, 560), 8)
	UIBuilder.title(box, UIBuilder.t("Buy %s for whom?") % BattleScene.item_name(item_id), 26)
	var units := Shop.eligible_units()
	if units.is_empty():
		UIBuilder.label(box, UIBuilder.t("No unit has a free item slot."), 16)
	for unit_id in units:
		var ud := DataRegistry.get_unit(unit_id)
		var count := (GameState.roster[unit_id].get("items", []) as Array).size()
		var btn := UIBuilder.button(box, UIBuilder.t("%s (%d/%d items)") % [ud.display_name if ud != null else unit_id, count, int(DataRegistry.rule("max_item_slots", 2))], 16)
		btn.custom_minimum_size = Vector2(760, 46)
		btn.pressed.connect(func() -> void:
			if Shop.buy(item_id, unit_id):
				purchased.emit(item_id, unit_id)
			show_catalog())
	var back := UIBuilder.button(box, UIBuilder.t("Cancel"), 16)
	back.custom_minimum_size = Vector2(195, 46)
	back.pressed.connect(show_catalog)


func _clear() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


static func item_effect_text(item: ItemData) -> String:
	if item == null:
		return ""
	if item.is_heal_item():
		return UIBuilder.t("restores %d HP") % int(item.heal_value)
	if item.is_buff_item():
		return UIBuilder.t("+%d %s for %d turns") % [int(item.buff_amount), String(item.buff_stat), int(item.buff_duration)]
	return ""
