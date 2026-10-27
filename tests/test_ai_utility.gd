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
const AiBrainCommand = preload("res://scripts/ai/ai_brain_command.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_registry_utility():
		return false
	if not _test_battle_defaults_to_utility():
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
	if not _test_move_attack_plan_includes_followup():
		return false
	if not _test_plan_followthrough_deals_damage():
		return false
	if not _test_pass_penalty_beats_idle_pass_bias():
		return false
	if not _test_combat_features_include_kills():
		return false
	if not _test_brain_init_keeps_train_mode():
		return false
	if not _test_pass_earns_no_leftover_ap():
		return false
	if not _test_trade_value_orders_by_absolute_gold():
		return false
	if not _test_trade_value_negative_when_counter_gold_higher():
		return false
	if not _test_trade_and_wipe_features_present():
		return false
	if not _test_hand_v1_trade_wipe_weights():
		return false
	if not _test_decide_cache_matches_fresh_brain():
		return false
	if not _test_cache_invalidated_on_board_change():
		return false
	if not _test_estimate_memo_within_pass():
		return false
	if not _test_brain_sim_count_is_per_brain():
		return false
	if not _test_memo_key_includes_sim_count():
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

func _test_battle_defaults_to_utility() -> bool:
	var BattlePhaseControllerScript = preload("res://scripts/minigame/battle_phase_controller.gd")
	var ctrl = BattlePhaseControllerScript.new(null)
	if ctrl.ai_brain == null or ctrl.ai_brain.id != "utility":
		push_error("BattlePhaseController should default to utility brain")
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

func _test_move_attack_plan_includes_followup() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -2))
	_teleport_legion(session, blue, Vector2i(1, -1))
	green.max_ap = 2
	green.current_ap = 2
	var ctx: AiContext = AiContextScript.build(session, green)
	for cand in AiCandidateGen.generate(session, green, ctx):
		if cand.action_id == "move" and cand.followup_action_id == "melee_attack":
			var cmd: Dictionary = cand.to_command()
			if String(cmd.get("followup_action_id", "")) != "melee_attack":
				push_error("Plan command should carry followup_action_id")
				return false
			if not cmd.has("path"):
				push_error("Plan command should include move path")
				return false
			return true
	push_error("Expected move-then-melee plan candidate")
	return false

func _test_plan_followthrough_deals_damage() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -2))
	_teleport_legion(session, blue, Vector2i(1, -1))
	green.max_ap = 2
	green.current_ap = 2
	var brain: AiBrain = AiBrainRegistry.create("utility")
	var cmd: Dictionary = brain.decide(session, green)
	if not AiBrainCommand.has_followup(cmd):
		push_error("Expected move+attack plan command, got %s" % cmd)
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var applied: Dictionary = AiBrainCommand.apply(
		session, cmd, green.tile_coords, green, rng, null
	)
	if not bool(applied.get("ok", false)):
		push_error("Plan follow-through apply failed")
		return false
	if not bool(applied.get("damage", false)):
		push_error("Plan follow-through should deal damage in one activation")
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

func _test_brain_init_keeps_train_mode() -> bool:
	var CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
	CombatExpectation.use_train_mode()
	var brain = UtilityBrainScript.new()
	var count: int = CombatExpectation.get_sim_count()
	CombatExpectation.use_play_mode()
	if brain == null or count != CombatExpectation.TRAIN_SIM_COUNT:
		push_error("UtilityBrain._init must not reset sim count (got %s)" % count)
		return false
	return true

func _test_pass_earns_no_leftover_ap() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -2))
	_teleport_legion(session, blue, Vector2i(2, -2))
	green.refresh_ap()
	var ctx: AiContext = AiContextScript.build(session, green)
	for cand in AiCandidateGen.generate(session, green, ctx):
		if cand.action_id != "pass":
			continue
		var feats: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand)
		if float(feats[AiFeatureNames.LEFTOVER_AP_FRAC]) != 0.0:
			push_error("Pass must not earn leftover AP credit")
			return false
		return true
	push_error("No pass candidate found")
	return false

func _goblin_stack(count: int, team: String) -> Legion:
	return Legion.new("GOBLIN", count, Vector2i.ZERO, team)

