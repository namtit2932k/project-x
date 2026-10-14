# AGENTS.md — Project X

Read this file fully before touching the project. Update the **Work Log** section at the end of every session.

## 1. Project summary

- 2D turn-based tactical RPG (Fire Emblem-like), PC, single player, mouse-driven. Engine: **Godot 4** (GDScript).
- Setting: after a 15-year war between the Physical Empire (ordinary humans, firearms, long-range comms) and the Magic Kingdom (mana users, beastfolk), a peace treaty is signed. The player leads a small mixed squad (12 characters from both sides) to persuade remnant factions that reject peace.
- Chapter loop: story scene → squad preparation → tactical battle → post-battle result → camp (bond scenes, stats, save) → next chapter.
- Core hooks: bond system (adjacent units get bonuses), reconciliation (win the map **and** persuade the faction; kill count stays under a hidden threshold), rewind (limited by difficulty).

## 2. Roles and boundaries

- **Designer** decides rules, balance numbers, chapter conditions and content.
- **Dev (us)** builds systems, data tooling, functional UI and tests.
- Where a rule is marked "TBD" or "to be confirmed", **do not hardcode it**. Put it in `data/rules/rules_config.tres` (or the relevant data file) with a sensible placeholder, and note it under Open Decisions below. If it blocks you, ask.
- Placeholder content (story, art, balance) must be replaceable by production data without code changes.

## 3. Architecture rules (non-negotiable)

1. **Logic is separate from presentation.** All rules live in plain `RefCounted` classes under `src/battle/` and read/write a single `BattleState`. Scenes only render state and forward input.
2. **One source of truth.** Forecast, combat screen, AI, objectives, results and rewind all use the same `BattleState` and the same `CombatResolver`. Forecast calls it in dry-run mode. Never duplicate a damage calculation.
3. **Every confirmed player/AI action is a Command** (`move`, `attack`, `wait`, `skill`, `pickup`, ...). A snapshot is pushed before each confirmed command; rewind restores a snapshot and drops later ones.
4. **Data-driven.** Units, classes, skills, items, maps, objectives, factions, bonds, chapters and dialogue are data with **stable ids**. Adding a map, a bond pair or a faction must not require changing core code.
5. **Objectives are plugins.** Each objective type implements `evaluate(state)` returning win/lose/progress. Maps only declare `{type, params}`. No per-chapter win/lose logic scattered in code.
6. **Reusable modules over special cases.** Example: one `DialoguePlayer` takes dialogue data and renders it; a new dialogue is data, not new logic.
7. **Autoloads: only `EventBus`, `DataRegistry`, `GameState`, `SaveService`.** Do not add more without discussion.
8. Animations (combat screen) are skippable, but the resulting battle state must be identical either way.

## 4. Folder structure

```
data/        designer-owned content (rules, units, classes, items, skills, maps, factions, bonds, chapters, dialogue)
src/core/    autoloads and utilities
src/battle/  state, rules, commands, objectives, ai, rewind, systems (bond, reconcile)
src/scenes/  battle view, combat screen, prep, post_battle, camp, dialogue, menu
src/ui/      theme and shared components
assets/      sprites, portraits, tilesets, ui, audio, fonts
tools/       data validation scripts
tests/       unit tests for rules
docs/        technical decisions, how to run, test log
```

Put new code in the matching folder. If a new top-level folder seems needed, ask first.

## 5. Code conventions

- Language of code, identifiers, comments, commit messages and ids: **English**. No mixed-language names.
- GDScript style: `snake_case` for variables, functions and file names; `PascalCase` for classes (`class_name`); `UPPER_SNAKE_CASE` for constants; `_leading_underscore` for private members; signals named in past tense (`unit_moved`, `turn_ended`).
- Use static typing everywhere (typed variables, parameters and return types).
- Data ids: lowercase `snake_case` with a type prefix, e.g. `unit_swordsman`, `map_ch01`, `bond_swordsman_knight`. Ids are permanent once saved or referenced; never rename casually.
- No magic numbers: numeric rules go to `rules_config` or data resources.
- Keep functions small and single-purpose. Prefer composition and signals over deep inheritance or node-path coupling.
- Do not use `get_node` paths across unrelated scenes; communicate via signals or `EventBus`.
- Comments explain *why*, not *what*. Public functions get a one-line doc comment.

## 6. Game rules reference (current agreement)

