extends Node
## T2.9 AC negative tests: every map-load checklist rule from Appendix E must REJECT a
## bad map with an explicit error message (load-blocking, never silently clamped).
## The validator instance is used purely for its strict-map checks; autoloads (DataRegistry)
## are live so unit/faction/item references resolve exactly like a real run.
## Run with: godot --headless --path . res://tests/test_validate_negative.tscn

var checks := 0
var failures := 0


func _ready() -> void:
	await run_all()
	print("\nvalidate negative: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: " + msg)
	else:
		print("ok: " + msg)


## A strictly valid base map fixture (same shape import_demo_data produces); per-case
## mutations turn one field bad and the checklist must reject it.
func _good_map() -> Resource:
	var m: Resource = load("res://data/maps/map_data.gd").new()
	m.id = "map_negative_case"
	m.display_name = "Negative test fixture"
	var rows: Array[String] = [".....", ".fff.", ".....", "....."]
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(4, 0)]
	m.terrain_rows = rows
	m.deploy_cells = cells
	m.deploy_tiles = cells
	m.map_deploy_cap = 2
	m.turn_par = 5
	m.objective_type = "Elimination"
	return m


## Error count from a dedicated validator instance so cases stay isolated.
func _rejects(name: String, mutate: Callable) -> void:
	var v: Node = load("res://tools/validate_data.gd").new()
	var m: Resource = _good_map()
	mutate.call(m)
	v._check_map_strict.call("map_negative_case", m)
	var rejected := int(v.errors) > 0
	v.free()  # keep the exit log clean (no resources in use at exit)
	ok(rejected, "rejects %s" % name)


func run_all() -> void:
	# --- deploy cap bounds (1..10, never above deploy tile count)
	_rejects("map_deploy_cap 0", func(m: Resource) -> void: m.map_deploy_cap = 0)
	_rejects("map_deploy_cap 11", func(m: Resource) -> void: m.map_deploy_cap = 11)
	_rejects("cap above deploy tiles", func(m: Resource) -> void: m.map_deploy_cap = 3)
	# --- turn_par mandatory / bound to turn_limit
	_rejects("missing turn_par", func(m: Resource) -> void: m.turn_par = 0)
	_rejects("turn_par above turn_limit", func(m: Resource) -> void:
		m.turn_limit = 4)
	# --- escort variants are exclusive and bound to turn_par
	_rejects("escort goal + turns together", func(m: Resource) -> void:
		m.objective_type = "Escort"
		m.escort_unit_id = "unit_demo_messenger"
		m.escort_goal = Vector2i(3, 3)
		m.escort_turns_required = 2)
	_rejects("escort with neither variant", func(m: Resource) -> void:
		m.objective_type = "Escort"
		m.escort_unit_id = "unit_demo_messenger")
	_rejects("escort turns above turn_par", func(m: Resource) -> void:
		m.objective_type = "Escort"
		m.escort_unit_id = "unit_demo_messenger"
		m.escort_turns_required = 6)
	_rejects("escort unknown unit", func(m: Resource) -> void:
		m.objective_type = "Escort"
		m.escort_unit_id = "unit_missing"
		m.escort_goal = Vector2i(3, 3))
	# --- protect zone in bounds, phases positive, turn_par covers them
	_rejects("protect zone out of bounds", func(m: Resource) -> void:
		m.objective_type = "Protect"
		m.protect_zone = Rect2i(3, 3, 5, 5)
		m.survive_enemy_phases = 2)
	_rejects("protect phases zero", func(m: Resource) -> void:
		m.objective_type = "Protect"
		m.protect_zone = Rect2i(1, 1, 1, 1)
		m.survive_enemy_phases = 0)
	_rejects("protect phases above turn_par", func(m: Resource) -> void:
		m.objective_type = "Protect"
		m.protect_zone = Rect2i(1, 1, 1, 1)
		m.survive_enemy_phases = 6)
	# --- retrieve tiles: declared, distinct
	_rejects("retrieve tiles missing", func(m: Resource) -> void:
		m.objective_type = "Retrieve")
	_rejects("retrieve tiles identical", func(m: Resource) -> void:
		m.objective_type = "Retrieve"
		m.item_tile = Vector2i(2, 2)
		m.return_tile = Vector2i(2, 2))
	# --- seize: control point present, phases positive and inside turn_par
	_rejects("seize point missing", func(m: Resource) -> void:
		m.objective_type = "Seize"
		m.hold_enemy_phases = 2)
	_rejects("seize phases zero", func(m: Resource) -> void:
		m.objective_type = "Seize"
		m.control_point = Vector2i(2, 2)
		m.hold_enemy_phases = 0)
	_rejects("seize phases above turn_par", func(m: Resource) -> void:
		m.objective_type = "Seize"
		m.control_point = Vector2i(2, 2)
		m.hold_enemy_phases = 6)
	# --- village rewards: exactly one of gold / existing item
	_rejects("village without reward", func(m: Resource) -> void:
		m.objective_type = "Elimination"
		var villages: Array[Dictionary] = [{"cell": Vector2i(2, 2)}]
		m.villages = villages)
	_rejects("village double reward", func(m: Resource) -> void:
		m.objective_type = "Elimination"
		var villages: Array[Dictionary] = [{"cell": Vector2i(2, 2), "gold_amount": 10, "item_id": "item_border_relic"}]
		m.villages = villages)
	_rejects("village unknown item", func(m: Resource) -> void:
		m.objective_type = "Elimination"
		var villages: Array[Dictionary] = [{"cell": Vector2i(2, 2), "item_id": "item_missing"}]
		m.villages = villages)
	# --- key unit must exist, faction must resolve
	_rejects("key_unit_id unknown", func(m: Resource) -> void:
		m.key_unit_id = "unit_missing")
	_rejects("faction_id unknown", func(m: Resource) -> void:
		m.faction = {"faction_id": "faction_missing"})
	# --- bond pairs must reference real units
	_rejects("bond pair unknown unit", func(m: Resource) -> void:
		var bonds: Array[Dictionary] = [{"a": "unit_demo_swordsman", "b": "unit_missing", "level": 1}]
		m.bonds = bonds)
	# --- objective vocabulary
	_rejects("unknown objective_type", func(m: Resource) -> void:
		m.objective_type = "Rampage")

	# The happy-path fixture must NOT trip the checklist.
	var v_ok: Node = load("res://tools/validate_data.gd").new()
	var m_ok: Resource = _good_map()
	v_ok._check_map_strict.call("map_negative_case", m_ok)
	var passed := int(v_ok.errors) == 0
	v_ok.free()
	ok(passed, "good map fixture passes the strict checklist")
