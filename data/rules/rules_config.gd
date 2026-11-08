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
## F-CC + F-CC-FE (AGENTS.md): Accuracy = hit_base + skill*accuracy_skill_mult + luck*accuracy_luck_mult
## + hit_bonus + weapon_accuracy_mod + bond; Avoid = speed*avoid_speed_mult + luck*avoid_luck_mult
## + terrain_avoid + bond; Hit% = clamp(Accuracy - Avoid, 0, 100). One roll, no 2RN.
## hit_base stands in for Fire Emblem's per-weapon Hit (70–95); 70 is the designer's provisional value.
@export var hit_base: int = 70
@export var accuracy_skill_mult: float = 2.0
@export var accuracy_luck_mult: float = 0.5
@export var avoid_speed_mult: float = 2.0
## Fire Emblem: full Luck in Avoid (GDD had 0.5).
@export var avoid_luck_mult: float = 1.0
## Crit% = clamp(skill*crit_skill_mult + weapon_crit_mod + crit_bonus - defender.luck*crit_luck_mult + bond, 0, 100).
@export var crit_skill_mult: float = 0.5
## Fire Emblem: crit evade = full Luck (GDD had 0.5).
@export var crit_luck_mult: float = 1.0
## CritDamage = floor(Damage * crit_multiplier); Fire Emblem ×3 (GDD had 2.5).
@export var crit_multiplier: float = 3.0

## EXP (F-EXP, GDD core-combat Core Rule 12 / F-CC13): a player unit performing an Attack
## or a Heal earns this flat amount, hit or miss, kill or not. Nothing else pays EXP.
@export var exp_per_action: int = 25
## F-CC14: EXP per level (excess rolls into the next level) and the level cap (EXP at the
## cap is discarded, never banked).
@export var exp_per_level: int = 100
@export var level_cap: int = 20
## F-CC14 stat ceilings for level-up rolls (GDD Core Rule 1: HP 15–60, other stats 0–30);
## a successful roll on a stat already at its cap is wasted. GDD stat keys.
@export var stat_caps: Dictionary = {
	"hp": 60, "str": 30, "mag": 30, "skill": 30, "speed": 30, "luck": 30, "def": 30, "res": 30,
}
## Designer (08-11-2026): losing is a game over, so a lost battle keeps nothing, EXP included
## (false). true = the GDD Dual Restraint edge case (action EXP survives a defeat).
@export var action_exp_commits_on_defeat: bool = false

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

## ------------------------------------------------------------ P-13 feature flags (data-only)
## Bộ công thức chiến đấu (P-05): "gdd" | "legacy". Hiện CombatResolver chỉ có MỘT công thức (GDD,
## xem AGENTS.md F-CC) và chưa đọc field này; giữ lại cho validator và dùng sau.
@export var combat_formula_set: String = "gdd"
## EXP và level-up (F-EXP): bật mặc định — GDD dùng EXP làm cơ chế phát triển nhân vật (P-04 đã bị thay).
@export var exp_enabled: bool = true
## Cửa hàng (P-03): bật cho campaign demo; chương legacy giữ stub.
@export var shop_enabled: bool = false
## Fog of war (W6): tắt tới khi hệ thống fog hoàn tất.
@export var fog_enabled: bool = false
## D-B2 placeholder: default base vision khi unit không khai báo (0 = inherit).
@export var base_vision_default: int = 4

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
## Giá trị GDD chốt = 4; CombatResolver đọc trực tiếp field này (field cũ double_attack_speed_gap=5 đã bỏ).
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
## P-02: adjacency bonus lands on the stat groups listed here (GDD-Combat §5): accuracy,
## avoid, crit and damage. BondSystem maps them onto the combat formula entries; the old
## single-stat `bond_bonus_stat` must no longer be read.
@export var bond_bonus_targets: Array[String] = ["accuracy", "avoid", "crit", "damage"]
## Bonus theo rank (designer đã chốt); tổng bonus kề ô tối đa +16 (ràng buộc test bằng test).
@export var bond_bonus_by_rank: Dictionary = {"C": 3, "B": 5, "A": 8, "S": 10}
@export var max_adjacent_bond_bonus: int = 16
@export var bond_point_limit_per_pair_per_map: int = 20
@export var bond_points_combat_action: int = 2
