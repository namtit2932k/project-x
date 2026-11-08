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
- **Player-facing text is never a bare string (I18N).** Wrap it as `UIBuilder.t("English source text")` (battle logic: `ObjectiveBase._t()` / `TranslationServer.translate()`), format after translating (`UIBuilder.t("Turn limit: %d") % n`), and add the row to `data/i18n/strings.csv` with **both** `en` and `vi`. Data that is shown to the player (passive names, skill display names) stores the English key. The validator and `test_i18n` fail on a missing row or an empty column.

## 6. Game rules reference (current agreement)

- Phase order: player → enemy → NPC. A unit acts at most once per phase unless a skill says otherwise. The next phase starts only when the current one ends.
- Win/lose is checked after each relevant event: move, combat, turn change, NPC action.
- Movement: allowed through allies; cannot end on an occupied tile; cannot pass enemies or blocked tiles; cost depends on terrain.
- Selecting any unit (player, enemy, NPC) shows its move range; attack range is shown from the edge of the move range. Move range and attack range use different colors and update after moves or deaths.
- Combat flow: choose valid target → show forecast (hit, crit, damage, counter) → confirm → combat screen (attacker first, then counter if able) → return to map.
- Defeat: any critical unit (protagonist or must-survive) dies = game over. Map-specific fail conditions come from map data. Casualty policy per difficulty lives in `rules_config.casualty_by_difficulty` (see D06).
- Objective types (F-OBJ): elimination, protect (unit or zone), escort (destination or timed), retrieve (carrier may only move), seize. Primary objective and fail conditions must show in prep and in battle.
- Bond (F-BOND): a pair earns +1 (max 2 per map) when one member performs an Attack/Heal next to the other; 2/5/9 points (plus a chapter gate) unlock the C/B/A scenes; rank rises after the scene is viewed or skipped; only unlocked ranks give adjacency bonus (C +3, B +5, A +8, S +10; max total adjacent bonus +16). S unlocks after A plus a story milestone, both alive; one S pair per character. Eligible pairs come from a designer-provided list, never inferred from gender.
- Reconciliation: separate from map victory. Each faction has its own conditions; low damage alone is not enough. Player gets feedback by dialogue or attitude color; the threshold is hidden. Store which conditions happened and the outcome so post-battle story can read them.
- Rewind: snapshot includes positions, HP, turn, AI, items, objectives, bond points, reconcile state, and EXP/level/live combat stats (F-EXP). Per battle: Story unlimited, Normal 5, Hard 3, Nightmare 0. Permadeath: off for Story/Normal, on for Hard (verify with designer).
- Class passives (F-PAS): every class has one fixed conditional passive (catalog in `rules_config.passive_catalog`); Bard has no weapon, cannot attack or counter, and uses Encore to give an adjacent ally that already acted another Move + Action; Healer cannot attack.
- EXP (F-EXP): a player unit gets a flat 25 EXP for each Attack or Heal it performs (hit or miss, kill or not); nothing else pays. 100 EXP = level up (cap 20), each stat rolls its class growth rate. A unit that dies earns no EXP; a full-HP ally cannot be healed. Losing is a game over: nothing from that battle is kept.
- Save: manual, between battles only, never mid-turn. Stores roster, stats, casualties, chapter progress, bond points/ranks/scenes/S locks, story branch, difficulty, outcomes. Options: volume, windowed/fullscreen. Difficulty can change between battles.

## 7. Open decisions (do not hardcode)

Track here. Remove an item once the designer confirms it.

- Special action of Beastwoman (beast transformation) and other classes — `special_action_id` empty for now
- Final damage/hit/crit formula numbers (schema implemented, numbers are placeholders)
- Final terrain cost/bonus table
- Story content and the true-ending scene
- Final bond pair list and S routes (current list is a placeholder incl. two pairs for Swordsman)
- Casualty *effects* for non-permadeath difficulties ("wounded" is recorded, no other mechanic yet)
- **R1 — hit chances.** Addressed by F-CC-FE (FE-style tuning, `hit_base = 70`, no triangle — designer-confirmed). Only playtest tuning remains.

### From the DEMO_PARITY_PLAN (v2) — technical decisions D-A, applied defaults

