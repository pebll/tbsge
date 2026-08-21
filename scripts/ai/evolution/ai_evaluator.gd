class_name AiEvaluator
extends RefCounted

## Fitness = mirrored rich match scores vs opponent (argmax utility). EA uses train MC N.

const AiBehaviorProbeScript = preload("res://scripts/ai/evolution/ai_behavior_probe.gd")
const AiDuelRunner = preload("res://scripts/balance/ai_duel_runner.gd")
const AiMatchScore = preload("res://scripts/ai/evolution/ai_match_score.gd")
const CascadeBrainScript = preload("res://scripts/ai/brains/cascade_brain.gd")
const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")

static func evaluate_genome(
	genome: AiGenome,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	return evaluate_vs_cascade(genome, pair_count, map_size, budget, seed_offset)

static func evaluate_vs_cascade(
	genome: AiGenome,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	var cascade: AiBrain = CascadeBrainScript.new()
	return _evaluate_vs_brain(genome, cascade, pair_count, map_size, budget, seed_offset, true)

static func evaluate_vs_genome(
	genome: AiGenome,
	opponent: AiGenome,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0,
	collect_probe: bool = false
) -> Dictionary:
	var opp_brain: UtilityBrain = UtilityBrainScript.new(opponent.to_profile("opp"))
	opp_brain.force_argmax = true
	return _evaluate_vs_brain(genome, opp_brain, pair_count, map_size, budget, seed_offset, collect_probe)

static func _evaluate_vs_brain(
	genome: AiGenome,
	opponent: AiBrain,
	pair_count: int,
	map_size: int,
	budget: int,
	seed_offset: int,
	collect_probe: bool
) -> Dictionary:
	CombatExpectation.use_train_mode()
	var probe = null
	if collect_probe:
		probe = AiBehaviorProbeScript.new()
	var utility: UtilityBrain = UtilityBrainScript.new(genome.to_profile("eval"))
	utility.force_argmax = true
	utility.probe = probe

	var pair_points := 0.0
	var outcome_sum := 0.0
	for i in range(pair_count):
		var game_index := seed_offset * 1000 + i
		var r1: Dictionary = AiDuelRunner.run_one(game_index, map_size, budget, utility, opponent)
		var r2: Dictionary = AiDuelRunner.run_one(game_index, map_size, budget, opponent, utility)
		pair_points += AiMatchScore.score_for_side(r1, true)
		pair_points += AiMatchScore.score_for_side(r2, false)
		outcome_sum += AiMatchScore.outcome_rate(r1, true)
		outcome_sum += AiMatchScore.outcome_rate(r2, false)

	var fitness := pair_points / float(maxi(pair_count, 1))
	var win_rate := outcome_sum / float(maxi(pair_count * 2, 1))
	var descriptor := {}
	if probe != null:
		descriptor = probe.descriptor()
	CombatExpectation.use_play_mode()
	return {
		"fitness": fitness,
		"descriptor": descriptor,
		"pair_points": pair_points,
		"pair_count": pair_count,
		"win_rate": win_rate,
	}
