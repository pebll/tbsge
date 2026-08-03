class_name ActionDefinition
extends Resource

enum TargetingKind {
	SELF,
	ADJACENT_MOVE,
	ADJACENT_ENEMY,
	ENEMY_IN_RANGE,
	ALLY_IN_RANGE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var ap_cost: int = 1
@export var terminal: bool = false
@export var targeting: TargetingKind = TargetingKind.ADJACENT_MOVE
## Tile overlay id when this action is selected (movable, attackable, healable).
@export var overlay_state: String = "movable"
@export var heal_amount: int = 0
## Hex range for ally/enemy targeting beyond adjacency helpers (0 = unused / self).
@export var target_range: int = 0
## Turns before this action can be used again (0 = no cooldown).
@export var cooldown: int = 0
## Plain-language tooltip; may include {heal}, {range}, {ap} tokens.
@export_multiline var tooltip_body: String = ""
## Glossary keyword ids shown as chips (e.g. terminal, range, ally).
@export var keywords: Array[String] = []
