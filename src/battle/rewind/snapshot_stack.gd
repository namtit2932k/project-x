extends RefCounted
class_name SnapshotStack
## Rewind/snapshot stack: stores a snapshot before each confirmed command; one use rolls back
## to a chosen frame and drops later frames. Budget by difficulty: Story unlimited (-1), Normal 5, Hard 3, Nightmare 0.
## Rewind counting mode (per-use vs per-step) is a designer decision: rules_config.rewind_count_mode.

var frames: Array = []        # newest last: {snapshot: Dictionary, label: String}


func push(state: BattleState, label: String) -> void:
	frames.append({"snapshot": state.to_dict(), "labels": label})


func has_frames() -> bool:
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
