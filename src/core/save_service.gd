extends Node
## Manual save/load between battles only. One campaign slot, JSON under user://.

const SAVE_PATH := "user://save_game.json"
## V2 adds GameState.story_flags (D09). V3 (F-SAVE) marks the 08-11-2026 schema (gold, bags,
## faction kills / states, starting bonds). Older saves still load: missing keys default in
## GameState.from_dict, migrate() fixes what defaults cannot, and REWRITTEN saves come out at
## the current version.
const SAVE_VERSION := 3
const READABLE_VERSIONS := [1, 2, 3]


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
	migrate(int(payload.get("save_version", SAVE_VERSION)))
	return true


## F-SAVE: steps for saves older than SAVE_VERSION, run after GameState.from_dict. Returns
## the warnings it logged (also printed), so tests and tools can read them.
func migrate(from_version: int) -> Array[String]:
	var notes: Array[String] = []
	if from_version < 3:
		# Roster units that no longer exist or belong to another campaign (the demo units that
		# leaked into legacy rosters before the campaign-tag fix).
		for unit_id in GameState.roster.keys():
			var ud := DataRegistry.get_unit(String(unit_id))
			if ud == null or not GameState._unit_in_campaign(ud):
				GameState.roster.erase(unit_id)
				notes.append("SaveService: v%d save - dropped roster unit %s (not in the %s campaign)" % [from_version, unit_id, GameState.campaign_tag])
	# F-CAS (every version): there is no permadeath any more - a dead roster unit comes back.
	for unit_id in GameState.roster:
		if not bool(GameState.roster[unit_id].get("alive", true)):
			GameState.roster[unit_id]["alive"] = true
			notes.append("SaveService: %s was dead in this save - permadeath no longer exists, back on the roster" % unit_id)
	for note in notes:
		push_warning(note)
	return notes
