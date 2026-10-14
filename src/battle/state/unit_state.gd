extends RefCounted
class_name UnitState
## Per-battle mutable unit state. Built from UnitData + BattleClassData; mutated only by
## rules code (commands, resolver). Scenes never write into it.

var id: String = ""
var display_name: String = ""
var class_id: String = ""
var faction_id: String = ""
var is_protagonist: bool = false
var level: int = 1
var exp: int = 0

var pos: Vector2i = Vector2i.ZERO
var hp: int = 20
var max_hp: int = 20
var power: int = 0
var defense: int = 0
var resistance: int = 0
var skill: int = 0
var speed: int = 0
var crit_bonus: int = 0
var hit_bonus: int = 0
var move_range: int = 5
var attack_range_min: int = 1
var attack_range_max: int = 1
var move_type: String = "foot"           # foot | flying
var damage_type: String = "physical"     # physical | magic
var portrait: String = ""
var sprite: String = ""
var skill_ids: Array[String] = []

var alive: bool = true
var acted: bool = false                  # used its action this phase
var moved: bool = false                  # already moved this phase — one move per unit per phase (FE rule)
var carried_item: String = ""            # retrieve objective
var death_recorded: bool = false         # kill already counted by reconcile tracking


## Builds a per-battle unit from UnitDef (base_stats + growths) with ClassDef fallbacks.
## Growth math is a designer decision (TBD); per-level growths stay stored on the roster later.
static func from_data(unit_res: Resource, cell: Vector2i, level_override: int = -1) -> UnitState:
	var c := DataRegistry.get_battle_class(String(unit_res.class_id))
	var u := UnitState.new()
	u.id = String(unit_res.id)
	u.display_name = String(unit_res.display_name)
	u.class_id = String(unit_res.class_id)
	u.faction_id = String(unit_res.faction_id)
	u.is_protagonist = bool(unit_res.is_protagonist)
	u.level = level_override if level_override >= 0 else int(unit_res.level)
	u.portrait = String(unit_res.portrait)
	u.sprite = String(unit_res.sprite)
	for skill_key in unit_res.skill_ids:
		u.skill_ids.append(String(skill_key))

	u.max_hp = unit_res.base_stat("hp", int(c.max_hp))
	u.hp = u.max_hp
	u.power = unit_res.base_stat("atk", int(c.power))
	u.defense = unit_res.base_stat("def", int(c.defense))
	u.resistance = unit_res.base_stat("res", int(c.resistance))
	u.skill = unit_res.base_stat("skl", int(c.skill))
	u.speed = unit_res.base_stat("spd", int(c.speed))
	u.crit_bonus = unit_res.base_stat("crit", int(c.crit_bonus))
	u.hit_bonus = unit_res.base_stat("hit", int(c.hit_bonus))
	u.move_range = unit_res.base_stat("mov", int(c.move_range))
	# Attack range lives on ClassDef (weapon range); riders nu unit base stats when present.
	u.attack_range_min = c.attack_range_min
	u.attack_range_max = c.attack_range_max
	u.move_type = String(c.move_type)
	u.damage_type = String(c.damage_type)
	for skill_id in c.skill_ids:
		if skill_id not in u.skill_ids:
			u.skill_ids.append(String(skill_id))
	u.pos = cell
	return u


func stat(id: String) -> int:
	match id:
		"max_hp": return max_hp
		"power": return power
		"defense": return defense
		"resistance": return resistance
		"skill": return skill
		"speed": return speed
		"crit_bonus": return crit_bonus
		"hit_bonus": return hit_bonus
		"move_range": return move_range
	return 0


func take_damage(amount: int) -> void:
	hp = clampi(hp - amount, 0, max_hp)
	if hp == 0:
		alive = false


func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)
	if hp > 0:
		alive = true


func to_dict() -> Dictionary:
	return {
		"id": id, "pos": [pos.x, pos.y], "hp": hp, "max_hp": max_hp,
		"alive": alive, "acted": acted, "moved": moved, "exp": exp, "carried_item": carried_item,
		"death_recorded": death_recorded,
	}


func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	pos = Vector2i(d.get("pos", [pos.x, pos.y])[0], d.get("pos", [pos.x, pos.y])[1])
	max_hp = int(d.get("max_hp", max_hp))
	hp = int(d.get("hp", hp))
	alive = bool(d.get("alive", alive))
	acted = bool(d.get("acted", acted))
	moved = bool(d.get("moved", moved))
	exp = int(d.get("exp", exp))
	carried_item = String(d.get("carried_item", carried_item))
	death_recorded = bool(d.get("death_recorded", death_recorded))
