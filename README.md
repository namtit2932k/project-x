# Project X

A 2D turn-based tactical RPG (Fire-Emblem-like) built with **Godot 4 (GDScript)**.

After a 15-year war between the Physical Empire and the Magic Kingdom, a peace treaty is signed — but not everyone laid down their arms. The player leads a small mixed squad of 12 characters from both sides to persuade the remnant factions that reject peace, where *how* you fight matters as much as *whether* you win.

## Status: Milestone-1 vertical slice

One complete chapter is playable with the mouse:

```
story scene → squad preparation → tactical battle → post-battle results → camp → next chapter
```

- Turn phases (player → enemy → NPC), Dijkstra movement over terrain costs
- Move range / attack range overlays (attack range drawn from the edge of the move range)
- Forecast → confirm → placeholder combat screen (skippable; state ends identical)
- 5 objective plugins fully data-driven: `eliminate`, `escort`, `defend`, `retrieve`, `capture` + `evacuate`
- Bond system (designer pair list, C/B/A scenes, adjacency bonus capped +16, exclusive S lock)
- Reconciliation system (hidden kill threshold + required in-battle events, per-faction outcome stored)
- Rewind snapshots per confirmed action; budget by difficulty (Story ∞ / Normal 5 / Hard 3 / Nightmare 0)
- Manual saves between battles; roster, casualties, bond ranks, chapter progress, reconcile outcomes persist

## Requirements

- [Godot 4.7.x](https://godotengine.org/download) (verified on 4.7.2 stable)

## Run

Open the project folder in Godot and press **F5**, or from a terminal:

```sh
godot --path .
```

### Battle mouse controls

| Action | Input |
| --- | --- |
| Select unit (any faction shows its ranges) | Left click |
| Move | Left click a highlighted move tile |
| Attack / Wait / skill | Action menu after moving |
| Forecast & confirm | Click an enemy on a red tile → ForecastPanel → Confirm |
| Cancel (also decline Confirm) | Right click |
| End phase | "End phase" button (bottom right) |
| Pause menu | Esc |
| Rewind (costs one use) | "Rewind" button |

A unit moves **once per phase**; after moving it may attack, wait or use a skill — changing position again requires Rewind.

## Verification (headless)

```sh
godot --headless --path . --quit-after 5        # boot check, no script errors
godot --headless --path . res://tools/validate_data.tscn     # data validation (0 errors expected)
godot --headless --path . res://tests/run_tests.tscn         # rule tests (movement/combat/objectives/rewind/bond/exp/save)
godot --headless --path . res://tests/smoke_full_battle.tscn # full battle driven by AI end-to-end
godot --headless --path . res://tests/smoke_test_maps.tscn   # all five test maps, win + lose each
godot --headless --path . res://tests/smoke_demo_maps.tscn   # six demo example maps: units, stats, objectives (F6)
```

Current: rule tests **184/184**, full-battle smoke **21/21**, test-map smoke **10/10**, validation **0 errors**.

Debug builds also get a **Test maps** entry on the main menu: every `data/maps/test_*` map
starts a battle straight away with the default roster (no chapter loop; results never merge
into the campaign), covering escort / defend / retrieve / capture / evacuate beside ch01's
eliminate.

## Architecture

Everything is engineer/designer separable — see [AGENTS.md](AGENTS.md) for full conventions and the work log.

- **Logic ≠ presentation.** All rules are plain `RefCounted` classes under `src/battle/`; scenes only render `BattleState` and forward mouse input through commands.
- **One source of truth.** Forecast, the combat screen, AI, objectives, post-battle and rewind all read the same `BattleState` and the same `CombatResolver` (forecast = dry-run).
- **Every confirmed action is a Command** (`move`, `attack`, `wait`, `skill`, `pickup`); a snapshot is pushed before each commit, so rewind = restore to a frame and drop later frames.
- **Data-driven.** Units, classes, skills, items, maps, objectives, factions, bonds, chapters and dialogue are `.tres` resources with stable ids — new content never requires core code changes.
- **Objectives are plugins.** Maps declare `{type, params}` only.
- **TBD numbers live in data** — `data/rules/rules_config.gd` defaults (damage formula id, rounding, terrain costs × movement type, casualty policy). Nothing is hardcoded.
- **Sides over factions** — control (`player`/`enemy`/`npc`) is separate from lore `faction_id`, so the mixed Empire+Kingdom squad and remnant reconciliation both work.

```
data/        designer-owned content (rules, units, classes, items, skills, maps, factions, bonds, chapters, dialogues)
src/core/    autoloads only: EventBus, DataRegistry, GameState, SaveService
src/battle/  state/ rules/ commands/ objectives/ ai/ rewind/ systems/
src/scenes/  menu, prep, battle view, combat screen, post-battle, camp, dialogue
src/ui/      shared UI builders
tools/       data validation
tests/       headless rule tests + full-battle smoke
docs/        how to run, technical decisions
```

Round-2 design decisions (forecast restored, must-survive heroes, rewind `per_use` + RNG not restored, win-only merge, EXP/level-ups, story flags, Esc pause, test maps) are logged in [AGENTS.md](AGENTS.md) §7b. Still open (placeholders in data): final damage/hit/crit numbers, the final terrain table, story content, the final bond pair list & S routes, and wounded-casualty effects for non-permadeath difficulties.

## Roadmap

Threat-range overlay for enemies, enemy defeat retry flow, event executor for `EventDef` triggers/actions, level-up math from growths, art/UI pass replacing placeholders, more chapters exercising every objective type.

## Credits

Game concept, characters and world: designer docs (World/Character/Overall, concept deck). Engineering: buffy — see the work log in [AGENTS.md](AGENTS.md).
