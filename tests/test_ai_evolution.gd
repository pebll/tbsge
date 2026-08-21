extends RefCounted

const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiMapElitesArchiveScript = preload("res://scripts/ai/evolution/ai_map_elites_archive.gd")
const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const AiEvolveRunner = preload("res://scripts/ai/evolution/ai_evolve_runner.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_genome_roundtrip():
		return false
	if not _test_mutate_changes_some_weights():
		return false
	if not _test_archive_keeps_better():
		return false
	if not _test_evaluator_smoke():
		return false
	if not _test_evolve_one_generation_smoke():
		return false
	print("Success: MAP-Elites evolution tests")
	return true

func _test_genome_roundtrip() -> bool:
	var g = AiGenomeScript.from_hand_v1()
	var p = g.to_profile("t")
	if not is_equal_approx(p.weight_for(AiFeatureNames.PASS_PENALTY), g.weights[AiFeatureNames.PASS_PENALTY]):
		push_error("Profile roundtrip mismatch")
		return false
	return true

func _test_mutate_changes_some_weights() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var g = AiGenomeScript.from_hand_v1()
	var child = g.mutate(rng, 1.0, 1.0)
	var changed := 0
	for name in AiFeatureNames.all_names():
		if not is_equal_approx(float(g.weights[name]), float(child.weights[name])):
			changed += 1
	if changed == 0:
		push_error("Expected mutate(gene_chance=1) to change weights")
		return false
	return true

func _test_archive_keeps_better() -> bool:
	var archive = AiMapElitesArchiveScript.new(5, 5)
	var g1 = AiGenomeScript.from_hand_v1()
	var g2 = g1.duplicate_genome()
	var desc := {"aggression": 0.1, "risk": 0.1, "support_focus": 0.0}
	if not archive.try_insert(g1, 0.5, desc):
		push_error("First insert should succeed")
		return false
	if archive.try_insert(g2, 0.4, desc):
		push_error("Worse fitness should not replace elite")
		return false
	if not archive.try_insert(g2, 0.9, desc):
		push_error("Better fitness should replace elite")
		return false
	if not is_equal_approx(archive.best_fitness(), 0.9):
		push_error("Best fitness should be 0.9")
		return false
	return true

func _test_evaluator_smoke() -> bool:
	var g = AiGenomeScript.from_hand_v1()
	var report: Dictionary = AiEvaluator.evaluate_genome(g, 1, 3, 75, 1)
	var fitness := float(report.get("fitness", -1.0))
	if fitness < 0.0 or fitness > 2.0:
		push_error("Fitness out of range: %s" % fitness)
		return false
	var d: Dictionary = report.get("descriptor", {})
	for key in ["aggression", "risk", "support_focus"]:
		if not d.has(key):
			push_error("Missing descriptor %s" % key)
			return false
	return true

func _test_evolve_one_generation_smoke() -> bool:
	var batch: Dictionary = AiEvolveRunner.run(1, 2, 1, 3, 75, 99, false)
	if int(batch.get("archive_size", 0)) < 1:
		push_error("Archive should have at least one elite")
		return false
	if int(batch.get("evaluations", 0)) < 2:
		push_error("Expected several evaluations")
		return false
	return true
