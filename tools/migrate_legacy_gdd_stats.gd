extends SceneTree
## tools/migrate_legacy_gdd_stats.gd — F1.4 one-off migration (rerunnable):
## rewrites the 12 roster classes and their units onto the GDD stat table
## (DEMO_PARITY_PLAN.md Phụ lục C, approved GDD first draft numbers).
##
## Run: godot --headless --path . -s res://tools/migrate_legacy_gdd_stats.gd
##
## Behavior:
##   classes: max_hp/power/defense/resistance/skill/speed set from the table; move from
##     the table's Move* column (only for the 12 classes); weapon_id + damage_type from
##     class_weapons.json / weapons.json (Magician + Magic Swordsman become magic).
##   units: base_stats rewritten to the GDD key set (hp,str,mag,skill,speed,move,luck,
##     def,res) mirroring the class table; growths keys keep the legacy names the level-up
##     engine (D08) already consumes (hp/atk/def/res/skl/spd).
##   Rebels and scenario classes/units are untouched (they are not in the table and stay
##     on the legacy key set through the UnitData alias).

const CLASSES_DIR := "res://data/classes"
const UNITS_DIR := "res://data/units"

## Phụ lục C: id postfix of class tres -> [hp, str, mag, skill, speed, move, luck, def, res]
const TABLE := {
	"class_swordsman": [32, 11, 2, 10, 9, 5, 8, 7, 4],
	"class_knight": [38, 10, 1, 6, 5, 6, 5, 14, 6],
	"class_lumberjack": [34, 15, 0, 5, 6, 4, 4, 9, 3],
	"class_lancer": [30, 10, 1, 8, 11, 5, 6, 8, 4],
	"class_gunner": [26, 8, 1, 13, 10, 5, 7, 5, 5],
	"class_wyvern_knight": [34, 12, 1, 7, 9, 7, 5, 10, 5],
	"class_beastman": [29, 10, 2, 11, 12, 6, 9, 6, 5],
	"class_magic_user": [24, 2, 13, 9, 8, 5, 6, 3, 9],
	"class_bard": [25, 4, 6, 12, 10, 5, 11, 4, 7],
	"class_healer": [26, 2, 12, 8, 7, 5, 7, 4, 8],
	"class_magic_swordsman": [28, 7, 9, 9, 8, 5, 6, 6, 6],
	"class_assassin": [22, 7, 1, 14, 13, 6, 10, 3, 4],
}

## class id postfix per unit file (Appendix C rows mirror the class table values).
const UNIT_CLASS := {
	"unit_swordsman": "class_swordsman", "unit_knight": "class_knight",
	"unit_lancer": "class_lancer", "unit_gunner": "class_gunner",
	"unit_healer": "class_healer", "unit_magician": "class_magic_user",
	"unit_beastwoman": "class_beastman", "unit_bard": "class_bard",
	"unit_lumberjack": "class_lumberjack", "unit_wyvern_knight": "class_wyvern_knight",
	"unit_magic_swordsman": "class_magic_swordsman", "unit_assassin": "class_assassin",
}

const MAGIC_CLASSES := ["class_magic_user", "class_magic_swordsman"]

var errors: int = 0


func _init() -> void:
	var class_weapons := {
		"class_swordsman": "weapon_iron_sword",
		"class_knight": "weapon_steel_lance",
		"class_lumberjack": "weapon_battle_axe",
		"class_lancer": "weapon_iron_lance",
		"class_gunner": "weapon_hunting_rifle",
		"class_wyvern_knight": "weapon_wyvern_lance",
		"class_beastman": "weapon_claws",
		"class_magic_user": "weapon_fire_tome",
		"class_bard": "weapon_light_rapier",
		"class_healer": "weapon_healing_staff",
		"class_magic_swordsman": "weapon_spell_blade",
		"class_assassin": "weapon_twin_daggers",
	}
	for class_id in TABLE:
		_rewrite_class(class_id, class_weapons.get(class_id, ""))
	for unit_id in UNIT_CLASS:
		_rewrite_unit(unit_id)
	print("migrate_legacy_gdd_stats: done, %d errors" % errors)
	quit(1 if errors > 0 else 0)


