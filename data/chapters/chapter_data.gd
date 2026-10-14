extends Resource
class_name ChapterData
## Chapter definition: which map, which units can deploy, and which dialogue plays around it.

@export var id: String = ""
@export var order: int = 0
@export var display_name: String = ""
@export var map_id: String = ""
@export var deployable_unit_ids: Array[String] = []
@export var deploy_max: int = 6                    # TBD with designer
@export var story_dialogue_id: String = ""         # pre-battle story scene
@export var post_dialogue_id: String = ""          # post-battle scene reading outcomes
