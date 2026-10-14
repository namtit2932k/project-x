extends Node
## Campaign-level state shared between screens (roster, chapter progress, difficulty, bond, outcomes).
## Saved only between battles by SaveService; never mutated mid-battle.

const BOND_RANKS: Array[String] = ["C", "B", "A", "S"]

var difficulty: String = "normal"
var current_chapter_id: String = ""
## roster: unit_id -> {level:int, exp:int, alive:bool, defeats:int}
var roster: Dictionary = {}
## bond_points: pair_id -> int; bond_ranks: pair_id -> rank string ("", C, B, A, S)
var bond_points: Dictionary = {}
var bond_ranks: Dictionary = {}
var bond_scenes_viewed: Dictionary = {}           # pair_id -> Array[String] of ranks watched/skipped
var s_pairs: Dictionary = {}                      # unit_id -> pair_id (exclusive S)
var s_lock_unit: String = ""                      # unit that confirmed the S lock this campaign
## reconcile_outcomes: chapter_id -> {faction_id: {persuaded: bool, kills: int, events: Array}}
var reconcile_outcomes: Dictionary = {}
var completed_chapters: Dictionary = {}           # chapter_id -> true
## Story branch id (work in progress: filled by event/dialogue choices; saved with the game).
var story_branch: String = ""
## options: {volume: float, fullscreen: bool}
var options: Dictionary = {"volume": 0.8, "fullscreen": false}


func new_game() -> void:
	# difficulty and options are NOT reset here: the player may pick them on the menu
	# right before "New campaign" (menu selection must survive the campaign reset).
	current_chapter_id = ""
	story_branch = ""
	roster.clear()
	bond_points.clear()
	bond_ranks.clear()
	bond_scenes_viewed.clear()
	s_pairs.clear()
	s_lock_unit = ""
	reconcile_outcomes.clear()
	completed_chapters.clear()
	options = {"volume": 0.8, "fullscreen": false}


## Register every roster unit from data (joined roster for the campaign; TBD story gating).
func build_roster() -> void:
	roster.clear()
	for unit_id in DataRegistry.all_ids("units"):
		var ud := DataRegistry.get_unit(unit_id)
		if ud == null or not ud.in_roster:
			continue
		roster[unit_id] = {"level": int(ud.level), "exp": 0, "alive": true, "defeats": 0}


func current_chapter() -> Resource:
	var chapters := DataRegistry.chapters_sorted()
	if chapters.is_empty():
		push_error("GameState: no chapters in data/")
		return null
	if current_chapter_id == "":
		return chapters[0]
	return DataRegistry.get_chapter(current_chapter_id)


## Moves to the next chapter (next in data order). On a new game (id == "") the first
## chapter counts as current, so this correctly lands on chapter 2. At the end of the
## campaign the id stays on the final chapter: check has_next_chapter() instead of
## guessing from the id, so the loop never silently replays the last chapter.
func advance_chapter() -> void:
	var chapter := current_chapter()
	if chapter == null:
		return
	var chapters := DataRegistry.chapters_sorted()
	for i in chapters.size():
		if String(chapters[i].id) == String(chapter.id):
			if i + 1 < chapters.size():
				current_chapter_id = String(chapters[i + 1].id)
			return


func has_next_chapter() -> bool:
	var chapter := current_chapter()
	if chapter == null:
		return false
	var chapters := DataRegistry.chapters_sorted()
	return not chapters.is_empty() and String(chapters[chapters.size() - 1].id) != String(chapter.id)


## Roster entries for units added to data after a save was written: merge them in as
## fresh members so prep/camp never index a missing id.
func merge_roster_with_data() -> void:
	for unit_id in DataRegistry.all_ids("units"):
		var ud := DataRegistry.get_unit(unit_id)
		if ud != null and bool(ud.in_roster) and not roster.has(unit_id):
			roster[unit_id] = {"level": int(ud.level), "exp": 0, "alive": true, "defeats": 0}


func bond_rank_for(pair_id: String) -> String:
	return bond_ranks.get(pair_id, "")


func to_dict() -> Dictionary:
	return {
		"difficulty": difficulty,
		"current_chapter_id": current_chapter_id,
		"roster": roster,
		"bond_points": bond_points,
		"bond_ranks": bond_ranks,
		"bond_scenes_viewed": bond_scenes_viewed,
		"s_pairs": s_pairs,
		"s_lock_unit": s_lock_unit,
		"reconcile_outcomes": reconcile_outcomes,
		"completed_chapters": completed_chapters,
		"story_branch": story_branch,
		"options": options,
	}


func from_dict(d: Dictionary) -> void:
	difficulty = String(d.get("difficulty", "normal"))
	current_chapter_id = String(d.get("current_chapter_id", ""))
	roster = d.get("roster", {})
	bond_points = d.get("bond_points", {})
	bond_ranks = d.get("bond_ranks", {})
	bond_scenes_viewed = d.get("bond_scenes_viewed", {})
	s_pairs = d.get("s_pairs", {})
	s_lock_unit = String(d.get("s_lock_unit", ""))
	reconcile_outcomes = d.get("reconcile_outcomes", {})
	completed_chapters = d.get("completed_chapters", {})
	story_branch = String(d.get("story_branch", ""))
	options = d.get("options", {"volume": 0.8, "fullscreen": false})
