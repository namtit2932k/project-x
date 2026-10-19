extends Resource
class_name ItemData
## Item definition (T2.3): objective relics, consumables (Heal/Buff) and shop goods — data-only.
## Two vocabularies coexist until the old campaign data migrates:
##  - base data (old ch01): objective payload relics (category = "objective")
##  - GDD/demo layer: consumables (heal_value) and buff tonics (buff_*), plus shop price.
## Adding an item is data-only: drop a .tres in data/items.

@export var id: String = ""
@export var display_name: String = ""
## category: "objective" (retrieve/evacuate payload) | "consumable" (use-in-battle item)
@export var category: String = "objective"
@export var description: String = ""
@export var weight: int = 0                 # TBD with designer
@export var move_penalty: int = 0           # TBD with designer

## ---- consumable fields (used when category == "consumable") ----
## type: "Heal" (restores HP) | "Buff" (grants a temporary stat buff)
@export var type: String = "Heal"
## Heal amount restored on use (no Mag bonus; use works even at full HP and still consumes the item).
@export var heal_value: int = 0
## Buff fields; one buff per stat, reusing overwrites amount and turns, never stacks (GDD-Combat §9).
@export var buff_stat: String = ""
@export var buff_amount: int = 0
@export var buff_duration: int = 0          # turns; decremented once per own Ready->Acted cycle
## Shop price in gold (0 = not sold).
@export var price: int = 0


func is_consumable() -> bool:
	return category == "consumable"


func is_heal_item() -> bool:
	return is_consumable() and type == "Heal"


func is_buff_item() -> bool:
	return is_consumable() and type == "Buff"
