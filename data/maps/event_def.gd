extends Resource
class_name EventDef
## Skeleton schema for map events. Triggers/actions are a closed vocabulary (see
## tools/validate_data.gd); an executor engine is a next-step, maps ship empty arrays today.

const TRIGGERS := ["enter_zone", "leave_zone", "pickup", "unit_dead", "turn_start", "turn_end", "talk", "faction_change"]
const ACTIONS := ["spawn", "dialogue", "change_team", "set_flag", "win", "lose"]

@export var trigger: String = ""           # one of TRIGGERS
@export var conditions: Dictionary = {}   # e.g. {"zone": Rect2i(...), "unit_id": "..."}
@export var actions: Array = []           # e.g. [{"type": "dialogue", "dialogue_id": "dlg_x"}]


static func from_dict(d: Dictionary) -> EventDef:
	var e := EventDef.new()
	e.trigger = String(d.get("trigger", ""))
	e.conditions = d.get("conditions", {})
	for a in d.get("actions", []):
		e.actions.append(a)
	return e
