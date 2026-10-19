# Kế hoạch bàn giao v2: đưa Project X (repo gốc) về giống demo, theo GDD

> Bản v2 (16.10.2026). Thay thế hoàn toàn bản v1: v1 lấy demo làm nguồn luật; v2 lấy **GDD đã duyệt** làm nguồn luật và dùng demo để lấy hành vi UI, dữ liệu scenario và các phần GDD chưa gửi.
> Dành cho agent/lập trình viên tiếp nhận. Đọc hết file, rồi đọc `AGENTS.md`, `docs/tech_decisions.md` và Work Log trước khi viết code.
> Tài liệu đi kèm: `project-x-demo-source.zip` (mã nguồn demo), `UI-Design.docx` (ảnh chụp + đặc tả UI demo), và 5 GDD: `1__game-concept.docx`, `2__battle-map-system.docx`, `3__battle-ui-system.docx`, `4__core-combat-system.docx`, `5__unit-roster-system.docx`.
> Quy ước đường dẫn: `demo/…` = mã nguồn trong zip demo; `repo/…` = project gốc (`project-x`, Godot 4.7). Trích GDD ghi dạng `GDD-Combat §5`, `GDD-Map §6`, `GDD-UI §4`, `GDD-Roster §5`, `GDD-Concept §3`.

---

## 0. Mục tiêu và phạm vi

**Mục tiêu:** repo chạy được trọn luồng của demo (menu → độ khó → thoại → chuẩn bị → 6 map ví dụ → hậu trận → bond → sảnh → kết thúc) **và** tuân luật của 5 GDD, nhưng giữ kiến trúc repo (logic tách khỏi giao diện, command + snapshot, objective plugin, dữ liệu `.tres`, test + validator).

**Ngoài phạm vi đợt này:** art cuối; nhạc/âm thanh thật; nội dung thoại cuối; thứ tự gia nhập 8 nhân vật sau Map 1 (GDD-Roster §2: "không hard-code thứ tự chưa được duyệt"); tuyến thời chiến và Cross-Storyline Campaign (GDD-Concept §6: Paused); event executor của `EventDef`; map procedural/multiplayer (GDD-Concept §6: không làm).

---

## 1. Thứ bậc nguồn sự thật

Khi hai nguồn mâu thuẫn, lấy theo thứ tự:

| Bậc | Nguồn | Dùng cho |
| --- | --- | --- |
| 1 | **5 GDD đã gửi** (trạng thái Approved, 15.10.2026) | Luật chơi, công thức, hành động, mục tiêu map, luật dữ liệu, hành vi và thông tin UI, vòng đời nhân vật, checklist chấp nhận |
| 2 | **Bảng GDD nằm trong demo**: `demo/data/weapons.json`, `class_weapons.json`, `items.json`, `terrain_types.json` | Số liệu vũ khí, vật phẩm, địa hình **tạm thời** cho tới khi GDD Weapon/Item được gửi. Khớp GDD-Combat/GDD-Map (xem Phụ lục C) |
| 3 | **Dữ liệu scenario demo**: `demo/data/battle_demo.json`, `game_flow_demo.json`, `tuning/gold_shop.json` + code `battle_demo.gd`, `game_flow.gd` | Dữ liệu 6 map ví dụ, quân scenario, hành vi UI/luồng, **và mọi hệ thống mà GDD chưa gửi** (xem dưới) |
| 4 | Repo hiện tại | Kiến trúc, test, tooling; dữ liệu cũ giữ lại nếu không mâu thuẫn |

**GDD chưa gửi** (đánh dấu `[PENDING-GDD: tên]` trong plan; làm theo demo ở dạng *tạm*, đặt toàn bộ số vào dữ liệu để thay không cần sửa mã): Persuasion + Faction (có F-PS4), Bond/Adjacency + Bond Scene, Weapon/Item, Dual Restraint Scoring, Rewind, Gold/Shop, Difficulty, Save/Progression, Narrative, Protect/Persuade AI, Progression UI, UX specs (Pause, Trade, hòa giải), `systems-index`.

**Luật làm việc với `[PENDING-GDD]`:** làm đúng như demo, không "cải tiến"; ghi vào `AGENTS.md` §7 mục Open decisions; khi GDD tới, chỉ đổi dữ liệu/lớp được đánh dấu.

---

## 2. Nguyên tắc bất di bất dịch

Giữ nguyên `AGENTS.md` §3, §5, §11 và thêm các luật rút từ GDD:

1. Logic trong `RefCounted` dưới `repo/src/battle/`; scene chỉ vẽ và chuyển input thành command. **UI chỉ đọc state và gửi lựa chọn; không tự sửa state gameplay** (GDD-UI §1).
2. Một nguồn công thức: `CombatResolver` (forecast = dry-run của execute). Không nhân đôi công thức ở UI, AI, test.
3. Mọi hành động đã xác nhận là Command qua `BattleDirector.commit()`; snapshot trước khi áp dụng. **Tầng luật luôn xác minh lại lúc chốt** (đích ngoài tầm, mục tiêu Trade mất hợp lệ, ô đi bị chiếm): từ chối trước khi đổi state (GDD-Combat §3).
4. Dữ liệu có id ổn định; không hard-code số luật. Ngưỡng hiển thị (HP 0,66/0,33/0,25, `BOND_STACK_MAX`) lấy từ cấu hình (GDD-UI §5).
5. **Dữ liệu sai thì chặn tải và báo rõ cho developer; không tự sửa, không gán mặc định âm thầm** (GDD-Map §7, GDD-Roster §6, GDD-Combat §13: `range.min > max` bị chặn khi tải, không đảo hay clamp).
6. Chỉ 4 autoload (`EventBus`, `DataRegistry`, `GameState`, `SaveService`). Không thêm.
7. Định danh/comment/commit/id tiếng Anh; kiểu tĩnh mọi nơi; chuỗi hiển thị tiếng Việt nằm trong dữ liệu (`data/text/`), lấy qua lớp tĩnh `UiText`.
8. Không xoá/đổi tên id dữ liệu, autoload, API công khai nếu chưa được duyệt.
9. Hiển thị phải cập nhật trong ≤ 1 frame ở 60 fps sau khi state đổi (GDD-UI §10).
10. Cuối mỗi nhiệm vụ: `validate_data`, `run_tests`, `smoke_full_battle` xanh; cập nhật Work Log.
11. **Thông tin ẩn:** không bao giờ hiện kill count, ngưỡng kill, phần trăm hay "còn lại" của hòa giải trong trận (GDD-Concept §3, GDD-UI §1). Chỉ báo màu áp lực là ngoại lệ duy nhất. Odds chiến đấu thì phải hiện đủ.

---

## 3. Bức tranh khác biệt tổng thể

| Hạng mục | Repo hiện tại | Đích (GDD + demo) | Workstream |
| --- | --- | --- | --- |
| Khung hình | 1920×1080 tuyệt đối | 1280×720, layout container | W1 |
| Chỉ số | `atk/skl/spd/mov/crit/hit` | HP, Str, Mag, Skill, Speed, Luck, Def, Res, Move, base_vision | W2 |
| Vũ khí | không có | Weapon record (might/acc/crit/range/heal) | W2, W3 |
| Công thức | `power − def`… | F-CC1…F-CC7 | W3 |
| Địa hình | def_bonus + avoid_bonus | Chỉ `combat_modifier` vào né; Plain/Forest/Hill/Fort/Hazard/Water/Village; vision modifier | W2, W3, W6 |
| Hành động | move/attack/wait/skill/pickup | Move + {Attack, Heal, Use Item, Visit, Wait}, Trade tùy chọn không tốn Action | W4 |
| Fog of war | không có | 3 trạng thái ô, `base_vision`, LoS; threat range chỉ cho địch VISIBLE | W6 |
| Mục tiêu | 6 plugin | 5 loại + biến thể, `turn_par` bắt buộc, `turn_limit` tùy chọn | W5 |
| AI | EnemyAI + NpcAI | Standard, Raider, ProtectPersuade + ghi đè theo mục tiêu | W7 |
| Hòa giải | ngưỡng ẩn | Máy trạng thái + restraint + chỉ báo màu | W8 |
| Roster | `in_roster` bool | `life_status` Active/Dead/Incapacitated, 12 nhân vật cố định, chiêu mộ dần | W9 |
| Triển khai | tự gán ô | Chọn quân **và** đặt từng quân lên ô triển khai, cap 1–10 | W9, W12 |
| Rewind | frame trước mỗi command | Ranh giới hành động hoàn chỉnh; icon theo lượt; Story ∞ | W11 |
| Kinh tế/điểm | chưa có | Vàng, Cửa hàng, điểm, nâng chỉ số | W10 |
| UI | menu/prep/battle/post/camp | ~33 màn của doc + HUD theo GDD-UI | W12, W13 |

---

## 4. Xung đột GDD ↔ demo (**theo GDD**, trừ khi ghi khác)

Mỗi dòng là một chỗ code demo làm khác GDD. Agent **không được port nguyên hành vi demo** ở các dòng này.

