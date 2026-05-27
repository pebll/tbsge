extends RefCounted

func run(tree: SceneTree) -> bool:
	var gm := GameManager.new()
	tree.root.add_child(gm)
	await tree.process_frame

	# Make the test independent from random terrain generation.
	for k in gm.grid_model.keys():
		var t: Tile = gm.grid_model[k]
		if t:
			t.terrain_type = "GRASS"
			t.walkable = true

	var center := Vector2i(0, 0)
	if not gm.grid_model.has(center):
		push_error("GameManager grid missing center tile")
		return false
	print("Success: Center tile exists")

	var spawn_coords := center
	if not gm.grid_model[spawn_coords].walkable:
		push_error("Center tile not walkable (expected forced walkable=true)")
		return false
	if gm.grid_model[spawn_coords].has_legion():
		push_error("Center tile already has legion (unexpected)")
		return false
	print("Success: Center tile spawnable")

	seed(4242)
	gm.spawn_unit(spawn_coords)

	var tile: Tile = gm.grid_model[spawn_coords]
	var tile_visu: TileVisu = gm.grid_visu[spawn_coords]
	if not tile.has_legion():
		push_error("spawn_unit did not assign Tile.legion")
		return false
	if tile_visu.legion_visu == null:
		push_error("spawn_unit did not assign TileVisu.legion_visu")
		return false
	if tile.legion.tile_coords != spawn_coords:
		push_error("spawn_unit: Legion.tile_coords mismatch")
		return false
	print("Success: Unit spawned at center")

	gm.queue_free()
	await tree.process_frame
	return true

