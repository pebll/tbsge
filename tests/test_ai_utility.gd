extends RefCounted

const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const AiCandidateGen = preload("res://scripts/ai/utility/ai_candidate_gen.gd")
const AiContextScript = preload("res://scripts/ai/utility/ai_context.gd")
const AiFeatureExtract = preload("res://scripts/ai/utility/ai_feature_extract.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const AiProfileScript = preload("res://scripts/ai/utility/ai_profile.gd")
const AiUtilityScorer = preload("res://scripts/ai/utility/ai_utility_scorer.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_registry_utility():
		return false
	if not _test_scorer_linear():
		return false
	if not _test_features_bounded():
		return false
	if not _test_melee_when_adjacent():
		return false
	if not _test_moves_when_far():
		return false
	if not _test_candidates_include_move_attack_plan():
		return false
	if not _test_pass_penalty_beats_idle_pass_bias():
		return false
	if not _test_combat_features_include_kills():
		return false
	print("Success: Utility AI P1 tests")
	return true

func _test_registry_utility() -> bool:
	var brain: AiBrain = AiBrainRegistry.create("utility")
	if brain == null or brain.id != "utility":
		push_error("Expected utility brain")
		return false
	if brain.get_script() != UtilityBrainScript:
		push_error("utility id should yield UtilityBrain")
		return false
	return true

func _test_scorer_linear() -> bool:
	var profile: AiProfile = AiProfileScript.new()
	profile.weights = {"a": 2.0, "b": -1.0}
	var score := AiUtilityScorer.score({"a": 3.0, "b": 4.0}, profile)
	if not is_equal_approx(score, 2.0):
		push_error("Expected linear score 2.0, got %s" % score)
		return false
	return true

func _teleport_legion(session, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion

func _start_goblins(session) -> Dictionary:
	return MinigameTestHelpersScript.start_two_legion_battle(session)

func _test_features_bounded() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	var ctx: AiContext = AiContextScript.build(session, green)
	var cands: Array = AiCandidateGen.generate(session, green, ctx)
	if cands.is_empty():
		push_error("Expected candidates")
		return false
	for cand in cands:
		var feats: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand)
		for key in AiFeatureNames.all_names():
			if not feats.has(key):
				push_error("Missing feature %s" % key)
				return false
			var v := float(feats[key])
			if v < -1.001 or v > 1.001:
				# PASS_PENALTY and indicators are 0/1; combat fracs clamped.
				if key == AiFeatureNames.PASS_PENALTY and is_equal_approx(v, 1.0):
					continue
				push_error("Feature %s out of [-1,1]: %s" % [key, v])
				return false
	return true

func _test_melee_when_adjacent() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	green.refresh_ap()
	var brain: AiBrain = AiBrainRegistry.create("utility")
	var cmd: Dictionary = brain.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "melee_attack":
		push_error("Utility should melee when adjacent, got %s" % cmd)
		return false
	if cmd.get("to") != blue.tile_coords:
		push_error("Melee should target adjacent enemy")
		return false
	return true

func _test_moves_when_far() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -2))
	_teleport_legion(session, blue, Vector2i(2, -2))
	green.refresh_ap()
	var brain: AiBrain = AiBrainRegistry.create("utility")
	var cmd: Dictionary = brain.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "move":
		push_error("Utility should move when far, got %s" % cmd)
		return false
	return true

func _test_candidates_include_move_attack_plan() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	# One hex away with 2 AP — move then melee should be a plan candidate.
	_teleport_legion(session, green, Vector2i(0, -2))
	_teleport_legion(session, blue, Vector2i(1, -1))
	green.max_ap = 2
	green.current_ap = 2
	var ctx: AiContext = AiContextScript.build(session, green)
	var cands: Array = AiCandidateGen.generate(session, green, ctx)
	var found_plan := false
	for cand in cands:
		if cand.action_id == "move" and cand.followup_action_id == "melee_attack":
			found_plan = true
			break
	if not found_plan:
		push_error("Expected move-then-melee plan candidate")
		return false
	return true

func _test_pass_penalty_beats_idle_pass_bias() -> bool:
	## With a free attack available, pass must lose to combat under hand_v1 weights.
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	var ctx: AiContext = AiContextScript.build(session, green)
	var profile: AiProfile = AiProfileScript.hand_v1()
	var best_combat := -INF
	var pass_score := -INF
	for cand in AiCandidateGen.generate(session, green, ctx):
		var feats: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand)
		var score := AiUtilityScorer.score(feats, profile)
		if cand.action_id == "pass":
			pass_score = score
		elif cand.action_id == "melee_attack":
			best_combat = maxf(best_combat, score)
	if best_combat <= pass_score:
		push_error("Melee score %.2f should beat pass %.2f" % [best_combat, pass_score])
		return false
	return true

func _test_combat_features_include_kills() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	# Soft target so kills are likely.
	for u in blue.units:
		u.current_health = 1
	var ctx: AiContext = AiContextScript.build(session, green)
	var CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
	CombatExpectation.set_sim_count(6)
	for cand in AiCandidateGen.generate(session, green, ctx):
		if cand.action_id != "melee_attack":
			continue
		var feats: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand)
		if float(feats.get(AiFeatureNames.KILL_PROB, 0.0)) <= 0.0:
			push_error("Expected kill_prob > 0 vs 1-HP stack")
			return false
		if float(feats.get(AiFeatureNames.ENEMY_KILL_FRAC, 0.0)) <= 0.0:
			push_error("Expected enemy_kill_frac > 0 vs 1-HP stack")
			return false
		CombatExpectation.use_play_mode()
		return true
	push_error("No melee candidate found")
	return false
