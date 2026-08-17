class_name UnitDefinition
extends Resource

enum ProjectileMotion {
	ARROW = 0,
	THROWN = 1,
}

@export var id: String = ""
@export var display_name: String = ""

@export var max_health: int = 10
@export var attack: int = 3
## Hex range for ranged attacks (0 = melee only). Valid values: 0, 1, 2.
@export var attack_range: int = 0
## Damage dealt by ranged_attack. Unused when attack_range is 0.
@export var ranged_attack: int = 0
## Projectile texture key under res://assets/projectiles/{id}.png
@export var projectile_id: String = ""
@export var projectile_motion: ProjectileMotion = ProjectileMotion.ARROW
## Action points restored at the start of this legion's team turn.
@export var ap: int = 2
## Damage absorbed from the first hit each unit takes per team turn (then breaks until next turn).
@export var shield: int = 0
## Relative sprite scale after auto-normalizing texture sheet size (~1.0 = default).
@export var image_size: float = 1.0

## Legion capacity + strip footprint. Allowed: 0.75, 1, 1.5, 2, 3, 4, 6, 8, 10, 12.
## See UnitFootprint for size→cell mapping and packing into the 6×2 board.
@export var size: float = 1.5
## Gold cost per individual unit (not per legion).
@export var price: int = 5

@export var icon: Texture2D
## Optional per-unit legion SFX; empty uses the global default for that action.
@export var sfx_select: AudioStream
@export var sfx_move: AudioStream
@export var sfx_hit: AudioStream
@export var sfx_death: AudioStream
## Empty = legion uses default move / melee_attack / ranged_attack / self_heal.
@export var action_ids: Array[String] = []
## Per-action param overrides: { "heal_ally": { "heal_amount": 4, "target_range": 2 } }.
@export var action_params: Dictionary = {}

func has_ranged() -> bool:
	return attack_range > 0 and ranged_attack > 0

func has_allowed_size() -> bool:
	const UnitFootprintScript = preload("res://scripts/ui/interact/unit_footprint.gd")
	return UnitFootprintScript.is_allowed(size)

func projectile_texture_path() -> String:
	if projectile_id.is_empty():
		return ""
	return "res://assets/projectiles/%s.png" % projectile_id
