extends RefCounted

const SandboxConfigScript = preload("res://scripts/match/sandbox_config.gd")
const SandboxSessionScript = preload("res://scripts/match/sandbox_session.gd")
const GridPresenterScript = preload("res://scripts/visu/grid_presenter.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")

func run(tree: SceneTree) -> bool:
	var config: SandboxConfigScript = load("res://data/sandbox/preview_r2.tres")
	var session := SandboxSessionScript.new(config)
	var presenter := GridPresenterScript.new()
	tree.root.add_child(presenter)
	await tree.process_frame
	presenter.build_map_from_grid(session.grid)

	for k in session.grid.keys():
		var t: Tile = session.grid[k]
		if t:
			t.terrain_type = "GRASS"
			t.walkable = true

	var from_coords := Vector2i(0, 0)
	if not session.grid.has(from_coords):
		push_error("Grid missing (0,0)")
		return false
	if not session.grid[from_coords].walkable:
		push_error("Center not walkable (expected forced walkable=true)")
		return false
	print("Success: From tile walkable")

	seed(9001)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var spawn_result := session.spawn_unit_at(from_coords, rng)
	if not spawn_result.get("ok", false):
		push_error("spawn_unit_at failed")
		return false
	var legion_spawned: Legion = spawn_result.get("payload", {}).get("legion")
	presenter.spawn_legion_visu(legion_spawned)

	var from_tile: Tile = session.grid[from_coords]
	var from_visu: TileVisu = presenter.grid_visu[from_coords]
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
		BattleStateScript.from_session(session),
		legion_before,
		ActionDefs.get_def("move")
	)
	if movable.is_empty():
		push_error("No legal move targets for spawned legion")
		return false
	for coords in movable:
		var t: Tile = session.grid.get(coords)
		if t and t.walkable and not t.has_legion():
			to_coords = coords
			found_to = true
			break
	if not found_to:
		push_error("No walkable empty tile found for to_coords")
		return false
	print("Success: Found destination tile")

	var move_result := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": from_coords,
		"to": to_coords,
	})
	if not move_result.get("ok", false):
		push_error("move action failed: %s" % move_result.get("error", "?"))
		return false

	presenter.rewire_legion_tile(legion_before, from_coords, to_coords)
	var tween := presenter.tween_legion_move(legion_before, to_coords)
	if tween:
		await tween.finished

	var to_tile: Tile = session.grid[to_coords]
	var to_visu: TileVisu = presenter.grid_visu[to_coords]

	if from_tile.has_legion():
		push_error("move did not clear from_tile.legion")
		return false
	if to_tile.legion != legion_before:
		push_error("move did not set to_tile.legion to original legion")
		return false
	if legion_before.tile_coords != to_coords:
		push_error("move did not update legion.tile_coords")
		return false
	print("Success: Unit moved (model)")

	if from_visu.legion_visu != null:
		push_error("move did not clear from_visu.legion_visu")
		return false
	if to_visu.legion_visu != legion_visu_before:
		push_error("move did not move legion visu reference")
		return false
	print("Success: Unit moved (visu wiring)")

	presenter.queue_free()
	await tree.process_frame
	return true
