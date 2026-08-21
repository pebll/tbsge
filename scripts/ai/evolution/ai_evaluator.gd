class_name AiEvaluator
extends RefCounted

## Fitness = mirrored pair score vs cascade baseline (argmax utility). EA uses train MC N.

const AiBehaviorProbeScript = preload("res://scripts/ai/evolution/ai_behavior_probe.gd")
const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const AiDuelRunner = preload("res://scripts/balance/ai_duel_runner.gd")
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
	CombatExpectation.use_train_mode()
	var probe = AiBehaviorProbeScript.new()
	var utility: UtilityBrain = UtilityBrainScript.new(genome.to_profile("eval"))
	utility.force_argmax = true
	utility.probe = probe
	var cascade: AiBrain = CascadeBrainScript.new()

	var pair_points := 0.0
	for i in range(pair_count):
		var game_index := seed_offset * 1000 + i
		# Mirror: genome as GREEN then as BLUE on same seed.
		var r1: Dictionary = AiDuelRunner.run_one(game_index, map_size, budget, utility, cascade)
		var r2: Dictionary = AiDuelRunner.run_one(game_index, map_size, budget, cascade, utility)
		pair_points += _brain_points(r1, true)
		pair_points += _brain_points(r2, false)

	var fitness := pair_points / float(maxi(pair_count, 1))  # 0..2
	var descriptor: Dictionary = probe.descriptor()
	CombatExpectation.use_play_mode()
	return {
		"fitness": fitness,
		"descriptor": descriptor,
		"pair_points": pair_points,
		"pair_count": pair_count,
	}

## Points for the genome side of one match (1 win, 0.5 draw, 0 loss).
static func _brain_points(result: Dictionary, genome_is_green: bool) -> float:
	if bool(result.get("timed_out", false)):
		return 0.5
	var winner := String(result.get("winner", ""))
	if winner.is_empty():
		return 0.5
	if winner == "GREEN":
		return 1.0 if genome_is_green else 0.0
	if winner == "BLUE":
		return 0.0 if genome_is_green else 1.0
	return 0.5
