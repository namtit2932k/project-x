extends RefCounted
class_name UseItemCommand
## F-ITEM Use Item (GDD Core Rule 3 / 9 / 10, F-CC10, F-CC11): self only, consumes the chosen
## item and the unit's action. Heal items restore a fixed amount (even at full HP); Buff items
## set a temporary stat buff that overwrites any buff on the same stat. Pays no EXP.


static func check(state: BattleState, unit: UnitState, item_id: String) -> String:
	if not state.units.has(unit.id) or not unit.alive or unit.acted:
		return "Unit unavailable or already acted."
	if unit.side != "player":
		return "Only the squad uses items."
	if state.is_move_only_carrier(unit):
		return "Carrier may only move."
	if not unit.items.has(item_id):
		return "Item not carried."
	var item := DataRegistry.get_item(item_id)
	if item == null or not item.is_consumable():
		return "Item cannot be used."
	return ""


static func apply(state: BattleState, unit: UnitState, item_id: String) -> bool:
	var item := DataRegistry.get_item(item_id)
	if item == null:
		return false
	if item.is_heal_item():
		unit.heal(int(item.heal_value))
	elif item.is_buff_item():
		var field := String(UnitState.BUFF_FIELDS.get(String(item.buff_stat), String(item.buff_stat)))
		# Overwrite, never stack; "fresh" skips the countdown of the action that used it.
		unit.active_buffs[field] = {"amount": int(item.buff_amount), "turns_remaining": int(item.buff_duration), "fresh": true}
	unit.items.erase(item_id)   # removes one copy only
	unit.acted = true
	return true
