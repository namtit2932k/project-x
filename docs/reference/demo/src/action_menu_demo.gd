extends Control
## Minimal demo wiring BattleActionMenu to CoreCombat/UnitRoster for visual
## verification of Core Rule 11 (battle-ui-system.md) and Core Rule 3a
## (core-combat-system.md). Not part of the old src/battle_demo.gd prototype
## — that uses an unrelated ad-hoc data shape (BattleGrid/CombatRules) this
## session's ADR-driven classes do not share.

const UnitRosterScript = preload("res://src/unit_roster.gd")
const UnitStatBlockScript = preload("res://src/unit_stat_block.gd")
const CoreCombatScript = preload("res://src/core_combat.gd")
const WeaponItemScript = preload("res://src/weapon_item.gd")
const BattleActionMenuScene = preload("res://src/ui/battle_action_menu.tscn")

const TILE_SIZE := 64
const GRID_ORIGIN := Vector2(220, 160)

var roster: UnitRoster
var combat: CoreCombat
var weapon_item: WeaponItem
var menu: Control


## Demo-only placeholder world-to-screen projection — no real camera/tilemap
## is wired up in this minimal demo (see src/battle_map.gd for the real
## terrain layer). Exists so the menu's anchor_position genuinely tracks the
## acting unit's tile instead of a fixed point.
func _screen_position_for_tile(tile: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(tile.x, tile.y) * TILE_SIZE


func _ready() -> void:
	roster = UnitRosterScript.new()
	combat = CoreCombatScript.new()
	weapon_item = WeaponItemScript.new()
	weapon_item.load_weapon_catalog()
	weapon_item.load_item_catalog()
	weapon_item.load_class_weapons()

	var stats_a := UnitStatBlockScript.new()
	stats_a.hp = 28
	roster.add_player_unit("lancer", "Lance", "Lancer", "Physical Empire", stats_a)
	combat.set_position("lancer", Vector2i(0, 0))
	roster.unit_records["lancer"]["carried_items"] = ["Thuốc hồi máu"]

	var stats_b := UnitStatBlockScript.new()
	stats_b.hp = 24
	roster.add_player_unit("archer", "Ari", "Gunner", "Physical Empire", stats_b)
	combat.set_position("archer", Vector2i(0, 1))

	combat.set_position("enemy_grunt", Vector2i(1, 0))  # distance 1 from Lancer — within Iron Lance's [1,1] range

	menu = BattleActionMenuScene.instantiate()
	add_child(menu)
	menu.action_chosen.connect(_on_action_chosen)
	menu.trade_target_chosen.connect(_on_trade_target_chosen)
	menu.trade_cancelled.connect(_on_trade_cancelled)
	menu.cancelled.connect(_on_cancelled)

	_show_menu_for("lancer")


func _show_menu_for(unit_id: String) -> void:
	var unit_class: String = roster.get_unit_record(unit_id)["class"]
	var legal: Array[String] = combat.legal_actions(unit_id, roster, ["archer"], weapon_item, unit_class, ["enemy_grunt"])
	var anchor: Vector2 = _screen_position_for_tile(combat.position_of(unit_id))
	menu.show_for_unit(roster.get_unit_record(unit_id)["display_name"], legal, anchor)


func _on_action_chosen(action: String) -> void:
	if action == "Trade":
		_show_trade_targets("lancer")
	elif action == "Wait":
		combat.mark_acted("lancer")
		menu.hide_menu()


func _show_trade_targets(unit_id: String) -> void:
	var acting_items: Array = roster.get_unit_record(unit_id)["carried_items"]
	var targets: Array[Dictionary] = []
	for candidate_id in ["archer"]:
		if not combat.can_trade(unit_id, candidate_id, roster):
			continue
		var candidate_items: Array = roster.get_unit_record(candidate_id)["carried_items"]
		targets.append({
			"id": candidate_id,
			"label": roster.get_unit_record(candidate_id)["display_name"],
			"before": _item_summary(candidate_items),
			"after": _item_summary(acting_items),
		})
	var anchor: Vector2 = _screen_position_for_tile(combat.position_of(unit_id))
	menu.show_trade_targets(roster.get_unit_record(unit_id)["display_name"], targets, anchor)


func _item_summary(items: Array) -> String:
	return "(trống)" if items.is_empty() else str(items[0])


func _on_trade_target_chosen(target_id: String) -> void:
	combat.trade("lancer", target_id, roster)
	_show_menu_for("lancer")


func _on_trade_cancelled() -> void:
	_show_menu_for("lancer")


func _on_cancelled() -> void:
	# Core Rule 11: Escape on the main list re-opens movement / backs out of
	# the Action Menu entirely — no Move-reopening UI exists yet in this
	# minimal demo, so this just hides the menu.
	menu.hide_menu()
