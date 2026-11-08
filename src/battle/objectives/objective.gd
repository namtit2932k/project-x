extends RefCounted
class_name ObjectiveBase
## Objective plugin interface. Each type implements evaluate()/on_event(); maps only declare
## {type, params} data. No per-chapter win/lose logic outside these plugins.

## evaluate returns {status: "win"|"lose"|"ongoing", progress: String}


## Optional hooks with sane defaults so the director can call them on any objective.
func evaluate(_state: BattleState) -> Dictionary:
	return {"status": "ongoing", "progress": "not implemented"}


## I18N: objective text in the current UI language (key = English source text, see
## data/i18n/strings.csv). Engine TranslationServer, so battle logic stays scene-free.
static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))


func describe() -> String:
	return "objective"


func identify() -> String:
	return "objective"


func on_event(_state: BattleState, _event_type: String, _data: Dictionary) -> void:
	pass

static func create(config: Dictionary) -> ObjectiveBase:
	var type := String(config.get("type", ""))
	var params: Dictionary = config.get("params", {})
	match type:
		"eliminate":
			return ObjectiveEliminate.new(params)
		"escort":
			return ObjectiveEscort.new(params)
		"escort_turns":
			return ObjectiveEscortTurns.new(params)
		"defend":
			return ObjectiveDefend.new(params)
		"retrieve":
			return ObjectiveRetrieve.new(params)
		"capture":
			return ObjectiveCapture.new(params)
		"evacuate":
			return ObjectiveEvacuate.new(params)
		_:
			push_error("ObjectiveFactory: unknown objective type '%s'" % type)
			return null
