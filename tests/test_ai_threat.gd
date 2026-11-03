extends RefCounted

const ThreatMapScript = preload("res://scripts/ai/threat/threat_map.gd")
const AiContextScript = preload("res://scripts/ai/utility/ai_context.gd")
const AiCandidateGen = preload("res://scripts/ai/utility/ai_candidate_gen.gd")
const AiFeatureExtract = preload("res://scripts/ai/utility/ai_feature_extract.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const AiProfileScript = preload("res://scripts/ai/utility/ai_profile.gd")
const AiUtilityScorer = preload("res://scripts/ai/utility/ai_utility_scorer.gd")
const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const Utils = preload("res://scripts/core/utils.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_adjacent_melee_is_threatening():
		return false
	if not _test_far_hex_lower_threat_than_adjacent():
		return false
	if not _test_utility_prefers_safer_hex_when_fragile():
		return false
	if not _test_enemy_counts_once_per_hex():
		return false
	if not _test_threat_scales_with_enemy_hp():
		return false
	if not _test_threat_at_stand_shares_scale():
		return false
	print("Success: Threat map / safety features")
	return true

func _teleport_legion(session, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion

func _test_adjacent_melee_is_threatening() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, 0))
	_teleport_legion(session, blue, Vector2i(1, 0))
	var map = ThreatMapScript.build(session, green.team_id)
	var adj := float(map.threat_at(green.tile_coords))
	if adj <= 0.0:
		push_error("Standing next to melee enemy should be threatening")
		return false
	return true

func _test_far_hex_lower_threat_than_adjacent() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, blue, Vector2i(0, 0))
	var adj := Vector2i(1, 0)
	var far := Vector2i(2, -2)
	if session.grid.get(adj) == null or session.grid.get(far) == null:
		return true
	var map = ThreatMapScript.build(session, green.team_id)
	var t_adj := float(map.threat_at(adj))
	var t_far := float(map.threat_at(far))
	if t_adj <= t_far:
		push_error("Adjacent hex should be hotter than far hex (%s vs %s)" % [t_adj, t_far])
		return false
	return true

func _test_utility_prefers_safer_hex_when_fragile() -> bool:
	## Low-HP goblin with AP: standing adjacent is worse than stepping away when no attack.
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, 0))
	_teleport_legion(session, blue, Vector2i(1, 0))
	for u in green.units:
		u.current_health = 1
	# Blue cannot be killed usefully and green has no need to stay — ensure move exists.
	green.max_ap = 2
	green.current_ap = 2
	var ctx = AiContextScript.build(session, green)
	var profile = AiProfileScript.hand_v1()
	# Amplify safety so the test is about the feature wiring, not hand weight balance.
	profile.set_weight(AiFeatureNames.THREAT_AT_STAND, -20.0)
	profile.set_weight(AiFeatureNames.LOW_HP_EXPOSURE, -20.0)
	profile.set_weight(AiFeatureNames.IS_COMBAT, 0.0)
	profile.set_weight(AiFeatureNames.NET_HP_FRAC, 0.0)
	profile.set_weight(AiFeatureNames.ENEMY_LOSS_FRAC, 0.0)
	profile.set_weight(AiFeatureNames.ENEMY_KILL_FRAC, 0.0)
	profile.set_weight(AiFeatureNames.KILL_PROB, 0.0)

	var best_move_score := -INF
	var stay_combat_score := -INF
	for cand in AiCandidateGen.generate(session, green, ctx):
		var feats: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand)
		var score := AiUtilityScorer.score(feats, profile)
		if cand.action_id == "move":
			var dest: Vector2i = cand.path[cand.path.size() - 1] if cand.path.size() >= 2 else cand.to
			if HexPathfinder.hex_distance(dest, blue.tile_coords) > 1:
				best_move_score = maxf(best_move_score, score)
		elif cand.action_id == "melee_attack":
			stay_combat_score = maxf(stay_combat_score, score)

	if best_move_score <= -INF / 2.0:
		# Geometry may not offer a non-adjacent step; still verify threat features fire.
		var stay_feats: Dictionary = {}
		for cand in AiCandidateGen.generate(session, green, ctx):
			if cand.action_id == "melee_attack":
				stay_feats = AiFeatureExtract.extract(session, green, ctx, cand)
				break
		if float(stay_feats.get(AiFeatureNames.THREAT_AT_STAND, 0.0)) <= 0.0:
			push_error("Expected threat_at_stand > 0 when adjacent")
			return false
		return true

	if best_move_score <= stay_combat_score:
		push_error(
			"Fragile unit should prefer safer move (%.2f) over staying to fight (%.2f)"
			% [best_move_score, stay_combat_score]
		)
		return false
	return true

func _test_enemy_counts_once_per_hex() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, blue, Vector2i(0, 0))
	blue.max_ap = 3
	blue.current_ap = 3
	var map = ThreatMapScript.build(session, green.team_id)
	var melee := float(ThreatMapScript._legion_melee_power(blue))
	# (2,0) is adjacent to many open stands of one enemy; it must not exceed one strike.
	var t := float(map.threat_at(Vector2i(2, 0)))
	if t > melee + 0.001:
		push_error("One enemy must count once per hex (%s > %s)" % [t, melee])
		return false
	if t <= 0.0:
		push_error("Walk-then-strike hex should still be threatened")
		return false
	return true

func _test_threat_scales_with_enemy_hp() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, blue, Vector2i(0, 0))
	var full := float(ThreatMapScript.build(session, green.team_id).threat_at(Vector2i(1, 0)))
	for u in blue.units:
		u.current_health = maxi(1, int(u.max_health / 2))
	var hurt := float(ThreatMapScript.build(session, green.team_id).threat_at(Vector2i(1, 0)))
	if hurt >= full:
		push_error("Wounded enemy should threaten less (%s vs %s)" % [hurt, full])
		return false
	return true

func _test_threat_at_stand_shares_scale() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, blue, Vector2i(0, 0))
	_teleport_legion(session, green, Vector2i(3, -3))
	blue.max_ap = 1
	blue.current_ap = 1
	green.max_ap = 3
	green.current_ap = 3
	var ctx = AiContextScript.build(session, green)
	var near_val := -1.0  # stand adjacent to blue now (full strike)
	var mid_val := -1.0  # stand reachable only after a walk (discounted)
	for cand in AiCandidateGen.generate(session, green, ctx):
		if cand.action_id != "move" or not cand.followup_action_id.is_empty():
			continue
		var feats: Dictionary = AiFeatureExtract.extract(session, green, ctx, cand)
		if cand.stand_coords() == Vector2i(1, -1):
			near_val = float(feats[AiFeatureNames.THREAT_AT_STAND])
		elif cand.stand_coords() == Vector2i(2, -2):
			mid_val = float(feats[AiFeatureNames.THREAT_AT_STAND])
	if near_val < 0.0 or mid_val < 0.0:
		push_error("Expected both stand candidates")
		return false
	if not (near_val > mid_val and mid_val > 0.0):
		push_error("Stands with different raw threat must differ (%s vs %s)" % [near_val, mid_val])
		return false
	return true
