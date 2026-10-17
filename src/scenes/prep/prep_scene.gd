extends Control
class_name PrepScene
## Squad preparation: choose deployed units (within deploy_max), see objectives, start the battle.

signal deploy_confirmed(deploy: Dictionary)

var _chapter: Resource
var _checks: Dictionary = {}          # unit_id -> CheckButton
var _start_button: Button


static func build(chapter: Resource) -> PrepScene:
	var scene := PrepScene.new()
	scene._chapter = chapter
	return scene


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIBuilder.label(self, "%s  -  preparation" % _chapter.display_name, 36)
	title.position = Vector2(60, 40)

	# Objectives panel (primary + fail conditions).
	var obj_panel := UIBuilder.panel(self, 60, 130, 500, 300)
	var obj_box := UIBuilder.vbox(obj_panel, 8)
	UIBuilder.label(obj_box, "Objectives", 22)
	var map := DataRegistry.get_map(String(_chapter.map_id))
	for cfg in map.objectives:
		var obj := ObjectiveBase.create(cfg)
		if obj != null:
			UIBuilder.label(obj_box, "- " + obj.describe(), 16)
	UIBuilder.label(obj_box, "Fail: protagonist down = game over.", 16)
	if int(map.turn_limit) > 0:
		UIBuilder.label(obj_box, "Turn limit: %d" % int(map.turn_limit), 16)
	# N10: when the map carries a remnant faction, warn about kills without the hidden number.
	var remnant_found := false
	var placements: Array = []
	placements.append_array(map.enemy_placements)
	placements.append_array(map.npc_placements)
	for p in placements:
		var ud := DataRegistry.get_unit(String(p.unit_id))
		if ud == null:
			continue
		var fid := String(p.get("faction_override", "")) if String(p.get("faction_override", "")) != "" else String(ud.faction_id)
		var fac := DataRegistry.get_faction(fid)
		if fac != null and String(fac.remnant_id) != "":
			remnant_found = true
	if remnant_found:
		UIBuilder.label(obj_box, "Note: limit your kills if you want to persuade the remnants.", 16)

	# Deploy roster panel.
	var list_panel := UIBuilder.panel(self, 600, 130, 760, 500)
	var list_box := UIBuilder.vbox(list_panel, 6)
	UIBuilder.label(list_box, "Deploy (max %d)" % int(_chapter.deploy_max), 22)
	var locked_any := false
	for unit_id in _chapter.deployable_unit_ids:
		var ud := DataRegistry.get_unit(String(unit_id))
		var entry := HBoxContainer.new()
		list_box.add_child(entry)
		var check := CheckButton.new()
		check.text = "%s  (Lv %d, %s)" % [ud.display_name, GameState.roster[unit_id].level, ud.class_id]
		entry.add_child(check)
		_checks[unit_id] = check
		var dead: bool = not bool(GameState.roster[unit_id].alive)
		check.disabled = dead
		check.toggled.connect(func(_on: bool) -> void: _enforce_count())
		# Campaign-critical units (protagonist / must_survive) deploy locked (D02).
		if not dead and (bool(ud.is_protagonist) or bool(ud.must_survive)):
			check.button_pressed = true
			check.disabled = true
			locked_any = true

	_start_button = UIBuilder.button(self, "Start battle", 24)
	_start_button.position = Vector2(600, 680)
	_start_button.size = Vector2(220, 56)
	_start_button.pressed.connect(_on_start)
	_enforce_count()


func _enforce_count() -> void:
	if _start_button == null:
		# Checkbox toggles fire while _ready is still building the screen; ignore those.
		return
	var count := _deployed_ids().size()
	_start_button.disabled = count == 0 or count > int(_chapter.deploy_max)


func _deployed_ids() -> Array:
	var out: Array = []
	for unit_id in _checks:
		if _checks[unit_id].button_pressed:
			out.append(unit_id)
	return out


func _on_start() -> void:
	var map := DataRegistry.get_map(String(_chapter.map_id))
	var deploy := {}
	var i := 0
	for unit_id in _deployed_ids():
		if i < map.deploy_cells.size():
			deploy[unit_id] = map.deploy_cells[i]
			i += 1
	deploy_confirmed.emit(deploy)
