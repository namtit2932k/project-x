extends Node
## Campaign-level state shared between screens (roster, chapter progress, difficulty, bond, outcomes).
## Saved only between battles by SaveService; never mutated mid-battle.

const BOND_RANKS: Array[String] = ["C", "B", "A", "S"]

var difficulty: String = "normal"
## Active campaign (F4.1): "demo" is the main flow, "legacy" = old ch01 reachable from
## the debug menu. Saved in the campaign save; old saves read back as legacy below.
var campaign_tag: String = "demo"
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
## F-PS3 persistent_kill_count: faction_id -> kills committed by earlier victories (never rewound).
var faction_kill_counts: Dictionary = {}
## F-FST GDD Faction Engagement State: faction_id -> "engaged" | "persuaded" | "unpersuadable"
## (missing = Unengaged). Written by victories only; persuaded/unpersuadable are terminal.
var faction_states: Dictionary = {}
## F-ITEM: campaign gold (never negative). Roster entries also carry "items" (max_item_slots).
var gold: int = 0
## F-AFTER (GDD Narrative Rule 6c): how many "pressure continues" beats each faction has had.
var pressure_continues_count: Dictionary = {}
const TERMINAL_FACTION_STATES: Array[String] = ["persuaded", "unpersuadable"]
## Story branch id (work in progress: filled by event/dialogue choices; saved with the game).
var story_branch: String = ""
## Story flags set by DialoguePlayer lines with set_flag (D09); the same dictionary is
## saved: reading an old save yields an empty flags table for missing keys.
var story_flags: Dictionary = {}
## options: {volume: float, fullscreen: bool, language: String}
var options: Dictionary = {"volume": 0.8, "fullscreen": false, "language": DEFAULT_LANGUAGE}

## I18N: languages the UI ships in, shown by their own name (never translated).
const LANGUAGES := {"en": "English", "vi": "Tiếng Việt"}
const DEFAULT_LANGUAGE := "en"


func _ready() -> void:
	# DataRegistry (earlier autoload) has registered the translations by now.
	apply_language()


## Current UI language code.
func language() -> String:
	return String(options.get("language", DEFAULT_LANGUAGE))


## Switches the UI language and applies it right away (screens built afterwards use it).
func set_language(code: String) -> void:
	options["language"] = code if LANGUAGES.has(code) else DEFAULT_LANGUAGE
	apply_language()


func apply_language() -> void:
	TranslationServer.set_locale(language())


func new_game() -> void:
	# difficulty and options are NOT reset here: the player may pick them on the menu
	# right before "New campaign" (menu selection must survive the campaign reset).
	campaign_tag = "demo"
	current_chapter_id = ""
	story_branch = ""
	story_flags.clear()
	roster.clear()
	bond_points.clear()
	bond_ranks.clear()
	bond_scenes_viewed.clear()
	s_pairs.clear()
	s_lock_unit = ""
	reconcile_outcomes.clear()
	completed_chapters.clear()
	faction_kill_counts.clear()
	faction_states.clear()
	gold = 0
	pressure_continues_count.clear()
	# The UI language is a player setting, it survives a new campaign.
	options = {"volume": 0.8, "fullscreen": false, "language": language()}


## Register the roster of the active campaign (F4.2): only units tagged for it (or
## untagged legacy characters) join, so demo chapters never mix in the old ch01 roster.
func build_roster() -> void:
	roster.clear()
	for unit_id in DataRegistry.all_ids("units"):
		var ud := DataRegistry.get_unit(unit_id)
		if ud == null or not _unit_in_campaign(ud):
			continue
		roster[unit_id] = {"level": int(ud.level), "exp": 0, "alive": true, "defeats": 0, "items": starting_items(String(unit_id))}
	_apply_starting_bonds()


## F-DLOCK (GDD Difficulty Rule 2): tiers the camp may switch between - Story / Normal / Hard,
## none at all once the campaign is on Nightmare (chosen only at New campaign, permanently).
const DIFFICULTIES_ALL: Array[String] = ["story", "normal", "hard", "nightmare"]


func camp_difficulty_choices() -> Array[String]:
	if difficulty == "nightmare":
		return []
	return ["story", "normal", "hard"]


