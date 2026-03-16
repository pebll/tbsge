class_name TbsTileState
extends RefCounted

var coords : Vector2i # position
var terrain_id: String = "" # terrain def link

func _init(p_coords: Vector2i, p_terrain_id: String) -> void:
      coords = p_coords
      terrain_id = p_terrain_id

