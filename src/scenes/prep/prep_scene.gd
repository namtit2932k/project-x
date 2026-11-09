extends Control
class_name PrepScene
## Squad preparation (F-UI step 3, UI doc "Chuẩn bị ra trận"): left column = the mission and
## the squad picker, right column = a map preview with the objective markers; bottom row =
## Back, Shop (when the campaign has one) and Start battle; Options (display, sound, difficulty,
## save) top right.

signal deploy_confirmed(deploy: Dictionary)
signal back_pressed

var _chapter: Resource
var _checks: Dictionary = {}          # unit_id -> toggle Button (one row per deployable unit)
var _start_button: Button
var _count_label: Label = null
var _preview: MapPreview = null
var _row_text: Dictionary = {}        # unit_id -> row text without the check mark
var _dialog: Control = null


static func build(chapter: Resource) -> PrepScene:
	var scene := PrepScene.new()
	scene._chapter = chapter
	return scene


func _ready() -> void:
	UIBuilder.fill_screen(self)
	UIBuilder.background(self)
	var map := DataRegistry.get_map(String(_chapter.map_id))

	var title := UIBuilder.title(self, UIBuilder.t("Prepare for battle"), 44)
	title.position = Vector2(48, 24)
	var tag := UIBuilder.label(self, UIBuilder.t("BEFORE BATTLE · %s") % String(_chapter.display_name).to_upper(), 12)
	tag.add_theme_color_override("font_color", UITheme.ACCENT)
	tag.position = Vector2(48, 88)
	var mode := UIBuilder.label(self, UIBuilder.t("SQUAD / MISSION · %s") % UIBuilder.t(GameState.difficulty.capitalize()).to_upper(), 12)
	mode.add_theme_color_override("font_color", UITheme.ACCENT)
	mode.position = Vector2(820, 88)
	var options := UIBuilder.button(self, UIBuilder.t("OPTIONS"), 14)
	options.name = "OptionsButton"
	options.position = Vector2(1090, 76)
	options.size = Vector2(142, 38)
	options.pressed.connect(open_options)

	# Left column: mission + squad (UI doc: at least 695 x 390).
	var left := UIBuilder.panel(self, 48, 120, 695, 456)
	left.name = "MissionPanel"
	var lbox := UIBuilder.vbox(left, 6)
	_gold_caption(lbox, UIBuilder.t("MISSION"))
	var first := true
	for cfg in map.objectives:
		var obj := ObjectiveBase.create(cfg)
		if obj == null:
			continue
		if first:
			UIBuilder.title(lbox, UIBuilder.t(obj.identify().capitalize()), 28)
			first = false
		UIBuilder.label(lbox, obj.describe(), 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIBuilder.label(lbox, UIBuilder.t("Fail: protagonist down = game over."), 14)
	if int(map.turn_limit) > 0:
		UIBuilder.label(lbox, UIBuilder.t("Turn limit: %d") % int(map.turn_limit), 14)
	if _has_open_remnant(map):
		UIBuilder.label(lbox, UIBuilder.t("Note: limit your kills if you want to persuade the remnants."), 14)
	_gold_caption(lbox, UIBuilder.t("DEPLOY LIMIT %d · MAP %d × %d") % [int(_chapter.deploy_max), _map_width(map), map.terrain_rows.size()])
	lbox.add_child(HSeparator.new())
	var head := HBoxContainer.new()
	lbox.add_child(head)
	var squad_title := UIBuilder.title(head, UIBuilder.t("Choose your squad"), 22)
	squad_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label = UIBuilder.title(head, "", 22)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(655, 150)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lbox.add_child(scroll)
	var rows := UIBuilder.vbox(scroll, 6)
	rows.custom_minimum_size = Vector2(640, 0)
	for unit_id in _chapter.deployable_unit_ids:
		_add_row(rows, String(unit_id))
	var note := UIBuilder.label(lbox, UIBuilder.t("Units you do not pick stay with the squad."), 13)
	note.add_theme_color_override("font_color", UITheme.MUTED)

	# Right column: map preview (UI doc: 440 x 390).
	var right := UIBuilder.panel(self, 768, 120, 464, 456)
	right.name = "PreviewPanel"
	var rbox := UIBuilder.vbox(right, 8)
	_gold_caption(rbox, UIBuilder.t("MAP PREVIEW · %d × %d") % [_map_width(map), map.terrain_rows.size()])
	_preview = MapPreview.new()
	_preview.custom_minimum_size = Vector2(428, 340)
	rbox.add_child(_preview)
	_preview.setup(map, 0)
	var legend := UIBuilder.label(rbox, UIBuilder.t("● Your units   ○ Free tile   ● Enemies   ● NPCs"), 13)
	legend.add_theme_color_override("font_color", UITheme.MUTED)

	# Bottom row.
	var back := UIBuilder.button(self, UIBuilder.t("← BACK"), 15)
	back.position = Vector2(48, 604)
	back.size = Vector2(160, 46)
	back.pressed.connect(func() -> void: back_pressed.emit())
	if bool(DataRegistry.rule("shop_enabled", false)):
		var shop := UIBuilder.button(self, UIBuilder.t("SHOP"), 15)
		shop.name = "ShopButton"
		shop.position = Vector2(780, 604)
		shop.size = Vector2(200, 46)
		shop.pressed.connect(open_shop)
	_start_button = UIBuilder.button(self, UIBuilder.t("START BATTLE →"), 15)
	_start_button.position = Vector2(992, 604)
	_start_button.size = Vector2(240, 46)
	_start_button.add_theme_stylebox_override("normal", DifficultyScene._accent_box())
	_start_button.add_theme_color_override("font_color", UITheme.BG)
	_start_button.pressed.connect(_on_start)
	_enforce_count()


## One squad row (UI doc: at least 58 high): name, HP, move, "Required"; a toggle with a check.
func _add_row(parent: Control, unit_id: String) -> void:
	var ud := DataRegistry.get_unit(unit_id)
	var stats := UnitState.from_data(ud, Vector2i.ZERO, int(GameState.roster[unit_id].get("level", 1)))
	var locked := bool(ud.is_protagonist) or bool(ud.must_survive)
	var text := "%s   Lv %d\nHP %d · %s %d" % [ud.display_name, int(GameState.roster[unit_id].get("level", 1)), stats.max_hp, UIBuilder.t("Move"), stats.move_range]
	if locked:
		text += " · " + UIBuilder.t("Required")
	# F-CAS: a unit that fell on the last map (Hard / Nightmare) sits this one out.
	var unavailable: bool = not bool(GameState.roster[unit_id].alive) or GameState.is_resting(unit_id)
	if GameState.is_resting(unit_id):
		text += " · " + UIBuilder.t("resting this map")
	var row := Button.new()
	row.toggle_mode = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(640, 58)
	row.add_theme_font_size_override("font_size", 15)
	parent.add_child(row)
	_checks[unit_id] = row
	_row_text[unit_id] = text
	row.disabled = unavailable
	row.toggled.connect(func(_on: bool) -> void: _enforce_count())
	# Campaign-critical units (protagonist / must_survive) deploy locked (D02).
	if not unavailable and locked:
		row.button_pressed = true
		row.disabled = true
	_refresh_row(unit_id)


func _refresh_row(unit_id: String) -> void:
	var row: Button = _checks[unit_id]
	row.text = ("✓  " if row.button_pressed else "     ") + String(_row_text[unit_id])
	if row.button_pressed:
		row.add_theme_stylebox_override("disabled", DifficultyScene._selected_box())
		row.add_theme_stylebox_override("normal", DifficultyScene._selected_box())
	else:
		row.remove_theme_stylebox_override("disabled")
		row.remove_theme_stylebox_override("normal")


func _enforce_count() -> void:
	if _start_button == null:
		# Toggles fire while _ready is still building the screen; ignore those.
		return
	for unit_id in _checks:
		_refresh_row(unit_id)
	var count := _deployed_ids().size()
	_start_button.disabled = count == 0 or count > int(_chapter.deploy_max)
	_count_label.text = "%d / %d" % [count, int(_chapter.deploy_max)]
	if _preview != null:
		_preview.set_picked(count)


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


## UI doc: the shop opens from the prep screen (and the lobby), never from the main menu.
func open_shop() -> void:
	_close_dialog()
	_dialog = ShopDialog.new()
	add_child(_dialog)


func open_options() -> void:
	_close_dialog()
	_dialog = BetweenBattlesOptions.new()
	add_child(_dialog)


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


static func _gold_caption(parent: Control, text: String) -> void:
	UIBuilder.label(parent, text, 12).add_theme_color_override("font_color", UITheme.ACCENT)


static func _map_width(map: Resource) -> int:
	var w := 0
	for row in map.terrain_rows:
		w = maxi(w, String(row).length())
	return w


## N10 / F-FST: the kill warning shows while an engaged (not terminal) remnant faction is on the map.
static func _has_open_remnant(map: Resource) -> bool:
	var placements: Array = []
	placements.append_array(map.enemy_placements)
	placements.append_array(map.npc_placements)
	for p in placements:
		var ud := DataRegistry.get_unit(String(p.unit_id))
		if ud == null:
			continue
		var fid := String(p.get("faction_override", "")) if String(p.get("faction_override", "")) != "" else String(ud.faction_id)
		var fac := DataRegistry.get_faction(fid)
		if fac != null and String(fac.remnant_id) != "" and not GameState.is_faction_terminal(fid):
			return true
	return false