| # | Chủ đề | GDD nói | Demo làm | Hành động |
| --- | --- | --- | --- | --- |
| C1 | Use Item Heal khi đầy HP | Vẫn được dùng, tiêu món, preview `+0` (GDD-Combat §7) | Từ chối, không tiêu món (`use_consumable`) | Theo GDD |
| C2 | Người mang vật nhiệm vụ (Retrieve) | Từ lượt sau chỉ **đi một lần**; không đánh, hồi máu, **Wait**, phản công (GDD-Map §5). Lượt nhặt: kết thúc bước đi ở `item_tile`, hành động lượt đó kết thúc | Carrier chỉ có `Wait` | Theo GDD: carrier không có menu hành động; sau khi đi tự chuyển Acted (xem D-B6) |
| C3 | Triển khai | Người chơi chọn tối đa `map_deploy_cap` quân rồi **tự đặt từng quân** lên ô triển khai bất kỳ; chọn quân + gán ô cùng commit (GDD-Map §3) | Vị trí cố định theo map, chỉ chọn quân | Theo GDD: UI đặt quân. Bắt buộc, không phải tùy chọn |
| C4 | Địa hình | Plain, Forest(+10), Hill(+5), Fort/Cover(+20), Hazard, Water/Impassable, Village; vision modifier riêng (GDD-Map §3) | `.` `F`(+12) `V` `W` | Theo GDD; scenario demo xem D-A3 |
| C5 | Fog of war | UNEXPLORED/VISIBLE/EXPLORED; `base_vision` 3–6; LoS; threat range và chỉ số địch chỉ hiện khi ô địch VISIBLE (GDD-Map §4, GDD-Combat §6) | Không có | Thêm mới (W6) |
| C6 | Vùng nguy hiểm | Hiển thị **liên tục** suốt Player Phase, kể cả chưa chọn quân; màu phẳng, không mã hóa Hit% (GDD-UI §2) | Chỉ khi "xem" một địch | Theo GDD |
| C7 | Turn limit / turn par | `turn_par` bắt buộc (khuyến nghị 6–20); `turn_limit` tùy chọn, quá hạn thua; `turn_par ≤ turn_limit`; Escort tính lượt: `turn_par ≥ escort_turns_required`; Seize: `turn_par ≥ hold_enemy_phases` (GDD-Map §2, §7) | Có `turn_par`, không rõ `turn_limit` | Theo GDD |
| C8 | Buff cùng stat | Mỗi stat chỉ một buff; dùng mới thay hẳn `amount` và `turns_remaining`, không cộng dồn (GDD-Combat §9) | Gán đè theo stat (khớp) | Giữ; thêm test |
| C9 | Heal | Chỉ vũ khí `action_category = Heal`; `HealAmount = Mag + heal_might`; tự hồi chỉ khi `heal_range.min = 0`; không đồng thời Attack | Mag + heal_might (khớp) | Giữ; thêm điều kiện tự hồi |
| C10 | AI Standard Aggressive | Chọn quân Player **gần nhất có thể đánh trong lượt**; hòa bằng tổng tọa độ thấp hơn; không có mục tiêu thì tiến gần nhất; không đi được mà có mục tiêu trong tầm thì vẫn đánh; không nhớ gì giữa các lượt (GDD-Combat §10) | Có thêm `priority_target_id`, hòa theo khoảng cách đánh | Theo GDD; `priority_target_id` là mở rộng của demo, xem D-B7 |
| C11 | Cap restraint khi phản công trong Player Phase | Dùng `last_context` của lần đánh giá Enemy Phase gần nhất; chưa từng đánh giá thì mặc định **Hold** (kiềm chế); không đánh giá lại; `last_context` phải được Rewind lưu/khôi phục (GDD-Combat §4) | Dùng `last_context` | Giữ; thêm test mặc định Hold |
| C12 | Dead / Incapacitated | Hard/Nightmare: Dead, rời trận, **cắt bond pairs liên quan**, Rank S vẫn giữ. Normal/Story: Incapacitated, giữ bond, cuối trận về Active đầy HP (GDD-Roster §5) | Chỉ `dead_ids` khi thắng và permadeath | Theo GDD (W9) |
| C13 | Bond | Tối đa 4 nguồn bonus kề cùng lúc; tổng chặn ở +16; số cặp bond không giới hạn; cộng cả accuracy/avoid/crit/damage (GDD-Combat §5, GDD-Roster §3) | Level 1–3 theo map (`[0,3,5,8]`) | Giữ rank C/B/A/S của repo (C+3, B+5, A+8, S+10); demo level 1–3 ↔ C/B/A. `[PENDING-GDD: Bond]` |
| C14 | Visit khi túi đầy | GDD-Combat: không được Visit **để lấy thưởng item**; GDD-Map: "nếu quân đã đủ 2 món thì không hiện Visit cho quân đó" | Chỉ chặn khi reward là item | Chưa rõ: xem D-B8. Mặc định theo GDD-Combat |
| C15 | Trade | Mục tiêu: đồng minh player Alive cách Manhattan đúng 1; trạng thái Ready/Acted của đồng minh **không** ảnh hưởng; "Không đưa gì" ≠ "Hủy"; không đụng vật phẩm Retrieve; hai bên không đưa gì là no-op nhưng vẫn tính đã Trade (GDD-Combat §8) | Tương tự, kiểm tra thêm | Theo GDD |
| C16 | Điểm khi thua | Vẫn hiện breakdown, nhưng ghi rõ `restraint_points_awarded` không được cộng vào save; map không đủ điều kiện kill-restraint bỏ hẳn dòng kill; trần 75 khi không đủ điều kiện (GDD-UI §7) | Chỉ cộng khi thắng (khớp) | Giữ; thêm hiển thị breakdown khi thua |
| C17 | Roster khởi đầu | 12 nhân vật cố định; Tutorial: Swordsman + Knight; sau Map 1: + Healer + Magician; 8 còn lại gia nhập theo narrative (chưa chốt) (GDD-Roster §2) | Chỉ Swordsman, Knight điều khiển được | Khớp phần đã chốt; repo hiện `in_roster=true` cho mọi unit → đổi (W9) |
| C18 | Chỉ báo áp lực hòa giải | Một chỉ báo cho **mỗi phe** Engaged/Unpersuadable, màu liên tục xanh→vàng→đỏ (0 / 0,5 / 1); đỏ trùng lúc Unpersuadable; ẩn khi Unengaged/Persuaded; không số; Rewind đổi màu ngay không animation ngược (GDD-UI §2, §5, §6) | Không có chỉ báo màu | Thêm mới (W8). Công thức `kill_pressure_ratio` = F-PS4 `[PENDING-GDD: Persuasion]` |
| C19 | Huy hiệu không tử trận | `zero_ally_deaths`: clean/broken, luôn hiện, đổi ngay khi chết hoặc Rewind (GDD-UI §2, §6) | Chỉ tính cuối trận | Thêm mới (W13) |
| C20 | Rewind trong UI | Icon từng lượt còn lại (Normal/Hard/Nightmare); Story ∞; có charge nhưng chưa có mốc thì không bấm được (GDD-UI §6) | Số đếm | Theo GDD (W11, W13) |
| C21 | Stat scale | Bảng 12 class (GDD-Combat §12): vd Swordsman Skill 10, Speed 9 | Scenario demo: Swordsman Skill 28, Speed 12, HP 28; Guard Skill 23 | **Hai bộ số khác nhau; xem §6.5 và D-A1** |
| C22 | Vũ khí | `weapons.json`: iron_sword might 8, acc 5, crit 5… | Scenario demo: sword might 5, acc 15, crit 2 | Cùng vấn đề với C21 |

---

## 5. Quyết định cần duyệt

### 5.A Quyết định kỹ thuật (người phụ trách repo / lead)

| ID | Câu hỏi | Mặc định đề xuất |
| --- | --- | --- |
| D-A1 | **Hai bộ số cân bằng** (C21, C22, C4): bộ GDD (12 class, `weapons.json`, `terrain_types.json`) và bộ scenario demo. Dùng bộ nào làm mặc định? | Tạo cơ chế `balance_profile` (`gdd` \| `demo`): thư mục `data/balance/<profile>/` chứa lớp ghi đè (vũ khí, địa hình, chỉ số quân, số luật), `DataRegistry` nạp lớp gốc + lớp của profile đang chọn, **id không đổi**. Cả hai profile đều qua validator và test. **Mặc định `demo`** cho 6 map ví dụ (để game chơi được và giống demo) cho tới khi GD gửi dữ liệu scenario theo thang GDD. Xem rủi ro R1. |
| D-A2 | Đổi khóa chỉ số theo GDD: `hp, str, mag, skill, speed, luck, def, res, move, base_vision`; bỏ `atk/skl/spd/mov/crit/hit` khỏi chỉ số quân (AGENTS §11 cấm đổi API nếu chưa duyệt). | Có. Thêm bước migrate trong `GameState.from_dict` cho save cũ. |
| D-A3 | Đổi khung 1920×1080 → 1280×720; sửa `AGENTS.md` §8, README, `project.godot`. | Có. |
| D-A4 | `growths`/level-up: GDD không có level-up (tiến triển bằng điểm giữa trận, `apply_stat_growth` đã clamp). | Giữ field `growths`, không dùng, ghi chú deprecated. |
| D-A5 | Dữ liệu cũ (`chapter_ch01`, `map_ch01`, `map_sample_escort`, 12 class cũ). | Giữ. Thêm campaign `demo` (6 chapter mới); thêm `campaign_tag` ở `ChapterData`. Class cũ được viết lại theo bảng GDD (cùng id `class_*`), đánh dấu giá trị cũ là deprecated. |
| D-A6 | Side `npc` của repo vs `side=player + controllable=false` của demo. | Dùng side `npc`. Địch có tấn công NPC không là câu hỏi cho GD (D-B5); mặc định như demo (có). |
| D-A7 | Xem trước đòn đánh: repo đã bỏ forecast panel; GDD-UI yêu cầu preview đầy đủ trước commit. | Theo GDD: dựng lại preview; cập nhật `docs/tech_decisions.md`. |
| D-A8 | Dữ liệu demo là JSON, repo là `.tres`. | Port sang `.tres` bằng script một lần trong `tools/`. |
| D-A9 | Chuỗi tiếng Việt vs quy ước tiếng Anh. | Mã/id tiếng Anh; chuỗi hiển thị trong `data/text/ui_vi.tres`, lấy qua `UiText`. |
| D-A10 | Tên "ceasefire" trong đường dẫn lưu demo. | Dùng `user://project_x_*.json`. |

### 5.B Câu hỏi cho Game Designer (ghi vào `AGENTS.md` §7; dùng mặc định tạm nếu chưa có trả lời)

