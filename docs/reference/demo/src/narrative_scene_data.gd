extends Resource
## Plain data input to NarrativeDialogueBox (ADR-0018). Owns no game state —
## the box reads it once via load_scene_data() and emits signals back out.
class_name NarrativeSceneData

## Each entry: {"speaker": String, "text": String, "scene": String (optional,
## backdrop mode key), "year": String (optional), "title": String (optional)}.
@export var lines: Array = []
@export var is_severance: bool = false
