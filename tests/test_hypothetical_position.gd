extends RefCounted

const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

## AI "what if" queries must see the legion at the new tile and restore the board exactly.

func run(_tree: SceneTree) -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var home := green.tile_coords
	var target := Vector2i.ZERO
	var found := false
	for c in session.grid.keys():
		var t: Tile = session.grid[c]
		if t and t.walkable and not t.has_legion():
			target = c
			found = true
			break
	if not found:
		push_error("No empty tile for hypothetical test")
		return false

	var seen: Variant = HypotheticalPosition.evaluate(session.grid, green, target, func() -> Array:
		return [green.tile_coords, session.get_legion_at(target) == green, session.get_legion_at(home) == null]
	, [])
	if seen != [target, true, true]:
		push_error("Query should see the legion relocated: %s" % [seen])
		return false
	if green.tile_coords != home or session.get_legion_at(home) != green:
		push_error("Legion must be restored to its home tile")
		return false
	if session.get_legion_at(target) != null:
		push_error("Hypothetical tile must be empty again")
		return false

	# Same-tile query is a no-op round trip.
	HypotheticalPosition.evaluate(session.grid, green, home, func() -> int: return 0, 0)
	if session.get_legion_at(home) != green or green.tile_coords != home:
		push_error("Same-tile hypothetical must leave the legion in place")
		return false

	# Unknown tile returns the fallback and touches nothing.
	var fb: Variant = HypotheticalPosition.evaluate(session.grid, green, Vector2i(999, 999), func() -> int: return 1, -1)
	if int(fb) != -1 or session.get_legion_at(home) != green:
		push_error("Off-grid hypothetical should return fallback untouched")
		return false
	print("Success: Hypothetical position tests")
	return true