| ID | Câu hỏi | Nguồn | Mặc định tạm |
| --- | --- | --- | --- |
| D-B1 | Làm tròn `.5`: `Luck×0,5`, `Skill×0,5` cho kết quả lẻ. Hit%/Crit% có làm tròn xuống (như demo `int()`)? | GDD-Combat §5 không nói | Cắt phần thập phân (`int`) |
| D-B2 | `base_vision` (3–6) từng class; luật LoS cho Hill giữa đường nhìn; vision modifier áp dụng ra sao nếu `effective_vision ≤ 0`. | GDD-Map §4; GDD-Roster §8 | Bảng placeholder (xem Phụ lục C); Hill không chắn LoS |
| D-B3 | Hazard tác động gì (GDD-Map: Core Combat tính; GDD-Combat không nói). | GDD-Map §3 | Không tác động (như Plain) |
| D-B4 | Move từng class (cột Move* trong GDD-Combat §12 chỉ là đề xuất chưa duyệt). | GDD-Combat §12 | Dùng bảng đề xuất, ghi chú chưa duyệt |
| D-B5 | Địch Standard Aggressive có tấn công NPC đồng minh không? | GDD-Combat §10 chỉ nói "quân Player" | Có (như demo) |
| D-B6 | Carrier Retrieve không có Wait: sau khi đi, quân tự chuyển Acted? Kết thúc phase người chơi thế nào nếu mọi quân còn lại đã Acted? | GDD-Map §5 | Carrier tự Acted sau khi đi; cho phép "Kết thúc lượt" |
| D-B7 | `priority_target_id` (địch ưu tiên mục tiêu cụ thể) có nằm trong thiết kế? | Chỉ có ở demo | Giữ là trường tùy chọn, mặc định rỗng |
| D-B8 | Visit khi đủ 2 item: chặn mọi Visit hay chỉ Visit có thưởng item? | GDD-Map §6 vs GDD-Combat §8 | Chỉ chặn thưởng item |
| D-B9 | Protect (quân): "sống tới điểm kết thúc đã khai báo" là gì (số Enemy Phase? ô đích?) và tham số tên gì. | GDD-Map §5 | Dùng `survive_enemy_phases` + `protect_unit_id` |
| D-B10 | Hit% quá thấp khi dùng đúng số GDD (xem R1). Có chỉnh GDD stat/weapon hay dữ liệu scenario theo thang GDD? | Vector GDD §6.3 | Chờ GD |
| D-B11 | Thứ tự gia nhập 8 nhân vật; map Tutorial/Map 1 thật. | GDD-Roster §2, §8 | Không hard-code; dùng 6 map ví dụ của demo |
| D-B12 | Quân `Civilian`/`unarmed` (`action_category None`) có nằm trong catalog không? | Demo-only | Giữ như demo |
| D-B13 | Trạng thái faction: GDD-UI dùng Unengaged/Engaged/Unpersuadable/Persuaded; demo thêm `Lost`. | GDD-UI §9 | Thêm cả hai, ghi `[PENDING-GDD: Persuasion]` |

---

## 6. Đặc tả luật triển khai

### 6.1 Vòng lượt và hành động (GDD-Combat §3, GDD-Map §4)

- Player Phase → Enemy Phase → (NPC) → Player Phase; `turn_number` tăng 1 sau Enemy Phase (và NPC nếu có), lượt đầu là 1. Vòng đời trận: Setup → Active → Won|Lost (hai trạng thái cuối).
- Mỗi quân: một Move (0…Move, theo chi phí địa hình và quy tắc đi) rồi một Action ∈ {Attack, Heal, Use Item, Visit, Wait}; xong chuyển Ready → Acted.
- **Trade** tùy chọn sau Move (hoặc đứng yên), tối đa một lần mỗi phase cho quân khởi xướng; **không tiêu Action**, không chuyển Acted; sau Trade vẫn chọn Action.
- Đi hợp lệ: `remaining_move = Move − Σ chi phí ô đi vào ≥ 0`; mọi ô đi qua passable; **không đi xuyên quân địch**; qua được đồng minh nhưng không kết thúc trên ô có bất kỳ quân nào. Đứng yên hợp lệ.
- Menu hành động (GDD-UI §4): thứ tự cố định **Attack → Heal → Use Item → Visit → Trade → Wait**; chỉ hiện mục hợp lệ; nếu không làm được gì khác chỉ còn Wait. Attack và Heal loại trừ nhau. Sau Trade, menu mở lại cho cùng quân, bỏ Trade và tính lại các mục còn lại.
- Hủy menu hành động trả quân về ô gốc và mở lại vùng đi, **trừ khi đã Trade** (Trade chỉ đảo bằng Rewind).

### 6.2 Công thức (GDD-Combat §5)

```
effective_stat(u, s) = base_s + buff active của đúng stat s      # không chặn lại ở trần 30
F-CC1 Accuracy = max(0, Skill*2 + Luck*0.5 + weapon_accuracy_mod + bond_bonus)   # người đánh
F-CC2 Avoid    = Speed*2 + Luck*0.5 + terrain_combat_modifier + bond_bonus        # người phòng thủ, ô đang đứng
F-CC3 Hit%     = clamp(Accuracy - Avoid, 0, 100)           # 0% vẫn là đòn hợp lệ, phải cho người chơi thấy
F-CC4 Crit%    = clamp(Skill*0.5 + weapon_crit_mod - defender_Luck*0.5 + bond_bonus, 0, 100)
F-CC5 Damage   = max(0, offense + weapon_might - defense + bond_bonus)   # Physical: Str/Def; Magic: Mag/Res
F-CC6 CritDmg  = floor(Damage * 2.5)                       # Damage = 0 thì crit vẫn 0
F-CC7 Double   = Speed_self - Speed_opponent >= 4          # chỉ một bên đủ điều kiện trong một exchange
```

- `attack_type`, tầm, might, accuracy, crit lấy từ vũ khí gán theo class, **không suy từ phe xuất thân**.
- Bond bonus: cộng các partner đang đứng kề 4 hướng và còn hiệu lực, tối đa 4 nguồn, tổng chặn +16; bond bonus và buff cộng được với nhau. Bonus rank (repo): C +3, B +5, A +8, S +10 `[PENDING-GDD: Bond]`.
- Địa hình chỉ cộng vào **né** (F-CC2), không cộng vào phòng thủ.
- Địch khi Deploy: nhân `ENEMY_STAT_MULTIPLIER` với Str/Mag/Skill/Speed/Def/Res rồi lấy phần nguyên xuống; **không** nhân HP/Luck. Quân mình dùng stat gốc.
- Tham số: `DOUBLE_THRESHOLD = 4`, `CRIT_MULTIPLIER = 2.5`, `MAX_ITEM_SLOTS = 2`, `BOND_STACK_MAX = 4` đều là dữ liệu, không hard-code.

### 6.3 Vector kiểm thử vàng

**Profile `gdd`** (stat 12 class GDD-Combat §12; vũ khí `weapons.json`, tạm cho tới khi có GDD Weapon/Item):

| Kịch bản | Hit% | Crit% | Damage | CritDmg | Đánh thêm |
| --- | --- | --- | --- | --- | --- |
| Swordsman (iron_sword) → Lancer, ô Plain, không bond | 4 | 7 | 11 | 27 | không (9−11) |
| Như trên, Lancer đứng Forest (+10) | **0** (clamp) | 7 | 11 | 27 | không |
| Như trên (Plain), Swordsman có bond C (+3) | 7 | 10 | 14 | 35 | không |
| Assassin (twin_daggers) → Swordsman, Plain | 26 | 33 | 6 | 15 | **có** (13−9 = 4, đúng ngưỡng) |
| Magician (fire_tome, Mag 13) → Swordsman (Res 4), Plain | 4 | (xem D-B1) | 17 | 42 | không |

Cách tính dòng 1: Accuracy = 10·2 + 8·0,5 + 5 = 29; Avoid = 11·2 + 6·0,5 + 0 = 25; Hit = 4; Crit = 10·0,5 + 5 − 6·0,5 = 7; Damage = 11 + 8 − 8 = 11; CritDmg = ⌊27,5⌋ = 27.
Dòng Magician: Crit = 9·0,5 + 0 − 8·0,5 = 0,5, phụ thuộc D-B1, **không** dùng làm test cho tới khi chốt.

**Profile `demo`** (stat scenario demo; vũ khí `sword`/`lance`; Forest +12):

| Kịch bản | Hit% | Crit% | Damage | Đánh thêm |
| --- | --- | --- | --- | --- |
| Swordsman → Guard, Plain, không bond | 59 | 14 | 10 | có (12−7 = 5) |
| Như trên, Swordsman kề Knight (bond +3) | 62 | 17 | 13 | có |
| Guard → Swordsman đứng Forest (+12), không bond | 20 | 7 | 7 | không (7−12) |

**Vector khác (cả hai profile):**
- Use Item Heal khi đầy HP: preview `+0`, chốt thì món bị tiêu và Action bị tiêu.
- Heal: `HealAmount = Mag_healer + heal_might`; `HP sau = min(HP + HealAmount, max_HP)`; Healer Mag 12 + staff 8 → 20.

### 6.4 Trình tự giao chiến và Restraint (GDD-Combat §4)

1. Trước commit tính và hiển thị **toàn bộ** exchange: Hit%, Crit%, Damage, phản công và đánh thêm của cả hai bên.
2. Chỉ nhận Attack khi mục tiêu nằm trong `weapon_range` từ ô sau Move (tôn trọng min range; Gunner `[2,3]` không đánh ô kề).
3. Người tấn công đánh trước; nếu người phòng thủ còn sống và vị trí người tấn công nằm trong `weapon_range` **của người phòng thủ** thì phản công. Heal weapon/unarmed không phản công.
4. Bên đủ F-CC7 đánh thêm theo thứ tự exchange; quân chết trước lượt đánh thêm thì bỏ đòn đó. HP về 0 thì dừng mọi phần còn lại ngay.
5. Địch chết phát kill event kèm faction/turn; đồng minh chết phát ally-death và cập nhật Roster.
6. Restraint: địch ProtectPersuade ở trạng thái `Engaged` và luật bật → `damage = min(damage, HP_mục_tiêu − 1)`. Khi phản công trong Player Phase dùng `last_context` (mặc định Hold nếu chưa từng đánh giá; không đánh giá lại; Rewind lưu/khôi phục). Standard/Raider không bị cap.
7. Mỗi đòn ghi `{actor, target, label, hit, critical, damage, target_hp, hit_chance, crit_chance}`; màn giao chiến chỉ phát lại dữ liệu này (bỏ qua được, state cuối đồng nhất).
8. Snapshot **không** khôi phục giữa đòn đầu và phản công.

### 6.5 Vật phẩm, buff, Heal, Trade, Visit

- **Use Item** chỉ dùng lên bản thân. Heal: `min(HP + item_heal_value, max_HP)` (không cộng Mag), được dùng và tiêu món kể cả đầy HP. Buff: tiêu đúng món chọn, ghi `buff_stat/buff_amount/buff_duration`. Mang 0: ẩn mục; mang 1: tự chọn; mang 2: picker.
- **Buff**: mỗi stat một buff; dùng mới thay hẳn amount và turns_remaining; stat khác nhau cùng tồn tại; giảm `turns_remaining` một lần sau mỗi Ready→Acted kế tiếp của chính quân đó; về 0 xóa ngay; xóa hết khi trận kết thúc; Rewind khôi phục stat/amount/turns. UI hiện từng buff với stat + lượt còn lại.
- **Heal** (vũ khí Heal): mục tiêu Alive trong `heal_range`; tự hồi chỉ khi `heal_range.min = 0`. Enemy không được cấu hình vũ khí Heal hay mang consumable (validator chặn).
- **Trade**: xem C15. Mỗi bên chọn tối đa một món riêng: bên có 2 món chọn món hoặc "Không đưa gì"; bên có 1 món tự chọn; hoán đổi 1–1 luôn hợp lệ; một bên đưa là tặng, hợp lệ khi người nhận sau đó ≤ 2 món. Ghi `carried_items` của cả hai trong **một transaction**. Preview Trade là nội dung trước/sau, không có Hit%/Crit%/Damage.
- **Visit**: quân đồng minh điều khiển được đứng trên Village chưa nhận; tiêu Action; thưởng nhận ngay; làng thành inert. Địch kết thúc Move trên làng chưa nhận thì phá làng (mất thưởng). Làng bị phá/đã nhận vẫn là địa hình Village, đi qua được. Làng không ảnh hưởng thắng/thua.