func _half_loss_est(defender: Legion, own: Legion, own_frac: float) -> Dictionary:
	var def_hp := 0.0
	for u in defender.units:
		def_hp += u.max_health
	var own_hp := 0.0
	for u in own.units:
		own_hp += u.max_health
	return {"enemy_loss_mean": def_hp * 0.5, "own_loss_mean": own_hp * own_frac}

func _test_trade_value_orders_by_absolute_gold() -> bool:
	var atk := _goblin_stack(3, "GREEN")
	var small_def := _goblin_stack(2, "BLUE")
	var big_def := _goblin_stack(6, "BLUE")
	var scale := 30.0
	# Same fraction of the defender stack lost, same own fraction lost.
	var tv_small: float = AiFeatureExtract.trade_value(_half_loss_est(small_def, atk, 0.1), atk, small_def, scale)
	var tv_big: float = AiFeatureExtract.trade_value(_half_loss_est(big_def, atk, 0.1), atk, big_def, scale)
	if tv_big <= tv_small:
		push_error("Bigger absolute trade should score higher: %s vs %s" % [tv_big, tv_small])
		return false
	if tv_small < -1.0 or tv_big > 1.0:
		push_error("trade_value must be clamped to [-1,1]")
		return false
	if AiFeatureExtract.trade_value(_half_loss_est(big_def, atk, 0.1), atk, big_def, 0.001) > 1.0:
		push_error("trade_value must clamp")
		return false
	return true

func _test_trade_value_negative_when_counter_gold_higher() -> bool:
	var atk := _goblin_stack(6, "GREEN")
	var def := _goblin_stack(2, "BLUE")
	# Defender loses 25%% of a cheap small stack; we lose 50%% of a big stack.
	var est := {"enemy_loss_mean": 4.0, "own_loss_mean": 24.0}
	var tv: float = AiFeatureExtract.trade_value(est, atk, def, 30.0)
	if tv >= 0.0:
		push_error("Expected negative trade value, got %s" % tv)
		return false
	return true

func _test_trade_and_wipe_features_present() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	blue.units.resize(1)
	blue.units[0].current_health = 1
	if not (AiFeatureNames.all_names().has("trade_value") and AiFeatureNames.all_names().has("wipe_prob")):
		push_error("trade_value / wipe_prob must be in all_names()")
		return false
	var ctx: AiContext = AiContextScript.build(session, green)
	for cand in AiCandidateGen.generate(session, green, ctx):
		if cand.action_id != "melee_attack":
			continue
		var feats: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand)
		if float(feats["wipe_prob"]) < 0.99:
			push_error("Expected wipe_prob ~1 vs lone 1-HP unit, got %s" % feats["wipe_prob"])
			return false
		if float(feats["trade_value"]) <= 0.0:
			push_error("Expected positive trade_value on a free kill, got %s" % feats["trade_value"])
			return false
		return true
	push_error("No melee candidate found")
	return false

func _test_hand_v1_trade_wipe_weights() -> bool:
	var p: AiProfile = AiProfileScript.hand_v1()
	if not is_equal_approx(p.weight_for("trade_value"), 6.0) or not is_equal_approx(p.weight_for("wipe_prob"), 3.0):
		push_error("hand_v1 must weight trade_value=6 wipe_prob=3")
		return false
	return true

func _adjacent_pair() -> Dictionary:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -2))
	_teleport_legion(session, blue, Vector2i(1, -1))
	green.max_ap = 2
	green.current_ap = 2
	return {"session": session, "green": green, "blue": blue}

func _test_decide_cache_matches_fresh_brain() -> bool:
	var w := _adjacent_pair()
	var session = w["session"]
	var green: Legion = w["green"]
	var cached = UtilityBrainScript.new()
	var order: Array[Vector2i] = cached.sort_actionable(session, [green.tile_coords] as Array[Vector2i])
	if order.size() != 1:
		push_error("sort_actionable should keep the legion")
		return false
	var cmd_cached: Dictionary = cached.decide(session, green)
	if cached.cache_hits != 1:
		push_error("decide should reuse the sorted candidate (hits=%d)" % cached.cache_hits)
		return false
	var fresh = UtilityBrainScript.new()
	var cmd_fresh: Dictionary = fresh.decide(session, green)
	if fresh.cache_hits != 0 or str(cmd_cached) != str(cmd_fresh):
		push_error("Cached decide differs from fresh: %s vs %s" % [cmd_cached, cmd_fresh])
		return false
	return true

