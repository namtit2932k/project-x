# Project X (Ceasefire) — How to run

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
- After moving: action menu at the unit (Attack / Wait / skills like Heal).
- Attack: click a highlighted target -> forecast panel (damage / hit% / crit% / counter) -> Confirm.
- Right click: cancel current selection/step.
- **End phase** button: hands over to enemy -> NPC phases, then next turn.
- **Rewind** button: restores the last confirmed-action snapshot (costs one use; budget by difficulty: story ∞, normal 5, hard 3, nightmare 0).

## Validation & tests (headless)

```
godot --headless --path . res://tools/validate_data.tscn    # data validation (0 errors expected)
godot --headless --path . res://tests/run_tests.tscn        # 24 rule checks (movement/combat/objectives/rewind/reconcile/save)
godot --headless --path . res://tests/smoke_full_battle.tscn # full battle driven by AI, end-to-end through BattleDirector
```

## Adding content (data-only)

- New class: copy any `data/classes/*.tres`, change id/stats.
- New unit: `data/units/*.tres`.
- New map/objective type combo: `data/maps/*.tres` and declare objectives as `{type, params}` (plugin types: eliminate / escort / defend / retrieve / capture).
- New bond pair: `data/bonds/*.tres` (never inferred — designer list only).
- New dialogue: `data/dialogues/*.tres` played by `DialoguePlayer`.
- Balance/TBD numbers: `data/rules/rules_config.tres`.

## Placeholders & notes

- Damage hit/crit formulas, terrain costs, severity of casualties, per-map conditions are placeholders in `rules_config` — flagged TBD for the designer; never hardcode alternatives in code.
- Combat screen art, UI theme and portraits are code-drawn placeholders pending assets.
- Save is manual between battles only (`user://save_game.json`).
