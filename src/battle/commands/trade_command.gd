extends RefCounted
class_name TradeCommand
## F-ITEM Trade (GDD Core Rule 3a): a Ready squad unit exchanges up to one item each with an
## adjacent living squad ally - swap, one-way gift (receiver needs a free slot) or nothing.
## Free action: does not end the turn; once per phase (has_traded).


static func check(state: BattleState, unit: UnitState, partner: UnitState, give_item: String, take_item: String) -> String:
	if not state.units.has(unit.id) or not unit.alive or unit.acted:
		return "Unit unavailable or already acted."
	if unit.side != "player" or partner == null or partner.side != "player" or not partner.alive or partner.id == unit.id:
		return "Trade needs a living squad ally."
	if unit.has_traded:
		return "Already traded this phase."
	if RangeHandler.manhattan(unit.pos, partner.pos) != 1:
		return "Partner must be adjacent."
	if give_item != "" and not unit.items.has(give_item):
		return "Item not carried."
	if take_item != "" and not partner.items.has(take_item):
		return "Partner does not carry that item."
	var slots := int(DataRegistry.rule("max_item_slots", 2))
	var unit_after := unit.items.size() - (1 if give_item != "" else 0) + (1 if take_item != "" else 0)
	var partner_after := partner.items.size() - (1 if take_item != "" else 0) + (1 if give_item != "" else 0)
	if unit_after > slots or partner_after > slots:
		return "No free item slot."
	return ""


static func apply(state: BattleState, unit: UnitState, partner: UnitState, give_item: String, take_item: String) -> bool:
	if give_item != "":
		unit.items.erase(give_item)
	if take_item != "":
		partner.items.erase(take_item)
	if give_item != "":
		partner.items.append(give_item)
	if take_item != "":
		unit.items.append(take_item)
	unit.has_traded = true
	return true
