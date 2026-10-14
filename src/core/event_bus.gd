extends Node
## Global event hub. Scenes, rules code and systems communicate through these typed signals.

signal unit_moved(unit_id: String, from_cell: Vector2i, to_cell: Vector2i)
signal combat_resolved(strikes: Array)
signal unit_died(unit_id: String, killer_id: String)
signal phase_changed(phase: int, turn_number: int)
signal turn_started(turn_number: int)
signal objectives_changed(progress: Array)
signal battle_ended(result: Dictionary)
signal bond_points_gained(pair_id: String, amount: int)
signal reconcile_state_changed()

const PHASE_PLAYER := 0
const PHASE_ENEMY := 1
const PHASE_NPC := 2