## The tier after the current one in the camp cycle (the current one when locked).
func next_camp_difficulty() -> String:
	var choices := camp_difficulty_choices()
	if choices.is_empty():
		return difficulty
	return choices[(choices.find(difficulty) + 1) % choices.size()]


## F-CAS: a unit that fell on the last map (Hard / Nightmare) cannot be picked for this one.
func is_resting(unit_id: String) -> bool:
	return int((roster.get(unit_id, {}) as Dictionary).get("rest", 0)) > 0


## F-ITEM: a unit's data-authored items, trimmed to the slot limit.
func starting_items(unit_id: String) -> Array:
	var ud := DataRegistry.get_unit(unit_id)
	var out: Array = []
	if ud == null:
		return out
	for item_id in ud.carried_items:
		if out.size() < int(DataRegistry.rule("max_item_slots", 2)):
			out.append(String(item_id))
	return out


func _unit_in_campaign(ud: Resource) -> bool:
	if bool(ud.in_roster) == false:
		return false
	var unit_tag := String(ud.campaign_tag)
	return unit_tag == "" or unit_tag == campaign_tag


func current_chapter() -> Resource:
	var chapters := DataRegistry.chapters_sorted(campaign_tag)
	if chapters.is_empty():
		push_error("GameState: no chapters in data/")
		return null
	if current_chapter_id == "":
		return chapters[0]
	return DataRegistry.get_chapter(current_chapter_id)


## D10 true-end eligibility (placeholder): every chapter flagged counts_for_true_ending
## must be completed AND every remnant faction of that chapter persuaded. The ending
## scene itself is content work (paused until production story data).
func is_true_ending_eligible() -> bool:
	for chapter in DataRegistry.chapters_sorted(campaign_tag):
		if not bool(chapter.counts_for_true_ending):
			continue
		var chapter_id := String(chapter.id)
		if not completed_chapters.has(chapter_id):
			return false
		var outcomes: Dictionary = reconcile_outcomes.get(chapter_id, {})
		for faction_id in remnant_factions_of(chapter):
			var entry: Dictionary = outcomes.get(String(faction_id), {})
			# F-FST: a faction persuaded in a later chapter counts as persuaded too.
			if not bool(entry.get("persuaded", false)) and faction_state(String(faction_id)) != "persuaded":
				return false
	return true


## F-FST: "unengaged" | "engaged" | "persuaded" | "unpersuadable".
func faction_state(faction_id: String) -> String:
	return String(faction_states.get(faction_id, "unengaged"))


## F-FST: persuaded / unpersuadable never change again and are ignored by later battles.
func is_faction_terminal(faction_id: String) -> bool:
	return faction_state(faction_id) in TERMINAL_FACTION_STATES


## Derives the chapter's remnant factions from its map placements (unit defs), so no
## per-chapter list is needed in data.
func remnant_factions_of(chapter: Resource) -> Array:
	var map := DataRegistry.get_map(String(chapter.map_id))
	if map == null:
		return []
	var out: Array = []
	var words: Array = []
	words.append_array(map.enemy_placements)
	words.append_array(map.npc_placements)
	for p in words:
		var ud := DataRegistry.get_unit(String(p.unit_id))
		if ud == null:
			continue
		var fid := String(p.get("faction_override", "")) if String(p.get("faction_override", "")) != "" else String(ud.faction_id)
		var fac := DataRegistry.get_faction(fid)
		if fac != null and String(fac.remnant_id) != "" and not out.has(fid):
			out.append(fid)
	return out


## Moves to the next chapter (next in data order). On a new game (id == "") the first
## chapter counts as current, so this correctly lands on chapter 2. At the end of the
## campaign the id stays on the final chapter: check has_next_chapter() instead of
## guessing from the id, so the loop never silently replays the last chapter.
func advance_chapter() -> void:
	var chapter := current_chapter()
	if chapter == null:
		return
	var chapters := DataRegistry.chapters_sorted(campaign_tag)
	for i in chapters.size():
		if String(chapters[i].id) == String(chapter.id):
			if i + 1 < chapters.size():
				current_chapter_id = String(chapters[i + 1].id)
			return


