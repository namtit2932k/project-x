extends Resource
class_name UnitData
## UnitDef (nhân vật / địch / NPC) theo schema bàn giao. Trạng thái ván (level, exp, alive)
## nằm ở GameState.roster; file này chỉ là định nghĩa tĩnh, thay nội dung không cần sửa mã.

@export var id: String = ""
@export var display_name: String = ""
@export var class_id: String = ""
## phe: "physical" | "magic" | "enemy" | "npc" — vẽ điều khiển từ faction tĩnh, khớp FactionData id.
@export var faction_id: String = "neutral"
@export var portrait: String = ""        # assets/portraits/<...>.png (placeholder rỗng = chip màu)
@export var sprite: String = ""          # assets/sprites/<...>.png (placeholder rỗng)
@export var level: int = 1
## Chỉ số base theo schema: {hp, atk, def, res, skl, spd, mov, crit, hit}; rng lấy từ ClassDef.range.
@export var base_stats: Dictionary = {}
## Tăng trưởng theo level (TBD số cuối; skeleton chờ designer): {hp, atk, def, res, skl, spd}.
@export var growths: Dictionary = {}
@export var skill_ids: Array[String] = []
@export var is_protagonist: bool = false
## Units the campaign cannot lose (D02): protagonist and, for now, the Beastwoman main heroine.
## Death of any is_protagonist/must_survive unit ends the battle immediately.
@export var must_survive: bool = false
## Reconcile event key recorded when this unit of a remnant faction survives to the end (D03).
@export var reconcile_event_key: String = ""
@export var in_roster: bool = true
## Short description used in prep/camp UI (from Character.docx; placeholder text fine).
@export var bio: String = ""


## base_stats lookup with fallback to the class default so missing keys never crash.
func base_stat(key: String, fallback: int) -> int:
	if base_stats.has(key):
		return int(base_stats[key])
	return fallback
