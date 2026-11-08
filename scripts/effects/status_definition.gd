extends Resource

## One status effect type (data/status/*.tres). Behaviour lives in `behavior`, a script
## extending scripts/effects/status_behavior.gd; this resource is the player-facing side.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## Badge colour when there is no icon yet (first letter of the name on this colour).
@export var color: Color = Color(0.5, 0.4, 0.7)
## Positive effects are shown with a light badge, negative ones dark.
@export var is_debuff: bool = true
## Re-applying: "refresh" keeps the larger stacks and duration; "add" adds stacks and
## refreshes the duration.
@export_enum("refresh", "add") var stacking: String = "refresh"
@export var max_stacks: int = 99
## Duration in the owner's turns when the applier doesn't say (-1 = until removed).
@export var default_turns: int = 1
@export var behavior: Script
