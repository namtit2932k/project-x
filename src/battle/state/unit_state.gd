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
## Growth rates in percent (F-EXP): the class table from the GDD, or UnitData.growths as a
## fallback when the class has none. Level-ups roll each entry once with the battle RNG.
var growths: Dictionary = {}
## Level-up stat gains earned in THIS battle only: {stat_id: gained}. The roster keeps the
## campaign total (replayed into the live stats by from_data); CampaignMerge adds this delta.
var stat_bonus: Dictionary = {}

## F-PAS: class passive (key of rules_config.passive_catalog) and whether the unit may Attack
## or counterattack at all (false for the GDD Bard and for Heal/None weapons).
var passive_id: String = ""
var can_attack: bool = true
## F-CC11 debuffs on this unit: {field: {"amount": int, "turns_remaining": int}}, field names
## as in stat() ("defense"...). Read through eff(); counted down per own Ready->Acted.
var active_debuffs: Dictionary = {}
## survive_once used this battle (Wyvern Knight) and the Magician's phase-start burst flag.
var miracle_used: bool = false
var fragile_circle_ready: bool = false
## F-ITEM: carried consumables (item ids, max rules max_item_slots), the once-per-phase Trade
## flag, and item buffs {field: {amount, turns_remaining, fresh}} read through eff().
var items: Array = []
var has_traded: bool = false
var active_buffs: Dictionary = {}
## F-AI: the unit's AI profile (StandardAggressive / Raider / ProtectPersuade), the state its
## last Enemy-Phase evaluation chose (counters reuse it for the Restraint Rule; default Hold),
## and its deploy tile (Flee tie-break toward the nearest map edge).
var ai_profile: String = ""
var ai_context: String = "hold"
var start_pos: Vector2i = Vector2i.ZERO
## Item buff_stat keys (GDD names) -> stat() field names.
const BUFF_FIELDS := {"str": "power", "mag": "magic", "skill": "skill", "speed": "speed", "luck": "luck", "def": "defense", "res": "resistance"}

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

	# The roster-carried stat bonus (campaign total) is replayed onto the base stats below;
	# it is NOT copied into u.stat_bonus, which only tracks this battle's gains.
	var roster_entry: Dictionary = GameState.roster.get(String(unit_res.id), {})
	var bonus: Dictionary = roster_entry.get("stat_bonus", {})
	# A roster unit carries its half-earned exp into the battle; the merge writes the
	# remainder back as the next starting exp.
	u.exp = int(roster_entry.get("exp", 0))
	# F-ITEM: roster units bring their campaign items; others their data-authored ones.
	var item_source: Array = roster_entry.get("items", unit_res.carried_items) if not roster_entry.is_empty() else unit_res.carried_items
	for item_id in item_source:
		u.items.append(String(item_id))
	# F-EXP: growth is per class in the GDD; the unit table is a legacy fallback.
	var growth_source: Dictionary = c.growths if not c.growths.is_empty() else unit_res.growths
	for stat_id in growth_source:
		u.growths[String(stat_id)] = int(growth_source[stat_id])

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
	u.ai_profile = String(unit_res.ai_profile) if "ai_profile" in unit_res else ""
	u.start_pos = cell
	# Attack range lives on ClassDef (weapon range); riders nu unit base stats when present.
	u.attack_range_min = c.attack_range_min
	u.attack_range_max = c.attack_range_max
	u.move_type = String(c.move_type)
	u.damage_type = String(c.damage_type)
	u.passive_id = String(c.passive_id)
	# GDD: Bard-like classes never attack; a Heal/None weapon cannot attack either. No weapon
	# record (legacy enemy classes) keeps the old behaviour: attacks with its stats.
	var weapon: Resource = DataRegistry.get_weapon(u.weapon_id) if u.weapon_id != "" else null
	u.can_attack = bool(c.can_attack) and (weapon == null or weapon.can_attack())
	for skill_id in c.skill_ids:
		if skill_id not in u.skill_ids:
			u.skill_ids.append(String(skill_id))
	u.pos = cell
	u.apply_stat_bonus(bonus)
	return u


## Replays the roster-carried campaign bonus onto the live stats at battle setup. Not a
## level-up: nothing is recorded into stat_bonus (that would count the bonus again on merge).
func apply_stat_bonus(bonus: Dictionary) -> void:
	for stat_id in bonus:
		_add_to_stat(String(stat_id), int(bonus[stat_id]))


## Level-up gain (F-CC14): raises the live stat and records it in this battle's stat_bonus.
## An HP gain raises current HP by the same amount (GDD Core Rule 12c).
func apply_stat_gain(stat_id: String, amount: int) -> void:
	if not _add_to_stat(stat_id, amount):
		return
	stat_bonus[stat_id] = int(stat_bonus.get(stat_id, 0)) + amount
	level_ups_recorded += 1


