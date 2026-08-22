class_name AiCurriculum
extends RefCounted

## Staged opponents + draft modes for curriculum learning.

const CascadeBrainScript = preload("res://scripts/ai/brains/cascade_brain.gd")
const DraftScenarioScript = preload("res://scripts/ai/curriculum/draft_scenario.gd")
const GreedyCombatBrainScript = preload("res://scripts/ai/brains/greedy_combat_brain.gd")
const HealOnlyBrainScript = preload("res://scripts/ai/brains/heal_only_brain.gd")
const PassBrainScript = preload("res://scripts/ai/brains/pass_brain.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")
const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const CurriculumTrackerScript = preload("res://scripts/ai/curriculum/curriculum_tracker.gd")

## Ordered ladder: pass → heal → greedy → cascade → self-play.
static func all_stages() -> Array:
	return [
		{
			"id": "pass_mirror",
			"title": "Pass bot, mirrored armies",
			"opponent": "curriculum_pass",
			"draft": "mirror_seed",
			"simple_fitness": true,
			"promote_win_rate": 0.90,
			"promote_min_games": 8,
		},
		{
			"id": "pass_random",
			"title": "Pass bot, random armies",
			"opponent": "curriculum_pass",
			"draft": "random",
			"simple_fitness": true,
			"promote_win_rate": 0.88,
			"promote_min_games": 10,
		},
		{
			"id": "heal_mirror",
			"title": "Heal-only, mirrored",
			"opponent": "curriculum_heal",
			"draft": "mirror_seed",
			"simple_fitness": true,
			"promote_win_rate": 0.85,
			"promote_min_games": 12,
		},
		{
			"id": "heal_ranged_random",
			"title": "Heal ranged only, random",
			"opponent": "curriculum_heal_ranged",
			"draft": "random",
			"simple_fitness": true,
			"promote_win_rate": 0.82,
			"promote_min_games": 12,
		},
		{
			"id": "heal_random",
			"title": "Heal-only, random",
			"opponent": "curriculum_heal",
			"draft": "random",
			"simple_fitness": true,
			"promote_win_rate": 0.80,
			"promote_min_games": 12,
		},
		{
			"id": "greedy_mirror",
			"title": "Greedy combat, mirrored",
			"opponent": "curriculum_greedy",
			"draft": "mirror_seed",
			"simple_fitness": false,
			"promote_win_rate": 0.75,
			"promote_min_games": 16,
		},
		{
			"id": "greedy_random",
			"title": "Greedy combat, random",
			"opponent": "curriculum_greedy",
			"draft": "random",
			"simple_fitness": false,
			"promote_win_rate": 0.70,
			"promote_min_games": 16,
		},
		{
			"id": "cascade_mirror",
			"title": "Cascade, mirrored",
			"opponent": "cascade",
			"draft": "mirror_seed",
			"simple_fitness": false,
			"promote_win_rate": 0.65,
			"promote_min_games": 20,
		},
		{
			"id": "cascade_random",
			"title": "Cascade, random",
			"opponent": "cascade",
			"draft": "random",
			"simple_fitness": false,
			"promote_win_rate": 0.58,
			"promote_min_games": 24,
			"save_hof_on_promote": true,
		},
		{
			"id": "self_play",
			"title": "Self-play vs past champions",
			"opponent": "self_play",
			"draft": "random",
			"simple_fitness": false,
			"promote_win_rate": 1.0,
			"promote_min_games": 99999,
		},
	]

static func stage_count() -> int:
	return all_stages().size()

static func stage_at(index: int) -> Dictionary:
	var stages := all_stages()
	if index < 0:
		return stages[0]
	if index >= stages.size():
		return stages[stages.size() - 1]
	return stages[index]

static func find_stage_index(stage_id: String) -> int:
	var key := stage_id.strip_edges().to_lower()
	for i in range(all_stages().size()):
		if String(all_stages()[i].get("id", "")).to_lower() == key:
			return i
	return -1

static func draft_for_stage(stage: Dictionary) -> DraftScenarioScript:
	return DraftScenarioScript.from_string(String(stage.get("draft", "random")))

static func create_opponent(stage: Dictionary, tracker: CurriculumTrackerScript, rng: RandomNumberGenerator) -> AiBrain:
	var opp_id := String(stage.get("opponent", "cascade"))
	match opp_id:
		"curriculum_pass":
			return PassBrainScript.new()
		"curriculum_heal":
			return HealOnlyBrainScript.new(false)
		"curriculum_heal_ranged":
			return HealOnlyBrainScript.new(true)
		"curriculum_greedy":
			return GreedyCombatBrainScript.new()
		"cascade":
			return CascadeBrainScript.new()
		"self_play":
			return _self_play_opponent(tracker, rng)
		_:
			return CascadeBrainScript.new()

static func _self_play_opponent(tracker: CurriculumTrackerScript, rng: RandomNumberGenerator) -> AiBrain:
	if tracker == null:
		return CascadeBrainScript.new()
	var hof: AiGenome = tracker.random_hof_genome(rng)
	if hof == null or rng.randf() < 0.35:
		return CascadeBrainScript.new()
	var brain: UtilityBrain = UtilityBrainScript.new(hof.to_profile("hof"))
	brain.force_argmax = true
	return brain