func has_next_chapter() -> bool:
	var chapter := current_chapter()
	if chapter == null:
		return false
	var chapters := DataRegistry.chapters_sorted(campaign_tag)
	return not chapters.is_empty() and String(chapters[chapters.size() - 1].id) != String(chapter.id)


## Roster entries for units added to data after a save was written: merge them in as
## fresh members so prep/camp never index a missing id.
func merge_roster_with_data() -> void:
	for unit_id in DataRegistry.all_ids("units"):
		var ud := DataRegistry.get_unit(unit_id)
		if ud != null and bool(ud.in_roster) and _unit_in_campaign(ud) and not roster.has(unit_id):
			roster[unit_id] = {"level": int(ud.level), "exp": 0, "alive": true, "defeats": 0, "items": starting_items(String(unit_id))}


## P-11: pairs that start a campaign already bonded (BondData.start_rank / start_points),
## only when both members are in this campaign's roster.
func _apply_starting_bonds() -> void:
	for pair_id in DataRegistry.all_ids("bonds"):
		var pair := DataRegistry.get_data("bonds", pair_id)
		if pair == null or String(pair.start_rank) == "" or String(pair.start_rank) == "S":
			continue
		if not roster.has(String(pair.unit_a)) or not roster.has(String(pair.unit_b)):
			continue
		bond_ranks[pair_id] = String(pair.start_rank)
		bond_points[pair_id] = maxi(int(bond_points.get(pair_id, 0)), int(pair.start_points))
		var seen: Array = []
		for rank in BOND_RANKS:
			seen.append(rank)
			if rank == String(pair.start_rank):
				break
		bond_scenes_viewed[pair_id] = seen


func bond_rank_for(pair_id: String) -> String:
	return bond_ranks.get(pair_id, "")


func to_dict() -> Dictionary:
	return {
		"difficulty": difficulty,
		"campaign_tag": campaign_tag,
		"current_chapter_id": current_chapter_id,
		"roster": roster,
		"bond_points": bond_points,
		"bond_ranks": bond_ranks,
		"bond_scenes_viewed": bond_scenes_viewed,
		"s_pairs": s_pairs,
		"s_lock_unit": s_lock_unit,
		"reconcile_outcomes": reconcile_outcomes,
		"completed_chapters": completed_chapters,
		"faction_kill_counts": faction_kill_counts,
		"faction_states": faction_states,
		"gold": gold,
		"pressure_continues_count": pressure_continues_count,
		"story_branch": story_branch,
		"story_flags": story_flags,
		"options": options,
	}


func from_dict(d: Dictionary) -> void:
	difficulty = String(d.get("difficulty", "normal"))
	# F4.1: old saves carry no campaign tag — they were legacy ch01 campaigns, so they read
	# back as "legacy"; saves written after this field exists keep their tag.
	if d.has("campaign_tag"):
		campaign_tag = String(d.get("campaign_tag", campaign_tag))
	current_chapter_id = String(d.get("current_chapter_id", ""))
	roster = d.get("roster", {})
	bond_points = d.get("bond_points", {})
	bond_ranks = d.get("bond_ranks", {})
	bond_scenes_viewed = d.get("bond_scenes_viewed", {})
	s_pairs = d.get("s_pairs", {})
	s_lock_unit = String(d.get("s_lock_unit", ""))
	reconcile_outcomes = d.get("reconcile_outcomes", {})
	completed_chapters = d.get("completed_chapters", {})
	# Saves written before F-PSI have no cumulative kills: they start from 0.
	faction_kill_counts = d.get("faction_kill_counts", {})
	# Saves written before F-FST: every faction reads as Unengaged.
	faction_states = d.get("faction_states", {})
	gold = maxi(int(d.get("gold", 0)), 0)
	pressure_continues_count = d.get("pressure_continues_count", {})
	# Saves written before F-ITEM: roster units start with their data-authored items.
	for unit_id in roster:
		if not (roster[unit_id] as Dictionary).has("items"):
			roster[unit_id]["items"] = starting_items(String(unit_id))
	story_branch = String(d.get("story_branch", ""))
	story_flags = d.get("story_flags", {})
	options = d.get("options", {"volume": 0.8, "fullscreen": false})
	if not options.has("language"):
		options["language"] = DEFAULT_LANGUAGE
	apply_language()
