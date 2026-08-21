class_name UtilityBrain
extends AiBrain

## Utility AI: enumerate candidates, extract features, linear score, argmax (EA mode).

const AiCandidateGen = preload("res://scripts/ai/utility/ai_candidate_gen.gd")
const AiContextScript = preload("res://scripts/ai/utility/ai_context.gd")
const AiFeatureExtract = preload("res://scripts/ai/utility/ai_feature_extract.gd")
const AiUtilityScorer = preload("res://scripts/ai/utility/ai_utility_scorer.gd")
const AiProfileScript = preload("res://scripts/ai/utility/ai_profile.gd")
const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")

var profile: AiProfile
## When true (default for EA / duels), always argmax. Softmax uses profile.temperature.
var force_argmax: bool = true
var debug_enabled: bool = false
var probe = null

func _init(p_profile: AiProfile = null) -> void:
	id = "utility"
	display_name = "Utility"
	profile = p_profile if p_profile != null else AiProfileScript.hand_v1()
	CombatExpectation.use_play_mode()

func decide(session, legion: Legion) -> Dictionary:
	if legion == null:
		return {"type": "pass", "coords": Vector2i.ZERO, "reason": "no legion"}
	var ctx: AiContext = AiContextScript.build(session, legion)
	var cands: Array = AiCandidateGen.generate(session, legion, ctx)
	if cands.is_empty():
		return {"type": "pass", "coords": legion.tile_coords, "reason": "no candidates"}

	var scored: Array[Dictionary] = []
	for cand in cands:
		var feats: Dictionary = AiFeatureExtract.extract(session, legion, ctx, cand)
		var score := AiUtilityScorer.score(feats, profile)
		scored.append({"cand": cand, "score": score, "feats": feats})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: float = float(a["score"])
		var sb: float = float(b["score"])
		if not is_equal_approx(sa, sb):
			return sa > sb
		# Deterministic tie-break: action id then coords.
		var ca: AiCandidate = a["cand"]
		var cb: AiCandidate = b["cand"]
		if ca.action_id != cb.action_id:
			return ca.action_id < cb.action_id
		if ca.to.x != cb.to.x:
			return ca.to.x < cb.to.x
		return ca.to.y < cb.to.y
	)

	var chosen: Dictionary = scored[0]
	if not force_argmax and profile.temperature > 0.0:
		chosen = _softmax_pick(scored, profile.temperature)

	var best_cand: AiCandidate = chosen["cand"]
	if probe != null:
		probe.record(chosen.get("feats", {}), _probe_action_id(best_cand))
	var cmd: Dictionary = best_cand.to_command()
	cmd["score"] = float(chosen["score"])
	if not String(cmd.get("reason", "")).is_empty():
		cmd["reason"] = "%s (u=%.2f)" % [cmd["reason"], float(chosen["score"])]
	if debug_enabled:
		print(
			"[UtilityAI] %s @ %s -> %s score=%.2f"
			% [legion.team_id, legion.tile_coords, cmd.get("action_id", "pass"), float(chosen["score"])]
		)
	return cmd

func _probe_action_id(cand: AiCandidate) -> String:
	if cand == null:
		return "pass"
	if not cand.followup_action_id.is_empty():
		return cand.followup_action_id
	return cand.action_id

func sort_actionable(session, actionable: Array[Vector2i]) -> Array[Vector2i]:
	if actionable.is_empty():
		return actionable
	var scored: Array[Dictionary] = []
	for coords in actionable:
		var legion: Legion = session.get_legion_at(coords)
		if legion == null or not session.can_act_legion(legion):
			scored.append({"coords": coords, "score": -INF})
			continue
		var ctx: AiContext = AiContextScript.build(session, legion)
		var cands: Array = AiCandidateGen.generate(session, legion, ctx)
		var best := -INF
		for cand in cands:
			var feats: Dictionary = AiFeatureExtract.extract(session, legion, ctx, cand)
			best = maxf(best, AiUtilityScorer.score(feats, profile))
		scored.append({"coords": coords, "score": best})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: float = float(a["score"])
		var sb: float = float(b["score"])
		if not is_equal_approx(sa, sb):
			return sa > sb
		var ca: Vector2i = a["coords"]
		var cb: Vector2i = b["coords"]
		if ca.x != cb.x:
			return ca.x < cb.x
		return ca.y < cb.y
	)
	var out: Array[Vector2i] = []
	for row in scored:
		out.append(row["coords"])
	return out

func _softmax_pick(scored: Array[Dictionary], temperature: float) -> Dictionary:
	var t := maxf(0.05, temperature)
	var max_s := float(scored[0]["score"])
	var weights: Array[float] = []
	var sum := 0.0
	for row in scored:
		var w := exp((float(row["score"]) - max_s) / t)
		weights.append(w)
		sum += w
	if sum <= 0.0:
		return scored[0]
	var r := randf() * sum
	var acc := 0.0
	for i in range(scored.size()):
		acc += weights[i]
		if r <= acc:
			return scored[i]
	return scored[scored.size() - 1]
