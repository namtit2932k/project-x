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

## EXP (D08): only the player side earns; a full batch per level; level cap. Numbers TBD
## final, designer-tunable.
@export var exp_gain_hit: int = 10
@export var exp_gain_kill: int = 30
@export var exp_gain_nonlethal_loss: int = 4
@export var exp_per_level: int = 100
@export var level_cap: int = 20

## ------------------------------------------------------------ terrain
## terrain_costs: địa hình × movement_type -> chi phí (bảng đúng schema交接; movement type từ ClassDef).
@export var terrain_costs: Dictionary = {
	"plain": {"foot": 1.0, "flying": 1.0},
	"road": {"foot": 1.0, "flying": 1.0},
	"forest": {"foot": 2.0, "flying": 1.0},
	"mountain": {"foot": 4.0, "flying": 1.0},
	"hill": {"foot": 2.0, "flying": 1.0},
	"cover": {"foot": 1.0, "flying": 1.0},
	"hazard": {"foot": 1.0, "flying": 1.0},
	"village": {"foot": 1.0, "flying": 1.0},
	"water": {"foot": 999.0, "flying": 1.0},
	"wall": {"foot": 999.0, "flying": 1.0},
}
## Bonuses per terrain (def/avoid) + blocked flags (flight truy cập được nhưng vẫn blocked cho foot).
## GDD-Combat §5: terrain only feeds avoid (combat_modifier); def_bonus is legacy.
@export var terrain_defs: Dictionary = {
	"plain": {"def_bonus": 0, "avoid_bonus": 0, "blocked": false},
	"road": {"def_bonus": 0, "avoid_bonus": 0, "blocked": false},
	"forest": {"def_bonus": 1, "avoid_bonus": 20, "blocked": false},
	"hill": {"def_bonus": 0, "avoid_bonus": 5, "blocked": false},
	"cover": {"def_bonus": 0, "avoid_bonus": 20, "blocked": false},
	"hazard": {"def_bonus": 0, "avoid_bonus": 0, "blocked": false},
	"village": {"def_bonus": 0, "avoid_bonus": 0, "blocked": false},
	"mountain": {"def_bonus": 2, "avoid_bonus": 30, "blocked": false},
	"water": {"def_bonus": 0, "avoid_bonus": 0, "blocked": true},
	"wall": {"def_bonus": 0, "avoid_bonus": 0, "blocked": true},
}
## Map ascii glyph -> terrain id (T2.4: repo keeps its own glyphs and ADDS the GDD ones;
## demo converts `V`->`v` on import, `h` hill, `c` fort/cover, `x` hazard, `v` village).
@export var terrain_glyphs: Dictionary = {
	".": "plain", "r": "road", "f": "forest", "m": "mountain", "w": "water", "#": "wall",
	"h": "hill", "c": "cover", "x": "hazard", "v": "village",
}
## GDD-Map §3/§4 vision data per terrain: {stand, view, blocks_line_of_sight}
## (Phụ lục C placeholders; Hill blocks nothing per D-B2 default).
@export var terrain_vision: Dictionary = {
	"plain": {"stand": 0, "view": 0, "blocks_line_of_sight": false},
	"road": {"stand": 0, "view": 0, "blocks_line_of_sight": false},
	"forest": {"stand": -1, "view": -1, "blocks_line_of_sight": false},
	"hill": {"stand": 2, "view": -1, "blocks_line_of_sight": false},
	"cover": {"stand": 0, "view": 0, "blocks_line_of_sight": false},
	"hazard": {"stand": 0, "view": 0, "blocks_line_of_sight": false},
	"village": {"stand": 0, "view": 0, "blocks_line_of_sight": false},
	"mountain": {"stand": 2, "view": -1, "blocks_line_of_sight": false},
	"water": {"stand": 0, "view": 0, "blocks_line_of_sight": true},
	"wall": {"stand": 0, "view": 0, "blocks_line_of_sight": true},
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

## ------------------------------------------------------------ T2.6: numbers luật GDD/demo (data-only)
## Đánh thêm vì chênh lệnh Speed (GDD-Combat §5, F-CC7): chỉ một bên đủ điều kiện một exchange.
## Demo/GDD dùng 4; số cũ của lớp ch01 dùng double_attack_speed_gap.
@export var double_threshold: int = 4
## Số nguồn bonus bond kề cùng lúc (GDD-Combat §5, tối đa 4 đối tác; tổng vẫn chặn ở max_adjacent_bond_bonus).
@export var bond_stack_max: int = 4
## Vật phẩm tối đa mang theo mỗi unit (GDD-Combat §8).
@export var max_item_slots: int = 2
## HP color bands cho HUD (GDD-UI §5): xanh > hp_high_band, vàng trong [hp_mid_band, hp_high_band],
## đỏ < hp_mid_band; nhấp nháy dưới hp_blink_band; mọi ngưỡng là dữ liệu.
@export var hp_high_band: float = 0.66
@export var hp_mid_band: float = 0.33
@export var hp_blink_band: float = 0.25
## Nhân chỉ số địch khi Deploy theo độ khó: nhân Str/Mag/Skill/Speed/Def/Res, lấy phần nguyên xuống;
## KHÔNG nhân HP/Luck (GDD-Combat §5). Quyết định tạm theo Phụ lục D.
@export var enemy_stat_multiplier_by_difficulty: Dictionary = {
	"story": 1.0, "normal": 1.0, "hard": 1.08, "nightmare": 1.15,
}
## Restraint (C11) bật theo độ khó; Nightmare tắt (Phụ lục D, quyết định tạm).
@export var restraint_rule_active_by_difficulty: Dictionary = {
	"story": true, "normal": true, "hard": true, "nightmare": false,
}
## balance_profile mechanism (D-A1/T2.7): DataRegistry nạp data/<profile>/ classes/units/weapons/items/maps
## đè các id trùng của lớp gốc. "" = tắt overlay (chạy dữ liệu ch01 gốc nguyên vẹn).
@export var balance_profile: String = "demo"

## ------------------------------------------------------------ bond
## Damage-side bonus stat selector (D05): the adjacency bonus lands on this stat of the
## attacking unit; "power" adds to damage. Change to e.g. "hit" to move it to accuracy.
@export var bond_bonus_stat: String = "power"
## Bonus theo rank (designer đã chốt); tổng bonus kề ô tối đa +16 (ràng buộc test bằng test).
@export var bond_bonus_by_rank: Dictionary = {"C": 3, "B": 5, "A": 8, "S": 10}
@export var max_adjacent_bond_bonus: int = 16
@export var bond_point_limit_per_pair_per_map: int = 20
@export var bond_points_combat_action: int = 2
