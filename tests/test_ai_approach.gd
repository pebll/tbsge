extends RefCounted

const AiCandidateGen = preload("res://scripts/ai/utility/ai_candidate_gen.gd")
const AiContextScript = preload("res://scripts/ai/utility/ai_context.gd")
const AiFeatureExtract = preload("res://scripts/ai/utility/ai_feature_extract.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

## Row r=-2 is a wall except the gap at (3,-2); (0,-1) is a dead-end pocket that is
## hex-closer to an enemy at (0,-3) but path-farther.
const WALL_ROW := [Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(2, -2)]
const POCKET_WALLS := [Vector2i(1, -1), Vector2i(-1, -1)]

func run(_tree: SceneTree) -> bool:
	if not _test_dist_to_focus_follows_walls():
		return false
	if not _test_closer_to_focus_rejects_dead_end():
		return false
	if not _test_unreachable_focus_falls_back():
		return false
	if not _test_swap_counts_displaced_ally():
		return false
	print("Success: Terrain-aware approach distance")
	return true

func _teleport_legion(session, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion

func _block(session, coords_list: Array) -> void:
	for c in coords_list:
		var tile: Tile = session.grid.get(c)
		if tile:
			tile.walkable = false

func _setup_pocket_map() -> Dictionary:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_block(session, WALL_ROW)
	_block(session, POCKET_WALLS)
	_teleport_legion(session, green, Vector2i(0, 0))
	_teleport_legion(session, blue, Vector2i(0, -3))
	green.max_ap = 1
	green.current_ap = 1
	return {"session": session, "green": green, "blue": blue}

func _test_dist_to_focus_follows_walls() -> bool:
	var m := _setup_pocket_map()
	var ctx: AiContext = AiContextScript.build(m["session"], m["green"])
	var pocket := ctx.dist_to_focus(Vector2i(0, -1))
	var start := ctx.dist_to_focus(Vector2i(0, 0))
	if pocket <= start:
		push_error("Dead-end pocket must be path-farther (%s) than start (%s)" % [pocket, start])
		return false
	if not is_equal_approx(start, 7.0):
		push_error("Expected path distance 7 around the wall, got %s" % start)
		return false
	return true

func _test_closer_to_focus_rejects_dead_end() -> bool:
	var m := _setup_pocket_map()
	var session = m["session"]
	var green: Legion = m["green"]
	var ctx: AiContext = AiContextScript.build(session, green)
	var pocket_val := INF
	var open_val := -INF
	for cand in AiCandidateGen.generate(session, green, ctx):
		if cand.action_id != "move":
			continue
		var feats: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand)
		var v := float(feats[AiFeatureNames.CLOSER_TO_FOCUS])
		if cand.stand_coords() == Vector2i(0, -1):
			pocket_val = v
		elif cand.stand_coords() == Vector2i(1, 0):
			open_val = v
	if pocket_val == INF or open_val == -INF:
		push_error("Expected both pocket and open move candidates")
		return false
	if pocket_val >= 0.0:
		push_error("Dead-end pocket must not look closer, got %s" % pocket_val)
		return false
	if open_val <= 0.0:
		push_error("Step along the real path must look closer, got %s" % open_val)
		return false
	return true

func _test_unreachable_focus_falls_back() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a := MinigameTestHelpersScript.team_a(session)
	var team_b := MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a)
	var slots_b: Array = session.get_deploy_slots(team_b)
	session.apply({"type": "draft_set_legion", "team": team_a, "coords": slots_a[0], "unit_type": "GOBLIN", "unit_count": 2})
	session.apply({"type": "draft_ready", "team": team_a})
	session.apply({"type": "draft_set_legion", "team": team_b, "coords": slots_b[0], "unit_type": "GOBLIN", "unit_count": 2})
	session.apply({"type": "draft_set_legion", "team": team_b, "coords": slots_b[1], "unit_type": "GOBLIN", "unit_count": 2})
	session.apply({"type": "draft_ready", "team": team_b})
	var green: Legion = null
	var blues: Array[Legion] = []
	for L in session.legions:
		if L.team_id == team_a:
			green = L
		elif L.team_id == team_b:
			blues.append(L)
	if green == null or blues.size() != 2:
		push_error("Expected one green and two blue legions")
		return false
	# Seal the whole wall row (including the gap) so the first blue is unreachable.
	_block(session, WALL_ROW)
	_block(session, [Vector2i(3, -2)])
	_teleport_legion(session, green, Vector2i(0, 0))
	_teleport_legion(session, blues[0], Vector2i(0, -3))
	_teleport_legion(session, blues[1], Vector2i(2, 2))
	# Make the unreachable one the preferred focus (lowest HP).
	for u in blues[0].units:
		u.current_health = 1
	var ctx: AiContext = AiContextScript.build(session, green)
	if ctx.focus != blues[1]:
		push_error("Focus should fall back to the reachable enemy")
		return false
	return true

## Swapping onto an ally ahead pushes that ally back: no net team progress.
func _test_swap_counts_displaced_ally() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a := MinigameTestHelpersScript.team_a(session)
	var team_b := MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a)
	var slots_b: Array = session.get_deploy_slots(team_b)
	session.apply({"type": "draft_set_legion", "team": team_a, "coords": slots_a[0], "unit_type": "GOBLIN", "unit_count": 2})
	session.apply({"type": "draft_set_legion", "team": team_a, "coords": slots_a[1], "unit_type": "GOBLIN", "unit_count": 2})
	session.apply({"type": "draft_ready", "team": team_a})
	session.apply({"type": "draft_set_legion", "team": team_b, "coords": slots_b[0], "unit_type": "GOBLIN", "unit_count": 2})
	session.apply({"type": "draft_ready", "team": team_b})
	var greens: Array[Legion] = []
	var blue: Legion = null
	for L in session.legions:
		if L.team_id == team_a:
			greens.append(L)
		elif L.team_id == team_b:
			blue = L
	if greens.size() != 2 or blue == null:
		push_error("Expected two green legions and one blue")
		return false
	var mover: Legion = greens[0]
	var ally: Legion = greens[1]
	_teleport_legion(session, mover, Vector2i(0, 0))
	_teleport_legion(session, ally, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(0, -3))
	mover.max_ap = 1
	mover.current_ap = 1
	var ctx: AiContext = AiContextScript.build(session, mover)
	if ctx.focus != blue:
		push_error("Focus should be the only enemy")
		return false
	var swap_val := INF
	for cand in AiCandidateGen.generate(session, mover, ctx):
		if cand.action_id == "move" and cand.followup_action_id.is_empty() and cand.stand_coords() == Vector2i(0, -1):
			var feats: Dictionary = AiFeatureExtract.extract(session, mover, ctx, cand)
			swap_val = float(feats[AiFeatureNames.CLOSER_TO_FOCUS])
	if swap_val == INF:
		push_error("Expected a swap move candidate onto the ally")
		return false
	if not is_zero_approx(swap_val):
		push_error("Swap onto an ally ahead must be net-zero progress, got %s" % swap_val)
		return false
	return true
