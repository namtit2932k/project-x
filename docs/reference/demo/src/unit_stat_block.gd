class_name UnitStatBlock
extends RefCounted
## Core Combat's 10-field unit stat block (ADR-0006). Plain scalar `int`
## properties, never a packed array — avoids Godot 4.7's packed-array
## setter change entirely. Never store a live instance inside a Dictionary
## that crosses a snapshot/save boundary — call to_dict() first.

var hp: int = 0          # 15-60, authored max HP (current_HP tracked separately)
var str_stat: int = 0    # 0-30 — renamed from "Str" to avoid shadowing str()
var mag: int = 0         # 0-30
var skill: int = 0       # 0-30
var speed: int = 0       # 0-30
var luck: int = 0        # 0-30
var def: int = 0         # 0-30
var res: int = 0         # 0-30
var move: int = 0        # 4-7 — satisfies Battle/Map's move_stat
var base_vision: int = 0 # 3-6 — satisfies Battle/Map's base_vision


## Lossless conversion to the plain-Dictionary shape used at every system
## boundary (Rewind, Save/Progression). Never pass `self` across either.
func to_dict() -> Dictionary:
	return {
		"HP": hp, "Str": str_stat, "Mag": mag, "Skill": skill,
		"Speed": speed, "Luck": luck, "Def": def, "Res": res,
		"Move": move, "base_vision": base_vision,
	}


## Reconstructs a live instance from the plain-Dictionary shape.
static func from_dict(data: Dictionary) -> UnitStatBlock:
	var block := UnitStatBlock.new()
	block.hp = data["HP"]
	block.str_stat = data["Str"]
	block.mag = data["Mag"]
	block.skill = data["Skill"]
	block.speed = data["Speed"]
	block.luck = data["Luck"]
	block.def = data["Def"]
	block.res = data["Res"]
	block.move = data["Move"]
	block.base_vision = data["base_vision"]
	return block
