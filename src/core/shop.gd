extends RefCounted
class_name Shop
## F-ITEM camp shop (GDD Gold/Shop Core Rules 3-5): a fixed catalog, immediate purchase into a
## living roster unit's free item slot, no selling back. Static rules over GameState.


## Catalog entries in order: [{item_id, item, price}] (rules_config.shop_catalog, price > 0).
static func catalog() -> Array:
	var out: Array = []
	for item_id in DataRegistry.rule("shop_catalog", []):
		var item := DataRegistry.get_item(String(item_id))
		if item != null and int(item.price) > 0:
			out.append({"item_id": String(item_id), "item": item, "price": int(item.price)})
	return out


static func price_of(item_id: String) -> int:
	for entry in catalog():
		if String(entry["item_id"]) == item_id:
			return int(entry["price"])
	return -1


## Living roster units with a free slot (AC-GS7 / AC-GS8).
static func eligible_units() -> Array[String]:
	var out: Array[String] = []
	var slots := int(DataRegistry.rule("max_item_slots", 2))
	for unit_id in GameState.roster:
		var entry: Dictionary = GameState.roster[unit_id]
		if bool(entry.get("alive", true)) and (entry.get("items", []) as Array).size() < slots:
			out.append(String(unit_id))
	return out


static func can_buy(item_id: String, unit_id: String = "") -> bool:
	var price := price_of(item_id)
	if price < 0 or GameState.gold < price:
		return false
	return unit_id == "" or unit_id in eligible_units()


## Pays and puts the item into the unit's free slot; false (nothing changes) when not allowed.
static func buy(item_id: String, unit_id: String) -> bool:
	if not can_buy(item_id, unit_id):
		return false
	GameState.gold -= price_of(item_id)
	var items: Array = GameState.roster[unit_id].get("items", [])
	items.append(item_id)
	GameState.roster[unit_id]["items"] = items
	return true
