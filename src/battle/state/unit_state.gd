extends RefCounted
class_name UnitState
## Per-battle mutable unit state. Built from UnitData + BattleClassData; mutated only by
## rules code (commands, resolver). Scenes never write into it.

var id: String = ""
## Template id this instance was built from (F2): unit data lookups go through template_id
## while id stays unique per battle instance.
var template_id: String = ""
var display_name: String = ""
var class_id: String = ""
var faction_id: String = ""
## Control side: "player" | "enemy" | "npc". Faction stays as story/reconcile identity
## (a mixed squad keeps its lore faction but all its units act on the player side).
var side: String = "enemy"
## Campaign-critical flag (D02): copied from UnitData; read via BattleState.critical_units().
var must_survive: bool = false
## Reconcile event key on survival (D03), copied from UnitData.
var reconcile_event_key: String = ""
var is_protagonist: bool = false
var level: int = 1
var exp: int = 0
var level_ups_recorded: int = 0

var pos: Vector2i = Vector2i.ZERO
var hp: int = 20
var max_hp: int = 20
var power: int = 0
var magic: int = 0                       # GDD stat mag (F1.2); consumed by weapon scaling in W3
var defense: int = 0
var resistance: int = 0
var skill: int = 0
var speed: int = 0
var luck: int = 0                        # GDD stat luck (F1.2)
var crit_bonus: int = 0
var hit_bonus: int = 0
var move_range: int = 5
var base_vision: int = 4                 # D-B2 placeholder default; real fog math is W6
## Weapon resolved from the class (GDD); combat formulas consume it in W3.
var weapon_id: String = ""
## Optional AI preference, resolved from the template to this instance id at setup (F2.2).
var priority_target_id: String = ""
var attack_range_min: int = 1
var attack_range_max: int = 1
var move_type: String = "foot"           # foot | flying
var damage_type: String = "physical"     # physical | magic
var portrait: String = ""
var sprite: String = ""
var skill_ids: Array[String] = []
## Growth table copy from UnitData (D08 level-ups roll per-stat with the battle RNG).
var growths: Dictionary = {}
## Campaign stat bonus carried via the roster (D08): {stat_id: gained}. Live stats already
## include these values; from_data re-applies the roster's share on every battle.
var stat_bonus: Dictionary = {}

var alive: bool = true
var acted: bool = false                  # used its action this phase
var moved: bool = false                  # already moved this phase — one move per unit per phase (FE rule)
var carried_item: String = ""            # retrieve objective
var death_recorded: bool = false         # kill already counted by reconcile tracking