func _test_cache_invalidated_on_board_change() -> bool:
	var w := _adjacent_pair()
	var session = w["session"]
	var green: Legion = w["green"]
	var blue: Legion = w["blue"]
	var cached = UtilityBrainScript.new()
	cached.sort_actionable(session, [green.tile_coords] as Array[Vector2i])
	blue.units[0].current_health = 1.0
	var cmd_cached: Dictionary = cached.decide(session, green)
	if cached.cache_hits != 0:
		push_error("Changed board must not hit the cache")
		return false
	var cmd_fresh: Dictionary = UtilityBrainScript.new().decide(session, green)
	if str(cmd_cached) != str(cmd_fresh):
		push_error("Recomputed decide differs from fresh")
		return false
	return true

func _test_estimate_memo_within_pass() -> bool:
	var CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = _start_goblins(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	var ctx: AiContext = AiContextScript.build(session, green)
	var cand: AiCandidate = null
	for c in AiCandidateGen.generate(session, green, ctx):
		if c.action_id == "melee_attack":
			cand = c
			break
	if cand == null:
		push_error("No melee candidate found")
		return false
	var memo: Dictionary = {}
	var before: int = CombatExpectation.estimate_calls
	var f1: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand, -1, memo)
	var f2: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand, -1, memo)
	var used: int = CombatExpectation.estimate_calls - before
	if used != 1 or str(f1) != str(f2):
		push_error("Memo should simulate once per (stand,target) in a pass (calls=%d)" % used)
		return false
	before = CombatExpectation.estimate_calls
	AiFeatureExtract.extract(session, green, ctx, cand)
	AiFeatureExtract.extract(session, green, ctx, cand)
	if CombatExpectation.estimate_calls - before != 2:
		push_error("Outside a pass nothing must be memoized")
		return false
	return true

func _test_brain_sim_count_is_per_brain() -> bool:
	var CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
	CombatExpectation.use_play_mode()
	if UtilityBrainScript.new().sim_count != CombatExpectation.PLAY_SIM_COUNT:
		push_error("UtilityBrain.sim_count must default to PLAY_SIM_COUNT")
		return false
	var w := _adjacent_pair()
	var session = w["session"]
	var green: Legion = w["green"]
	var low = UtilityBrainScript.new()
	low.sim_count = 2
	var high = UtilityBrainScript.new()
	high.sim_count = 5
	var calls0: int = CombatExpectation.estimate_calls
	var sims0: int = CombatExpectation.sims_run
	low.decide(session, green)
	var calls_low: int = CombatExpectation.estimate_calls - calls0
	var sims_low: int = CombatExpectation.sims_run - sims0
	calls0 = CombatExpectation.estimate_calls
	sims0 = CombatExpectation.sims_run
	high.decide(session, green)
	var calls_high: int = CombatExpectation.estimate_calls - calls0
	var sims_high: int = CombatExpectation.sims_run - sims0
	if calls_low <= 0 or calls_high <= 0:
		push_error("Both brains should have estimated combat")
		return false
	if sims_low != 2 * calls_low or sims_high != 5 * calls_high:
		push_error("Each brain must simulate its own sim_count (low %d/%d, high %d/%d)" % [
			sims_low, calls_low, sims_high, calls_high])
		return false
	if CombatExpectation.get_sim_count() != CombatExpectation.PLAY_SIM_COUNT:
		push_error("Per-brain sim counts must not touch the global")
		return false
	return true

func _test_memo_key_includes_sim_count() -> bool:
	var w := _adjacent_pair()
	var session = w["session"]
	var green: Legion = w["green"]
	var blue: Legion = w["blue"]
	var memo: Dictionary = {}
	var a: Dictionary = AiFeatureExtract.estimate(
		green, blue, "melee_attack", green.tile_coords, blue.tile_coords, 3, memo
	)
	var b: Dictionary = AiFeatureExtract.estimate(
		green, blue, "melee_attack", green.tile_coords, blue.tile_coords, 4, memo
	)
	if int(a.get("sim_count", 0)) != 3 or int(b.get("sim_count", 0)) != 4:
		push_error("Memo must not serve an estimate made with another sim count")
		return false
	return true