### 6.6 Mục tiêu map (GDD-Map §5, §7)

Mỗi map đúng một mục tiêu chính. Điều kiện thua chung có thể khai báo: hết quân triển khai, quá `turn_limit`. Điều kiện chết mục tiêu / thủng vùng / chết người mang đồ xử lý ngay khi xảy ra.

| Loại | Thắng | Thua / lưu ý |
| --- | --- | --- |
| Elimination | Hạ toàn bộ địch hoặc boss chỉ định | — |
| Protect (quân) | Mục tiêu sống tới điểm kết thúc đã khai báo (D-B9) | Mục tiêu chết: thua ngay; hạ hết địch không là thắng |
| Protect (vùng) | Giữ vùng qua `survive_enemy_phases` Enemy Phase | Bất kỳ địch bước vào vùng: thua ngay |
| Escort (tính lượt) | NPC sống qua `escort_turns_required` Enemy Phase, hoặc hạ hết địch trước | NPC chết: thua ngay, bất kể permadeath |
| Escort (tới đích) | NPC tự đến `escort_goal` sau lượt địch | NPC chết: thua. Hạ hết địch mà NPC chưa tới: chưa thắng |
| Retrieve | Quân đã lấy vật phẩm trở về `return_tile` | Người mang chết: thua. Hạ hết địch chưa đủ thắng |
| Seize | Quân điều khiển được giữ `control_point` qua `hold_enemy_phases` Enemy Phase **liên tiếp** | Mất điểm thì về 0, chưa thua |

- Thứ tự Escort tới đích: Người chơi → Địch → NPC. NPC đi theo chi phí địa hình, qua đồng minh nhưng không kết thúc trên họ, không qua địch; không có bước hợp lệ thì chờ. NPC bị địch giết trước bước NPC: thua ngay; NPC tới đích: thắng trước Player Phase kế tiếp.
- Seize: kiểm tra đúng cuối mỗi Enemy Phase; có quân điều khiển được sống đứng trên điểm → `control_progress + 1`; trống/địch chiếm/chỉ có NPC → về 0; đổi quân giữ điểm giữa các lượt được.
- Khi cả thắng và thua cùng kích hoạt: ưu tiên theo `result_priority` của map (giữ cơ chế repo).
- `battle_won(objective_type)` phát **đúng một lần** khi chốt Won; Lost không phát. Gold/Shop chống cộng trùng khi Rewind rồi thắng lại.
- Persuade-Pressure và Village không đổi Won/Lost; AI Cornered/Surrender không tự quyết định kết quả map.

### 6.7 Fog of war (GDD-Map §4, GDD-Combat §6)

- Trạng thái ô: UNEXPLORED → VISIBLE (có đồng minh thấy) → EXPLORED (hết đồng minh thấy, giữ địa hình, ẩn quân hiện tại, không về UNEXPLORED).
- VISIBLE nếu có đồng minh thỏa Manhattan ≤ `base_vision + vision_stand(ô đứng) + vision_viewed(ô nhìn vào)` và đường nhìn không bị chắn (Water/Impassable chắn). Ô quân mình đứng luôn VISIBLE. Tầm nhìn của nhiều đồng minh là hợp của họ.
- UI chỉ hiện chỉ số, tầm di chuyển/đe dọa và tầm đánh của địch khi ô địch VISIBLE; thay đổi hiển thị ngay trước nước đi kế tiếp.
- Rewind lưu trạng thái nhìn của ô; sau restore tính lại vùng nhìn và UI.
- Dữ liệu vision theo địa hình: xem Phụ lục C.

### 6.8 AI (GDD-Combat §10, GDD-Map §5; chi tiết hòa theo demo `[PENDING-GDD: Protect/Persuade AI]`)

- **Chọn nhánh:** `ai_profile = ProtectPersuade` và `faction.state = Engaged` → AI Protect/Persuade; ngoài ra Standard Aggressive hoặc Raider. Map **Seize** và **Protect vùng**: logic tiến tới điểm/vùng ưu tiên hơn `ai_profile`.
- **Standard Aggressive:** theo C10. Tính lại từ đầu mỗi lượt, không có ký ức; đánh không bị cap Restraint; Wait khi không đi/đánh được.
- **Raider:** nếu có Village chưa nhận tới được trong lượt, chọn làng gần nhất (hòa: tổng tọa độ), đi thẳng lên, phá làng; sau Move vẫn Attack mục tiêu trong tầm hoặc Wait; không chọn mục tiêu người chơi lần hai trong cùng lượt. Không có làng tới được: toàn bộ Standard Aggressive.
- **ZoneAssault** (Protect vùng): tiến tới ô vùng gần nhất theo chi phí; đánh quân Player trong tầm HP thấp nhất. **ControlPoint** (Seize): tiến tới điểm; đánh quân trong tầm, ưu tiên quân đang giữ điểm.
- **ProtectPersuade** (ngữ cảnh `Hold/Protect/Flee/Rally/Cornered`): che thủ lĩnh khi HP ≤ `protect_hp_threshold` (0,3) và bị đe dọa; rút lui khỏi vùng bị đe dọa; Cornered khi hết ô an toàn (không đánh); Rally khi không còn đồng đội trong `rally_radius` (3). Đòn đánh ở `Hold`/`Flee` bị cap Restraint khi faction Engaged.
- Địch dùng đúng các Command của W4 qua director, không chỉnh vị trí trực tiếp.

### 6.9 Roster và vòng đời (GDD-Roster)

- 12 nhân vật cố định (Empire: Swordsman, Knight, Lumberjack, Lancer, Gunner, Wyvern Knight; Kingdom: Beastwoman, Magician, Bard, Healer, Magic Swordsman, Assassin). Chưa chiêu mộ thì **không có** trong roster sở hữu (không dùng Dead để biểu diễn chưa gia nhập).
- Player unit: `unit_id, display_name, class_id, faction_of_origin, base_stat_block, life_status, bond_pairs, carried_items, s_partner_id`. Enemy unit: `unit_id, faction_tag, combat_stat_block` (không có bond/life_status dài hạn). Trạng thái trận (vị trí, current HP, Ready/Acted) **không** nhập vào roster.
- `life_status ∈ {Active, Dead, Incapacitated}`.
- F1: `1 ≤ số quân chọn ≤ map_deploy_cap` và mọi quân chọn đều Active. F2: `effective_cap = min(map_deploy_cap, số Active)`. Không còn quân Active: chuyển Game Over, **không mở trận với 0 quân**. Hủy chọn chỉ bỏ `deploy_selection` tạm.
- HP về 0: Hard/Nightmare → Dead (rời trận, xóa deploy_selection và **đúng** các `bond_pairs` liên quan trong cùng một transaction, giữ Rank S); Normal/Story → Incapacitated (rời trận, giữ bond và Rank S; cuối trận về Active đầy HP). `PERMADEATH_ACTIVE` theo độ khó. Heal không hồi sinh Dead. Rewind về trước lúc chết hoàn tác.
- `s_partner_id`: khi khóa Rank S, hai bản ghi trỏ đối xứng, không đổi kể cả khi một người chết. Save thiếu field → null. ID không tồn tại, tự trỏ chính mình hoặc không đối xứng → báo lỗi và **từ chối dữ liệu**.
- `apply_stat_growth(unit_id, stat, points)` chỉ nhận điểm đã được Progression kiểm tra giới hạn.
- Nhân vật chính chết: Game Over theo luồng riêng.

### 6.10 Điểm, kinh tế, hòa giải (`[PENDING-GDD]`, theo demo)

Giữ nguyên hành vi demo (xem Phụ lục D), kèm hai ràng buộc đã có trong GDD: (1) Won mới cộng điểm, Lost vẫn hiện breakdown nhưng không cộng vào save; (2) map không đủ điều kiện kill-restraint bỏ hẳn dòng kill count/restraint, trần 75.

---

## 7. Dữ liệu cần port

| Dữ liệu | Nguồn | Đích |
| --- | --- | --- |
| Stat 12 class (HP, Str, Mag, Skill, Speed, Move*, Luck, Def, Res) | GDD-Combat §12 | `data/classes/class_*.tres` + `data/units/unit_*.tres` (xem Phụ lục C). `base_vision` placeholder (D-B2) |
| 12 vũ khí + `class_weapons` | `demo/data/weapons.json`, `class_weapons.json` | `data/weapons/*.tres` (`WeaponData`); `BattleClassData.weapon_id` |
| Vật phẩm | `demo/data/items.json` (heal) + `battle_demo.json` (buff: `vigor_tonic`, `focus_tonic`) + giá `gold_shop.json` | `ItemData` mở rộng (`type, heal_value, buff_stat, buff_amount, buff_duration, price`) |
| Địa hình 7 loại + vision | `demo/data/terrain_types.json` + GDD-Map §3 | `RulesConfig.terrain_*` + glyph: giữ glyph hiện có của repo (`.` Plain, `f` Forest, `w` Water; `r`/`m`/`#` là dữ liệu cũ) và **đề xuất** thêm `h` Hill, `c` Fort/Cover, `x` Hazard, `v` Village |
| Profile `demo`: stat quân scenario, `sword/lance/staff/unarmed`, Forest +12, 4 loại địa hình | `battle_demo.json` | `data/balance/demo/` (lớp ghi đè) |
| 6 map + quân scenario (Guard, Raider, Commander…) + `faction` + `bonds` + `villages` | `battle_demo.json` | `data/maps/demo_01…06/map.tres`, `data/units/…` |
| Độ khó (rewind, permadeath, `enemy_stat_multiplier`, `restraint_rule_active`) | `battle_demo.json` | `RulesConfig` (mở rộng 3 bảng sẵn có) |
| `scoring`, `upgrade`, `gold_shop`, `ai_rules` | `battle_demo.json`, `game_flow_demo.json`, `gold_shop.json` | `RulesConfig` / `data/rules/shop_config.tres` |
| `intro`, `generic_aftermath`, `bond_scene` | `game_flow_demo.json` | `DialogueData` (+ `title/year/scene`) |

