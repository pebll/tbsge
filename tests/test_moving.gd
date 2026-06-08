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

	var from_coords := Vector2i(0, 0)
	if not gm.grid_model.has(from_coords):
		push_error("Grid missing (0,0)")
		return false
	if not gm.grid_model[from_coords].walkable:
		push_error("Center not walkable (expected forced walkable=true)")
		return false
	print("Success: From tile walkable")

	seed(9001)
	gm.spawn_unit(from_coords)
	var from_tile: Tile = gm.grid_model[from_coords]
	var from_visu: TileVisu = gm.grid_visu[from_coords]
	if not from_tile.has_legion():
		push_error("Precondition failed: no legion spawned at from_coords")
		return false
	if from_visu == null or from_visu.legion_visu == null:
		push_error("Precondition failed: no legion visu spawned at from_coords")
		return false
	print("Success: Unit spawned")

	var legion_before: Legion = from_tile.legion
	var legion_visu_before: LegionVisu = from_visu.legion_visu

	var to_coords := Vector2i(0, 0)
	var found_to := false
	var movable := ActionTargeting.get_targets(
		BattleState.from_game_manager(gm),
		legion_before,
		ActionDefs.get_def("move")
	)
	if movable.is_empty():
		push_error("No legal move targets for spawned legion")
		return false
	for coords in movable:
		var t: Tile = gm.grid_model.get(coords)
		if t and t.walkable and not t.has_legion():
			to_coords = coords
			found_to = true
			break
	if not found_to:
		push_error("No walkable empty tile found for to_coords")
		return false
	print("Success: Found destination tile")

	gm.move_unit(from_coords, to_coords)

	var to_tile: Tile = gm.grid_model[to_coords]
	var to_visu: TileVisu = gm.grid_visu[to_coords]

	if from_tile.has_legion():
		push_error("move_unit did not clear from_tile.legion")
		return false
	if to_tile.legion != legion_before:
		push_error("move_unit did not set to_tile.legion to original legion")
		return false
	if legion_before.tile_coords != to_coords:
		push_error("move_unit did not update legion.tile_coords")
		return false
	print("Success: Unit moved (model)")

	if from_visu.legion_visu != null:
		push_error("move_unit did not clear from_visu.legion_visu")
		return false
	if to_visu.legion_visu != legion_visu_before:
		push_error("move_unit did not move legion visu reference")
		return false
	print("Success: Unit moved (visu wiring)")

	gm.queue_free()
	await tree.process_frame
	return true