## Live value of a growth stat, for either key set (legacy atk/skl/spd or GDD str/skill/speed).
## -1 for an unknown key.
func growth_stat_value(stat_id: String) -> int:
	match stat_id:
		"hp": return max_hp
		"atk", "str": return power
		"mag": return magic
		"skl", "skill": return skill
		"spd", "speed": return speed
		"luck": return luck
		"def": return defense
		"res": return resistance
	return -1


## Adds amount to the live stat behind a growth key (both key sets); false if unknown.
func _add_to_stat(stat_id: String, amount: int) -> bool:
	match stat_id:
		"hp":
			max_hp += amount
			hp += amount
		"atk", "str":
			power += amount
		"mag":
			magic += amount
		"skl", "skill":
			skill += amount
		"spd", "speed":
			speed += amount
		"luck":
			luck += amount
		"def":
			defense += amount
		"res":
			resistance += amount
		_:
			return false
	return true


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


## Effective value of a combat stat (F-CC11): stat() minus an active debuff on it.
func eff(field: String) -> int:
	var value := stat(field)
	if active_debuffs.has(field):
		var entry: Dictionary = active_debuffs[field]
		if int(entry.get("turns_remaining", 0)) > 0:
			value -= int(entry.get("amount", 0))
	# F-ITEM / F-CC11: an item buff adds on top (and stacks with bond bonuses elsewhere).
	if active_buffs.has(field):
		var buff: Dictionary = active_buffs[field]
		if int(buff.get("turns_remaining", 0)) > 0:
			value += int(buff.get("amount", 0))
	return value


## F-DIFF (GDD F-DS2): enemy stat block scaled once at deploy — floor(stat * multiplier) on
## Str/Mag/Skill/Speed/Def/Res; HP and Luck are never scaled.
## F-ELV (Fire Emblem style): an enemy above level 1 gains floor((level - 1) x growth / 100)
## per stat from its class growth table - fixed average gains, no dice. HP raises max and current.
func apply_enemy_levels() -> void:
	if level <= 1:
		return
	var gains := {}
	for key in growths:
		gains[String(key)] = int(floor((level - 1) * int(growths[key]) / 100.0))
	max_hp += int(gains.get("hp", 0))
	hp = max_hp
	power += int(gains.get("str", gains.get("atk", 0)))
	magic += int(gains.get("mag", 0))
	skill += int(gains.get("skill", gains.get("skl", 0)))
	speed += int(gains.get("speed", gains.get("spd", 0)))
	luck += int(gains.get("luck", 0))
	defense += int(gains.get("def", 0))
	resistance += int(gains.get("res", 0))


func apply_enemy_scaling(multiplier: float) -> void:
	power = int(floor(power * multiplier))
	magic = int(floor(magic * multiplier))
	skill = int(floor(skill * multiplier))
	speed = int(floor(speed * multiplier))
	defense = int(floor(defense * multiplier))
	resistance = int(floor(resistance * multiplier))


## Max weapon range right now: catalog value plus extended_range when its condition holds.
func attack_max() -> int:
	return attack_range_max + PassiveSystem.extra_range(self)


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
		# F-EXP: live combat stats too, so rewinding past a level-up undoes its stat gains.
		"power": power, "magic": magic, "defense": defense, "resistance": resistance,
		"skill": skill, "speed": speed, "luck": luck,
		# F-PAS battle-scoped passive state (rewind restores it).
		"active_debuffs": active_debuffs.duplicate(true), "miracle_used": miracle_used,
		"fragile_circle_ready": fragile_circle_ready,
		"items": items.duplicate(), "has_traded": has_traded, "active_buffs": active_buffs.duplicate(true),
		"ai_context": ai_context,
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
	power = int(d.get("power", power))
	magic = int(d.get("magic", magic))
	defense = int(d.get("defense", defense))
	resistance = int(d.get("resistance", resistance))
	skill = int(d.get("skill", skill))
	speed = int(d.get("speed", speed))
	luck = int(d.get("luck", luck))
	active_debuffs = (d.get("active_debuffs", {}) as Dictionary).duplicate(true)
	miracle_used = bool(d.get("miracle_used", miracle_used))
	fragile_circle_ready = bool(d.get("fragile_circle_ready", fragile_circle_ready))
	items = (d.get("items", items) as Array).duplicate()
	has_traded = bool(d.get("has_traded", has_traded))
	active_buffs = (d.get("active_buffs", {}) as Dictionary).duplicate(true)
	ai_context = String(d.get("ai_context", ai_context))
	max_hp = int(d.get("max_hp", max_hp))
	hp = int(d.get("hp", hp))
	alive = bool(d.get("alive", alive))
	acted = bool(d.get("acted", acted))
	moved = bool(d.get("moved", moved))
	exp = int(d.get("exp", exp))
	carried_item = String(d.get("carried_item", carried_item))
	death_recorded = bool(d.get("death_recorded", death_recorded))
