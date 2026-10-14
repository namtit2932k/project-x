extends Resource
class_name FactionData
## Faction definition including its reconciliation rules (separate from map victory).
## Thresholds are hidden from the player at runtime but live here as designer data.

@export var id: String = ""
@export var display_name: String = ""
## Remnant sub-faction ch01: who we must persuade in this map's post-battle.
@export var remnant_id: String = ""
## Reconciliation conditions: secret kill threshold + required in-battle event keys.
## Event keys (recorded by systems): "dialog_talk", "spared_boss", "no_nonquest_kills", ...
@export var reconcile: Dictionary = {
	"kill_threshold": 4,          # TBD with designer, hidden threshold
	"required_events": [],        # Array[String]
}
## UI attitude color per reconcile progress: safe / neutral / lost.
@export var attitude_colors: Dictionary = {"safe": Color(0.3, 0.8, 0.4), "neutral": Color(0.9, 0.85, 0.3), "lost": Color(0.85, 0.3, 0.3)}
