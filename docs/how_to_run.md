# Project X — How to run

## Requirements

- Godot 4.7.x (project verified with 4.7.2 stable).
- Project root: this folder (`project.godot`).

## Open in editor / run the game

1. Open Godot -> Import -> select this folder.
2. Press F5 (main scene: `src/scenes/main/main.tscn`).
3. Main menu -> **New campaign** -> story dialogue -> prep -> battle.

From a terminal:

```
godot --path .
godot --headless --path . --quit-after 5   # boot check (no rendering)
```

## Mouse controls (battle)

- Left click a unit: select it (any side shows its ranges). A ready player unit shows its blue move range and attack edge — **no action menu yet** (F-MOVE).
- Left click a blue tile: the unit moves there and the **action menu** opens next to it (GDD order: Attack, Heal, Use Item, Visit, Encore, Trade, Wait). Left click the unit **again** instead = stay on its tile, the menu opens there.
- Attack: menu Attack (or click an enemy on a red tile) -> forecast -> Confirm / Cancel. Right after selecting, a red enemy can be clicked directly (attack from where the unit stands).
- Until an action is confirmed the move is provisional: **right click** puts the unit back on its start tile for free; right click again deselects. Picking another unit, End phase or Rewind also take the move back first.
- While choosing an Attack / Heal / Encore target: right click returns to the menu.
- When every player unit has acted the turn passes to the enemy by itself after half a second (F-AUTOEND); the **End phase** button works at any time.
- **Pause** button (top right): pause menu (Resume / Squad / Options / Quit to menu, with a "progress will be lost" confirmation). The game is mouse-only: Esc does nothing (F-NOESC).
- **Rewind** button: opens the rewind point list (newest first, "Undo last action" on top); each use costs one charge (story ∞, normal 5, hard 3, nightmare 0). RNG is intentionally NOT restored (D04).

## Validation & tests (headless)

```
godot --headless --path . res://tools/validate_data.tscn    # data validation (0 errors expected)
godot --headless --path . res://tests/run_tests.tscn        # 658 rule checks (movement/combat/range/side/objectives/rewind/reconcile/bond/exp/save)
godot --headless --path . res://tests/smoke_full_battle.tscn # full battle driven by AI, end-to-end through BattleDirector (21 checks)
godot --headless --path . res://tools/playtest_demo_maps.tscn # bot playtest of the 6 demo maps -> docs/playtest/demo_maps_report.md (not pass/fail)
godot --headless --path . res://tests/smoke_test_maps.tscn   # all five test maps, one scripted win + one lose scenario each
godot --headless --path . res://tests/smoke_demo_maps.tscn   # six demo example maps: sides/stat/objective parity vs battle_demo.json (F6)
```

Every test scene above has a watchdog: a parse error stops the run at once with
`FAIL: watchdog: ...` (exit code 1) instead of hanging, and a run that never finishes is
stopped after 300 s (`run_tests`) / 120 s (the others).

`smoke_demo_maps` needs `docs/reference/demo/data/battle_demo.json`, which is not in git: without
that file it reports 1 failure.

## Test maps (debug builds only)

The main menu shows a **Test maps** button in debug builds: every `data/maps/test_*` map
starts a battle instantly with the default roster (no chapter, no story scene, results
never merge into the campaign). Together with `map_ch01` they cover all six mechanics:
elimination / protect / escort / retrieve / seize (F-OBJ).

## Adding content (data-only)

- New class: copy any `data/classes/*.tres`, change id/stats.
- New unit: `data/units/*.tres`.
- New map/objective type combo: `data/maps/*.tres` and declare objectives as `{type, params}` (GDD types: elimination / protect / escort / retrieve / seize — params in AGENTS.md F-OBJ). See `data/maps/valley_escort/map.tres` for an escort sample where NpcAI walks the escortee, and `data/maps/test_*` for one minimal sample per objective type.
- New bond pair: `data/bonds/*.tres` (never inferred — designer list only).
- New dialogue: `data/dialogues/*.tres` played by `DialoguePlayer`.
- Balance/TBD numbers: `data/rules/rules_config.tres`.

## Placeholders & notes

- Damage hit/crit formulas, terrain costs, severity of casualties, per-map conditions are placeholders in `rules_config` — flagged TBD for the designer; never hardcode alternatives in code.
- Combat screen art, UI theme and portraits are code-drawn placeholders pending assets.
- Save is manual between battles only (`user://save_game.json`).
