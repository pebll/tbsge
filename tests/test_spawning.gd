extends RefCounted

const SandboxConfigScript = preload("res://scripts/match/sandbox_config.gd")
const SandboxSessionScript = preload("res://scripts/match/sandbox_session.gd")
const GridPresenterScript = preload("res://scripts/visu/grid_presenter.gd")

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

	var center := Vector2i(0, 0)
	if not session.grid.has(center):
		push_error("Sandbox grid missing center tile")
		return false
	print("Success: Center tile exists")

	var spawn_coords := center
	if not session.grid[spawn_coords].walkable:
		push_error("Center tile not walkable (expected forced walkable=true)")
		return false
	if session.grid[spawn_coords].has_legion():
		push_error("Center tile already has legion (unexpected)")
		return false
	print("Success: Center tile spawnable")

	seed(4242)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var result := session.spawn_unit_at(spawn_coords, rng)
	if not result.get("ok", false):
		push_error("spawn_unit_at failed: %s" % result.get("error", "?"))
		return false

	var legion: Legion = result.get("payload", {}).get("legion")
	presenter.spawn_legion_visu(legion)

	var tile: Tile = session.grid[spawn_coords]
	var tile_visu: TileVisu = presenter.grid_visu[spawn_coords]
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

	presenter.queue_free()
	await tree.process_frame
	return true