Mọi chuỗi hiển thị (nút, nhãn, thông báo) gom vào `data/text/ui_vi.tres`.

---

## 8. Workstream chi tiết

Quy ước: **S** nửa ngày, **M** 1–2 ngày, **L** 3+ ngày. Mỗi mục có test bắt buộc. "AC" = tiêu chí chấp nhận; tham chiếu checklist GDD ở Phụ lục F.

### W0 — Chuẩn bị và baseline (S)
- T0.1 Giải nén demo vào `docs/reference/demo/` (chỉ đọc). Đặt 5 GDD + `UI-Design.docx` vào `docs/reference/`.
- T0.2 Chạy 3 lệnh kiểm tra, ghi baseline (hiện: 92 test, smoke 12, validator 0 lỗi).
- T0.3 Chạy demo 4.7, chụp lại 6 map và các modal chính để đối chiếu.
- T0.4 Gửi các câu hỏi D-B1…D-B13 cho GD; ghi trả lời hoặc mặc định tạm vào `AGENTS.md` §7.
- T0.5 Xin duyệt D-A1…D-A10.

### W1 — Khung hình 1280×720 và nền UI (M)
- T1.1 `project.godot`: viewport 1280×720.
- T1.2 Helper layout dựa trên container (không tọa độ tuyệt đối); giữ `UIBuilder` cũ cho tới khi mọi màn được thay.
- T1.3 `src/ui/ui_theme.gd` (màu demo: `INK #07141a`, `PANEL #0b1d23`, `GOLD #dfbd80`, `MINT #a9d7c9`, `PALE #f3eddd`, `MUTED #a9b8b7`, `LINE rgba(.72,.84,.81,.20)`; font serif cho tiêu đề), `src/ui/ui_text.gd`.
- T1.4 Widget: `ModalDialog` (rộng tối thiểu 600/900, cuộn khi cao hơn màn), `ActionButton` (≥195×46, chữ 16), `Panel` (đệm 23), `Eyebrow/Title` (55px).
- T1.5 `ScreenRouter` (`Node` trong `main.tscn`, không phải autoload): `show(screen_id, params)`, chồng modal, bật/tắt lớp trận phía sau.
- T1.6 `flow_backdrop` (mode `battle`, `vn_war`, `vn_signal`, `vn_magic`, `vn_ruins`, `vn_peace`, `vn_journey`, `menu`) port từ `demo/src/flow_backdrop.gd`.
- **AC:** menu chạy ở 1280×720; không rò node khi tạo/hủy router.

### W2 — Mô hình dữ liệu, profile, validator (L)
- T2.1 `UnitData`/`UnitState`: khóa chỉ số GDD (D-A2); `base_vision`; `ai_profile`, `priority_target_id`, `controllable`, `carried_items`; state trận `active_buffs`, `has_traded_this_phase`, `last_context`.
- T2.2 `WeaponData` (`weapon_id, action_category (Combat|Heal|None), attack_type, weapon_range[min,max], weapon_might, weapon_accuracy_mod, weapon_crit_mod, heal_might, heal_range`); `BattleClassData.weapon_id`.
- T2.3 `ItemData` mở rộng (`type, heal_value, buff_*, price`).
- T2.4 `MapData`: thêm `width/height` suy từ `terrain_rows`; `deploy_tiles`, `map_deploy_cap`, `turn_par`, `turn_limit`, `objective_type`, các tham số mục tiêu (`protect_zone`, `survive_enemy_phases`, `protect_unit_id`, `item_tile`, `return_tile`, `control_point`, `hold_enemy_phases`, `escort_goal`, `escort_turns_required`, `escort_unit_id`), `villages[{cell, reward}]`, `bonds`, `faction`, `key_unit_id`, `hint_lines`, `objective_text`, `aftermath_lines`, `persuade_pressure`. Placement địch/NPC thêm `instance_id` (nhiều bản thể của một mẫu, vd `guard_1`, `guard_2`).
- T2.5 `ChapterData.campaign_tag`; `GameState.chapters_sorted()` lọc theo tag.
- T2.6 `RulesConfig`: giữ trường cũ, thêm số luật mới (`double_threshold`, `crit_multiplier`, `bond_stack_max`, `bond_bonus_by_rank`, `max_item_slots`, ngưỡng màu HP, `enemy_stat_multiplier` theo độ khó…).
- T2.7 Cơ chế `balance_profile` (D-A1): `DataRegistry` nạp lớp gốc + lớp profile; validator chạy cho từng profile.
- T2.8 `tools/import_demo_data.gd`: sinh `.tres` từ JSON demo (một lần). Quy tắc đặt id: tiền tố `unit_` (`swordsman → unit_swordsman`), cập nhật mọi tham chiếu (`bonds`, `escort_unit_id`, `priority_target_id`, `unit_id` của điều kiện thuyết phục, `key_unit_id`).
- T2.9 Validator, **chặn tải và báo rõ** (không sửa âm thầm):
  - quân: HP 15–60; 7 stat 0–30; Move 4–7; `base_vision` 3–6; `weapon_range.min ≤ max`; vũ khí giải được từ catalog; enemy không có vũ khí Heal và không mang consumable; `carried_items ≤ 2`;
  - map: toàn bộ danh sách ở Phụ lục E (GDD-Map §7);
  - roster: `s_partner_id` đối xứng, tồn tại, không tự trỏ.
- T2.10 Kiểm tra lại `check_chapters` trong `tools/validate_data.gd` (theo file hiện có, khối `required_count`/`deploy_max` có vẻ nằm ngoài vòng `for` và dùng biến `c`/`id` của vòng lặp). Sửa nếu đúng.
- **AC:** `validate_data` 0 lỗi cho cả hai profile; mỗi lỗi trong Phụ lục E có test âm tính (map xấu → từ chối với thông báo).

### W3 — Lõi chiến đấu (L)
- T3.1 `CombatResolver` viết lại theo §6.2 (giữ chữ ký `forecast/execute`); `effective_stat`.
- T3.2 `forecast` trả **toàn bộ** exchange (đòn tấn công, phản công, đánh thêm, cho cả hai bên) với Hit%/Crit%/Damage từng đòn.
- T3.3 `execute` theo §6.4: nhãn `TẤN CÔNG/PHẢN CÔNG/ĐÁNH ĐÔI`; dừng khi HP = 0; restraint cap; ghi `hit_chance/crit_chance`; ảnh chụp hai bên cho màn giao chiến.
- T3.4 `BondSystem.bond_bonus(state, unit)`: cộng partner đang kề, tối đa `bond_stack_max` nguồn, chặn tổng 16; áp vào accuracy/avoid/crit/damage.
- T3.5 `RangeHandler`: tầm `[min,max]` theo vũ khí; `can_counter` theo loại vũ khí và tầm; `ThreatRange` tôn trọng min range, chi phí địa hình, ô bị chiếm; kết quả có thể rỗng.
- T3.6 EXP trong trận: GDD không có → đặt `exp_gain_*` mặc định 0.
- **Test bắt buộc:** toàn bộ vector §6.3 (cả hai profile); đánh thêm đúng ngưỡng 4 (bằng 4 đủ điều kiện); Magic dùng Mag/Res; 0% Hit vẫn hợp lệ; phản công theo tầm người phòng thủ; chết chặn đòn còn lại; bond + buff cộng đồng thời; bond cap 16; terrain chỉ vào né; enemy multiplier floor, không nhân HP/Luck.
- **AC:** forecast và execute trùng số; checklist F-CC1…F-CC7 của GDD-Combat §13.

### W4 — Mô hình hành động và command (L)
- T4.1 Giữ `move/attack/wait/end_phase`; thêm `heal`, `use_item`, `visit`, `trade`; giữ `skill`/`pickup` cũ chạy được cho dữ liệu cũ.
- T4.2 `ActionRules.legal_actions(state, unit)` (hàm tĩnh, thứ tự cố định §6.1; carrier không có hành động theo C2).
- T4.3 `UseItemCommand` (C1), `VisitCommand`, `TradeCommand` (C15; một transaction; tạo ranh giới Rewind), `HealCommand` (C9).
- T4.4 Quy trình: chọn quân → vùng đi; bấm lại quân = xác nhận đứng yên; sau Move/đứng yên mở menu; hủy menu trả về ô gốc trừ khi đã Trade.
- T4.5 Nhặt tài liệu (Retrieve): quân điều khiển được **kết thúc bước đi** ở `item_tile` thì lấy đồ và hành động lượt đó kết thúc (GDD-Map §5). Không cần lệnh `pickup` thủ công trong UI; giữ `PickupCommand` cũ cho dữ liệu cũ.
- T4.6 Mỗi command xong giảm buff của quân đó đúng một lần (§6.5).
- T4.7 `check()` của mọi command xác minh lại lúc chốt (§2 luật 3).
- **Test:** từng command hợp lệ/không hợp lệ; Trade swap/gift/no-op/capacity 2/đồng minh đã Acted vẫn là mục tiêu/mục tiêu mất hợp lệ bị từ chối/ghi hai quân cùng lúc; Use Item đầy HP tiêu món; buff đè cùng stat; Visit khi đủ túi; menu đúng thứ tự và tính lại sau Trade.

### W5 — Mục tiêu map (M)
- T5.1 Plugin theo §6.6: `eliminate` (hỗ trợ boss chỉ định), `escort` (hai biến thể, loại trừ nhau), `defend`→Protect (quân/vùng), `retrieve`, `capture`→Seize. Giữ `evacuate` cũ (ngoài GDD).
- T5.2 `turn_limit` thua; `turn_par` bắt buộc.
- T5.3 Bộ đếm `enemy_phases`, `control_progress`, `evac_progress`/vùng giữ, vật phẩm Retrieve + người mang, trạng thái Village (`unclaimed/claimed/destroyed`) — **trường riêng**, đều nằm trong snapshot.
- T5.4 `battle_won(objective_type)` phát đúng một lần; Lost không phát.
- **Test:** từng loại thắng/thua/ongoing; Escort NPC bị giết trước bước NPC; Seize đếm liên tiếp và reset; vùng Protect thua ngay khi bị xâm nhập; hạ hết địch không thắng khi map không phải Elimination; Rewind phục hồi mọi bộ đếm.