- Phase order: player → enemy → NPC. A unit acts at most once per phase unless a skill says otherwise. The next phase starts only when the current one ends.
- Win/lose is checked after each relevant event: move, combat, turn change, NPC action.
- Movement: allowed through allies; cannot end on an occupied tile; cannot pass enemies or blocked tiles; cost depends on terrain.
- Selecting any unit (player, enemy, NPC) shows its move range; attack range is shown from the edge of the move range. Move range and attack range use different colors and update after moves or deaths.
- Combat flow: choose valid target → show forecast (hit, crit, damage, counter) → confirm → combat screen (attacker first, then counter if able) → return to map.
- Defeat: protagonist dies = game over. Map-specific fail conditions come from map data. Casualty handling of other characters depends on difficulty (**TBD**).
- Objective types: eliminate, escort, defend, retrieve (carrier may only move), capture and hold, evacuate. Primary objective and fail conditions must show in prep and in battle.
- Bond: pairs earn points from valid adjacent or support actions; points unlock C/B/A scenes; rank rises after the scene is viewed or skipped; only unlocked ranks give adjacency bonus (C +3, B +5, A +8, S +10; max total adjacent bonus +16). S unlocks after A plus a story milestone, both alive; one S pair per character. Eligible pairs come from a designer-provided list, never inferred from gender.
- Reconciliation: separate from map victory. Each faction has its own conditions; low damage alone is not enough. Player gets feedback by dialogue or attitude color; the threshold is hidden. Store which conditions happened and the outcome so post-battle story can read them.
- Rewind: snapshot includes positions, HP, turn, AI, items, objectives, bond points, reconcile state. Per battle: Story unlimited, Normal 5, Hard 3, Nightmare 0. Permadeath: off for Story/Normal, on for Hard (verify with designer).
- Save: manual, between battles only, never mid-turn. Stores roster, stats, casualties, chapter progress, bond points/ranks/scenes/S locks, story branch, difficulty, outcomes. Options: volume, windowed/fullscreen. Difficulty can change between battles.

## 7. Open decisions (do not hardcode)

Track here. Remove an item once the designer confirms it.

- Damage formula, hit/crit rates, strike order
- Terrain costs and class special actions
- Final roster and classes
- Casualty/permadeath rules per difficulty
- Per-map conditions
- Bond pair list and S routes
- Reconciliation thresholds
- Ch01 win objective vs reconcile: a plain rout kills the commander, so `spared_commander` never fires and persuade stays unreachable. Designer to pick: targeted objectives (commander excluded), commander surrender, or a bigger kill_threshold.
- Rewind valid restore point: currently the newest PLAYER-phase frame incl. a turn-start snapshot (DESIGNER: action-level or turn-level only?). RNG state restores so the re-roll sequence stays identical (reseed alternative pending).
- Bond point actions implemented as: attack supported by an adjacent pair-member ally, and heal between pair members (bond_points_combat_action). Bonus applies to damage AND hit — designer confirms which one.
- Defeat flow placeholder: camp shows "Retry chapter" (replays the same chapter); designer confirms retry vs load-save.
- Who is the protagonist: only unit_swordsman has is_protagonist = true; game over on protagonist down (World doc: leader + beastwoman co-lead pending).
- Scope mismatches between docs: "evacuate" objective, Nightmare difficulty and a future shop appear in the concept deck but not all in the coder brief

## 8. Assets and UI

- Request or expect assets as `.png` with transparent background, same canvas size and resolution per frame, equal spacing if packed in a sprite sheet. Each asset needs a description: purpose and which scene uses it.
- UI is laid out for 16:9 (1920×1080) first. Check fonts and element sizes against that before accepting a handoff.
- Use placeholder art for anything missing; keep it behind the same data ids so it can be swapped.

## 9. Git workflow

- Branches: `main` (stable), `develop` (integration), `feature/<short-name>`, `fix/<short-name>`.
- Small commits with English messages in the form `type(scope): summary`, e.g. `feat(battle): add threat range overlay`.
- Do not edit the same file as another active branch without coordinating; prefer splitting files by module to avoid conflicts.
- Do not commit generated or `.godot/` cache files.

## 10. Testing and definition of done

A task is done when:

- It runs in Godot without errors or warnings.
- Rules code has tests in `tests/` (movement, range, damage, objectives, rewind, save/load, bond S).
- Data validation passes (`tools/`: duplicate ids, broken references, missing fields).
- Forecast, combat screen and post-battle HP agree.
- Every mouse interaction works: select tile/unit/target, cancel, confirm.
- Docs and this file are updated if a decision changed.

Milestone 1 target: play one full chapter with the mouse, result recorded, return to camp without losing state.

## 11. Working as an AI agent here

- Before coding: read this file, `docs/`, and the Work Log. Do not re-ask things already decided.
- Prefer extending existing modules over writing new one-off code. Check for an existing module first.
- Make the smallest change that satisfies the task. Do not refactor unrelated code.
- If a requirement is unclear or marked TBD, create a config entry and ask, rather than guessing and hardcoding.
- When finishing, append to the Work Log: what you did, what is in progress, what is next, known issues. Keep entries short so the next agent can pick up without re-reading everything.
- Do not delete or rename data ids, autoloads or public APIs without explicit approval.

## 12. Work Log

Newest first. Format: `YYYY-MM-DD — agent/person — done / in progress / next / issues`.

