class_name TbsHexCoord
extends RefCounted


static func neighbors_axial(q: int, r: int) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
	]
	var result: Array[Vector2i] = []
	for d in dirs:
		result.append(Vector2i(q + d.x, r + d.y))
	return result

