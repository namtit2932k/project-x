# Technical decisions

## Round-2 handoff (tài liệu "đợt 2", D01–D12 / N01–N13)

- **Forecast KHÔI PHỤC lại theo D01** (ghi đè đoạn cũ dưới đây): chọn unit (đã move hay chưa) →
  click địch trong ô đỏ (tính từ vị trí đứng) → `ForecastPanel` (src/scenes/battle/forecast_panel.gd)
  hiện dự báo lấy 100% từ `CombatResolver.forecast()` gồm double attack và bonus bond → Confirm mới
  commit `attack` qua director; Cancel / right-click hủy, unit vẫn ở vị trí cũ. Wait-sau-move: click
  lại chính unit / click ô khác / right-click.
- **Critical units (D02):** `UnitState.must_survive` + `BattleState.critical_units()`; chết bất kỳ
  unit nào critical → thua ngay. Prep tự chọn và khóa các unit bắt buộc khi chúng có trong
  `deployable_unit_ids`; `spared_commander` là `reconcile_event_key` trên UnitData (D03).
- **Rewind (D04):** `per_use` chính thức; chỉ frame PLAYER là điểm khôi phục (có snapshot đầu lượt);
  **RNG không restore** — `BattleState.from_dict` giữ seed hiện hành, replay sau rewind ra kết quả khác.
  Banner thua có nút Rewind nếu còn lượt; Nightmare không có.
- **Merge chỉ khi thắng (D06):** `src/core/campaign_merge.gd` — static `CampaignMerge.merge(...)`,
  thua không ghi gì vào GameState; màn thua có Retry chapter / Main menu (+ Rewind trên banner);
  camp ẩn "Next chapter" nếu chương chưa thắng.
- **EXP/level-up (D08):** chỉ phía người chơi tích EXP (attack cả khi bị né đều được cộng);
  `exp_per_level`, `level_cap`, `exp_gain_*` trong rules_config; roll growths bằng battle RNG, kết quả
  lưu `stat_bonus` trong roster và ứng lại vào chỉ số gốc mỗi trận; hậu trận liệt kê lên cấp.
- **Story flags & dialogue (D09):** `GameState.story_flags` lưu trong save; DialoguePlayer đặt cờ qua
  `set_flag`, hỗ trợ `portrait`. **True ending placeholder (D10):** `counts_for_true_ending` trên
  ChapterData + `GameState.is_true_ending_eligible()` hiển thị ở camp.
- **Esc pause (D11):** OptionPanel dùng chung với menu; khi pause chặn input bàn phím chuột và vòng
  pha địch treo; Quit to menu có hộp xác nhận mất tiến độ trận.
- **Test maps (N12):** 5 map `data/maps/test_<type>` + mục menu debug; smoke từng map (thắng/thua).
- **Fix engine trong đợt này:** `run_next_enemy_plan` không còn ở unit NPC trong pha địch — escortee
  đi bộ đúng trong pha NPC riêng của nó.

## Milestone-1 decisions (đợt 1, giữ lại làm lịch sử)



## Schema hội đồng (phiên 2 — theo đề xuất kiến trúc của designer/coder brief)

- **src/battle/ tách đúng thành các thư mục**: `state/` (BattleState, UnitState), `rules/`, `commands/`, `objectives/` (thêm **evacuate**), `ai/` (thêm **NpcAI**: NPC escort đi về đích qua director), `rewind/snapshot_stack.gd` (đổi tên class từ RewindSystem → **SnapshotStack**), `systems/`.
- **RulesConfig schema chốt:** `damage_formula_id` ("atk_minus_def", thêm nhánh mới qua CombatResolver), `rounding` (floor/round/ceil), `terrain_costs` (**địa hình × movement_type**), `rewind_per_difficulty`, `rewind_count_mode` (mặc định "per_use"; "per_step" chờ designer), `casualty_by_difficulty` (temp_injury / permadeath / none), `win_lose_priority` (global mặc định "lose", map.result_priority vẫn override được).
- **UnitDef schema:** `base_stats: {hp, atk, def, res, skl, spd, mov, crit, hit}` + `growths` (skeleton chờ designer chốt công thức level-up) + `portrait`/`sprite` (đường dẫn .png, rỗng = placeholder chip). Range vũ khí sống ở ClassDef theo schema; **ClassDef** thêm `weapon_type`, `special_action_id`, `stat_mods` (TBD).
- **MapDef:** map đặt trong thư mục riêng `data/maps/ch01_border_post/map.tres`; thêm `fail_conditions[]` (vốn dùng cùng bộ plugin objective, xét là lose) và `events[]` — skeleton với từ vựng trigger/action đóng (EventDef), executor engine là bước tiếp theo.
- **Items:** data/items/ + ItemData (category "objective" | "consumable"); item mẫu `item_border_relic`.
- **DataRegistry** giờ nạp đệ quy subfolder (một thư mục mỗi map), cảnh báo id trùng.
- **VALIDATOR mở rộng:** check base_stats/growths keys, weapon/movement type, event trigger/action vocabulary, item refs, casualty/rewind tables đủ 4 difficulty, và ràng buộc **bond bonus per-rank ≤ max_adjacent_bond_bonus (+16)** từ slide deck.