### W6 — Fog of war (L)
- T6.1 `VisionSystem` (`RefCounted`): tính VISIBLE/EXPLORED/UNEXPLORED từ `base_vision`, vision modifier, Manhattan, LoS (Water chắn; Hill theo D-B2).
- T6.2 Cập nhật sau mỗi Move, chết, Rewind; ô quân mình luôn VISIBLE.
- T6.3 Gate hiển thị: threat range/chỉ số địch chỉ khi VISIBLE. Cờ `fog_enabled` trong `RulesConfig` để bật dần (milestone M2 có thể chạy với fog tắt).
- **Test:** chuyển trạng thái ô; nhiều đồng minh = hợp; đồng minh duy nhất rời đi → EXPLORED, không giữ hình bóng địch; Rewind tính lại.

### W7 — AI (L)
- T7.1 Tách `EnemyAI` thành chiến lược theo `ai_profile` và objective (§6.8): `StandardAggressive`, `Raider`, `ProtectPersuade`, `ZoneAssault`, `ControlPoint`.
- T7.2 Tie-break đúng GDD (tổng tọa độ); không ký ức; đứng yên vẫn đánh nếu có mục tiêu trong tầm.
- T7.3 Raider phá làng, vẫn Attack sau Move, không chọn mục tiêu lần hai.
- T7.4 ProtectPersuade với `last_context` (lưu vào snapshot) `[PENDING-GDD]`.
- T7.5 `NpcAI` theo §6.6 (chi phí tới đích, hòa y rồi x), chạy sau Enemy Phase, ghi ranh giới `NPC`.
- T7.6 Địch dùng Command qua director.
- **Test:** mỗi hành vi một kịch bản xác định; địch ProtectPersuade rời Engaged thì chuyển sang fallback Standard/Raider; Cornered không đánh.

### W8 — Hòa giải và chỉ báo áp lực `[PENDING-GDD: Persuasion]` (M)
- T8.1 `ReconcileSystem` thêm trạng thái faction (Unengaged/Engaged/Unpersuadable/Persuaded, + Lost của demo), `battle_kills`, `persuasion_kills`, `persistent_kills` (từ `prior_kills`), điều kiện `named_unit_alive`; giữ API cũ (`record_kill`, `record_event`, `evaluate`, `attitude`).
- T8.2 Luật demo (xem Phụ lục D): `prior_kills ≥ threshold` → khởi đầu Unpersuadable; hai bộ đếm tách; Persuaded khi thắng + điều kiện đạt; thua → Lost.
- T8.3 `kill_pressure_ratio(faction)` ∈ [0,1] cho HUD; công thức chờ F-PS4. Tạm: `persuasion_kills / kill_threshold` (clamp), đặt ở dữ liệu để thay.
- T8.4 `is_restrained(state, unit, context)` (§6.4 điểm 6).
- **Test:** HUD không bao giờ nhận kill count hay ngưỡng (API chỉ trả ratio); ratio phục hồi đúng sau Rewind; Persuaded ẩn chỉ báo.

### W9 — Roster, vòng đời, triển khai (L)
- T9.1 `GameState.recruited_ids` + `life_status` mỗi quân; `in_roster` chỉ còn nghĩa "có trong dữ liệu". Roster khởi đầu theo C17; **không** hard-code thứ tự 8 người còn lại (chỉ cơ chế `recruit(unit_id)` do dữ liệu/narrative gọi).
- T9.2 Quy trình HP = 0 theo §6.9: Dead/Incapacitated; cắt `bond_pairs` + giữ Rank S trong một transaction; "đánh dấu bond bị cắt" trong save (không mở lại S).
- T9.3 `s_partner_id` và kiểm tra tính đối xứng khi tải.
- T9.4 Triển khai: F1/F2, UI **đặt từng quân lên ô triển khai** (click ô), chọn quân + gán ô cùng commit; 0 quân Active → Game Over.
- T9.5 `apply_stat_growth` (chỉ nhận điểm đã kiểm).
- **Test:** F1/F2; Dead cắt đúng bond liên quan và giữ S; Incapacitated giữ bond và về Active đầy HP; Rewind về trước lúc chết khôi phục `life_status` trước rồi mới tới phần phụ thuộc; save/restore khứ hồi; không thể có quân đã chọn mà chưa có ô.

### W10 — Điểm, vàng, Cửa hàng, nâng chỉ số `[PENDING-GDD: Scoring/Gold-Shop/Progression/Difficulty]` (M–L)
- T10.1 `GameState`: `gold`, `pool`, `upgrades`, `item_loadout`, `rewarded_maps`, `rewarded_factions`, `dead_ids`/`life_status`, `support_points`, `viewed_bond`, `tier_switch_confirmed`.
- T10.2 `CampaignEconomy` (`RefCounted`): `apply_battle_result`, `purchase`, `buy_stat`.
- T10.3 Điểm theo Phụ lục D; thua: hiển thị breakdown, không cộng (C16).
- T10.4 Áp `upgrades`, `item_loadout`, `enemy_stat_multiplier` khi dựng quân.
- T10.5 Game Over khi nhân vật chính chết (kể cả khi thua trận).
- **Test:** thưởng vàng một lần mỗi map/faction (kể cả Rewind rồi thắng lại); trần nâng chỉ số (30, HP 60); túi ≤ 2; permadeath loại quân khỏi danh sách chọn; save/load đủ trường.

### W11 — Rewind (M) `[PENDING-GDD: Rewind]`
- T11.1 Ranh giới hành động hoàn chỉnh trước/sau Move+Action (kể cả Trade); không khôi phục giữa đòn đầu và phản công.
- T11.2 Snapshot mở rộng: `turn_number`, `last_context`, buff, `carried_items`, `has_traded_this_phase`, trạng thái nhìn của ô, tiến độ mục tiêu, Retrieve + người mang, Village, `faction_state` + hai bộ đếm kill, `life_status`, `zero_ally_deaths`.
- T11.3 Số lần theo độ khó (Story ∞, Normal 5, Hard 3, Nightmare 0); màn **Chọn mốc**; "Rewind" nhanh về ranh giới trước.
- T11.4 Quyết định D04 của repo (RNG không reset) giữ nguyên; ghi chú nếu GDD Rewind khác.
- **Test:** quay lại mốc khôi phục mọi trường; hết lượt thì chặn; Nightmare không có nút; Story không trừ; chỉ báo áp lực và huy hiệu khôi phục ngay.

### W12 — Flow chiến dịch và màn hình (L)
`main.gd` thành bộ điều phối mỏng dùng `ScreenRouter`; mỗi màn là scene/lớp riêng.

| Màn demo | Tên trong `UI-Design.docx` | Ghi chú |
| --- | --- | --- |
| `home` | Menu chính | 3 nút: Trò chơi mới, Tiếp tục, Tùy chọn |
| `options` | Tùy chọn (menu / giữa các trận / phần dưới) | Âm lượng Master/Music/SFX, cửa sổ, lưu thủ công, đổi độ khó |
| `difficulty`, `nightmare_confirm` | Chọn độ khó, Xác nhận Nightmare | 4 thẻ ≥ 280×248 |
| `intro` | Giới thiệu thế giới | `DialoguePlayer` kiểu visual novel |
| `prep` | Map 1…6 (chuẩn bị) | **Chọn quân + đặt quân lên ô triển khai** (C3), cap theo map, nút Cửa hàng |
| `shop`, `shop_target` | Cửa hàng | |
| `battle`, `action_menu` | Bản đồ chiến đấu | W13 |
| `pause`, `squad_list`, `squad_detail`, `leave_confirm` | Tạm dừng, Đội hình trong trận, Xác nhận rời trận | Chỉ đọc, mở được cả Enemy Phase |
| `battle_items`, `trade_targets`, `trade_offer` | Vật phẩm, Trade | picker 2 món; "Không đưa gì" ≠ Hủy |
| `rewind` | Chọn mốc Rewind | W11 |
| `summary` | Tổng kết | `DualRestraintResult` (§6.10) |
| `aftermath` | Thoại hậu trận | |
| `bond`, `bond_list`, `bond_scene` | Danh sách bond, Cảnh bond | `BondSystem` + `GameState.bond_*` |
| `progression`, `upgrade_confirm` | Đội hình và nâng chỉ số | |
| `gameover`, `ending` | Game Over, Kết thúc 6 màn | |

- T12.1 Campaign: 6 chapter theo `order`; kết thúc → `ending`. Giữ `retry_chapter` khi thua.
- T12.2 Bond sau thắng: `viewed_bond`, `support_points`; liên kết với rank C/B/A/S của repo.
- T12.3 Đổi độ khó giữa trận: thẻ xác nhận, áp dụng từ trận kế tiếp.
- **AC:** từ Trò chơi mới chơi hết 6 map tới `ending` bằng chuột.

### W13 — Giao diện trận đấu theo GDD-UI (L)
Máy trạng thái UI: `PlayerPhase_Idle → ActionMenu → ActionPreview → (EnemyPhase_Locked) → BattleEnd_Summary`.
- T13.1 Bản đồ phủ gần toàn màn; `tile_size` cấu hình (demo 64); camera theo quân đang thao tác.
- T13.2 Bố cục theo doc: khung **Mục tiêu + lượt** (~250×125, góc trái trên), **thẻ quân** (~500×190, góc trái dưới), **khung địa hình** (~150×90, góc phải dưới, chỉ khi có ô trỏ); Pause và Rewind là điều khiển nhỏ.
- T13.3 Thành phần bắt buộc (GDD-UI §2): preview giao chiến (đổi mục tiêu cập nhật ngay), vùng nguy hiểm liên tục (màu phẳng), thanh HP (xanh > 0,66; vàng 0,33–0,66 gồm cả hai biên; đỏ < 0,33; nhấp nháy ≤ 0,25, độc lập với màu), một dấu cho mỗi cặp bond (tối đa 4, kèm rank), một dấu cho mỗi buff (stat + lượt còn lại, không lấy `MAX_ITEM_SLOTS` làm giới hạn), icon Rewind theo lượt/∞, huy hiệu clean/broken, chỉ báo áp lực hòa giải theo phe.
- T13.4 `BattleActionMenu` (port `demo/src/ui/battle_action_menu.gd`): ≥280 rộng, nút cao ≥44, chữ 24, lệch quân (24, −12), điều hướng bàn phím.
- T13.5 `CombatPresentation` (port `demo/src/ui/combat_presentation.gd`, 169 dòng, tự vẽ bằng `_draw`; API `enqueue/advance/skip/reset`, tín hiệu `presentation_state_changed/finished`): chỉ phát lại `strikes` của `CombatResolver`; hoãn tín hiệu kết thúc trận cho tới khi xong (`_pending_battle_finished` trong demo).
- T13.6 Enemy Phase: khóa input chiến thuật; HP/badge/tầm vẫn cập nhật live; Pause + Xem Đội Hình vẫn dùng được.
- T13.7 Xem Đội Hình: danh sách đồng minh đã triển khai (kể cả Incapacitated; Dead xám + nhãn "Đã chết", vẫn mở chi tiết); chi tiết gồm 8 chỉ số, current HP, bond + rank, buff + lượt, carried_items; trường "Đặc điểm nhân vật" hiện "Đang cập nhật"; **chỉ đọc**.
- T13.8 Tổng kết: `zero_ally_deaths`, `restraint_points_awarded`; chỉ khi `kill_restraint_eligible` mới có `battle_kill_count` + `low_kill_restraint`; thua: ghi rõ không cộng vào save.
- T13.9 Hai điểm UX chưa chốt (GDD-UI §10): hình thức/vị trí dấu buff; cách xếp nhiều chỉ báo áp lực. Làm bản tạm, đặt vị trí trong cấu hình.
- **AC:** đối chiếu mắt từng ảnh trong `UI-Design.docx` (HUD theo bố cục mới, không theo ảnh HUD cũ); checklist GDD-UI §10.

