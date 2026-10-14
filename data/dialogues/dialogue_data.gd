extends Resource
class_name DialogueData
## Dialogue script playable by the reusable DialoguePlayer. New dialogue = new data, no new logic.

@export var id: String = ""
@export var display_name: String = ""
## Lines: {speaker: String, text: String}
@export var lines: Array[Dictionary] = []
