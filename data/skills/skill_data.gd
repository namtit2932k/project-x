extends Resource
class_name SkillData
## Skill definition consumed by the skill command. Effects are data-driven; effect types are a
## closed set implemented in code (designer composes skills; new effect types come via code).

@export var id: String = ""
@export var display_name: String = ""
## effect types: "heal" | "encore" (Bard: refresh an adjacent ally that acted) | "damage_strike" (not live)
@export var effect_type: String = "heal"
@export var power: int = 10          # heal amount or strike bonus
@export var range_min: int = 1
@export var range_max: int = 1
@export var description: String = ""
