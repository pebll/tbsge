class_name TbsBoardConfig
extends Resource


@export var terrain_definitions: Array[TbsTerrainDefinition] = []
@export var unit_definitions: Array[TbsUnitDefinition] = []

# Simple baked layout: list of tiles and unit spawns.
@export var tiles: Array[Dictionary] = []      # { "coords": Vector2i, "terrain_id": String }
@export var unit_spawns: Array[Dictionary] = []  # { "coords": Vector2i, "unit_def_id": String, "team_id": int }


func get_terrain_def(id: String) -> TbsTerrainDefinition:
	for def in terrain_definitions:
		if def.id == id:
			return def
	return null


func get_unit_def(id: String) -> TbsUnitDefinition:
	for def in unit_definitions:
		if def.id == id:
			return def
	return null

