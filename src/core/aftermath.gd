extends RefCounted
class_name Aftermath
## F-AFTER (GDD Narrative/Bond-Scene Rules 6-7): which scenes play right after a battle, in
## order. Pure selection - Main plays them. Read BEFORE the campaign merge (the
## pressure-continues index is the count before this battle's beat).


## [DialogueData] for this battle's end. Empty for the bad ending (it has its own scene).
static func scenes(result: Dictionary, chapter: Resource, map: Resource) -> Array:
	var out: Array = []
	var won := String(result.get("status", "")) == "win"
	if won and not Array(result.get("bad_ending_factions", [])).is_empty():
		return out
	# 6a severance: impossible without permadeath (F-CAS); nothing to queue.
	if not won:
		var fallen := not bool(result.get("restraint", {}).get("zero_ally_deaths", true))
		var keys: Array = ["LostFallen", "Lost"] if fallen else ["LostClean", "Lost"]
		_append(out, _from_map(map, keys), "loss_fallen" if fallen else "loss_clean")
		return out
	var reconcile: Dictionary = result.get("reconcile", {})
	if reconcile.is_empty():
		# 6d plain victory: the chapter's own post-battle scene, else the map's, else generic.
		var chapter_scene := _dialogue(String(chapter.post_dialogue_id)) if chapter != null and "post_dialogue_id" in chapter else null
		if chapter_scene != null:
			out.append(chapter_scene)
		else:
			_append(out, _from_map(map, ["Victory"]), "victory")
		return out
	# 6c: one scene per engaged holdout faction, by its state after this battle.
	for faction_id in reconcile:
		var f := DataRegistry.get_faction(String(faction_id))
		if bool(reconcile[faction_id].get("persuaded", false)):
			var own := _dialogue(String(f.persuaded_dialogue_id)) if f != null else null
			_append(out, own if own != null else _from_map(map, ["Persuaded"]), "persuaded")
		else:
			var beat: Resource = null
			if f != null and not f.engaged_dialogue_ids.is_empty():
				var idx := mini(int(GameState.pressure_continues_count.get(String(faction_id), 0)), f.engaged_dialogue_ids.size() - 1)
				beat = _dialogue(String(f.engaged_dialogue_ids[idx]))
			_append(out, beat if beat != null else _from_map(map, ["Engaged"]), "engaged")
	if chapter != null and "post_dialogue_id" in chapter:
		var post := _dialogue(String(chapter.post_dialogue_id))
		if post != null:
			out.append(post)
	return out


static func _append(out: Array, scene: Resource, fallback_key: String) -> void:
	if scene == null:
		scene = _dialogue(String(DataRegistry.rule("aftermath_dialogue_ids", {}).get(fallback_key, "")))
	if scene != null:
		out.append(scene)


static func _dialogue(id: String) -> Resource:
	return DataRegistry.get_dialogue(id) if id != "" else null


## The map's aftermath_lines under the first key present, as a narrator scene; null if none.
static func _from_map(map: Resource, keys: Array) -> Resource:
	if map == null or not ("aftermath_lines" in map):
		return null
	for key in keys:
		var lines: Variant = map.aftermath_lines.get(key, [])
		if lines is Array and not (lines as Array).is_empty():
			var dlg := DialogueData.new()
			dlg.id = "aftermath_%s_%s" % [String(map.id), String(key)]
			for text in lines:
				dlg.lines.append({"speaker": "", "text": String(text)})
			return dlg
	return null
