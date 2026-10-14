extends Resource
class_name BondData
## One eligible bond pair, straight from the designer-provided pair list.
## The system never infers pairs from gender or roster; eligibility is data-only.

@export var id: String = ""
@export var unit_a: String = ""
@export var unit_b: String = ""
## Points needed to unlock each rank's scene (rank rises only after scene watched/skipped).
@export var scene_thresholds: Dictionary = {"C": 20, "B": 40, "A": 60}
## Scene dialogue id per rank: {rank: dialogue_id}
@export var scene_dialogue_ids: Dictionary = {}
## Story milestone flag gating S (extends Resource; leave "" when not yet in story data).
@export var s_milestone_chapter_id: String = ""
