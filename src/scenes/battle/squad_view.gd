extends Control
class_name SquadView
## F-BUI Rule 13 (P-10): in-battle Squad View, opened from the pause menu. Two read-only
## levels: the deployed allies (fallen ones greyed), then one unit's detail - the 8 stats,
## current HP, active bond links, active buffs, items and a traits placeholder. Writes nothing.

signal closed

var state: BattleState = null
var _panel: Control = null


static func build(p_state: BattleState) -> SquadView:
	var view := SquadView.new()
	view.state = p_state
	return view


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	show_list()


## Level a: every deployed ally, fallen ones greyed and labelled.
func show_list() -> void:
	_clear()
	_panel = UIBuilder.modal(self)
	var box := UIBuilder.vbox(UIBuilder.modal_panel(_panel, 610, 140, 700, 760), 6)
	UIBuilder.label(box, UIBuilder.t("Squad"), 28)
	for u in allies(state):
		var line := "%s | Lv %d | HP %d/%d" % [u.display_name, u.level, u.hp, u.max_hp]
		if not u.alive:
			line += " | " + UIBuilder.t("Fallen")
		var btn := UIBuilder.button(box, line, 18)
		if not u.alive:
			btn.modulate = Color(0.6, 0.6, 0.6)
		var unit_id: String = u.id
		btn.pressed.connect(func() -> void: show_detail(unit_id))
	var close := UIBuilder.button(box, UIBuilder.t("Close"), 18)
	close.pressed.connect(_close)


## Level b: one unit's battle-scoped detail.
func show_detail(unit_id: String) -> void:
	_clear()
	var u: UnitState = state.units.get(unit_id, null)
	if u == null:
		show_list()
		return
	_panel = UIBuilder.modal(self)
	var box := UIBuilder.vbox(UIBuilder.modal_panel(_panel, 610, 140, 700, 760), 6)
	for line in detail_lines(state, u):
		UIBuilder.label(box, line, 18)
	var back := UIBuilder.button(box, UIBuilder.t("Back"), 18)
	back.pressed.connect(show_list)


## Deployed player units, the order they sit in the battle state.
static func allies(p_state: BattleState) -> Array:
	var out: Array = []
	for u in p_state.units.values():
		if u.side == "player":
			out.append(u)
	return out


## Plain text lines of the detail level (also what the test reads).
static func detail_lines(p_state: BattleState, u: UnitState) -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s | %s | Lv %d%s" % [u.display_name, u.class_id, u.level, (" | " + UIBuilder.t("Fallen")) if not u.alive else ""])
	lines.append(UIBuilder.t("HP %d/%d") % [u.hp, u.max_hp])
	lines.append("Str %d  Mag %d  Skill %d  Spd %d" % [u.power, u.magic, u.skill, u.speed])
	lines.append("Luck %d  Def %d  Res %d" % [u.luck, u.defense, u.resistance])
	var links: Array[String] = []
	for link in BondSystem.active_partners(p_state, u):
		links.append("%s (%s)" % [p_state.units[String(link["partner_id"])].display_name, String(link["rank"])])
	lines.append(UIBuilder.t("Active bonds: %s") % (", ".join(links) if not links.is_empty() else UIBuilder.t("none")))
	var buffs: Array[String] = []
	for field in u.active_buffs:
		var b: Dictionary = u.active_buffs[field]
		buffs.append(UIBuilder.t("%s +%d (%d turns)") % [String(field), int(b.get("amount", 0)), int(b.get("turns_remaining", 0))])
	lines.append(UIBuilder.t("Buffs: %s") % (", ".join(buffs) if not buffs.is_empty() else UIBuilder.t("none")))
	lines.append(UIBuilder.t("Items: %s") % (BattleScene.item_list_text(u.items) if not u.items.is_empty() else UIBuilder.t("none")))
	lines.append(UIBuilder.t("Traits: updating"))
	return lines


func _clear() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _close() -> void:
	closed.emit()
	queue_free()