## Architecture

- **Logic/presentation split:** all rules live as `RefCounted` classes in `src/battle/`; scenes (`src/scenes/`) only render `BattleState` and forward mouse input through commands.
- **Single source of truth:** `BattleState` + `CombatResolver` are shared by forecast, combat screen, AI, objectives, post-battle and rewind. `CombatResolver.forecast()` is a dry-run of the same math `execute()` uses; the combat screen replays the recorded strikes (skippable, state ends identical).
- **Commands:** `move`, `attack`, `wait`, `skill`, `pickup`, `end_phase` — each confirmed action goes through `BattleDirector.commit()`, which pushes a snapshot (rewind: restore to last frame or selected frame, later frames dropped, counts against the difficulty budget).
- **Objectives are plugins:** `ObjectiveBase.create({type, params})` produces eliminate/escort/defend/retrieve/capture instances. Maps declare data only; `_check_battle_end()` aggregates and applies `result_priority` from map data when both win+lose fire.
- **Autoloads:** exactly 4 — `EventBus`, `DataRegistry`, `GameState`, `SaveService`. Communicating via signals (unit_moved, combat_resolved, objectives_changed, battle_ended, ...).
- **Data-driven:** `DataRegistry` scans `data/*/` for `.tres`; adding class/unit/map/faction/bond/skill/chapter/dialogue never touches core code. `rules_config.tres` holds all TBD numeric rules (terrain costs, hit/crit/damage, rewind budget, casualty policy, bond bonus).
- **Bond & reconcile:** pair list designer-only (never inferred); ranks rise only after `DialoguePlayer` scene watched/skipped; adjacency bonus sums unlocked ranks capped at +16 (rules_config). Reconcile: per-faction hidden `kill_threshold` + required event keys (`spared_<unit_id>` auto-recorded after a won battle;直接的 `record_event` cho designer-defined dialogue events); outcome stored in `GameState.reconcile_outcomes` for post-battle story.

## Scene/UI

- Screens are code-built `Control`s (placeholder art), flow controller `main.gd`: menu → story scene (`DialoguePlayer`) → prep → battle → post-battle → camp → next chapter.
- `BattleMapView` (`Node2D`) draws terrain colors, move/attack/target overlays, unit chips with HP bars; ready to swap behind real tilesets.
- Saves: manual between battles via `SaveService` → `user://save_game.json` (roster, exp/levels, casualties, chapter progress, bond ranks/scenes/S pairs, reconcile outcomes, difficulty, options).

## Test/tooling

- Headless runs via dedicated scenes (autoloads active): `tools/validate_data.tscn`, `tests/run_tests.tscn`, `tests/smoke_full_battle.tscn`.
- Smoke test drives a complete battle through `BattleDirector` with `EnemyAI` on both sides and asserts win, reconcile tracking, rewind budget, casualty/campaign merge.

## Known limitations / next candidates

- Skill effects: only `heal`; `damage_strike` etc. need effect implementation when designer defines the kit.
- Prep deployment is auto cell assignment (no drag-drop placement); overlay for enemy threat ranges (structure ready via `RangeHandler`).
- Per-map turn-limit enforcement UI, event dialog objects in maps — data + small glue (event executor).
- DialoguePlayer placeholder styling; charset/portraits pending art.
- Superseded: reconcile event keys now come from `UnitData.reconcile_event_key` (D03) — the old `spared_<unit_id>` derivation is gone.