func _save(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("migrate: cannot write " + path)
		errors += 1
		return
	f.store_string(text)


func _props_text(res: Resource) -> String:
	var lines: Array[String] = []
	var props := res.get_property_list()
	for p in props:
		var name := String(p.name)
		if name in ["script", "resource_name", "resource_path", "resource_local_to_scene",
				"resource_scene_unique_id", "metadata", "RefCounted", "Resource", "script_class"]:
			continue
		if name.begins_with("resource_"):
			continue
		var value: Variant = res.get(name)
		var type := typeof(value)
		match type:
			TYPE_NIL:
				continue
			TYPE_BOOL:
				lines.append("%s = %s" % [name, "true" if value else "false"])
			TYPE_INT:
				lines.append("%s = %s" % [name, str(value)])
			TYPE_FLOAT:
				lines.append("%s = %s" % [name, str(value)])
			TYPE_STRING:
				lines.append("%s = \"%s\"" % [name, str(value).replace("\"", "\\\"")])
			TYPE_ARRAY:
				lines.append("%s = %s" % [name, _array_text(value)])
			TYPE_DICTIONARY:
				lines.append("%s = %s" % [name, _dict_text(value)])
			_:
				printerr("migrate: unsupported type for %s.%s" % [res.id, name])
				errors += 1
	return "\n".join(lines)


func _array_text(arr: Array) -> String:
	if arr.is_empty():
		return "[]"
	var parts: Array[String] = []
	for e in arr:
		parts.append("\"%s\"" % str(e) if typeof(e) == TYPE_STRING else str(e))
	return "[" + ", ".join(parts) + "]"


func _dict_text(d: Dictionary) -> String:
	if d.is_empty():
		return "{}"
	var parts: Array[String] = []
	for k in d:
		var value: Variant = d[k]
		var rendered := "\"%s\"" % str(value) if typeof(value) == TYPE_STRING else str(value)
		parts.append("\n\"%s\": %s," % [str(k), rendered])
	return "{" + "".join(parts).trim_suffix(",") + "\n}"


func _write_resource(path: String, res: Resource, script_path: String, script_class: String) -> void:
	var header := "[gd_resource type=\"Resource\" script_class=\"%s\" load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]\n\n[resource]\nscript = ExtResource(\"1\")\n" % [script_class, script_path]
	_save(path, header + _props_text(res) + "\n")


func _rewrite_class(class_id: String, weapon_id: String) -> void:
	var path := "%s/%s.tres" % [CLASSES_DIR, class_id]
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if res == null:
		printerr("migrate: missing " + path)
		errors += 1
		return
	var row: Array = TABLE[class_id]
	res.set("max_hp", row[0])
	res.set("power", row[1])
	res.set("skill", row[3])
	res.set("speed", row[4])
	res.set("move_range", row[5])
	res.set("defense", row[7])
	res.set("resistance", row[8])
	# crit/hit bonuses come from weapons + skill in the GDD; legacy class floor values go.
	res.set("crit_bonus", 0)
	res.set("hit_bonus", 0)
	if weapon_id != "":
		res.set("weapon_id", weapon_id)
	res.set("damage_type", "magic" if class_id in MAGIC_CLASSES else "physical")
	_write_resource(path, res, "res://data/classes/class_data.gd", "BattleClassData")


## Rewrites base_stats to the GDD keys from the class table (units mirror their class).
func _rewrite_unit(unit_id: String) -> void:
	var path := "%s/%s.tres" % [UNITS_DIR, unit_id]
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if res == null:
		printerr("migrate: missing " + path)
		errors += 1
		return
	var class_path := "%s/%s.tres" % [CLASSES_DIR, String(UNIT_CLASS[unit_id])]
	var class_res: Resource = ResourceLoader.load(class_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if class_res == null:
		printerr("migrate: missing class for %s" % unit_id)
		errors += 1
		return
	var row: Array = TABLE[String(UNIT_CLASS[unit_id])]
	res.set("base_stats", {
		"hp": row[0], "str": row[1], "mag": row[2], "skill": row[3], "speed": row[4],
		"move": row[5], "luck": row[6], "def": row[7], "res": row[8],
	})
	# Growth keys stay legacy: the level-up engine (D08) maps hp/atk/def/res/skl/spd.
	res.set("growths", {"hp": 60, "atk": 50, "def": 40, "res": 30, "skl": 50, "spd": 50})
	_write_resource(path, res, "res://data/units/unit_data.gd", "UnitData")
