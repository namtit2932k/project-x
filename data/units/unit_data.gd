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
## Chỉ số base. Lớp GDD dùng khóa mới {hp, str, mag, skill, speed, luck, def, res, move, base_vision};
## lớp cũ (ch01) dùng {hp, atk, def, res, skl, spd, mov, crit, hit}. Validator chấp nhận cả hai;
## khóa cũ được ánh xạ sang khóa mới ở độ kết xuất (GameState/UnitState), không trộn khóa trong file .tres.
@export var base_stats: Dictionary = {}
## Tăng trưởng theo level (D-A4: deprecated — GDD không có level-up; giữ skeleton chờ designer).
@export var growths: Dictionary = {}
## Tầm nhìn cơ bản cho fog of war (D-B2, placeholder 3–6; 0 = dùng lớp/faction mặc định).
@export var base_vision: int = 0
## AI profile (GDD-Combat §10): "" = mặc định theo side; StandardAggressive | Raider | ProtectPersuade.
## priority_target_id là mở rộng demo (D-B7): rỗng, chỉ thiết kế tạm cho mục tiêu ưu tiên.
@export var ai_profile: String = ""
@export var priority_target_id: String = ""
## false = exits, AI điều khiển (người đưa tin, dân thường); đủ nghĩa cùng side npc của repo.
@export var controllable: bool = true
## Vật phẩm mang theo trong trận (tối đa max_item_slots trong rules_config).
@export var carried_items: Array[String] = []
@export var skill_ids: Array[String] = []
@export var is_protagonist: bool = false
## Units the campaign cannot lose (D02): protagonist and, for now, the Beastwoman main heroine.
## Death of any is_protagonist/must_survive unit ends the battle immediately.
@export var must_survive: bool = false
## Reconcile event key recorded when this unit of a remnant faction survives to the end (D03).
@export var reconcile_event_key: String = ""
@export var in_roster: bool = true
## F4.2: campaign membership for the roster filter ("" = legacy/unassigned, "demo" = the
## demo parity campaign). Keeps demo roster data from merging into the old campaign.
@export var campaign_tag: String = ""
## Short description used in prep/camp UI (from Character.docx; placeholder text fine).
@export var bio: String = ""


## Alias table between the legacy stat keys and the GDD keys (D-A2/F1.1): either key set
## reads through, so a legacy unit (ch01) and a GDD unit (demo) share the same accessors.
const STAT_KEY_ALIASES := {
	"atk": "str", "str": "atk",
	"skl": "skill", "skill": "skl",
	"spd": "speed", "speed": "spd",
	"mov": "move", "move": "mov",
}

## base_stats lookup with fallback to the class default so missing keys never crash.
## Legacy keys read through the alias table (atk->str, skl->skill, spd->speed, mov->move);
## crit/hit have no GDD counterpart and only exist on legacy data.
func base_stat(key: String, fallback: int) -> int:
	if base_stats.has(key):
		return int(base_stats[key])
	if STAT_KEY_ALIASES.has(key) and base_stats.has(STAT_KEY_ALIASES[key]):
		return int(base_stats[STAT_KEY_ALIASES[key]])
	return fallback
