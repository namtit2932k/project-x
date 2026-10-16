extends Resource
class_name RulesConfig
## Designer-tunable numeric rules (schema theo bảng交接: công thức, địa hình, rewind, thương vong).
## Mọi con số chưa chốt nằm đây — không hardcode. Thay gameplay phổi thay từ file này.

## ------------------------------------------------------------ combat
## Chọn công thức sát thương; mặc định "atk_minus_def". Thêm công thức = thêm nhánh trong CombatResolver.
@export var damage_formula_id: String = "atk_minus_def"
## Cách xử lý số lẻ: "floor" | "round" | "ceil" (edge case đã nhắc trong docs/ch Tech).
@export var rounding: String = "floor"

@export var damage_flat: int = 0                          # sai số ngẫu nhiên trên damage
@export var min_damage: int = 0
@export var hit_base: int = 100
@export var hit_variance: int = 10
@export var crit_base: int = 5
@export var crit_multiplier: float = 2.0
@export var double_attack_speed_gap: int = 5
@export var hit_scale_skill: int = 3
@export var hit_scale_speed_avoid: int = 2
@export var crit_scale_skill: int = 2

## EXP (TBD final numbers, configurable).
@export var exp_gain_hit: int = 10
@export var exp_gain_kill: int = 30
@export var exp_gain_nonlethal_loss: int = 4

## ------------------------------------------------------------ terrain
## terrain_costs: địa hình × movement_type -> chi phí (bảng đúng schema交接; movement type từ ClassDef).
@export var terrain_costs: Dictionary = {
	"plain": {"foot": 1.0, "flying": 1.0},
	"road": {"foot": 1.0, "flying": 1.0},
	"forest": {"foot": 2.0, "flying": 1.0},
	"mountain": {"foot": 4.0, "flying": 1.0},
	"water": {"foot": 999.0, "flying": 1.0},
	"wall": {"foot": 999.0, "flying": 1.0},
}
## Bonuses per terrain (def/avoid) + blocked flags (flight truy cập được nhưng vẫn blocked cho foot).
@export var terrain_defs: Dictionary = {
	"plain": {"def_bonus": 0, "avoid_bonus": 0, "blocked": false},
	"road": {"def_bonus": 0, "avoid_bonus": 0, "blocked": false},
	"forest": {"def_bonus": 1, "avoid_bonus": 20, "blocked": false},
	"mountain": {"def_bonus": 2, "avoid_bonus": 30, "blocked": false},
	"water": {"def_bonus": 0, "avoid_bonus": 0, "blocked": true},
	"wall": {"def_bonus": 0, "avoid_bonus": 0, "blocked": true},
}
## Map ascii glyph -> terrain id.
@export var terrain_glyphs: Dictionary = {
	".": "plain", "r": "road", "f": "forest", "m": "mountain", "w": "water", "#": "wall",
}

## ------------------------------------------------------------ rewind
## Số lượt rewind mỗi trận theo độ khó: Story không giới hạn (-1); Normal 5; Hard 3; Nightmare 0.
@export var rewind_per_difficulty: Dictionary = {"story": -1, "normal": 5, "hard": 3, "nightmare": 0}
## Cách tính lượt rewind khi hoàn tác nhiều bước: "per_use" (1 lần = 1 thể thức về mốc chọn.
## "per_step", chờ designer chốt, sẽ đếm theo số command hoàn tác.
@export var rewind_count_mode: String = "per_use"

## ------------------------------------------------------------ casualties
## Thương vong theo độ khó (chờ chốt): "temp_injury" (về đội sau trận) | "permadeath" | "none".
@export var casualty_by_difficulty: Dictionary = {
	"story": "temp_injury", "normal": "temp_injury", "hard": "permadeath", "nightmare": "permadeath",
}

## ------------------------------------------------------------ battle outcome
## Nếu thắng và thua cùng kích hoạt, thứ tự xử lý chung: "win" | "lose". Map.result_priority override.
@export var win_lose_priority: String = "lose"

## Nhân vật chính chết là game over ngay, bất kể mục tiêu map.
@export var protagonist_death_loses: bool = true

## ------------------------------------------------------------ bond
## Damage-side bonus stat selector (D05): the adjacency bonus lands on this stat of the
## attacking unit; "power" adds to damage. Change to e.g. "hit" to move it to accuracy.
@export var bond_bonus_stat: String = "power"
## Bonus theo rank (designer đã chốt); tổng bonus kề ô tối đa +16 (ràng buộc test bằng test).
@export var bond_bonus_by_rank: Dictionary = {"C": 3, "B": 5, "A": 8, "S": 10}
@export var max_adjacent_bond_bonus: int = 16
@export var bond_point_limit_per_pair_per_map: int = 20
@export var bond_points_combat_action: int = 2
