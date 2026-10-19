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

- Left click: select unit (any faction shows its ranges) / move to a highlighted move cell.
- After moving: only the red attack range shows (melee = 1 tile; ranged classes reach further per ClassDef).
- Attack: click an enemy on a red tile — the combat screen plays immediately, HP updates on the map when it closes.
- Wait (after moving): click the unit again, click any non-target tile, or right click.
- Skill: action-menu button when the unit has one (e.g. Heal).
- Right click (before moving): cancel current selection/step.
- **End phase** button: hands over to enemy -> NPC phases, then next turn.
- **Esc**: pause menu (Resume / Options / Quit to menu with a progress-lost warning).
- **Rewind** button: restores the newest valid PLAYER-phase snapshot (turn start after the
  enemy/NPC bookkeeping; costs one use, `per_use` mode; budget by difficulty: story ∞,
  normal 5, hard 3, nightmare 0). RNG is intentionally NOT restored, so a replay after a
  rewind rolls different results (D04).

## Validation & tests (headless)

```
godot --headless --path . res://tools/validate_data.tscn    # data validation (0 errors expected)
godot --headless --path . res://tests/run_tests.tscn        # 184 rule checks (movement/combat/range/side/objectives/rewind/reconcile/bond/exp/save)
godot --headless --path . res://tests/smoke_full_battle.tscn # full battle driven by AI, end-to-end through BattleDirector (21 checks)
godot --headless --path . res://tests/smoke_test_maps.tscn   # all five test maps, one scripted win + one lose scenario each
godot --headless --path . res://tests/smoke_demo_maps.tscn   # six demo example maps: sides/stat/objective parity vs battle_demo.json (F6)
```

## Test maps (debug builds only)

The main menu shows a **Test maps** button in debug builds: every `data/maps/test_*` map
starts a battle instantly with the default roster (no chapter, no story scene, results
never merge into the campaign). Together with `map_ch01` they cover all six mechanics:
eliminate / escort / defend / retrieve / capture / evacuate.

## Adding content (data-only)

- New class: copy any `data/classes/*.tres`, change id/stats.
- New unit: `data/units/*.tres`.
- New map/objective type combo: `data/maps/*.tres` and declare objectives as `{type, params}` (plugin types: eliminate / escort / defend / retrieve / capture / evacuate). See `data/maps/valley_escort/map.tres` for an escort sample where NpcAI walks the escortee, and `data/maps/test_*` for one minimal sample per objective type.
- New bond pair: `data/bonds/*.tres` (never inferred — designer list only).
- New dialogue: `data/dialogues/*.tres` played by `DialoguePlayer`.
- Balance/TBD numbers: `data/rules/rules_config.tres`.

## Placeholders & notes

- Damage hit/crit formulas, terrain costs, severity of casualties, per-map conditions are placeholders in `rules_config` — flagged TBD for the designer; never hardcode alternatives in code.
- Combat screen art, UI theme and portraits are code-drawn placeholders pending assets.
- Save is manual between battles only (`user://save_game.json`).
