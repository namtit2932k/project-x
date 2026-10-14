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
## options: {volume: float, fullscreen: bool}
var options: Dictionary = {"volume": 0.8, "fullscreen": false}


func new_game() -> void:
	difficulty = "normal"
	current_chapter_id = ""
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
	if current_chapter_id == "":
		return DataRegistry.chapters_sorted()[0]
	return DataRegistry.get_chapter(current_chapter_id)


func advance_chapter() -> void:
	var chapters := DataRegistry.chapters_sorted()
	var idx := 0
	for i in chapters.size():
		if chapters[i].id == current_chapter_id:
			idx = i + 1
			break
	current_chapter_id = chapters[mini(idx, chapters.size() - 1)].id


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
	options = d.get("options", {"volume": 0.8, "fullscreen": false})
