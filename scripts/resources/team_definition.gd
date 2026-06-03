class_name TeamDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
## Banner art variant: 1, 2, or 3 (maps to banners_0_0 .. banners_0_2).
@export_range(1, 3) var banner_variant: int = 1
