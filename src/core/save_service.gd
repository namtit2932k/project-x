extends Node
## Manual save/load between battles only. One campaign slot, JSON under user://.

const SAVE_PATH := "user://save_game.json"
## V2 adds GameState.story_flags (D09). V1 saves still load: missing keys default to
## empty in GameState.from_dict, and REWRITTEN saves come out at the current version.
const SAVE_VERSION := 2
const READABLE_VERSIONS := [1, 2]


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func write_save(save_dict: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot open %s for writing" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(save_dict, "\t"))
	file.close()
	return true


func read_save() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary) or int(parsed.get("save_version", -1)) not in READABLE_VERSIONS:
		push_warning("SaveService: save file missing or corrupted version")
		return {}
	return parsed


func save_campaign() -> Dictionary:
	var payload := {"save_version": SAVE_VERSION, "game_state": GameState.to_dict()}
	if not write_save(payload):
		return {}
	return payload


func load_campaign() -> bool:
	var payload := read_save()
	if payload.is_empty():
		return false
	GameState.from_dict(payload.get("game_state", {}))
	return true
