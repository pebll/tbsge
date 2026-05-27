extends RefCounted

func run(_tree: SceneTree) -> bool:
	var radius := 3
	var expected_tiles := 1 + 3 * radius * (radius + 1)

	var parent := Node2D.new()
	var grid_visu := {}
	var grid_model := {}

	var mg := MapGenerator.new(135.3, 0.75)
	mg.generate_hex_map(radius, parent, grid_visu, grid_model)

	if grid_visu.size() != expected_tiles:
		push_error("grid_visu size mismatch: got %d expected %d" % [grid_visu.size(), expected_tiles])
		return false
	if grid_model.size() != expected_tiles:
		push_error("grid_model size mismatch: got %d expected %d" % [grid_model.size(), expected_tiles])
		return false
	if parent.get_child_count() != expected_tiles:
		push_error("parent child_count mismatch: got %d expected %d" % [parent.get_child_count(), expected_tiles])
		return false
	print("Success: Correct tile count (%d)" % expected_tiles)

	for k in grid_model.keys():
		var t: Tile = grid_model[k]
		if t == null:
			push_error("null Tile at key %s" % [str(k)])
			return false
		if t.coords != k:
			push_error("Tile.coords mismatch at key %s, got %s" % [str(k), str(t.coords)])
			return false
		if max(abs(t.cube_q), abs(t.cube_r), abs(t.cube_s)) > radius:
			push_error("Tile outside radius: %s (qrs=%d,%d,%d)" % [str(t.coords), t.cube_q, t.cube_r, t.cube_s])
			return false
	print("Success: All tiles inside radius")

	# Avoid resource/RID leaks in headless runs: explicitly free instantiated nodes.
	for child in parent.get_children():
		child.free()
	parent.free()

	return true

