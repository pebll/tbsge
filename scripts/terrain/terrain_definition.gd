extends Resource

## One terrain type (data/terrain/<id>.tres). Read through scripts/terrain/terrain_rules.gd.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Tile art under res://assets/tiles_sliced/tiles_terrain/, tinted by `tint` (placeholders
## for terrains without their own art reuse another texture with a tint).
@export var texture: Texture2D
@export var tint: Color = Color.WHITE
## (scale, dx, dy) fit of `texture` on the hex grid (see variant_fit).
@export var texture_fit: Vector3 = Vector3(1, 0, 0)
## Alternative looks (same rules). A match picks one per terrain (Tile.variant indexes
## [texture] + variants). variant_fit[i] = (scale, dx, dy) to sit the art on the hex grid
## like the 700x650 originals (dx/dy in original texture pixels); computed from the art.
@export var variants: Array[Texture2D] = []
@export var variant_fit: PackedVector3Array = PackedVector3Array()
## Ground units can stand here.
@export var walkable: bool = true
## AP to step onto this tile (ground units).
@export var move_cost: int = 1
## Incoming damage multipliers for legions standing here (cover).
@export var ranged_defense: float = 1.0
@export var melee_defense: float = 1.0
## Blocks line of sight for ranged attacks and ranged casts passing over it.
@export var blocks_los: bool = false
## Vision change for legions standing here (fog of war).
@export var vision_mod: int = 0
## Flyers may cross / stop here.
@export var flyer_can_cross: bool = true
@export var flyer_can_stop: bool = true
## Relative frequency in map generation.
@export var map_weight: float = 1.0
