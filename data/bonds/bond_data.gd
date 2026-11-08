extends Resource
class_name BondData
## One eligible bond pair, straight from the designer-provided pair list.
## The system never infers pairs from gender or roster; eligibility is data-only.

@export var id: String = ""
@export var unit_a: String = ""
@export var unit_b: String = ""
## F-BOND: cumulative support points that make each rank's scene choosable (GDD provisional
## 2/5/9); the rank itself rises only after the scene is watched or skipped.
@export var scene_thresholds: Dictionary = {"C": 2, "B": 5, "A": 9}
## F-BOND: earliest chapter id at which each rank's scene may open ({rank: chapter_id}, "" or
## missing = no story gate). Writer content.
@export var scene_earliest_chapter: Dictionary = {}
## Scene dialogue id per rank: {rank: dialogue_id}
@export var scene_dialogue_ids: Dictionary = {}
## F-BOND: designer whitelist — only pairs marked here can ever reach rank S (GDD Core Rule 4b).
@export var s_eligible: bool = false
## The GDD's s_earliest_chapter: S cannot be locked before the campaign reaches this chapter
## ("" = no gate). Field name kept from D05 (ids/fields are not renamed casually).
@export var s_milestone_chapter_id: String = ""