## Builds a per-battle unit from UnitDef (base_stats + growths) with ClassDef fallbacks.
## Growth math is a designer decision (TBD); per-level growths stay stored on the roster later.
## instance_id is the per-battle key (F2): empty = the template id itself (player roster units).
static func from_data(unit_res: Resource, cell: Vector2i, level_override: int = -1, instance_id: String = "") -> UnitState:
	var c := DataRegistry.get_battle_class(String(unit_res.class_id))
	var u := UnitState.new()
	u.id = instance_id if instance_id != "" else String(unit_res.id)
	u.template_id = String(unit_res.id)
	u.display_name = String(unit_res.display_name)
	u.class_id = String(unit_res.class_id)
	u.faction_id = String(unit_res.faction_id)
	u.is_protagonist = bool(unit_res.is_protagonist)
	u.must_survive = bool(unit_res.must_survive)
	u.reconcile_event_key = String(unit_res.reconcile_event_key)
	u.level = level_override if level_override >= 0 else int(unit_res.level)
	u.portrait = String(unit_res.portrait)
	u.sprite = String(unit_res.sprite)
	for skill_key in unit_res.skill_ids:
		u.skill_ids.append(String(skill_key))

	# D08: roster-carried stat bonus applies to the base stats of every battle.
	var roster_entry: Dictionary = GameState.roster.get(String(unit_res.id), {})
	var bonus: Dictionary = roster_entry.get("stat_bonus", {})
	u.stat_bonus = bonus.duplicate()
	# A roster unit carries its half-earned exp into the battle (D08): level-ups always
	# whole batches, so the merge above writes the remainder back as the new starting exp.
	u.exp = int(roster_entry.get("exp", 0))
	for stat_id in unit_res.growths:
		u.growths[String(stat_id)] = int(unit_res.growths[stat_id])

	u.max_hp = unit_res.base_stat("hp", int(c.max_hp))
	u.hp = u.max_hp
	# Atk reads both key sets through the UnitData alias (F1.1): str for GDD units, atk for legacy.
	u.power = unit_res.base_stat("atk", int(c.power))
	u.magic = unit_res.base_stat("mag", 0)
	u.defense = unit_res.base_stat("def", int(c.defense))
	u.resistance = unit_res.base_stat("res", int(c.resistance))
	u.skill = unit_res.base_stat("skl", int(c.skill))
	u.speed = unit_res.base_stat("spd", int(c.speed))
	u.luck = unit_res.base_stat("luck", 0)
	# crit/hit exist only on legacy data; GDD units fall back to the class placeholder.
	u.crit_bonus = unit_res.base_stat("crit", int(c.crit_bonus))
	u.hit_bonus = unit_res.base_stat("hit", int(c.hit_bonus))
	u.move_range = unit_res.base_stat("mov", int(c.move_range))
	u.base_vision = int(unit_res.base_vision) if int(unit_res.base_vision) > 0 \
			else int(DataRegistry.rule("base_vision_default", 4))
	# Weapon comes from the class def (GDD class_weapons table); formulas consume it in W3.
	u.weapon_id = String(c.weapon_id)
	u.priority_target_id = String(unit_res.priority_target_id)
	# Attack range lives on ClassDef (weapon range); riders nu unit base stats when present.
	u.attack_range_min = c.attack_range_min
	u.attack_range_max = c.attack_range_max
	u.move_type = String(c.move_type)
	u.damage_type = String(c.damage_type)
	for skill_id in c.skill_ids:
		if skill_id not in u.skill_ids:
			u.skill_ids.append(String(skill_id))
	u.pos = cell
	u.apply_stat_bonus(bonus)
	return u


## Applies the roster-carried bonus replay at battle setup (D08 stat bonus on base stats).
func apply_stat_bonus(bonus: Dictionary) -> void:
	for stat_id in bonus:
		apply_stat_gain(String(stat_id), int(bonus[stat_id]))


## Adds a growth-stat gain to both the live value and the recorded stat_bonus (level-ups).
func apply_stat_gain(stat_id: String, amount: int) -> void:
	match stat_id:
		"hp":
			max_hp += amount
			hp += amount
		"atk":
			power += amount
		"def":
			defense += amount
		"res":
			resistance += amount
		"skl":
			skill += amount
		"spd":
			speed += amount
		_:
			return
	stat_bonus[stat_id] = int(stat_bonus.get(stat_id, 0)) + amount
	level_ups_recorded += 1


func stat(id: String) -> int:
	match id:
		"max_hp": return max_hp
		"power": return power
		"magic": return magic
		"defense": return defense
		"resistance": return resistance
		"skill": return skill
		"speed": return speed
		"luck": return luck
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
		"id": id, "template_id": template_id, "side": side, "pos": [pos.x, pos.y], "hp": hp, "max_hp": max_hp,
		"alive": alive, "acted": acted, "moved": moved, "exp": exp, "carried_item": carried_item,
		"death_recorded": death_recorded, "must_survive": must_survive, "reconcile_event_key": reconcile_event_key,
		"level": level, "stat_bonus": stat_bonus.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	template_id = String(d.get("template_id", template_id))
	side = String(d.get("side", side))
	must_survive = bool(d.get("must_survive", must_survive))
	reconcile_event_key = String(d.get("reconcile_event_key", reconcile_event_key))
	pos = Vector2i(d.get("pos", [pos.x, pos.y])[0], d.get("pos", [pos.x, pos.y])[1])
	level = int(d.get("level", level))
	stat_bonus = d.get("stat_bonus", {}).duplicate()
	max_hp = int(d.get("max_hp", max_hp))
	hp = int(d.get("hp", hp))
	alive = bool(d.get("alive", alive))
	acted = bool(d.get("acted", acted))
	moved = bool(d.get("moved", moved))
	exp = int(d.get("exp", exp))
	carried_item = String(d.get("carried_item", carried_item))
	death_recorded = bool(d.get("death_recorded", death_recorded))
