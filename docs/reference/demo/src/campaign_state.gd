extends RefCounted
## Small campaign-progress store for authored story checkpoints and battles.
## Demo persistence is separate from the final seven-domain Save/Progression file.

const SCHEMA_VERSION := 1
const DEFAULT_SAVE_PATH := "user://ceasefire_campaign_demo.json"
const FACTION_STATES := ["Unengaged", "Engaged", "Persuaded", "Unpersuadable"]

var campaign_checkpoint: int = 0
var chapter_id: String = ""
var recruited_unit_ids: Array[String] = []
var faction_states: Dictionary = {}
var faction_kill_counts: Dictionary = {}
var completed_battle_ids: Array[String] = []
var last_error: String = ""


## Advances one authored story beat; chapter_id is supplied by story data.
func advance_checkpoint(next_checkpoint: int, next_chapter_id: String) -> bool:
	if next_checkpoint != campaign_checkpoint + 1 or next_chapter_id.is_empty():
		return false
	campaign_checkpoint = next_checkpoint
	chapter_id = next_chapter_id
	return true


## Adds a story-recruited unit once, without inventing its recruitment event.
func recruit_unit(unit_id: String) -> bool:
	if unit_id.is_empty() or recruited_unit_ids.has(unit_id):
		return false
	recruited_unit_ids.append(unit_id)
	return true


## Commits the persuasion-system kill count at battle end, even on defeat.
## battle_id prevents a replayed result from counting the same battle twice.
func commit_faction_battle(battle_id: String, faction_id: String, kills: int, final_state: String) -> bool:
	if battle_id.is_empty() or faction_id.is_empty() or kills < 0 or completed_battle_ids.has(battle_id):
		return false
	if final_state not in ["Engaged", "Persuaded", "Unpersuadable"]:
		return false
	if faction_state(faction_id) in ["Persuaded", "Unpersuadable"]:
		return false
	faction_kill_counts[faction_id] = faction_kills(faction_id) + kills
	faction_states[faction_id] = final_state
	completed_battle_ids.append(battle_id)
	return true


## Returns the campaign state of a faction not yet or already encountered.
func faction_state(faction_id: String) -> String:
	return str(faction_states.get(faction_id, "Unengaged"))


## Returns prior-battle kill pressure for one faction, never a UI-visible tally.
func faction_kills(faction_id: String) -> int:
	return int(faction_kill_counts.get(faction_id, 0))


## Returns a detached snapshot that callers may serialize or inspect.
func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"campaign_checkpoint": campaign_checkpoint,
		"chapter_id": chapter_id,
		"recruited_unit_ids": recruited_unit_ids.duplicate(),
		"faction_states": faction_states.duplicate(true),
		"faction_kills": faction_kill_counts.duplicate(true),
		"completed_battle_ids": completed_battle_ids.duplicate()
	}


## Restores only a fully valid snapshot; invalid input leaves current state intact.
func restore(data: Variant) -> bool:
	last_error = ""
	if not data is Dictionary:
		last_error = "Campaign save root must be an object"
		return false
	var record: Dictionary = data
	for key in ["schema_version", "campaign_checkpoint", "chapter_id", "recruited_unit_ids", "faction_states", "faction_kills", "completed_battle_ids"]:
		if not record.has(key):
			last_error = "Campaign save is missing %s" % key
			return false
	if not _whole_number(record["schema_version"], 1) or int(record["schema_version"]) != SCHEMA_VERSION:
		last_error = "Unsupported campaign save version"
		return false
	if not _whole_number(record["campaign_checkpoint"], 0) or not record["chapter_id"] is String:
		last_error = "Invalid campaign position"
		return false
	if int(record["campaign_checkpoint"]) > 0 and record["chapter_id"].is_empty():
		last_error = "Campaign chapter id is missing"
		return false
	if not record["recruited_unit_ids"] is Array or not record["completed_battle_ids"] is Array:
		last_error = "Campaign id lists must be arrays"
		return false
	var recruits: Array[String] = _checked_ids(record["recruited_unit_ids"])
	var battles: Array[String] = _checked_ids(record["completed_battle_ids"])
	if recruits.size() != record["recruited_unit_ids"].size() or battles.size() != record["completed_battle_ids"].size():
		last_error = "Invalid or duplicate campaign ids"
		return false
	if not record["faction_states"] is Dictionary or not record["faction_kills"] is Dictionary:
		last_error = "Invalid faction tables"
		return false
	var states: Dictionary = record["faction_states"]
	var kills: Dictionary = record["faction_kills"]
	var normalized_kills: Dictionary = {}
	if states.size() != kills.size():
		last_error = "Faction tables do not match"
		return false
	for faction_id in states.keys():
		if not faction_id is String or faction_id.is_empty() or not kills.has(faction_id):
			last_error = "Invalid faction id"
			return false
		if states[faction_id] not in FACTION_STATES or not _whole_number(kills[faction_id], 0):
			last_error = "Invalid faction state or kill count"
			return false
		if states[faction_id] == "Unengaged" and int(kills[faction_id]) != 0:
			last_error = "Unengaged faction has kills"
			return false
		normalized_kills[faction_id] = int(kills[faction_id])
	campaign_checkpoint = int(record["campaign_checkpoint"])
	chapter_id = record["chapter_id"]
	recruited_unit_ids = recruits
	completed_battle_ids = battles
	faction_states = states.duplicate(true)
	faction_kill_counts = normalized_kills
	return true


## Writes a versioned demo progress file via a temporary file and rename.
func save(path: String = DEFAULT_SAVE_PATH) -> bool:
	last_error = ""
	if path.is_empty():
		last_error = "Campaign save path is empty"
		return false
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open temporary campaign save: %d" % FileAccess.get_open_error()
		return false
	var written: bool = file.store_string(JSON.stringify(snapshot()))
	file.close()
	if not written:
		last_error = "Cannot write temporary campaign save"
		return false
	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		last_error = "Cannot promote campaign save: %d" % rename_error
		return false
	return true


## Loads a demo progress file; missing and corrupt files both return false.
## last_error is empty for a missing file and describes corruption otherwise.
func load(path: String = DEFAULT_SAVE_PATH) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Cannot open campaign save: %d" % FileAccess.get_open_error()
		return false
	var json := JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		last_error = "Cannot parse campaign save: %s" % json.get_error_message()
		return false
	return restore(json.data)


static func _whole_number(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and float(value) == float(int(value)) and int(value) >= minimum


static func _checked_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		if not item is String or item.is_empty() or result.has(item):
			return []
		result.append(item)
	return result
