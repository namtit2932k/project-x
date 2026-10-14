extends Resource
class_name ItemData
## Item definition (objective relics, consumables later). Adding an item is data-only.

@export var id: String = ""
@export var display_name: String = ""
## category: "objective" (retrieve/evacuate payload) | "consumable" (TBD)
@export var category: String = "objective"
@export var description: String = ""
@export var weight: int = 0                 # TBD with designer
@export var move_penalty: int = 0           # TBD with designer