- 2026-10-15 (6) — Buffy (Codebuff) — done: P0 review fixes theo handoff doc: T01 side tách khỏi faction (đội hỗn hợp Empire+Kingdom hoạt động: select/move/pass-through/eliminate/AI/map view màu theo side + faction_override), T02 command.check() trong director (trước mỗi apply; attack bằng manhattan trong [min..max], check cả skill/pickup, carrier move-only, AI move bị từ chối → wait), T03 rewind deep-copy lồng nhau + RNG state + khôi phục chỉ frame PLAYER + turn-start snapshot + labels/label, T04 escort dùng target_cell (thêm map sample valley_escort), T05 reconcile chỉ cho remnant faction (empire/kingdom rỗng), spared_event_keys mapping, evaluate cùng schema mọi lần, T06 bond điểm từ attack có đồng minh cặp kề + heal cặp, merge bond_points vào GameState sau trận, so rank theo BOND_RANKS index, S exclusive, T07 advance_chapter dùng current_chapter().id + advance trước camp trên thắng + Retry chapter khi thua + new_game giữ difficulty/options + merge roster thiếu + story_branch, T08 DataRegistry nạp .tres/.res/.remap cho export. Tests 92/92, smoke 12/12, validation 0. — in progress: P1 (T09-T13, T14-T16). — next: hành trình P1 theo thứ tự tài liệu. — issues: ch01 rout vẫn làm persuade bất khả thi (mở quyết định designer §7).

- 2026-10-15 (5) — Buffy (Codebuff) — done: luồng tương tác mới: sau move chỉ hiện ô đỏ tầm đánh (ranged xa hơn theo ClassDef), bỏ nút Attack/Wait (click unit lại / ô khác / right-click sau move = Wait), click địch trong ô đỏ = auto combat screen, HP cập nhật ngay trên map sau màn giao chiến; bỏ forecast panel UI (CombatResolver.forecast vẫn giữ làm dry-run). Tests: 51/51 + smoke 10/10 — commit + push. — in progress: none. — next: event executor, evac map mẫu, CI, level-up growths, retry flow. — issues: none.

- 2026-10-15 (4) — Buffy (Codebuff) — done: bỏ tên làm việc "Ceasefire": chỉ còn "Project X" (README, AGENTS, docs/how_to_run, menu title UI); boot sạch; commit 50c8d0f đã push. — in progress: none. — next: như trước (event executor, evac map mẫu, CI, level-up theo growths). — issues: none.

- 2026-10-15 (3) — Buffy (Codebuff) — done: README.md cho repo công khai; git init + commit đầu (158 files) + push lên origin main (github.com/namtit2932k/project-x). — in progress: none. — next: như phiên trước (event executor, evac map mẫu, level-up theo growths, retry sau thất bại). — issues: none.

- 2026-10-15 (2) — Buffy (Codebuff) — done: tái cấu trúc theo schema đề xuất: src/battle/state/ & rewind/snapshot_stack (SnapshotStack); RulesConfig schema (damage_formula_id, rounding, terrain_costs x movement_type, rewind_per_difficulty, rewind_count_mode, casualty_by_difficulty, win_lose_priority); UnitDef (base_stats+growths+portrait/sprite, regen 16 .tres) + ClassDef (weapon_type/special_action_id/stat_mods skeleton); DataRegistry nạp đệ quy; map về data/maps/ch01_border_post/; objective plugin evacuate mới + NpcAI wired vào director/scene; MapDef thêm events[]/fail_conditions[] skeleton + EventDef; data/items/ + ItemData; validator mở rộng theo schema + test bond cap 16 + test evacuate + test terrain costs. Checks: 34/34 rule tests, smoke 10/10, validation 0/0, boot sạch. — in progress: none. — next: damage_formula_id thứ hai (để designer A/B công thức), event executor engine theo EventDef, evac map sample dùng NpcAI, level-up theo growths khi designer chốt.

- 2026-10-15 — Buffy (Codebuff) — done: milestone-1 vertical slice. Autoloads (EventBus/DataRegistry/GameState/SaveService); rules core (BattleState, movement Dijkstra, attack range from move-edge, CombatResolver shared by forecast/combat/AI); commands (move/attack/wait/skill-heal/pickup) via BattleDirector with snapshots; rewind by difficulty (+ Story∞/Normal5/Hard3/Nightmare0, permadeath flags in rules_config); objective plugins eliminate/escort/defend/retrieve/capture; bond system (designer pair list, C/B/A scenes via DialoguePlayer, adjacency bonus capped 16) and reconcile system (hidden kill threshold + required events, outcome stored); sample data built from the concept docs (12 classes + 4 ch01 units, map_ch01, chapter, dialogues, bond pair, factions); scenes menu→story→prep→battle(mouse: select/move/attack/forecast/combat screen placeholder)→post-battle→camp (roster, bond scenes, save, difficulty)→next chapter; validator + 24 rule tests + full-battle AI smoke (all green, validation 0 errors). — in progress: none. — next: retry-after-defeat flow, threat range overlay for enemies, more chapters/maps exercising escort/defend/retrieve/capture, prep drag-drop deployment, options polish. — issues: enemy AI is a naive approach/attack bot; reconcile event keys currently `spared_<unit_id>` (designer to confirm mapping); combat screen is placeholder graphics; defeat ends chapter loop without retry.
