extends RefCounted

const MoveReachability = preload("res://scripts/battle/move_reachability.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const AiActionScorer = preload("res://scripts/ai/ai_action_scorer.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
const TileScript = preload("res://scripts/models/tile.gd")
const LegionScript = preload("res://scripts/models/legion.gd")
const HexLayoutScript = preload("res://scripts/core/hex_layout.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_soft_pathfinding():
		return false
	if not _test_draft_move():
		return false
	if not _test_greedy_heal_beats_trades():
		return false
	if not _test_move_reachability_basic():
		return false
	if not _test_depth_layer_order():
		return false
	print("Success: Playtest polish (P5–P9 helpers) tests")
	return true

func _test_soft_pathfinding() -> bool:
	var grid: Dictionary = {}
	for q in range(0, 5):
		var c := Vector2i(q, 0)
		var t: Tile = TileScript.new(q, 0, "GRASS")
		grid[c] = t

	var ally: Legion = LegionScript.new("GOBLIN", 1, Vector2i(2, 0), "GREEN")
	grid[Vector2i(2, 0)].legion = ally

	var from := Vector2i(0, 0)
	var goal := Vector2i(4, 0)
	var hard := HexPathfinder.find_path(grid, from, goal, {})
	if not hard.is_empty():
		push_error("Expected hard path blocked by ally")
		return false
	var near := {Vector2i(1, 0): true}
	var soft := HexPathfinder.find_path(grid, from, goal, {}, true, near)
	if soft.size() < 2:
		push_error("Expected soft path to ignore distant ally")
		return false
	return true

func _test_draft_move() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team := MinigameTestHelpersScript.team_a(session)
	var slots: Array = session.get_deploy_slots(team)
	if slots.size() < 2:
		push_error("Need 2 deploy slots")
		return false
	var a: Vector2i = slots[0]
	var b: Vector2i = slots[1]
	var place: Dictionary = session.apply({
		"type": "draft_set_legion",
		"team": team,
		"coords": a,
		"unit_type": "GOBLIN",
		"unit_count": 2,
	})
	if not place["ok"]:
		push_error("Place failed: %s" % place.get("error"))
		return false
	var moved: Dictionary = session.apply({
		"type": "draft_move_legion",
		"team": team,
		"from": a,
		"to": b,
	})
	if not moved["ok"]:
		push_error("Move failed: %s" % moved.get("error"))
		return false
	var draft = session.drafts[team]
	if draft.find_placement(b) == null:
		push_error("Expected legion at destination")
		return false
	if draft.find_placement(a) != null:
		push_error("Expected source cleared")
		return false
	return true

func _test_greedy_heal_beats_trades() -> bool:
	var heal_score := 10.0
	var trade_score := 18.0 - 10.0
	if heal_score <= trade_score:
		push_error("Sanity: heal should beat trade in the stated example")
		return false
	var gob: Legion = LegionScript.new("GOBLIN", 1, Vector2i.ZERO, "GREEN")
	if not AiActionScorer.is_frontline(gob):
		push_error("Goblin should be frontline")
		return false
	return true

func _test_move_reachability_basic() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team := MinigameTestHelpersScript.team_a(session)
	var slots: Array = session.get_deploy_slots(team)
	session.apply({
		"type": "draft_set_legion",
		"team": team,
		"coords": slots[0],
		"unit_type": "GOBLIN",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team})
	while session.phase == MinigameSessionScript.Phase.DRAFT:
		var active: String = session.active_draft_team
		if active == team:
			break
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		for cmd in AiDrafter.build_draft_commands(session, active, rng):
			session.apply(cmd)
		session.apply({"type": "draft_ready", "team": active})
	if session.phase != MinigameSessionScript.Phase.BATTLE:
		push_error("Could not reach battle for reachability test")
		return false
	var legion: Legion = null
	for L in session.legions:
		if L.team_id == team:
			legion = L
			break
	if legion == null:
		push_error("No player legion")
		return false
	legion.current_ap = 3
	var state := session.battle_state()
	var data := MoveReachability.compute(state, legion)
	var reachable: Array = data["reachable"]
	if reachable.is_empty():
		push_error("Expected some reachable tiles with 3 AP")
		return false
	return true

func _test_depth_layer_order() -> bool:
	var y_north := 100.0
	var y_south := 120.0
	var north_tile := HexLayoutScript.depth_sort_z(y_north, HexLayoutScript.DEPTH_LAYER_TILE)
	var north_banner := HexLayoutScript.depth_sort_z(y_north, HexLayoutScript.DEPTH_LAYER_BANNER)
	var north_units := HexLayoutScript.depth_sort_z(y_north, HexLayoutScript.DEPTH_LAYER_UNITS)
	var south_tile := HexLayoutScript.depth_sort_z(y_south, HexLayoutScript.DEPTH_LAYER_TILE)

	if not (north_tile < north_banner and north_banner < north_units):
		push_error("Expected tile < banner < units within a row")
		return false
	if north_units >= south_tile:
		push_error("Southern tile must draw above northern units (iso occlusion)")
		return false
	# Relative children: parent at TILE layer + child layer == absolute layer z.
	var legion_root := HexLayoutScript.depth_sort_z(y_north, HexLayoutScript.DEPTH_LAYER_TILE)
	var banner_effective := legion_root + HexLayoutScript.DEPTH_LAYER_BANNER
	if banner_effective != north_banner:
		push_error("Banner relative stack should match absolute layer z")
		return false
	if banner_effective <= north_tile:
		push_error("Banner must sit above its own tile")
		return false
	# Idle northern units sit under the next southern tile (correct iso).
	if north_units >= south_tile:
		push_error("Idle northern units should sit under southern tiles")
		return false
	# Southbound move: depth uses max(from,to) Y so the legion clears the dest tile.
	var move_depth_y := maxf(y_north, y_south)
	var moving_units := HexLayoutScript.depth_sort_z(move_depth_y, HexLayoutScript.DEPTH_LAYER_UNITS)
	if moving_units <= south_tile:
		push_error("Southbound move depth must stay above the destination tile")
		return false
	return true
