extends RefCounted
class_name BondCampaign
## Between-battle bond rules (F-BOND; GDD bond-adjacency Core Rules 4a/4b, Support revision
## 2026-10-07): which scene is next, whether it may open (points + chapter gate + both alive),
## raising a rank after the scene, and the exclusive S lock. Static, reads/writes GameState;
## the camp only renders these answers. Not an autoload.

const RANKS: Array[String] = ["C", "B", "A"]


## Next normal rank after the pair's current one ("C", "B", "A"), or "" once A is reached.
static func next_rank(pair: Resource) -> String:
	var idx := RANKS.find(GameState.bond_rank_for(String(pair.id)))
	if idx >= RANKS.size() - 1 or GameState.bond_rank_for(String(pair.id)) == "S":
		return ""
	return RANKS[idx + 1]


## Points still missing for the next scene (0 when reached, -1 when there is no next scene).
static func points_missing(pair: Resource) -> int:
	var rank := next_rank(pair)
	if rank == "":
		return -1
	var need := int(pair.scene_thresholds.get(rank, 1 << 30))
	return maxi(need - int(GameState.bond_points.get(String(pair.id), 0)), 0)


## "ready" | "need_points" | "waiting_story" | "unavailable" (a member is gone) | "max".
static func scene_state(pair: Resource) -> String:
	var rank := next_rank(pair)
	if rank == "":
		return "max"
	if not both_alive(pair):
		return "unavailable"
	if points_missing(pair) > 0:
		return "need_points"
	if not chapter_reached(String(pair.scene_earliest_chapter.get(rank, ""))):
		return "waiting_story"
	return "ready"


## Watching or skipping the next scene raises the rank (surplus points carry over).
static func rank_up(pair: Resource, rank: String) -> void:
	GameState.bond_ranks[String(pair.id)] = rank
	var viewed: Array = GameState.bond_scenes_viewed.get(String(pair.id), [])
	if not viewed.has(rank):
		viewed.append(rank)
	GameState.bond_scenes_viewed[String(pair.id)] = viewed


## "not_eligible" | "locked" (this pair is S) | "closed" (a member is S with someone else)
## | "available" | "not_yet" (A not viewed, a member gone, or before s_earliest_chapter).
static func s_state(pair: Resource) -> String:
	if not bool(pair.s_eligible):
		return "not_eligible"
	var a := String(pair.unit_a)
	var b := String(pair.unit_b)
	if String(GameState.s_pairs.get(a, "")) == String(pair.id) and String(GameState.s_pairs.get(b, "")) == String(pair.id):
		return "locked"
	if GameState.s_pairs.has(a) or GameState.s_pairs.has(b):
		return "closed"
	var a_viewed: bool = GameState.bond_scenes_viewed.get(String(pair.id), []).has("A")
	if GameState.bond_rank_for(String(pair.id)) != "A" or not a_viewed or not both_alive(pair) \
			or not chapter_reached(String(pair.s_milestone_chapter_id)):
		return "not_yet"
	return "available"


## Atomic S lock (GDD lock_s_partner): re-checks every condition, then rank S and the
## symmetric S partner entries in one step. false = nothing changed.
static func lock_s(pair: Resource) -> bool:
	if s_state(pair) != "available":
		return false
	GameState.bond_ranks[String(pair.id)] = "S"
	GameState.s_pairs[String(pair.unit_a)] = String(pair.id)
	GameState.s_pairs[String(pair.unit_b)] = String(pair.id)
	GameState.s_lock_unit = String(pair.unit_a)
	return true


static func both_alive(pair: Resource) -> bool:
	for unit_id in [String(pair.unit_a), String(pair.unit_b)]:
		if not GameState.roster.has(unit_id) or not bool(GameState.roster[unit_id].get("alive", false)):
			return false
	return true


## Story gate: true when chapter_id is empty or the campaign's current chapter (or a completed
## one) is at or past it in chapter order.
static func chapter_reached(chapter_id: String) -> bool:
	if chapter_id == "":
		return true
	if GameState.completed_chapters.has(chapter_id):
		return true
	var gate := DataRegistry.get_data("chapters", chapter_id)
	var current := GameState.current_chapter()
	if gate == null or current == null:
		return false
	return int(current.order) >= int(gate.order)