### W14 — Lưu, tải, tùy chọn (M)
- T14.1 `SaveService`: `save_version = 2`, đọc được v1; trường chiến dịch mới; checkpoint (`prep`|`progression`); chỉ lưu giữa các trận.
- T14.2 Âm thanh (bus `Master/Music/SFX`) và chế độ cửa sổ lưu riêng khỏi save chiến dịch.
- T14.3 `roster_save_snapshot()` / `restore_roster_from_save()`; restore `life_status` trước rồi tới phần phụ thuộc.
- **Test:** khứ hồi mọi trường; save v1 nạp được; dữ liệu `s_partner_id` sai bị từ chối.

### W15 — Cốt truyện và hội thoại (S–M)
- `dlg_demo_intro` (6 đoạn có `year/title/scene`), `dlg_demo_aftermath`, `dlg_demo_bond_swordsman_knight_c`; aftermath theo trạng thái hòa giải; `DialoguePlayer` hỗ trợ backdrop `scene`.

### W16 — Placeholder art (S)
- Quân/bản đồ vẽ bằng ô màu/chip. Màu demo: Đồng `#7c9b73`, Rừng `#3d705e`, Làng `#98774e`, Nước `#456d88`. Thêm màu cho Hill/Fort/Hazard. Ba trạng thái sương mù, ô triển khai, marker mục tiêu phải phân biệt được.

### W17 — Kiểm thử, tài liệu, bàn giao (M)
- T17.1 Giữ bài cũ (đổi giá trị mong đợi có chú thích), thêm bài mới cho W2–W11; không giảm số assertion so với baseline.
- T17.2 Smoke: mỗi trong 6 map và một smoke chạy flow chiến dịch qua `ScreenRouter`.
- T17.3 Cập nhật `README.md`, `docs/how_to_run.md`, `docs/tech_decisions.md`, `AGENTS.md` (khung 1280×720, GDD là nguồn luật, open decisions, Work Log).
- T17.4 Chạy 4 lệnh: boot check, `validate_data`, `run_tests`, `smoke_full_battle`.

---

## 9. Mốc kiểm thu

| Mốc | Gồm | Bằng chứng |
| --- | --- | --- |
| **M1 — Luật xong** | W0–W3 | Vector vàng xanh ở cả hai profile; validator chặn đúng map/quân xấu; 1 trận Elimination chạy smoke |
| **M2 — Trận đầy đủ (fog tắt)** | W4, W5, W7, W8 | 6 map thắng/thua đúng bằng test; AI từng hành vi có test; Trade/Visit/Use Item đúng GDD |
| **M3 — Vòng đời + Rewind + fog** | W6, W9–W11 | Dead/Incapacitated, bond cắt, Rewind đủ trường, fog đúng ba trạng thái |
| **M4 — Flow + UI** | W1, W12–W15 | Chơi hết 6 map bằng chuột; đối chiếu `UI-Design.docx` và checklist GDD-UI |
| **M5 — Đóng gói** | W16–W17 | 4 lệnh kiểm tra xanh; tài liệu và Work Log cập nhật |

W1 chạy song song với W2–W3.

---

## 10. Rủi ro và bẫy đã biết

1. **R1 — Số GDD cho tỉ lệ trúng rất thấp.** Với stat 12 class và `weapons.json`, các vector ở §6.3 cho Hit% 4–26% (vd Swordsman → Lancer chỉ 4%). Scenario demo bù bằng cách tăng Skill (Swordsman 28, Guard 23) nên ra 59%. GDD ghi rõ số cân bằng chưa playtest, nhưng nếu agent chuyển mặc định sang profile `gdd` thì trận gần như không chơi được. **Báo GD (D-B10) trước khi đổi mặc định; không tự chỉnh số.**
2. **Hai lớp tính toán trong demo.** `CoreCombat/UnitRoster/CatalogLoader` (sạch, theo GDD) chỉ được `action_menu_demo.gd` dùng; trận chạy thật dùng `CombatRules` + `battle_demo.gd`. Dùng chúng làm tham chiếu thiết kế dữ liệu, không làm nguồn hành vi.
3. **Hành vi demo trái GDD** (C1–C22): đừng port "cho đúng demo" mà bỏ qua bảng §4.
4. **Terrain:** repo hiện cộng địa hình vào phòng thủ; GDD chỉ cộng vào né. Quên đổi sẽ lệch mọi vector.
5. **Side `npc` vs `controllable=false`:** mọi chỗ demo kiểm `side == "player"` cho Heal/AI/đếm quân cần xem lại (D-A6, D-B5).
6. **Nhiều bản thể một mẫu:** demo có `guard_1`, `guard_2`… từ cùng một template; repo hiện đặt theo `unit_id` duy nhất → thêm `instance_id` (T2.4), khóa `BattleState.units` theo instance.
7. **Id quân:** demo dùng id ngắn (`swordsman`), repo dùng tiền tố (`unit_swordsman`). Ánh xạ khi import và cập nhật mọi tham chiếu (T2.8).
8. **Mở rộng schema vỡ test cũ:** cập nhật giá trị mong đợi và ghi lý do; không xoá test.
9. **`check_chapters` có vẻ sai thụt lề** (T2.10); kiểm bằng cách chạy validator.
10. **`SnapshotStack.find_last_player_frame` có `return` thừa** (`return not frames.is_empty()` sau `return -1`, code chết); dọn trong W11.
11. **Hộp thoại cao hơn màn:** demo dùng `await get_tree().process_frame` rồi đo để kẹp panel (`_clamp_modal_panel`); làm giống để không nhấp nháy.
12. **Chuỗi tiếng Việt có dấu** trong `.tres`: UTF-8 (đã có `.editorconfig`).
13. **Tên "ceasefire"** trong đường dẫn lưu demo; không mang sang repo.

---

## 11. Định nghĩa hoàn thành

- [ ] Từ menu → độ khó → thoại → chuẩn bị (đặt quân) → 6 trận → ending chơi được bằng chuột, không lỗi/cảnh báo.
- [ ] Mỗi màn trong `UI-Design.docx` có tương ứng; HUD trận theo bố cục mới và checklist GDD-UI §10.
- [ ] Mọi checklist chấp nhận của 5 GDD (Phụ lục F) có test hoặc ghi chú vì sao chưa làm.
- [ ] Vector vàng §6.3 xanh ở cả hai profile; `validate_data` 0 lỗi cho cả hai profile; `run_tests` không giảm số kiểm tra so với baseline; smoke 6 map xanh.
- [ ] Không thêm autoload; không còn tọa độ 1920×1080 trong màn mới; mọi số luật trong dữ liệu; không có đường nào lộ kill count/ngưỡng trên HUD.
- [ ] `AGENTS.md`, README, `docs/` cập nhật; mọi `[PENDING-GDD]` còn mở được liệt kê trong §7 của `AGENTS.md`.

---

## Phụ lục A — Ánh xạ nguồn demo → đích repo

| Demo | Chức năng | Đích repo |
| --- | --- | --- |
| `combat_rules.gd` | accuracy/avoid/crit/damage/bond/in_range | `src/battle/rules/combat_resolver.gd`, `range_handler.gd`, `systems/bond_system.gd` |
| `battle_demo.gd` `_strike/_resolve_exchange` | giao chiến | `CombatResolver.execute` |
| `…` `legal_actions`, `_select_unit`, `_confirm_no_move`, `cancel_action_menu` | menu hành động và hủy | `src/battle/rules/action_rules.gd` (mới) + `BattleScene` |
| `…` `use_consumable`, `_decrement_buffs` | vật phẩm/buff (**sửa theo C1**) | `src/battle/commands/use_item_command.gd` (mới) |
| `…` `visit_village`, `_destroy_village_under_enemy` | làng | `visit_command.gd` (mới) + `BattleState.village_states` |
| `…` `can_trade`, `trade_items` | trao đổi | `trade_command.gd` (mới) |
| `…` `_standard_enemy_action`, `_raider_action`, `_protect_persuade_action`, `_zone_assault_action`, `_control_point_enemy_action`, `_advance_escort_npc` | AI | `src/battle/ai/*.gd` |
| `…` `_check_outcome`, `_finish_battle` | thắng/thua/điểm | `BattleDirector._check_battle_end` + objective plugin + `CampaignEconomy` |
| `…` `_register_enemy_kill` | kill hòa giải | `ReconcileSystem` |
| `…` `_record_boundary`, `_rewind_last_action`, `rewind_to_boundary` | rewind | `SnapshotStack`, `BattleDirector.use_rewind` |
| `battle_grid.gd` | `reachable`, `costs_to_goal` | `MovementHandler` (thêm `costs_to_goal`) |
| `game_flow.gd` các `_render_*` | màn hình | `src/scenes/*` + `ScreenRouter` |
| `ui/battle_action_menu.gd`, `ui/combat_presentation.gd`, `ui/home_menu.gd`, `ui/narrative_dialogue_box.gd` | widget | `src/ui/` |
| `flow_backdrop.gd` | nền | `src/ui/flow_backdrop.gd` |
| `data/*.json` | dữ liệu | `data/**/*.tres` qua `tools/import_demo_data.gd` |

## Phụ lục B — Ánh xạ khóa chỉ số (D-A2)

