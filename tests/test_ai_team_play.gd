extends RefCounted

## 0.1 team play puzzles: focus fire, legion ordering, covering a soft ally.

const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const AiCandidateScript = preload("res://scripts/ai/utility/ai_candidate.gd")
const AiCandidateGen = preload("res://scripts/ai/utility/ai_candidate_gen.gd")
const AiContextScript = preload("res://scripts/ai/utility/ai_context.gd")
const AiFeatureExtract = preload("res://scripts/ai/utility/ai_feature_extract.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const AiTeamPlanScript = preload("res://scripts/ai/utility/ai_team_plan.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_followup_counts_only_allies_in_reach():
		return false
	if not _test_focus_fire_picks_finishable_target():
		return false
	if not _test_ranged_acts_before_melee():
		return false
	if not _test_v0_keeps_score_order():
		return false
	if not _test_cover_ally_rewards_tank_swap():
		return false
	print("Success: AI team play tests")
	return true

## Battle with exactly the given legions. specs: [[team "a"/"b", unit_type, count, coords], ...].
## Team a is active with full AP.
func _board(specs: Array) -> Dictionary:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	for L in session.legions.duplicate():
		var tile: Tile = session.grid.get(L.tile_coords)
		if tile:
			tile.legion = null
		session.legions.erase(L)
	var out: Array[Legion] = []
	for spec in specs:
		var team: String = started["team_a"] if spec[0] == "a" else started["team_b"]
		var coords: Vector2i = spec[3]
		var legion := Legion.new(String(spec[1]), int(spec[2]), coords, team)
		session.legions.append(legion)
		session.grid[coords].legion = legion
		legion.refresh_ap()
		out.append(legion)
	return {"session": session, "legions": out}

func _test_followup_counts_only_allies_in_reach() -> bool:
	var b := _board([
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["a", "GOBLIN", 2, Vector2i(3, -1)],
		["b", "GOBLIN", 2, Vector2i(2, -1)],
		["b", "GOBLIN", 2, Vector2i(-3, 2)],
	])
	var session = b["session"]
	var L: Array[Legion] = b["legions"]
	var plan = AiTeamPlanScript.new().setup(session, L[0])
	if plan.ally_count() != 1:
		push_error("Expected 1 ally able to act, got %d" % plan.ally_count())
		return false
	var near: float = plan.followup_damage(L[2])
	if near <= 0.0:
		push_error("Adjacent goblins should be able to follow up on the near target")
		return false
	if plan.followup_damage(L[3]) > 0.0:
		push_error("Goblins cannot reach the far target this turn")
		return false
	return true

## Two identical targets in archer range; only one can be finished by the goblins. The
## tie-break (smaller x first) favours the other, so the choice comes from team_finish.
func _test_focus_fire_picks_finishable_target() -> bool:
	var b := _board([
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["a", "GOBLIN", 2, Vector2i(3, -1)],
		["b", "GOBLIN", 2, Vector2i(2, -1)],
		["b", "GOBLIN", 2, Vector2i(-2, 1)],
	])
	var session = b["session"]
	var L: Array[Legion] = b["legions"]
	# 1 AP: shoot from here, so both brains compare the same two direct shots.
	L[0].current_ap = 1
	var cmd: Dictionary = AiBrainRegistry.create("utility_hand").decide(session, L[0])
	if _strike(cmd) != ["ranged_attack", Vector2i(2, -1)]:
		push_error("Archer should shoot the target the goblins can finish, got %s" % cmd)
		return false
	var old: Dictionary = AiBrainRegistry.create("utility_v0").decide(session, L[0])
	if _strike(old) != ["ranged_attack", Vector2i(-2, 1)]:
		push_error("Puzzle sanity: without team_finish the tie-break picks (-2,1), got %s" % old)
		return false
	return true

## [action, target] of the attack a command ends in (direct, or a move-then-strike plan).
static func _strike(cmd: Dictionary) -> Array:
	if not String(cmd.get("followup_action_id", "")).is_empty():
		return [cmd["followup_action_id"], cmd.get("followup_to")]
	return [cmd.get("action_id"), cmd.get("to")]

func _test_ranged_acts_before_melee() -> bool:
	var b := _board([
		["a", "GOBLIN", 2, Vector2i(1, 0)],
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["b", "GOBLIN", 2, Vector2i(2, -1)],
	])
	var session = b["session"]
	var L: Array[Legion] = b["legions"]
	var brain = AiBrainRegistry.create("utility_hand")
	var order: Array[Vector2i] = brain.sort_actionable(
		session, [L[0].tile_coords, L[1].tile_coords] as Array[Vector2i]
	)
	if order.is_empty() or order[0] != L[1].tile_coords:
		push_error("Archer should act before the melee goblins, got %s" % [order])
		return false
	return true

## Only a stationary shot / heal jumps the queue; move-then-strike plans and melee keep
## best-score order (role tiers for those lost in benchmarks).
func _test_v0_keeps_score_order() -> bool:
	var shot := AiCandidateScript.new()
	shot.action_id = "ranged_attack"
	var walk_shot := AiCandidateScript.new()
	walk_shot.action_id = "move"
	walk_shot.followup_action_id = "ranged_attack"
	var melee := AiCandidateScript.new()
	melee.action_id = "melee_attack"
	if UtilityBrainScript.order_tier(shot) != UtilityBrainScript.ORDER_TIER_SUPPORT:
		push_error("a ranged shot from here should go first")
		return false
	for cand in [walk_shot, melee]:
		if UtilityBrainScript.order_tier(cand) != UtilityBrainScript.ORDER_TIER_OTHER:
			push_error("%s should keep score order" % cand.action_id)
			return false
	var v0 = AiBrainRegistry.create("utility_v0")
	if v0.role_ordering:
		push_error("utility_v0 must keep the old ordering")
		return false
	return true

## A full-HP golem swapping forward onto a wounded archer pulls it out of the ogre's reach:
## cover_ally > 0. The reverse swap (archer onto the golem) must score 0.
func _test_cover_ally_rewards_tank_swap() -> bool:
	var b := _board([
		["a", "GOLEM", 1, Vector2i(-1, 0)],
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["b", "OGRE", 1, Vector2i(1, 0)],
	])
	var session = b["session"]
	var L: Array[Legion] = b["legions"]
	var golem: Legion = L[0]
	var archer: Legion = L[1]
	archer.units[0].current_health = 2
	var ctx = AiContextScript.build(session, golem)
	var forward: float = AiFeatureExtract.cover_ally(
		session, golem, ctx, [golem.tile_coords, archer.tile_coords]
	)
	if forward <= 0.0:
		push_error("Golem swapping in front of the wounded archer should cover it, got %s" % forward)
		return false
	var actx = AiContextScript.build(session, archer)
	var back: float = AiFeatureExtract.cover_ally(
		session, archer, actx, [archer.tile_coords, golem.tile_coords]
	)
	if back > 0.0:
		push_error("Archer swapping onto the golem covers nobody, got %s" % back)
		return false
	# The feature reaches the scored candidate.
	var cands: Array = AiCandidateGen.generate(session, golem, ctx)
	for cand in cands:
		if cand.action_id == "move" and cand.followup_action_id.is_empty() and cand.path.size() == 2 \
				and cand.path[1] == archer.tile_coords:
			var feats: Dictionary = AiFeatureExtract.extract(session, golem, ctx, cand)
			if float(feats[AiFeatureNames.COVER_ALLY]) <= 0.0:
				push_error("cover_ally missing from the swap candidate's features")
				return false
			return true
	push_error("Expected a swap move candidate for the golem")
	return false