- **D-A1 (approved default applied):** two numeric sets coexist via `balance_profile`.
  `rules_config.balance_profile = "demo"` overlays `data/balance/demo/` on the base layers
  (same ids replace base entries; one rules overlay under `data/balance/demo/rules/` carries
  the demo Forest +12). Default stays `demo` for the 6 example maps until the designer sends
  GDD-scale scenario data. (D-B10/R1 note: the combat formula itself was switched to the GDD
  one on the user's instruction on 08-11-2026 — see F-CC; the low hit chances stay open as R1.)
- **D-A2 (partial):** unit stat keys — demo layer uses GDD keys
  (`hp,str,mag,skill,speed,luck,def,res,move,base_vision`); the old ch01 layer keeps legacy
  keys. Validator accepts either but rejects a single unit mixing both. Migration of
  `GameState` saves is still pending (W9).
- **D-A6:** demo scenario NPC use side-player-with-`controllable=false` semantics via
  `faction_neutral` + `controllable=false`; base-layer `side npc` stays.
- **D-A5/D-A8:** all demo JSON ported to `.tres` via `tools/import_demo_data.gd` (rerunnable,
  erases only its output roots). Demo unit templates get the dedicated `unit_demo_` prefix so
  they never silently replace base-roster ids; item ids are un-prefixed additions (`item_potion`...).
- **Weapon ids normalized:** every weapon id carries the `weapon_` prefix (`weapon_sword`,
  `weapon_lance`, `weapon_staff`, `weapon_unarmed`, `weapon_iron_sword`...).

### Pending designer questions D-B (temporary defaults in code/data)

- D-B1 rounding `.5`: truncate (`int`) — affects Magician crit vector; not yet a test
- D-B2 `base_vision` per class: placeholder table in `rules_config.terrain_vision`; Hill does not block LoS
- D-B3 Hazard effect: none (like Plain)
- D-B4 class Move: demo scenario values
- D-B5 enemies attack allied NPC: yes (like demo)
- D-B6 carrier Retrieve auto-Acted after moving: not yet implemented (W4)
- D-B7 `priority_target_id`: optional field honored by AI later (data carries it now)
- D-B8 Visit with full bag: block only item-reward villages when usable (W4)
- D-B9 Protect(unit) params: `protect_unit_id` + `survive_enemy_phases` on MapData
- D-B11 recruit order: not hardcoded; demo chapters deploy Swordsman + Knight only
- D-B12 Civilian/unarmed units: kept (class_civilian, move 2/0 are scenario values, validator exempts non-controllable from move 4–7)
- D-B13 faction states Unengaged/Engaged/Unpersuadable/Persuaded (+ demo Lost): W8

## 7b. Decisions log (round-2 design document)

---

Committed here from the round-2 "đợt 2" handoff; removed from section 7. **D01 and D02 are
directly confirmed by the designer. D03–D12 are reasonable proposals fixed so the agent did
not have to wait — every number/flag lives in `rules_config` or data and can be changed
without code edits.** Round-2 doc wins over the round-1 doc when they conflict.

**P-01 source hierarchy (19.10.2026, `DEMO_PARITY_NEXT_STEPS.md`):** approved GDD
(`docs/reference/*.docx`) > D01, D02 (designer-confirmed) > D03–D12 only when they do not
conflict with the GDD > demo (data + UI behaviour) > old repo. **D05, D07, D08, D12 are
superseded provisionally by P-02/P-03/P-04/P-05 (19.10.2026).**

### P-decisions P-01…P-15 (provisional, 19.10.2026 — from DEMO_PARITY_NEXT_STEPS.md)

| ID | Decision | Reverse via |
| --- | --- | --- |
| P-01 | Source order: approved GDD > D01/D02 > D03–D12 (not conflicting) > demo > old repo. | Update this §7b. |
| P-02 | Bond bonus lands on ALL of accuracy, avoid, crit, damage (`bond_bonus_targets`); points rule of D05 unchanged. | Edit `rules_config.bond_bonus_targets`. |
| P-03 | The shop IS built (shop demo parity); `shop_enabled = true` for campaign demo, legacy camp keeps its stub. | `shop_enabled = false`. |
| P-04 | ~~No in-battle EXP/level-up: `exp_enabled = false` by default.~~ **Superseded by F-EXP (08-11-2026):** EXP is on by default per the GDD. | `exp_enabled = false`. |
| P-05 | `combat_formula_set = "gdd"` (F-CC1…F-CC7) is the default; "legacy" keeps old formulas. Old tests set `legacy` locally, none deleted. | `combat_formula_set = "legacy"`. |
| P-06 | Rewind per_use + no RNG restore stay; ADD post-Trade boundary, Chọn-mốc screen, quick rewind to last player boundary (W11). | Trim W11 scope. |
| P-07 | `must_survive` stays for legacy `unit_beastwoman`; the DEMO protagonist is `unit_demo_swordsman` (`is_protagonist = true`). | Data edit. |
| P-08 | `chapter_ch01` leaves the main flow (`campaign_tag = "legacy"`); debug-only menu entry. Base-layer classes/units carry the GDD stat table (Appendix C) read through the F1 alias. | `campaign_tag` data edit. |
| P-09 | D06 stays (defeat merges nothing, EXP included — designer: losing is a game over, F-EXP); add losing-screen points breakdown marked "not applied" (GDD-UI §7, W13). | UX scope trim. |
| P-10 | D09/D10/D11 stay; pause gains read-only "Xem Đội Hình" usable during Enemy Phase (W13). | UX trim. |
| P-11 | Demo bond: Swordsman–Knight start rank C with 2 points; B at 5 points (`bond_demo_swordsman_knight`; `[PENDING-GDD: Bond]`). | Data edit. |
| P-12 | In-battle action menu per GDD-UI §4 (Attack/Heal/Use Item/Visit/Trade/Wait) replaces "re-click unit = Wait" for the DEMO campaign; Forecast preview + Confirm/Cancel, right-click = cancel. | Keep D01 flow for legacy. |
| P-13 | Config flags (data-only, no hardcode): `combat_formula_set`, `exp_enabled`, `shop_enabled`, `fog_enabled`, plus `bond_bonus_targets`. | RulesConfig edit. |
| P-14 | Frame is 1280×720 only (no dual resolution); every scene rebuilt on containers when W1/W12/W13 run. | Approved D-A3. |
| P-15 | D-B1…D-B13 defaults stay as recorded; `[PENDING-GDD]` items follow the demo. | Designer answers. |

### Known mismatches until W5 — resolved by F-OBJ (08-11-2026)

The demo maps now run on the GDD objective plugins (F-OBJ below). Still data-only, not wired: priority-target AI and the restraint rule (W7).

- **D01 — Forecast restored (confirmed).** Attack flow: select unit (may move) → click an
  enemy on a red tile (measured from the current position) → ForecastPanel → Confirm/Cancel
  (right click = Cancel) → combat screen. Panel shows both sides: name, HP, Hit%, Crit%,
  damage per strike, double attack second strike, and whether a counter happens — 100% from
  `CombatResolver.forecast()`. No Attack/Wait buttons; Wait-after-move stays
  re-click-the-unit / click-a-non-target-tile / right click.
- **D02 — Protagonist (confirmed).** Only Swordsman has `is_protagonist = true`. Added
  `must_survive` to UnitData (`true` for Beastwoman); the death of any protagonist or
  must-survive unit loses immediately (`protagonist_death_loses`; `BattleState.critical_units()`).
  Prep auto-selects and locks such units when present in `deployable_unit_ids`, they count
  toward `deploy_max`; validator checks forced units ≤ deploy_max.
- **D03 — Ch01 data & reconciliation.** Ch01 objective eliminate targets the three soldiers
  only; the commander survives and "surrenders" on victory. `reconcile_event_key` on UnitData;
  the commander carries `spared_commander`, recorded only for living units on remnant sides.
  `faction_rebel_ch01` keeps `required_events=["spared_commander"]`, `kill_threshold=4`
  (placeholder number for the first map). Reconcile blocks removed from the base factions.
- **D04 — Rewind.** Counting mode `per_use` is official (one click = one use regardless of
  restored steps). Valid restore points: PLAYER-phase snapshots only (each confirmed player
  command plus one snapshot per turn start). Rewind undoes the last player action; from a
  turn start it drops to the last action of the previous turn, skipping the enemy/NPC phase
  in between. RNG is NOT restored (no seed reset in `from_dict`) — replays roll differently.
  Defeat banner shows a Rewind button when budget allows (never on Nightmare); victory never.
- **D05 — Bond. (Point rules and thresholds superseded by F-BOND, 08-11-2026.)** Points: after every combat, for each valid pair, when one member fought
  (attacker or defender) and the other lives, is player-side and stands adjacent (manhattan
  1) — plus the same value for a support skill (heal) between pair members
  (`bond_points_combat_action`, cap 20/battle/pair). Adjacency bonus applies to the stat in
  `rules_config.bond_bonus_stat` (default `power`), never to hit. Rank order compared via
  GameState.BONDS index; B requires C viewed/skipped, A requires B. S needs A, both alive,
  past `s_milestone_chapter_id`, and exclusivity (one S pair per character). Pairs (placeholder):
  `bond_swordsman_knight`, `bond_swordsman_beastwoman`, `bond_lancer_gunner` with placeholder
  C/B/A/S dialogues; validator reports a missing dialogue for any threshold rank.
- **D06 — Defeat & casualties.** Only a VICTORY merges into the campaign (exp, casualties,
  bond, reconcile, chapter completion); defeat writes nothing. Defeat result screen offers
  Retry chapter (same chapter, pre-battle roster), Main menu, and Rewind on the banner.
  Camp hides "Next chapter" while the current chapter is not completed. Casualties:
  Story/Normal = temp_injury (fuel restoration, "wounded" recorded), Hard/Nightmare = permadeath.
- **D07 — Scope.** Nightmare stays. No shop (camp keeps a stub only). Evacuate keeps its deck
  definition. An "escape" objective type is backlog P3, not in the slice.
- **D08 — EXP & level-ups. (Superseded by F-EXP, 08-11-2026 — kept for history.)** Only the player side earns EXP; attacking or being attacked pays
  even when the target avoids (`exp_gain_hit`, `exp_gain_nonlethal_loss`, `exp_gain_kill` in
  config). `exp_per_level = 100`, `level_cap = 20`. On level-up each growth stat rolls its
  percentage on the battle RNG; gains accumulate into roster `stat_bonus` and are recomputed
  into base stats each battle. Post-battle lists who leveled and which stats rose.
- **D09 — Dialogue & story flags.** Each line optionally carries `portrait` (path, empty =
  placeholder) and `set_flag` (story flag). `GameState.story_flags` Dictionary saved in
  campaign saves (SAVE_VERSION-aware, old saves read as empty). `DialoguePlayer` sets flags on
  playback. CSV import tool = backlog P3.
- **D10 — True ending (placeholder).** `counts_for_true_ending` on ChapterData (ch01 true);
  `GameState.is_true_ending_eligible()` = every flagged chapter completed AND its remnant
  factions persuaded. Camp shows this status; the real ending scene awaits content.
- **D11 — Esc pause & quit.** Esc in battle opens pause: Resume / Options (reuses the shared
  options panel) / Quit to menu with a confirm box explaining battle progress is lost (saves
  are between battles only; closing the window likewise). Pausing blocks map input and stalls
  the enemy phase loop.
- **D12 — Numbers unchanged.** `atk_minus_def`, rounding floor, `win_lose_priority = lose`,
  current hit/crit and terrain tables, 12-character roster. `turn_limit > 0`: running out =
  defeat, turns left shown on the HUD; ch01 has none. Beastwoman's beast transformation is
  NOT implemented (`special_action_id` empty).

### F-CC — Combat formula rewrite from the approved GDD (08-11-2026, `core-combat-system.md` F-CC1…F-CC7 + `damage-heal-formulas.docx`)

Supersedes D-B10's formula question (the low hit chances it warned about stay open as **R1** in §7) and the old `hit_base/hit_scale_*/hit_variance/crit_base/crit_scale_skill/crit_multiplier=2.0/double_attack_speed_gap=5` shape in `rules_config`/`CombatResolver`. Per P-01's source hierarchy the approved GDD overrides the prior placeholder formula outright; this was never a `combat_formula_set` branch choice ("legacy" vs "gdd") — that field existed in `rules_config` but `CombatResolver` never actually read it, so there was only ever one (wrong) formula in code. The field stays for future "legacy old-repo" use but is not branched on yet.

- **Accuracy** `= skill*2 + luck*0.5 + hit_bonus (class/unit misc modifier) + weapon_accuracy_mod (from WeaponData of attacker.weapon_id) + bond adjacency bonus ("accuracy" group)`.
- **Avoid** `= speed*2 + luck*0.5 + terrain_avoid_at(defender) + bond adjacency bonus ("avoid" group)`. Ally aura bonuses (e.g. Bard +3 Avoid) are a passive-system concern (12-class passive catalog, not yet built — see Open Decisions) and are NOT part of this pass.
- **Hit%** `= clamp(Accuracy - Avoid, 0, 100)` — a direct subtraction, no base-100 term, no variance/RNG spread on the percentage itself.
- **Crit%** `= clamp(skill*0.5 + weapon_crit_mod - defender.luck*0.5 + bond adjacency bonus ("crit" group), 0, 100)`.
- **Damage** `= max(0, offense_stat + weapon_might - defense_stat + bond adjacency bonus ("damage" group))`, where offense/defense pick Str/Def for `damage_type=="physical"` or Mag/Res for `"magic"`. Terrain no longer feeds damage (terrain_defs.def_bonus is legacy/unused by combat math — terrain only feeds Avoid, already noted in rules_config comments).
- **Source conflict noted:** the one-page `damage-heal-formulas.docx` (marked "BẢN TẠM", provisional) leaves weapon might out of Damage "until weapon design is locked"; `core-combat-system.md` F-CC5 — the formula authority per the GDD's own reading guide — includes `weapon_might`. Code follows core-combat.
- **CritDamage** `= floor(Damage * crit_multiplier)`, `crit_multiplier` now **2.5** (was 2.0).
- **Double attack** threshold now reads `rules_config.double_threshold` (already present, GDD value **4**); the old separate `double_attack_speed_gap=5` field is removed as dead/superseded.
- **Heal** is unaffected by this pass (no Hit/Crit roll on Heal per GDD — verify `skill_command.gd`/heal path separately; not touched here).
- Nuke/burst passive bonuses (Magician), terrain-ignore (Gunner), and all other per-class conditional passive math are explicitly **out of scope** — tracked under the still-open "12 class passives" item below.
- `rules_config.tres`/`data/balance/demo/rules/rules_config.tres` do not override any of these numeric fields today (only `terrain_defs`), so no `.tres` data edit was needed beyond the `.gd` default change; profile `"demo"` and `"gdd"` now share one correct formula.
- Existing rule tests that encoded the old formula's implicit "100 base" hit assumption (`test_forecast_matches_execution`) were updated to set enough `skill` for a deterministic 100% hit under the new formula instead of relying on the removed base-100 term.

### F-CC-FE — Fire Emblem tuning of the combat formula (designer decision 08-11-2026, overrides parts of F-CC)

The GDD formula gave ~9% average hit (R1). Designer: "follow Fire Emblem, no 2RN, hit base 70 for now". Changes on top of F-CC (all numbers in `rules_config`):

- **Accuracy** `= hit_base (70, provisional) + skill*2 + luck*0.5 + hit_bonus + weapon_accuracy_mod + bond`. `hit_base` stands in for FE's per-weapon Hit stat (70–95); weapon mods stay ±15 for now. Moving to a per-weapon Hit table later = set `hit_base` to 0 and author weapon Hit values.
- **Avoid** `= speed*2 + luck*1 + terrain + bond` (FE uses full Luck; was ×0.5).
- **Crit%** `= skill*0.5 + weapon_crit_mod + crit_bonus − defender.luck*1 + bond` (FE crit evade = full Luck; was ×0.5).
- **CritDamage** `= floor(Damage * 3)` (FE ×3; was ×2.5).
- **No 2RN:** one roll against the displayed Hit%, so the shown number is the true chance (keeps GDD Pillar 2).
- Unchanged from F-CC: Hit% clamp 0–100, Damage = Str/Mag + might − Def/Res + bond, double attack at Speed gap ≥ 4.
- **Designer-confirmed (08-11-2026, later the same day):** no weapon triangle; keep `hit_base = 70` (one value for every weapon, no per-weapon Hit table). FE's Attack Speed (weight vs Con) not adopted.
- **Still open:** demo-layer enemies (raider/guard, Skill 23) use a different stat scale and now hit almost always.
- Result with current data: roster vs roster 73% average on plain (41–100%), 61% in forest +12; roster → ch01 rebels 88%; rebels → roster 54%.

### F-PAS — Class passives + Bard Encore from the GDD (08-11-2026, `core-combat-system.md` Core Rule 3b, Core Rule 11, F-CC7/F-CC11/F-CC15, Authored Passive Catalog)

Replaces the flat `crit_bonus`/`hit_bonus` idea of a passive (GDD retired it). Each class has one fixed `passive_id` (`BattleClassData.passive_id`, enemies of that class too); the catalog — effect type + numbers — lives in `rules_config.passive_catalog`, the effect logic in `src/battle/systems/passive_system.gd` (`PassiveSystem`), dispatched on `effect_type` so a number change is data-only.

| Class | passive_id | Effect (GDD numbers) |
|---|---|---|
| Swordsman | `disarming_strike` | Attack hit → target Def −3 for 2 of the target's turns |
| Knight | `iron_retaliation` | Defending, HP ≥ 50% at the start of the exchange and survives → 4 damage to the attacker |
| Lumberjack | `battle_bloodlust` | Attack hit → heal floor(damage × 0.3) |
| Lancer | `twin_lance_strike` | Attacking → always strikes twice in a row first, then the enemy counters (designer change 08-11-2026) |
| Gunner | `cover_piercing_shot` | Attacking from exactly its max weapon range → defender's terrain Avoid = 0 |
| Wyvern Knight | `survival_instinct` | The first time it would die in a battle (any combat damage, attacking or defending, thorns included) → revived at 1 HP (once per battle; designer change 08-11-2026) |
| Beastwoman | `feral_regeneration` | After its own Attack or Heal → heal 5 |
| Magician | `fragile_magic_circle` | Phase began at full HP → +5 damage on the first strike of its first Attack that phase (flag consumed even on a miss) |
| Bard | `inspiring_melody` | Every other ally cardinally adjacent to the Bard gets +3 Avoid |
| Healer | `devoted_mentor` | Heals another ally → that ally gets +10 EXP (F-CC14) |
| Magic Swordsman | `extended_reach` | HP ≥ 75% → max weapon range +1 (attack legality and threat range) |
| Assassin | `silent_assassination` | Target has not acted yet this phase → no counterattack |

- **Debuff (F-CC11):** `UnitState.active_debuffs {stat: {amount, turns_remaining}}`, re-applying overwrites; every combat formula reads stats through `UnitState.eff()`. It counts down on each of the debuffed unit's own Ready→Acted transitions (director, after a command flips `acted`) and disappears at 0.
- **Lancer (designer change 08-11-2026, overrides the GDD "force a second strike"):** the Lancer's two strikes come back to back before any counter — order A, A, then the defender's counter (and the defender's own second strike if its Speed check passes). Never three strikes even with a Speed advantage.
- **Bard (Core Rule 3b):** no weapon (`weapon_id = ""`), `can_attack = false` — cannot Attack or counterattack. Active action **Diễn Tấu / Encore** = skill `skill_encore` (effect `encore`, range 1): target an adjacent `Acted`, alive ally that is not itself an Encore user (no chains); Bard becomes Acted, the target gets a fresh Move + Action this phase (its Trade / Magician flags are not reset); Bard earns 25 EXP (F-CC13). `weapon_light_rapier` stays in data but is no longer used by any class.
- **Healer cannot Attack** (GDD Core Rule 3: a Heal-category weapon has no Attack) — same `can_attack` check, from the weapon's `action_category` (Heal/None weapons cannot attack or counter). Classes with no weapon record keep attacking as before (legacy enemies).
- **Rewind:** `active_debuffs`, `miracle_used`, `fragile_circle_ready` are in `UnitState.to_dict()`.
- **Implementation choices where the GDD is silent:** (a) an exchange is fully planned before it runs (forecast = execution), so a debuff or lifesteal from strike 1 does not change strike 2's numbers — the debuff applies from the next exchange; (b) Knight's 50% check reads HP at the start of the exchange; thorns damage can kill the attacker; (c) — removed: the designer widened Wyvern Knight's save to any death in combat; (d) — replaced: **the player picks the target for Encore and Heal** (designer 08-11-2026). Pressing the skill button enters target selection (valid targets highlighted, from `SkillCommand.check`); left click a highlighted unit commits, right click cancels without spending the action.
- **Preview (closes GDD Core Rule 11f's open UI gap, 08-11-2026):** formula effects (debuff on later exchanges, aura, extended range, burst, terrain-ignore, Lancer double, no-counter) were already in the forecast numbers; now `CombatResolver.forecast()` also returns `notes` — one entry per passive that applies to this exchange, built by `PassiveSystem.forecast_notes()` as data `{owner: attacker|defender, name, effect_type, value, ...}` — and `ForecastPanel` lists them under each side with the passive's display name (`passive_catalog[...].name`, the GDD Vietnamese names). Covered: lifesteal (HP per hit), thorns (if the defender survives), survive-once (while unused), regen, debuff on hit, Lancer double, terrain-ignore, burst, no-counter, extended range, Bard aura on either side, and debuffs already active on either unit. Mentor EXP belongs to Heal, shown nowhere in the attack forecast. `execute()` does not build notes (forecast only).

### F-HEAL — Heal formula from the GDD (08-11-2026, `core-combat-system.md` F-CC9, `damage-heal-formulas.docx`)

- **HealAmount** `= healer Mag (effective) + heal_might` of the healer's Heal-category weapon; target HP after = `min(hp + HealAmount, max_hp)`. No Hit/Crit roll. One helper, `CombatResolver.heal_amount()` / `heal_range()` / `heal_preview()`, used by the command, the UI preview and the combat screen.
- **Range** comes from the weapon's `heal_range` (base `weapon_healing_staff` [1,2], demo `weapon_staff` [1,1]); a `heal_range` minimum of 0 would allow self-heal (GDD). `skill_heal` stays as the action entry in the UI; its `power`/range are only a fallback for a unit with no Heal weapon.
- Designer rule kept: a full-HP ally cannot be healed (overrides GDD's "0 effective healing is legal").
- **Preview (GDD Pillar 2):** while choosing a Heal target, hovering a highlighted ally shows the raw HealAmount and the real HP gain (e.g. "Heal 20 → +12 HP (36→48)").

### F-OBJ — The five GDD objective types (08-11-2026, `battle-map-system.md` Core Rules 4, 6, 10–14)

Replaces the legacy plugins `eliminate` / `defend` / `escort_turns` / `capture` / `evacuate`. Maps declare `{type, params}` with exactly the GDD enum (`ObjectiveBase.TYPES`); all map data and the demo importer were converted. `evacuate` is retired (the GDD has no such type — `test_evacuate` became a timed Escort).

| type | params | Win | Lose |
|---|---|---|---|
| `elimination` | `target_unit_ids` (empty = every enemy) | targets / all enemies down | — |
| `protect` (unit) | `unit_id`, `survive_enemy_phases` | N enemy phases end with the unit alive | the unit dies |
| `protect` (zone) | `zone_x/y/w/h`, `survive_enemy_phases` | N enemy phases end with no breach (killing all enemies does not end it early) | any enemy steps into the zone, at once |
| `escort` (destination) | `npc_unit_id`, `target_cell_x/y` | the NPC reaches the tile (it walks in the NPC phase, after the enemies) | the NPC dies; killing all enemies does not win |
| `escort` (timed) | `npc_unit_id`, `turns_required` | N enemy phases end with the NPC alive **or** all enemies are defeated, whichever first | the NPC dies |
| `retrieve` | `item_id`, `exit_zone_x/y/w/h` (return tile/area) | the living carrier enters the return area | the carrier dies (the item no longer drops) |
| `seize` | `control_x/y`, `hold_enemy_phases` | a player unit stands on the point at the end of N consecutive enemy phases (resets to 0 when unheld; the same unit need not hold every phase) | — (enemy occupation only blocks) |

- Every counter counts **enemy phases** (`enemy_phase_ended`); the director re-evaluates the objectives right after the enemy phase ends, so a timed win lands before the next player phase.
- **Retrieve carrier (GDD Core Rule 13):** ending a move on the item's tile picks it up and ends the unit's action (move command, no separate pickup step needed); the carrier can only move — no attack, heal or counterattack (`BattleState.is_move_only_carrier()` shared by the commands and `RangeHandler.can_counter`); enemy AI prefers the carrier as a target.
- Shared rules stay where they were: protagonist / must-survive death, turn limit, `result_priority`.

### F-BOND — Support points, scene gates and exclusive S from the GDD (08-11-2026, `bond-adjacency-system.md` Core Rules 4a/4b, F-BA3, `bond-support-revision-2026-10-07.md`, `narrative-bond-scene-system.md`)

Supersedes the D05 point rules (and the old 20/45/70 thresholds); the adjacency bonus (C+3/B+5/A+8/S+10, cap +16, P-02 targets) is unchanged.

- **Accrual (F-BA3):** when a player unit **performs** an Attack or a Heal, every pairing it belongs to whose partner is alive, player-side and cardinally adjacent **to the actor** gets **+1** (`rules_config.bond_points_combat_action` = 1), once per pairing per action (never per strike); max **2 per pairing per map** (`bond_point_limit_per_pair_per_map` = 2). Being attacked, moving, waiting or Encore earn nothing. Battle points live in `BattleState.bond_points` (rewind restores them) and merge into `GameState.bond_points` on a win (D06).
- **Scenes C/B/A:** thresholds **2 / 5 / 9** cumulative points (`BondData.scene_thresholds`, provisional per the GDD). Only the next rank can open; it opens when the points are reached **and** the campaign has reached that scene's `scene_earliest_chapter` (chapter order; empty = no gate) **and** both units are alive in the roster. Otherwise the camp shows "needs N pts" or "waiting on the story". Watching or skipping the scene raises the rank; surplus points carry over.
- **S (Core Rule 4b):** only pairs with `BondData.s_eligible = true` (designer whitelist — the 6 Swordsman routes: Knight, Gunner, Wyvern Knight, Beastwoman, Magician, Healer; `bond_lancer_gunner` stays a C/B/A pair). Available when rank A is viewed, both alive in the roster, the campaign has reached `s_milestone_chapter_id` (= the GDD's `s_earliest_chapter`; empty = no gate) and **neither** unit has an S partner. The camp asks for confirmation ("both can never lock S with anyone else"); cancel changes nothing; on confirm `BondCampaign.lock_s()` re-checks everything and commits rank S + symmetric `GameState.s_pairs` in one step, then plays the S scene. Other S candidates of either unit show "S closed"; their C/B/A bonus stays.
- Campaign-side rules live in `src/core/bond_campaign.gd` (`BondCampaign`, static, like `CampaignMerge`); the camp only renders them.
- **Data added:** `bond_swordsman_gunner`, `bond_swordsman_wyvern_knight`, `bond_swordsman_magician`, `bond_swordsman_healer` with placeholder C/B/A/S dialogues (writer content pending); `BondData.s_eligible`, `BondData.scene_earliest_chapter`.
- **Known limit:** the pairs reference the legacy roster ids (`unit_swordsman`...); the demo campaign's `unit_demo_swordsman`/`unit_demo_knight` have no pairs yet (P-11 demo bond data still to author).

### F-DIFF — Enemy stats by difficulty (08-11-2026, `difficulty-system.md` F-DS2 / AC-DS2 / AC-DS4, `core-combat-system.md` Core Rule 1)

- At deploy time (`BattleDirector.setup`), every **enemy-side** unit's Str/Mag/Skill/Speed/Def/Res becomes `floor(stat × rules_config.enemy_stat_multiplier_by_difficulty[tier])` — Story 1.0, Normal 1.0, Hard 1.08, Nightmare 1.15. **HP and Luck are never scaled**; player units and NPCs are never scaled. Unknown tier → 1.0 (GDD edge case). The scaled values are the battle's own stats, so forecast, AI and rewind all see them.

### I18N — Two UI languages (designer 08-11-2026: "the game will have at least 2 languages, do both")

- **English + Vietnamese** for all UI text. Table: `data/i18n/strings.csv` (`keys,en,vi`; key = English source text, so a missing translation shows English). Imported as `keep` (`strings.csv.import`) and read by `DataRegistry._load_translations()` into Godot's `TranslationServer` — no extra autoload, no generated files. A new language = a new column + an entry in `GameState.LANGUAGES`.
- **Setting:** `GameState.options.language` (default `en`, kept across New campaign, saved with the options, applied by `GameState.apply_language()` at startup and after a load). Options panel has a Language button cycling the languages (names shown in their own language); the main menu rebuilds itself on a switch. Screens already open (e.g. the battle HUD behind the pause menu) switch on the next screen.
- **Covered:** menu, options, pause, prep, dialogue controls, battle HUD/banners/combat log, forecast (incl. passive notes, stat names), skill names, Game Over, camp, post-battle, objective names/descriptions/status, difficulty and casualty-policy names, passive names (VI = GDD names).
- **Not covered yet (content, needs per-language data):** unit/class/weapon/map/chapter/faction display names, dialogue and story lines, bond scenes. Proposed approach when content arrives: the data fields keep an English key and the writer fills `vi` rows (or per-language dialogue files) — designer to confirm.

### F-EXP — EXP & level-up from the GDD (08-11-2026, `core-combat-system.md` Core Rule 12 / F-CC13 / F-CC14 / AC-CC78–84 + `dual-restraint-scoring.md` Edge Cases)

Supersedes **D08** and **P-04** outright. D06/P-09 stay as they were (see "No defeat, only game over" below). Source: Core Combat is still "In Review" in the GDD index, but the user asked to follow it for EXP; the defeat rule comes from Dual Restraint Scoring, which is Approved.

- **F-CC13 — action EXP.** Performing an `Attack` or a `Heal` pays the **acting player-side unit** a flat `rules_config.exp_per_action` (**25**), regardless of hit/miss/crit/kill or heal amount. Nothing else pays: the defender/counter side earns nothing for being attacked, enemies never earn, `Use Item`/`Trade`/`Visit`/`Wait`/pickup pay 0. The old `exp_gain_hit` / `exp_gain_kill` / `exp_gain_nonlethal_loss` are removed (kill-scaled EXP is exactly what the GDD forbids, Pillar 5). Bard's `Encore` pays the same 25 once Encore exists (not built — passive/active class kit is a separate item).
- **F-CC14 — one level-up resolution** (`ExpSystem.resolve_level_up`, `src/battle/systems/exp_system.gd`) for every EXP source: add the gain, then while `exp >= exp_per_level` (100) and `level < level_cap` (20): level +1, exp −100, roll each growth stat once; success = +1 unless the stat already sits at `rules_config.stat_caps` (HP 60, others 30 — GDD Core Rule 1), in which case the success is wasted. HP growth raises current HP by the same amount. At `level_cap` the remaining EXP is discarded (exp = 0), and a unit already at the cap gains nothing.
- **Growth rates are per class** (GDD "Authored Growth Rate Table", 12 classes × 8 stats) and now live in `BattleClassData.growths` with GDD keys (`hp,str,mag,skill,speed,luck,def,res`), including the three demo-overlay class files. `UnitData.growths` is a legacy fallback, read only when the class has no table (enemy/rebel classes — enemies never level anyway). Level-up gains accept both key sets via `UnitData.STAT_KEY_ALIASES`.
- **`exp_enabled = true` by default** (base + demo rules). EXP is the progression mechanic in the GDD, not an optional stand-in for "mid-battle points".
- **No defeat, only game over (designer-confirmed 08-11-2026).** The game has no "lost battle" outcome that carries on — losing is a game over, so nothing from that battle is kept, EXP included. `rules_config.action_exp_commits_on_defeat = false` (the GDD's Dual Restraint edge case says action EXP survives a defeat; the designer overrides it). D06 therefore stands unchanged for EXP. **Game Over screen (designer, 08-11-2026): "game over goes together with Retry chapter".** A lost battle (after the defeat banner, where Rewind is still offered) opens `GameOverScene` (`src/scenes/game_over/`) instead of the post-battle results + camp: title "Game Over", the reason (critical unit down / objective failed), and two buttons — **Retry chapter** (replays the same chapter from its story scene with the pre-battle roster) and **Main menu**. Victories still go to post-battle → camp.
- **Rewind** now reverts level-up stat gains: `UnitState.to_dict()/from_dict()` carry the live combat stats (power/magic/defense/resistance/skill/speed/luck) besides HP/exp/level, so rewinding to before a level-up undoes it completely (GDD Core Rule 12e). Growth rolls are not replayed after a rewind (RNG not restored, D04).
- **Latent bugs fixed (they only showed up once EXP was on):** (1) the roster stat bonus was counted three times per battle (`from_data` copied the roster bonus into `UnitState.stat_bonus` and then re-recorded it while replaying it; the merge then added that again). `UnitState.stat_bonus` now holds **only this battle's gains**; the roster keeps the running total. (2) Level-up gains on GDD keys (`str/mag/skill/speed/luck`) were silently dropped; `mag`/`luck` gains were impossible. (3) The rewind stat problem above.
- **Not in this slice:** F-DRS2 bonus EXP (needs the Dual Restraint tracking system), Healer `devoted_mentor` +10 EXP to the healed target (class passive catalog), Bard `Encore`.
- **Edge cases (designer-confirmed 08-11-2026):** (a) a unit that dies earns no EXP — including an attacker felled by the counter in its own exchange (`grant_action_exp` requires the unit to be alive after the action); (b) a full-HP ally cannot be healed (the existing SkillCommand rule stays; this overrides GDD AC-CC78's "Heal on a full-HP ally pays 25"), so a Heal always has a wounded target.

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

- 2026-11-08 (13) — Claude (Opus) — done: objectives rewritten to the five GDD types (new §7b **F-OBJ**; "Known mismatches until W5" resolved; D-B6 done). New plugins `elimination`, `protect` (unit/zone), `escort` (destination/timed, timed also wins on full elimination), `retrieve`, `seize`; removed `eliminate/defend/escort_turns/capture/evacuate` (`ObjectiveBase.TYPES`). All counters count enemy phases and the director re-evaluates right after the enemy phase (`advance_after_enemy_phase`), `advance_to_player_phase` stops once the battle is over. Retrieve: pickup on move ends the action (MoveCommand), carrier move-only incl. no counter (`BattleState.is_move_only_carrier`), carrier death loses (no drop), AI prefers the carrier. All 13 maps + demo importer converted (`test_evacuate` → timed escort, `test_capture` → seize on its deploy tile). Validator: GDD enum + per-type params. Tests: objectives / timed escort / seize rewritten, new `test_retrieve_rules`. Verified: validation 0/0, run_tests **329/329**, smoke_full_battle 21/21 (×3), smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: Dual Restraint + bonus EXP, persuasion pressure color, demo enemy stats / demo bond data, objective markers on the map view (zones/points are not drawn yet). — issues: not pushed.

- 2026-11-08 (12) — Claude (Opus) — done: bond Support/S per the GDD (new §7b **F-BOND**, D05 point rules superseded). In battle: `BondSystem.reward_action()` gives +1 per pairing when a player unit performs an Attack/Heal with its partner adjacent to it (defenders earn nothing), max 2 per pairing per map (rules 1 / 2). Between battles: new `src/core/bond_campaign.gd` (`BondCampaign`: next rank only, 2/5/9 thresholds, `scene_earliest_chapter` gate, both alive, surplus carries; S only for `s_eligible` pairs, exclusive, atomic `lock_s`). Camp shows needs-points / waiting-on-story / S locked / S closed, asks for confirmation before locking S, then plays the S scene. Data: 4 new Swordsman S pairs (Gunner, Wyvern Knight, Magician, Healer) + 16 placeholder dialogues; existing pairs moved to 2/5/9, Knight/Beastwoman marked `s_eligible`, Lancer x Gunner not. Validator: rising thresholds, gate chapter ids, S scene for S pairs. Tests: `test_bond_rules_d05` rewritten for F-BA3, new `test_bond_campaign`. Verified: validation 0/0, run_tests **314/314**, smoke_full_battle 21/21 (×3), smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: GDD backlog (objectives W5, Dual Restraint + bonus EXP, persuasion pressure color, demo enemy stats / demo bond data). — issues: not pushed; demo campaign units have no bond pairs yet.

- 2026-11-08 (11) — Claude (Opus) — done: enemy stats by difficulty (new §7b **F-DIFF**, GDD F-DS2): `BattleDirector._scale_enemies()` applies `rules_config.enemy_stat_multiplier_by_difficulty` once at deploy to enemy-side Str/Mag/Skill/Speed/Def/Res (floor; HP/Luck and player/NPC units untouched) via `UnitState.apply_enemy_scaling()`. "Known mismatches" note updated. New `test_enemy_difficulty_scaling` (AC-DS2, AC-DS4, Nightmare vs Normal on ch01). Verified: validation 0/0, run_tests **302/302**, smoke_full_battle 21/21 (×3), smoke_test_maps 10/10, negative 25/25. — in progress: bond S-routes. — next: rest of the GDD backlog. — issues: not pushed.

- 2026-11-08 (10) — Claude (Opus) — done: two UI languages (new §7b **I18N**, new §5 rule). `data/i18n/strings.csv` (141 rows, en + vi; key = English text) loaded by `DataRegistry._load_translations()` into `TranslationServer`; `UIBuilder.t()` / `ObjectiveBase._t()`; `GameState.LANGUAGES`, `options.language`, `set_language()/apply_language()`; Language button in OptionsPanel, menu rebuilds on switch. Every UI string in menu/options/pause/prep/dialogue/battle/forecast/game over/camp/post-battle and all objective descriptions wrapped; passive catalog names are English keys now (VI = GDD names). Validator `check_translations()`; new `test_i18n` (scans src/ for every t() key, checks vi texts on screens, setting survives New campaign); preview test updated for English name keys. Verified: validation 0/0, run_tests **296/296**, smoke_full_battle 21/21 (×4), smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: content localization once the designer confirms the approach (names, dialogue, story); GDD backlog. — issues: not pushed (cached account `kame-gamedesign` has no write access). A first test run hung because a parse error in run_tests.gd kept the test scene from quitting — fixed; worth adding a timeout to the test runner later.

- 2026-11-08 (9) — Claude (Opus) — done: forecast preview of passive side effects (F-PAS "Preview" bullet updated; closes GDD Core Rule 11f's UI gap). `PassiveSystem.forecast_notes()` returns data notes for the exchange (lifesteal per hit, thorns, survive-once while unused, regen, debuff on hit, Lancer double, terrain-ignore, burst, no-counter, extended range, Bard aura on either side, active debuffs); `CombatResolver.forecast()` attaches them as `notes` (execute() does not); `ForecastPanel.note_text()` formats each line under its side, using the GDD display names now stored as `name` in `rules_config.passive_catalog`. New `test_forecast_passive_notes`. Verified: validation 0/0, run_tests **287/287**, smoke_full_battle 21/21 (×5), smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: GDD backlog (demo enemy stats, bond S-routes, objectives W5, Dual Restraint, persuasion UI, enemy stat multiplier). — issues: not pushed (cached account `kame-gamedesign` has no write access). Panel text is English with Vietnamese passive names (UI language not decided yet).

- 2026-11-08 (8) — Claude (Opus) — done: heal formula (new §7b **F-HEAL**, GDD F-CC9): HealAmount = healer Mag + Heal-weapon `heal_might`, capped at max HP, no Hit/Crit roll; range from the weapon's `heal_range`; `skill_heal` power/range only as a no-weapon fallback. New `CombatResolver.heal_amount()/heal_range()/heal_preview()` used by SkillCommand, the battle UI (hover preview "Heal 20 -> +12 HP (20->32)" while choosing a target) and the combat screen (shows the real gain). New `test_heal_formula`; skill-target UI test re-arranged because the demo staff heals at range 1. Verified: validation 0/0, run_tests **276/276**, smoke_full_battle 21/21 (×5), smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: GDD backlog (forecast preview of side-effect passives, demo enemy stats, bond S-routes, objectives W5, Dual Restraint, persuasion UI, enemy stat multiplier). — issues: not pushed (cached account `kame-gamedesign` has no write access). Healer heal amounts rise (was a flat 10, now ~20 with Mag 12 + staff 8).

- 2026-11-08 (7) — Claude (Opus) — done: designer changes to F-PAS: Lancer now strikes twice back to back before the enemy counters (A, A, counter; never a third strike); Wyvern Knight revives at 1 HP the first time it would die from any combat damage (attacking, defending or thorns), once per battle; Heal and Encore targets are chosen by the player — skill button enters `Mode.SKILL_TARGET` in battle_scene (valid targets from `SkillCommand.check` highlighted, left click commits, right click cancels at no cost; old auto-pick removed). Tests: Lancer order, Wyvern revive on counter/thorns, new `test_skill_target_selection` (Heal picks the clicked ally, cancel spends nothing, Encore via clicks). Verified: validation 0/0, run_tests **268/268**, smoke_full_battle 21/21 (×6), smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: preview of side-effect passives in the forecast; GDD backlog. — issues: not pushed (cached account `kame-gamedesign` has no write access).

- 2026-11-08 (6) — Claude (Opus) — done: class passives + Bard fix (new §7b **F-PAS**). `BattleClassData.passive_id` / `can_attack`; GDD catalog in `rules_config.passive_catalog`; new `src/battle/systems/passive_system.gd` implements all 12 effect types; hooks in CombatResolver (aura/terrain-ignore in Avoid, burst on first strike, force double, no-counter, survive-once, debuff + lifesteal on hit, thorns), RangeHandler/AttackCommand/EnemyAI (can_attack, `UnitState.attack_max()` for extended range), director (phase start → Magician flag; Ready→Acted → debuff countdown), SkillCommand (Healer mentor EXP, Beastwoman regen on Heal, new `encore` effect). `UnitState`: `eff()` stat reads, `active_debuffs`, `miracle_used`, `fragile_circle_ready` (all in rewind snapshots). Bard: `weapon_id = ""`, `can_attack = false`, `skill_ids = ["skill_encore"]` (new `data/skills/skill_encore.tres`); battle UI auto-picks the Encore target and shows skill display names. Healer can no longer attack (Heal weapon, GDD Core Rule 3). Validator checks passive ids and effect types. New tests `test_class_passives` (all 12 + rewind) and `test_bard_encore`. Verified: validation 0/0, run_tests **260/260**, smoke_full_battle 21/21 (×8), smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: UI preview for side-effect passives (GDD open gap), Encore manual target choice if wanted, rest of the GDD backlog (heal formula, bond S-routes, objectives W5, Dual Restraint, persuasion UI, enemy stat multiplier, demo enemy stat scale). — issues: not pushed (cached account `kame-gamedesign` has no write access). `weapon_light_rapier` is now unused data (kept, ids are not deleted without approval).

- 2026-11-08 (5) — Claude (Opus) — done: designer answers: no weapon triangle, keep `hit_base = 70` (recorded in F-CC-FE, R1 closed except playtest); "game over together with Retry chapter" → new `src/scenes/game_over/game_over_scene.gd` (`GameOverScene`: Game Over title, defeat reason, Retry chapter + Main menu); `main._show_post_battle(false)` now opens it instead of post-battle + camp. New `test_game_over_screen`. Verified: boot clean, validation 0/0, run_tests **223/223**, smoke_full_battle 21/21, smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: demo-layer enemy stat scale; GDD backlog (heal formula F-CC9, class passives + Bard fix, bond S-routes/thresholds, objective renames/rules W5, Dual Restraint + bonus EXP, persuasion color UI, enemy stat multiplier). — issues: not pushed (cached account `kame-gamedesign` has no write access). The camp still has its old "Retry chapter" button logic (unreachable after a defeat now; left as is).

- 2026-11-08 (4) — Claude (Opus) — done: designer chose Fire Emblem tuning (new §7b **F-CC-FE**): `hit_base = 70` (provisional) added to Accuracy, Luck ×1 in Avoid and crit evade, crit damage ×3, single roll (no 2RN). R1 marked provisionally addressed. New `test_fe_formula` locks the numbers; bond accuracy test re-tuned (hit_bonus −18). Hit rates now: roster vs roster 73% avg (41–100), rebels → roster 54%. Verified: validation 0/0, run_tests **217/217**, smoke_full_battle 21/21 (×8), smoke_test_maps 10/10, negative 25/25. — in progress: none. — next: designer input on weapon triangle (needs a weapon-type tag per weapon), final hit_base vs per-weapon Hit table, demo-layer enemy stat scale (Skill 23); Game Over flow; rest of the GDD backlog. — issues: not pushed (cached account `kame-gamedesign` has no write access).

- 2026-11-08 (3) — Claude (Opus) — done: applied three designer answers to F-EXP: (1) no defeat, only game over → `action_exp_commits_on_defeat = false` by default (a lost battle keeps nothing, EXP included; D06/P-09 back to unchanged; code fallbacks flipped to false); (2) a unit that dies earns no EXP (confirmed, new test); (3) a full-HP ally cannot be healed (confirmed, overrides GDD AC-CC78; new test). Fixed a flaky `smoke_full_battle` "spared" scenario (random seed; the commander could die to counters under the new hit chances, ~1 run in 7) by giving the commander +500 HP in that scenario — 10/10 runs pass after. Verified: validation 0/0, run_tests **213/213**, smoke_full_battle 21/21 (×10), smoke_test_maps 10/10, negative 25/25. Gave the user rebalancing options for R1 (base hit constant / lower Speed weight in Avoid) — proposal only, nothing changed in formulas or data. — in progress: none. — next: designer picks an R1 option, then write it into F-CC and rules_config; Game Over flow to replace "Retry chapter" (UI decision needed); rest of the GDD backlog. — issues: not pushed (cached account `kame-gamedesign` has no write access).

- 2026-11-08 (2) — Claude (Opus) — done: EXP rework to the GDD (new §7b **F-EXP**, supersedes D08 + P-04, partially D06/P-09). New `src/battle/systems/exp_system.gd`: F-CC13 flat `exp_per_action` = 25 for each Attack/Heal by a player unit (hit/miss/kill alike; defender, enemies, other actions = 0) and F-CC14 `resolve_level_up` (100 EXP/level, cap 20, EXP discarded at cap, `stat_caps` HP 60 / others 30 with wasted rolls, HP growth heals). Removed `exp_gain_hit/kill/nonlethal_loss` and `CombatResolver._grant_levels`; SkillCommand heal now pays EXP. GDD growth table (12 classes) added as `BattleClassData.growths` in the 12 base class files + 3 demo-overlay classes (sums checked against the GDD); unit growths are a legacy fallback. `exp_enabled = true` in rules (.gd + both .tres). Defeat now keeps action EXP/levels (`action_exp_commits_on_defeat = true`, from the Dual Restraint GDD edge case); `CampaignMerge` split into `_merge_progression` + victory-only part; director puts exp/level_ups into the defeat result too. Fixed latent bugs that EXP-on exposed: roster stat bonus counted 3× per battle (`UnitState.stat_bonus` is now this battle's gains only; roster replay doesn't record), GDD stat keys (str/mag/skill/speed/luck) ignored by level-up gains, rewind not reverting level-up stats (to_dict/from_dict carry power/magic/defense/resistance/skill/speed/luck). Validator: class growth keys/ranges, rules exp/stat_caps sanity, warning for a roster unit with no growth rates. Tests: `test_exp_and_levels` rewritten for F-CC13/F-CC14 (AC-CC78/80–84 + heal + flag), new `test_exp_rewind_and_growth_table` and `test_exp_merge_and_replay` (no triple counting), D06 test now checks both flag states. **Also fixed tests broken by the previous combat-formula commit** (they assumed near-certain hits): `test_second_target_damage`, `test_second_target_via_clicks`, `test_reconcile_hud` now set `skill = 60` for deterministic hits; the old EXP test's kill would also have failed. Re-opened the low-hit-chance balance concern as **R1** in §7 (the formula is right, the numbers give ~5–25% hits). docs/tech_decisions.md updated. **Verified in Godot 4.7.2** (found at `D:\Work software\Godot\…_console.exe`, not in PATH; this run covers the previous combat-formula commit too): boot clean, validation 0 errors / 0 warnings (base + demo profile), run_tests **210/210**, smoke_full_battle **21/21**, smoke_test_maps **10/10**, test_validate_negative **25/25**. README/how_to_run counts updated. — in progress: none. — next: F-DRS2 bonus EXP with a Dual Restraint tracking system, heal formula F-CC9 (Mag + heal_might, full-HP heal legality), class passives (incl. Healer +10 EXP mentor, Bard Encore), bond S-routes/thresholds, objective rename/rules (W5), R1 balance with the designer. — issues: smoke_demo_maps cannot run in a fresh clone — it reads `docs/reference/demo/data/battle_demo.json`, which is gitignored (pre-existing, unrelated to this change). Not pushed: the cached GitHub account (`kame-gamedesign`) has no write access to `namtit2932k/project-x`; commits are local only.

- 2026-11-08 — Claude (Fable) — done: read the full new GDD handoff (16 systems under `Detailed GDD`/`Nguồn` zips + `damage-heal-formulas.docx` + `characters.docx` + `Project-X-Master-Design.xlsx`), gap-analyzed it against this repo (combat formulas, EXP model, class passives, bond S-routes, objective types, persuasion UI, items/shop, difficulty, rewind — see chat log, not committed as a doc). Implemented W3 (combat formula rewrite only, F-CC1…F-CC5 per the approved `core-combat-system.md`): new §7b "F-CC" decision entry superseding D-B10 and the old `hit_base/hit_scale_*/hit_variance/crit_base/crit_scale_skill` shape; `rules_config.gd` replaced those fields with `accuracy_skill_mult/accuracy_luck_mult/avoid_speed_mult/avoid_luck_mult/crit_skill_mult/crit_luck_mult` and bumped `crit_multiplier` 2.0→2.5; `double_attack_speed_gap` (5) removed, `CombatResolver` now reads the existing `double_threshold` (4); `_hit_pct`/`_crit_pct`/`_damage` rewritten to the GDD's Accuracy/Avoid/Hit/Crit/Damage shape (Luck now feeds hit/avoid/crit; weapon `weapon_accuracy_mod`/`weapon_crit_mod`/`weapon_might` now read from `WeaponData` via `attacker.weapon_id`; damage no longer reads terrain, matches rules_config's own "terrain only feeds Avoid" comment; Magic/Physical split uses Mag/Res vs Str/Def). Updated `tests/run_tests.gd`'s two formula-dependent assertions (`test_forecast_matches_execution`'s "deterministic hit 100" setup, and the bond P-02 accuracy-bonus-visibility setup) to hit the new formula's numbers instead of the old base-100 assumption. D-B10 removed from Open Decisions (closed by the GDD). — in progress: none for this slice. — next: everything else the GDD gap-analysis flagged is still open — EXP model conflict with D08 (flat action-based EXP vs current kill/hit-based), 12-class passive catalog (unbuilt, Bard incorrectly has a weapon), bond S-route data (4 of 6 confirmed Swordsman pairs missing + stale rank thresholds), objective renames/rule fixes (evacuate should retire, defend/capture/retrieve/escort_turns still have known rule mismatches), item/shop catalog (partially present under `data/balance/demo/items/`, needs full GDD 5-item check), enemy stat multiplier by difficulty (data exists in `rules_config.enemy_stat_multiplier_by_difficulty`, not wired into combat), persuasion continuous pressure-ratio UI, Dual Restraint Scoring system existence unconfirmed. — issues: **could not run the project's own verification suite** — no Godot executable found on this machine (`godot`/`godot4` not in PATH), so the mandatory `tools/validate_data.tscn` / `tests/run_tests.tscn` / smoke scenes (normally 184/184 + 21/21 + 10/10 + 0 errors) were not re-run after this change; the two edited test assertions were hand-traced against the new formula and the default unit/weapon data but need an actual headless run to confirm before merging with confidence. Formula change affects every battle's balance — full-battle smoke outcomes (win/lose) may shift and were not verified.

- 2026-10-19 (2) — Buffy (Codebuff) — done: đợt F (mốc M0) theo demo_parity_plan/DEMO_PARITY_NEXT_STEPS.md: F1 — UnitData.base_stat có bảng alias hai chiều (atk↔str, skl↔skill, spd↔speed, mov↔move); UnitState thêm mag/luck/base_vision/weapon_id/template_id/priority_target_id, from_data nhận instance_id; migrate 12 class + 12 unit roster ch01 sang bảng GDD Phụ lục C (tools/migrate_legacy_gdd_stats.gd, chay lại được; rebel giữ khóa cũ qua alias; weapon_id + damage_type theo class_weapons.json — Magician/Magic Swordsman thành magic). F2 — BattleState.units khóa theo instance_id (placement.instance_id, thiếu thì dùng unit_id); npc_unit_ids resolve theo instance; priority_target_id template được đổi sang instance của bản cùng template; to_dict/from_dict + snapshot mang template_id. F3 — importer chỉ đặt in_roster cho unit_demo_swordsman/knight và is_protagonist cho swordsman; validator chặn placement dùng quân roster và bắt mọi chapter có ≥1 protagonist trong deployable; thêm unit_npc_guide thay quân roster làm NPC trong các map test/sample. F4 — DataRegistry.chapters_sorted(tag) lọc theo campaign_tag (chapter không tag = legacy); GameState.campaign_tag (mặc định "demo", save cũ đọc là "legacy"); build_roster/merge_roster lọc theo UnitData.campaign_tag; menu debug "Legacy chapter (ch01)"; chapter_ch01 mang campaign_tag="legacy". F5 — RulesConfig thêm combat_formula_set/exp_enabled/shop_enabled/fog_enabled/base_vision_default/bond_bonus_targets (P-13; demo overlay bật shop); BondSystem đọc bond_bonus_targets theo P-02 (accuracy/avoid/crit/damage); EXP chặn bởi exp_enabled (test exp tự bật cờ cục bộ). F6 — tests/smoke_demo_maps.gd+.tscn: 62 checks trên 6 map demo (số quân mỗi phe, chỉ số demo swordsman/knight, id instance không trùng, objective_type khớp battle_demo.json, rebel đọc atk qua alias). Fix test cũ: bond P-02 (accuracy hưởng bonus — D05 cũ bị P-02 thay), smoke/test gắn tag legacy, unit NPC đổi id. AGENTS.md: bảng P-01…P-15, chú thích bậc nguồn P-01, mục Known mismatches until W5 (F7). README/how_to_run thêm lệnh smoke_demo_maps. Kiểm tra cuối: validation 0/0 cả hai lượt, run_tests 184/184, smoke 21/21, smoke maps 10/10, negative 25/25, smoke demo maps 62/62. — in progress: none. — next: W3 lõi chiến đấu (combat_formula_set="gdd", F-CC1..F-CC7, vector vàng cả hai profile), W1 khung 1280×720 chạy song song, W4 menu hành động + preview (P-12), W5 rewrite mục tiêu theo MapData (protect_zone/protect_unit/seize mới; escort_turns đếm enemy phase; Retrieve thua khi carrier chết), rồi W7 AI/W8 hòa giải/W9 roster. — issues: thứ tự menu ch01/debug theo P-08 là quyết định tạm chờ designer; lệch law khác ghi trong mục Known mismatches until W5 của §7b.

- 2026-10-19 — Buffy (Codebuff) — done: W2 của DEMO_PARITY_PLAN v2 (demo_parity_plan/): schema dữ liệu theo GDD — WeaponData mới (data/weapons/weapon_data.gd) + 12 vũ khí GDD; UnitData thêm base_vision/ai_profile/priority_target_id/controllable/carried_items; ItemData thêm consumable (heal/buff + price); MapData thêm map_deploy_cap/turn_par/deploy_tiles/objective params/villages/faction/bonds/aftermath_lines; ChapterData.campaign_tag; RulesConfig thêm double_threshold/bond_stack_max/max_item_slots/HP bands/enemy_stat_multiplier & restraint theo độ khó/terrain glyphs h,c,x,v + terrain_vision. Cơ chế balance_profile (T2.7): DataRegistry nạp lớp gốc rồi lớp data/balance/demo/ (id trùng ghi đè, id mới thêm vào) + rules overlay riêng cho profile; demo rules đặt rules_config.tres (Forest +12). tools/import_demo_data.gd (T2.8) sinh .tres từ JSON demo: units lớp demo dùng prefix unit_demo_ để KHÔNG đè roster ch04... (unit_swordsman/id người thật giữ nguyên trong lớp gốc), factions faction_neutral/faction_river_guard, item_demo_document, 6 map demo_01..06 (chuyển glyph F→f, V→v, W→w) + 6 chapter_demo (campaign_tag demo), item consumable + giá shop. Validator (T2.9/T2.10) chạy 2 lượt (base + profile) với checks mới: cả hai bộ khóa chỉ số (cấm trộn), vũ khí (range min>max chặn, Combat cần attack_type, Heal cần might), unit strict layer (hp 15–60, move 4–7 chỉ cho controllable, base_vision 3–6, max_item_slots), AI profiles, map checklist Phụ lục E (deploy cap 1–10, turn_par bắt buộc & ràng buộc với turn_limit/escort/protect/seize, làng đúng một reward, key_unit/faction, bond pair)... escort_turns plugin mới (objective_escort_turns.gd) cho biến thể hộ tống theo lượt. Tests mới tests/test_validate_negative.gd (25 case âm tính checklist Phụ lục E; không rò resource). Kiểm tra cuối: validation 0/0 cả base lẫn profile demo; run_tests 184/184; smoke 21/21; smoke maps 10/10; negative 25/25; boot sạch. — in progress: none. — next: W3 lõi chiến đấu (CombatResolver theo F-CC1..7, forecast full exchange, BondSystem cap 4 nguồn), W4 commands new (heal/use_item/visit/trade), W5 objective rewrite theo MapData mới. — issues: class demo ghi đè class_swordsman/knight/healer của lớp gốc theo D-A1/D-A5 (id người thật vẫn giữ data, chỉ số class đổi theo profile) — cần xác nhận designer khi chơi ch01 trên profile demo.

- 2026-10-18 (2) — Buffy (Codebuff) — done: toàn bộ đợt 2 (tài liệu "đợt 2" D01–D12/N01–N13): N01 forecast khôi phục (Mode.CONFIRM_ATTACK + ForecastPanel lấy số 100% từ CombatResolver.forecast), N02 must_survive/critical_units (Swordsman protagonist, Beastwoman phải sống, prep khóa unit bắt buộc), N03 ch01 target 3 lính + sparing commander `spared_commander`, N04 rewind per_use chỉ PLAYER frame + RNG không khôi phục + Rewind trên banner thua, N05 bond D05 (điểm combat/heal cặp kề, bonus vào bond_bonus_stat, so rank theo index, S độc quyền, thêm 2 cặp + dialogue C/B/A/S), N06 CampaignMerge chỉ khi thắng + Retry/Menu/Rewind + camp ẩn Next, N07 story_flags + portrait/set_flag + counts_for_true_ending + round-trip save, N08 Esc pause dùng chung OptionsPanel, N09 capture qua pha địch + zones[] + contested_rule, N10 HUD reconcile chips + prep/battle warning + feedback dialogue khi đổi thái độ, N11 EXP/level-up cho phía người chơi (exp_gain_hit khi bị né cũng được, stat_bonus vào roster, hậu trận liệt kê), N12: năm map test `test_<type>` + menu "Test maps" debug-only + smoke từng map 10/10; fix engine: `run_next_enemy_plan` không còn ở unit NPC trong pha địch; N13: Decisions log D01–D12 vào §7b (D01/D02 designer chốt; D03–D12 đề xuất chốt tạm), dọn mục 7, README/how_to_run/tech_decisions theo luồng mới. Checks cuối: validation 0/0, run_tests 184/184, smoke ch01 21/21, smoke maps 10/10, boot sạch; từng mục commit riêng. — in progress: none. — next: T14–T16 (đợt 1), backlog P3 (escape, CSV dialogue tool, special actions, ending/bond scenes nội dung thật). — issues: none.

- 2026-10-15 (6) — Buffy (Codebuff) — done: P0 review fixes theo handoff doc: T01 side tách khỏi faction (đội hỗn hợp Empire+Kingdom hoạt động: select/move/pass-through/eliminate/AI/map view màu theo side + faction_override), T02 command.check() trong director (trước mỗi apply; attack bằng manhattan trong [min..max], check cả skill/pickup, carrier move-only, AI move bị từ chối → wait), T03 rewind deep-copy lồng nhau + RNG state + khôi phục chỉ frame PLAYER + turn-start snapshot + labels/label, T04 escort dùng target_cell (thêm map sample valley_escort), T05 reconcile chỉ cho remnant faction (empire/kingdom rỗng), spared_event_keys mapping, evaluate cùng schema mọi lần, T06 bond điểm từ attack có đồng minh cặp kề + heal cặp, merge bond_points vào GameState sau trận, so rank theo BOND_RANKS index, S exclusive, T07 advance_chapter dùng current_chapter().id + advance trước camp trên thắng + Retry chapter khi thua + new_game giữ difficulty/options + merge roster thiếu + story_branch, T08 DataRegistry nạp .tres/.res/.remap cho export. Tests 92/92, smoke 12/12, validation 0. — in progress: P1 (T09-T13, T14-T16). — next: hành trình P1 theo thứ tự tài liệu. — issues: ch01 rout vẫn làm persuade bất khả thi (mở quyết định designer §7).

- 2026-10-15 (5) — Buffy (Codebuff) — done: luồng tương tác mới: sau move chỉ hiện ô đỏ tầm đánh (ranged xa hơn theo ClassDef), bỏ nút Attack/Wait (click unit lại / ô khác / right-click sau move = Wait), click địch trong ô đỏ = auto combat screen, HP cập nhật ngay trên map sau màn giao chiến; bỏ forecast panel UI (CombatResolver.forecast vẫn giữ làm dry-run). Tests: 51/51 + smoke 10/10 — commit + push. — in progress: none. — next: event executor, evac map mẫu, CI, level-up growths, retry flow. — issues: none.

- 2026-10-15 (4) — Buffy (Codebuff) — done: bỏ tên làm việc "Ceasefire": chỉ còn "Project X" (README, AGENTS, docs/how_to_run, menu title UI); boot sạch; commit 50c8d0f đã push. — in progress: none. — next: như trước (event executor, evac map mẫu, CI, level-up theo growths). — issues: none.

- 2026-10-15 (3) — Buffy (Codebuff) — done: README.md cho repo công khai; git init + commit đầu (158 files) + push lên origin main (github.com/namtit2932k/project-x). — in progress: none. — next: như phiên trước (event executor, evac map mẫu, level-up theo growths, retry sau thất bại). — issues: none.

- 2026-10-15 (2) — Buffy (Codebuff) — done: tái cấu trúc theo schema đề xuất: src/battle/state/ & rewind/snapshot_stack (SnapshotStack); RulesConfig schema (damage_formula_id, rounding, terrain_costs x movement_type, rewind_per_difficulty, rewind_count_mode, casualty_by_difficulty, win_lose_priority); UnitDef (base_stats+growths+portrait/sprite, regen 16 .tres) + ClassDef (weapon_type/special_action_id/stat_mods skeleton); DataRegistry nạp đệ quy; map về data/maps/ch01_border_post/; objective plugin evacuate mới + NpcAI wired vào director/scene; MapDef thêm events[]/fail_conditions[] skeleton + EventDef; data/items/ + ItemData; validator mở rộng theo schema + test bond cap 16 + test evacuate + test terrain costs. Checks: 34/34 rule tests, smoke 10/10, validation 0/0, boot sạch. — in progress: none. — next: damage_formula_id thứ hai (để designer A/B công thức), event executor engine theo EventDef, evac map sample dùng NpcAI, level-up theo growths khi designer chốt.

- 2026-10-15 — Buffy (Codebuff) — done: milestone-1 vertical slice. Autoloads (EventBus/DataRegistry/GameState/SaveService); rules core (BattleState, movement Dijkstra, attack range from move-edge, CombatResolver shared by forecast/combat/AI); commands (move/attack/wait/skill-heal/pickup) via BattleDirector with snapshots; rewind by difficulty (+ Story∞/Normal5/Hard3/Nightmare0, permadeath flags in rules_config); objective plugins eliminate/escort/defend/retrieve/capture; bond system (designer pair list, C/B/A scenes via DialoguePlayer, adjacency bonus capped 16) and reconcile system (hidden kill threshold + required events, outcome stored); sample data built from the concept docs (12 classes + 4 ch01 units, map_ch01, chapter, dialogues, bond pair, factions); scenes menu→story→prep→battle(mouse: select/move/attack/forecast/combat screen placeholder)→post-battle→camp (roster, bond scenes, save, difficulty)→next chapter; validator + 24 rule tests + full-battle AI smoke (all green, validation 0 errors). — in progress: none. — next: retry-after-defeat flow, threat range overlay for enemies, more chapters/maps exercising escort/defend/retrieve/capture, prep drag-drop deployment, options polish. — issues: enemy AI is a naive approach/attack bot; reconcile event keys currently `spared_<unit_id>` (designer to confirm mapping); combat screen is placeholder graphics; defeat ends chapter loop without retry.
