class_name ActionDefinition
extends Resource

enum TargetingKind {
	SELF,
	ADJACENT_MOVE,
	ADJACENT_ENEMY,
	ENEMY_IN_RANGE,
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