static func stale_idle_turns_for_stage(stage: Dictionary) -> int:
	var opp := String(stage.get("opponent", ""))
	if opp == "curriculum_pass":
		# STALE_MIN_TEAM_TURNS (10) + 5 idle team-turns without damage.
		return 5
	if opp in ["curriculum_heal", "curriculum_heal_ranged"]:
		return 36
	return 0

static func retain_win_rate(stage: Dictionary) -> float:
	return maxf(0.5, float(stage.get("promote_win_rate", 0.85)) - 0.10)

static func promotion_requirements(stage: Dictionary, stage_index: int = 0) -> String:
	var need_wr := float(stage.get("promote_win_rate", 0.85))
	var min_games := int(stage.get("promote_min_games", 12))
	var retain_n := maxi(0, stage_index)
	return (
		"promote-check: eval cum ≥%.0f%% wr over %d scout/confirm games on %s%s"
		% [
			100.0 * need_wr,
			min_games,
			String(stage.get("id", "?")),
			(
				"; retain %d prior stage(s) @ ≥%.0f%% (promote−10%%)"
				% [retain_n, 100.0 * retain_win_rate(stage)]
				if retain_n > 0
				else ""
			),
		]
	)

static func eval_cum_progress(stage: Dictionary, member_desc: Dictionary) -> String:
	const GaPop = preload("res://scripts/ai/evolution/ai_ga_population.gd")
	var need_wr := float(stage.get("promote_win_rate", 0.85))
	var min_games := int(stage.get("promote_min_games", 12))
	var games := GaPop.eval_cum_games(member_desc)
	var wr := 100.0 * GaPop.cumulative_win_rate(member_desc)
	return (
		"eval cum %s: %d/%d games wr %.0f%% (need ≥%.0f%%)"
		% [String(stage.get("id", "?")), games, min_games, wr, 100.0 * need_wr]
	)

static func promotion_progress(
	stage: Dictionary,
	_tracker: CurriculumTrackerScript,
	member_desc: Dictionary = {}
) -> String:
	if not member_desc.is_empty() and int(member_desc.get("cum_pair_count", 0)) > 0:
		return eval_cum_progress(stage, member_desc)
	return promotion_requirements(stage, _tracker.stage_index if _tracker != null else 0)

static func format_retention_line(retention: Dictionary) -> String:
	var stages: Array = retention.get("stages", [])
	if stages.is_empty():
		return "retain —"
	var parts: PackedStringArray = []
	for row in stages:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var sid := String(d.get("stage_id", "?"))
		var mark := "✓" if bool(d.get("passed", false)) else "✗"
		var got := int(d.get("audit_games", 0))
		var need := int(d.get("need_games", 0))
		var wr := 100.0 * float(d.get("win_rate", 0.0))
		var need_wr := 100.0 * float(d.get("need_win_rate", 0.0))
		parts.append("%s %s %d/%d wr %.0f%% (≥%.0f%%)" % [sid, mark, got, need, wr, need_wr])
	return "retain " + ", ".join(parts)

static func format_promotion_audit(audit: Dictionary) -> String:
	if audit.is_empty():
		return "(no audit yet)"
	var need_wr := float(audit.get("need_win_rate", 0.0))
	var need_games := int(audit.get("need_games", 0))
	var cum_games := int(audit.get("audit_games", 0))
	var cum_wr := 100.0 * float(audit.get("audit_win_rate", 0.0))
	var stage_id := String(audit.get("stage_id", "?"))
	var retain: Dictionary = audit.get("retention", {})
	var retain_line := format_retention_line(retain)
	var promoted := bool(audit.get("promotion_passed", false))
	var verdict := "PROMOTE" if promoted else "HOLD"
	var reasons: PackedStringArray = []
	if not bool(audit.get("current_passed", false)):
		if cum_games < need_games:
			reasons.append("eval cum %d/%d games" % [cum_games, need_games])
		else:
			reasons.append("eval cum wr %.1f%% < %.0f%%" % [cum_wr, 100.0 * need_wr])
	if not bool(audit.get("retention_passed", true)):
		reasons.append("retention failed")
	var reason_suffix := (" — %s" % ", ".join(reasons)) if not reasons.is_empty() else ""
	var wins := int(audit.get("trainee_wins", 0))
	var losses := int(audit.get("trainee_losses", 0))
	var draws := int(audit.get("trainee_draws", 0))
	return (
		"%s | eval cum %s %d/%d wr %.1f%% (≥%.0f%%) (%dW-%dL-%dD) | %s%s"
		% [
			verdict,
			stage_id,
			cum_games,
			need_games,
			cum_wr,
			100.0 * need_wr,
			wins,
			losses,
			draws,
			retain_line,
			reason_suffix,
		]
	)

static func stage_header(stage: Dictionary) -> String:
	return "%s (%s)" % [String(stage.get("id", "?")), String(stage.get("draft", "?"))]
