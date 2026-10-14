extends RefCounted
class_name SnapshotStack
## Rewind/snapshot stack: stores a snapshot before each confirmed command; one use rolls back
## to a chosen frame and drops later frames. Budget by difficulty: Story unlimited (-1), Normal 5, Hard 3, Nightmare 0.
## Rewind counting mode (per-use vs per-step) is a designer decision: rules_config.rewind_count_mode.

var frames: Array = []        # newest last: {snapshot: Dictionary, label: String}


func push(state: BattleState, label: String) -> void:
	frames.append({"snapshot": state.to_dict(), "label": label})


func has_frames() -> bool:
	return not frames.is_empty()


## Player rewinds restore the newest frame whose phase == PLAYER (end-of-enemy/NPC-phase
## frames are engine bookkeeping, not a valid player action point). Returns -1 when none.
func find_last_player_frame() -> int:
	for i in range(frames.size() - 1, -1, -1):
		var snap: Dictionary = frames[i]["snapshot"]
		if int(snap.get("phase", -1)) == BattleState.PHASE_PLAYER:
			return i
	return -1
	return not frames.is_empty()


## Rolls back to the frame at index (0-based, oldest = 0), dropping newer frames.
func restore_to(state: BattleState, frame_index: int) -> void:
	if frame_index < 0 or frame_index >= frames.size():
		push_error("SnapshotStack: invalid frame index %d" % frame_index)
		return
	state.from_dict(frames[frame_index]["snapshot"])
	frames.resize(frame_index)


func drop_all() -> void:
	frames.clear()


## Rewind budget for difficulty: -1 means unlimited. (rewind_per_difficulty in rules_config)
static func budget_for_difficulty(difficulty: String) -> int:
	var uses: Dictionary = DataRegistry.rule("rewind_per_difficulty", {"normal": 5})
	return int(uses.get(difficulty, 5))


## Rewind counting (D04): "per_use" is the official mode - one button press costs one use
## no matter how many actions it rolls back. Other values stay readable in config but the
## engine only implements per_use.
static func rewind_count_mode() -> String:
	var mode := String(DataRegistry.rule("rewind_count_mode", "per_use"))
	if mode != "per_use":
		push_warning("SnapshotStack: rewind_count_mode '%s' has no implementation; per_use used" % mode)
	return "per_use"