| Repo cũ | GDD / mới |
| --- | --- |
| `hp` | `hp` (= max_HP; `current_HP` là state trận) |
| `atk` | `str` (+ thêm `mag`) |
| `def`, `res` | `def`, `res` |
| `skl` | `skill` |
| `spd` | `speed` |
| `mov` | `move` |
| `crit`, `hit` | bỏ (đến từ vũ khí + skill/luck); thêm `luck` |
| — | `base_vision` (mới) |

## Phụ lục C — Dữ liệu GDD canonical

**Stat 12 class (GDD-Combat §12, bản đầu 15.10.2026, chưa playtest).** Move* là đề xuất chưa duyệt; `base_vision` do repo đặt placeholder (D-B2).

| Class | HP | Str | Mag | Skill | Speed | Move* | Luck | Def | Res | base_vision (tạm) | Vũ khí (`class_weapons.json`) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Swordsman | 32 | 11 | 2 | 10 | 9 | 5 | 8 | 7 | 4 | 4 | iron_sword |
| Knight | 38 | 10 | 1 | 6 | 5 | 6 | 5 | 14 | 6 | 4 | steel_lance |
| Lumberjack | 34 | 15 | 0 | 5 | 6 | 4 | 4 | 9 | 3 | 4 | battle_axe |
| Lancer | 30 | 10 | 1 | 8 | 11 | 5 | 6 | 8 | 4 | 4 | iron_lance |
| Gunner | 26 | 8 | 1 | 13 | 10 | 5 | 7 | 5 | 5 | 5 | hunting_rifle |
| Wyvern Knight | 34 | 12 | 1 | 7 | 9 | 7 | 5 | 10 | 5 | 5 | wyvern_lance |
| Beastwoman | 29 | 10 | 2 | 11 | 12 | 6 | 9 | 6 | 5 | 5 | claws |
| Magician | 24 | 2 | 13 | 9 | 8 | 5 | 6 | 3 | 9 | 4 | fire_tome |
| Bard | 25 | 4 | 6 | 12 | 10 | 5 | 11 | 4 | 7 | 4 | light_rapier |
| Healer | 26 | 2 | 12 | 8 | 7 | 5 | 7 | 4 | 8 | 4 | healing_staff |
| Magic Swordsman | 28 | 7 | 9 | 9 | 8 | 5 | 6 | 6 | 6 | 4 | spell_blade |
| Assassin | 22 | 7 | 1 | 14 | 13 | 6 | 10 | 3 | 4 | 5 | twin_daggers |

Giới hạn (validator): HP 15–60; 7 stat còn lại 0–30; Move 4–7; `base_vision` 3–6; `carried_items ≤ 2`.

**Vũ khí (`demo/data/weapons.json`, tạm `[PENDING-GDD: Weapon/Item]`):** iron_sword (Physical, 1–1, might 8, acc 5, crit 5); steel_lance (1–1, 10, 0, 0); battle_axe (1–1, 12, −5, 10); iron_lance (1–1, 9, 0, 0); hunting_rifle (2–3, 7, 10, 5); wyvern_lance (1–2, 11, −2, 5); claws (1–1, 10, 5, 15); fire_tome (Magic, 1–2, 8, 5, 0); light_rapier (1–1, 5, 15, 10); healing_staff (Heal, `heal_might` 8, `heal_range` 1–2); spell_blade (Magic, 1–1, 9, 0, 5); twin_daggers (1–1, 6, 15, 30).

**Vật phẩm:** potion (heal 10), vulnerary (15), elixir (30); buff `vigor_tonic` (str +5, 3 lượt), `focus_tonic` (skill +5, 3 lượt). Giá: potion 10, vulnerary 15, elixir 30, vigor_tonic 20, focus_tonic 20.

**Địa hình (GDD-Map §3 + `terrain_types.json`):**

| Địa hình | Chi phí | Tránh đòn | Tầm nhìn đứng / nhìn vào | Ghi chú |
| --- | --- | --- | --- | --- |
| Plain | 1 | 0 | 0 / 0 | |
| Forest | 2 | +10 | −1 / −1 | |
| Hill | 2 | +5 | +2 / −1 | LoS: D-B2 |
| Fort/Cover | 1 | +20 | 0 / 0 | |
| Hazard | 1 | 0 | 0 / 0 | Tác động: D-B3 |
| Water/Impassable | không đi được (99) | — | — / chắn tầm nhìn | |
| Village | 1 | 0 | 0 / 0 | Giống Plain, thêm Visit |

(Profile `demo` ghi đè: Forest +12; scenario chỉ dùng 4 loại Plain/Forest/Village/Water.)

## Phụ lục D — Hệ thống `[PENDING-GDD]` lấy theo demo

- **Hòa giải:** `battle_kills` (mọi kill địch thuộc `faction.id`), `persuasion_kills` (chỉ khi `Engaged`), khởi đầu `Unpersuadable` nếu `prior_kills ≥ kill_threshold`; khi `Engaged` và `prior_kills + persuasion_kills ≥ kill_threshold` → `Unpersuadable`; thắng + `Engaged` + điều kiện `named_unit_alive` đạt → `Persuaded`; thua trên map có faction → `Lost`.
- **Điểm:** `clean` = không quân người chơi nào chết (hoặc permadeath tắt); `low_kill = battle_kills ≤ kill_tolerance (2)`; `swift = turn ≤ turn_par`; `points = (clean ? 50 : 0) + (eligible && low_kill ? 50 : 0) + (eligible && low_kill && clean ? 25 : 0) + (swift ? 25 : 0)`; `eligible` = map có faction. Khi không đủ điều kiện tối đa 75 (khớp GDD-UI §7).
- **Kinh tế:** vàng một lần mỗi map: 15; Retrieve +15; thuyết phục faction (một lần mỗi faction) +20. Nâng chỉ số: 10 điểm/+1; trần 30 (HP 60); chỉ số nâng được `hp, str, mag, skill, speed, luck, def, res`.
- **Độ khó:** Story/Normal ×1,0, Hard ×1,08, Nightmare ×1,15 cho `enemy_stat_multiplier`; rewind Story ∞/Normal 5/Hard 3/Nightmare 0; permadeath Hard/Nightmare; `restraint_rule_active` tắt ở Nightmare.
- **Bond điểm hỗ trợ:** +1 mỗi hành động tấn công/hồi máu của quân điều khiển được khi bạn cặp đang sống và kề; tối đa 2 mỗi trận; cuối trận thắng cộng vào `support_points`.

## Phụ lục E — Danh sách kiểm tra khi tải map (GDD-Map §7; mỗi mục có test âm tính)

- `map_deploy_cap` ∈ [1,10] và ≤ số `deploy_tiles`; không có deploy tile trên ô impassable.
- Có `turn_par`; nếu có `turn_limit` thì `turn_par ≤ turn_limit`; Escort tính lượt: `turn_par ≥ escort_turns_required`; Seize: `turn_par ≥ hold_enemy_phases`.
- Mọi địch có `ai_profile` hợp lệ (ProtectPersuade, StandardAggressive, Raider); `key_unit_id` có thể trống.
- Escort tới đích: `escort_goal` trong map, đi được, trống lúc đầu; `escort_unit_id` là NPC đồng minh di chuyển được, không điều khiển; không khai báo đồng thời `escort_turns_required`.
- Protect vùng: `protect_zone` nằm trọn trong map, mọi ô đi được, không có địch bên trong lúc bắt đầu; `survive_enemy_phases > 0`.
- Retrieve: `item_tile` và `return_tile` khác nhau, trong map, đi được, trống lúc đầu.
- Seize: `control_point` trong map, đi được, trống lúc đầu; `hold_enemy_phases > 0`.
- Village: mỗi làng đúng một reward; `gold_amount > 0` hoặc `item_id` trỏ tới catalog thật; thiếu/thừa reward đều là lỗi.
- Mỗi map đúng một `objective_type` thuộc 5 giá trị.

## Phụ lục F — Truy vết checklist GDD → workstream/test

| Checklist GDD | Workstream |
| --- | --- |
| GDD-Combat §13: stat hợp lệ, vũ khí giải được, range min>max chặn | W2 (T2.9) |
| GDD-Combat §13: Player/Enemy Phase, `turn_number`, một Move một Action, Trade một lần không tiêu Action | W4 |
| GDD-Combat §13: preview toàn exchange, phản công theo tầm, chết chặn đòn còn lại, 0% hợp lệ | W3 |
| GDD-Combat §13: F-CC1…F-CC7, Physical/Magic, bond+buff cộng | W3 |
| GDD-Combat §13: Path/ThreatRange, min/max range, rỗng, không vòng vô hạn | W3 (T3.5), W6 |
| GDD-Combat §13: Heal, Use Item (+0 vẫn tiêu), Trade, Visit, Raider, AI fallback | W4, W7 |
| GDD-Combat §13: Buff overwrite/cộng/giảm theo lượt riêng/hết hạn/UI | W4 (T4.6), W13 |
| GDD-Combat §13: Dead/Incapacitated, kill/death events, Rewind khôi phục | W9, W11 |
| GDD-Map §10: tải map hợp lệ, dữ liệu sai bị chặn | W2 (T2.9), Phụ lục E |
| GDD-Map §10: đi xuyên quân mình, cost, passability | W3, W2 |
| GDD-Map §10: fog 3 trạng thái, địch VISIBLE hiện đủ chỉ số | W6 |
| GDD-Map §10: năm mục tiêu và biến thể, kết quả chốt đúng thời điểm | W5 |
| GDD-Map §10: Player → Địch → NPC; Retrieve khóa carrier; Seize liên tiếp; vùng Protect thua ngay | W5, W7 |
| GDD-Map §10: Village nhận/phá đúng một lần, Rewind phục hồi | W4, W5, W11 |
| GDD-Map §10: `battle_won` đúng một lần | W5 (T5.4) |
| GDD-UI §10: preview, vùng nguy hiểm, HP, bond/buff, menu hành động, Rewind, badge, chỉ báo áp lực | W13 |
| GDD-UI §10: Enemy Phase khóa input nhưng live, Pause + Xem Đội Hình ở cả hai phase | W13 (T13.6–T13.7) |
| GDD-UI §10: tổng kết Won/Lost, bỏ hàng kill khi không đủ điều kiện | W13 (T13.8), W10 |
| GDD-Roster §8: 12 ID duy nhất, filter Active, deploy cap, Dead/Incapacitated, bond và S, Save/Rewind, Trade ≤ 2 | W9, W11, W14, W4 |
