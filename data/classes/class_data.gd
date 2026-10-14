extends Resource
class_name BattleClassData
## Class definition. Stats/formulas belong here; units reference classes by stable id.
## Adding a class is data-only: create a .tres in data/classes.

@export var id: String = ""
@export var display_name: String = ""
@export var faction_id: String = ""
## Movement ability: foot uses terrain costs/blocks, flying ignores them (still never ends on occupied tiles).
@export var move_type: String = "foot"    # foot | flying
@export var move_range: int = 5           # TBD final numbers with designer
@export var attack_range_min: int = 1
@export var attack_range_max: int = 1

## Base stats placeholder (TBD final roster/classes with designer).
@export var max_hp: int = 20
@export var power: int = 6
@export var defense: int = 4
@export var resistance: int = 2
@export var skill: int = 6
@export var speed: int = 6
@export var crit_bonus: int = 0
@export var hit_bonus: int = 0
## Attacks scale off defense (physical) or resistance (magic). Open decision with designer.
@export var damage_type: String = "physical"   # physical | magic

## Placeholder skill ids the class can use (empty = none yet; skills data-only too).
@export var skill_ids: Array[String] = []
