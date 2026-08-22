extends RefCounted

const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiGaPopulationScript = preload("res://scripts/ai/evolution/ai_ga_population.gd")
const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const AiEvolveRunner = preload("res://scripts/ai/evolution/ai_evolve_runner.gd")
const AiArchiveStore = preload("res://scripts/ai/evolution/ai_archive_store.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_genome_roundtrip():
		return false
	if not _test_mutate_changes_some_weights():
		return false
	if not _test_ga_population_basics():
		return false
	if not _test_cumulative_fitness():
		return false
	if not _test_elite_pairs_budget():
		return false
	if not _test_eval_rank_mark():
		return false
	if not _test_confirm_report_merge():
		return false
	if not _test_evaluator_smoke():
		return false
	if not _test_evolve_one_generation_smoke():
		return false
	if not _test_checkpoint_roundtrip_and_continue():
		return false
	if not _test_stop_file():
		return false
	print("Success: GA evolution tests")
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

func _test_ga_population_basics() -> bool:
	var pop = AiGaPopulationScript.new()
	var g1 = AiGenomeScript.from_hand_v1()
	var g2 = g1.duplicate_genome()
	pop.add_member(g1, 1.5, {"aggression": 0.2, "risk": 0.2})
	pop.add_member(g2, 2.2, {"aggression": 0.5, "risk": 0.5})
	if not is_equal_approx(pop.best_fitness(), 2.2):
		push_error("Best fitness should be 2.2")
		return false
	if not pop.would_confirm(2.3):
		push_error("Should confirm above best")
		return false
	if pop.would_confirm(1.0):
		push_error("Should not confirm far below best")
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var picked = pop.tournament_select(rng)
	if picked == null:
		push_error("Tournament should return a genome")
		return false
	return true

func _test_cumulative_fitness() -> bool:
	var desc: Dictionary = {}
	var r1 := {"pair_points": 8.0, "pair_count": 4, "trainee_wins": 8, "trainee_losses": 0, "trainee_draws": 0}
	var r2 := {"pair_points": 7.0, "pair_count": 4, "trainee_wins": 7, "trainee_losses": 0, "trainee_draws": 1, "trainee_stale_draws": 1}
	var fit1 := AiGaPopulationScript.accumulate_eval(desc, r1)
	if not is_equal_approx(fit1, 2.0):
		push_error("First cumulative fit expected 2.0 got %s" % fit1)
		return false
	var fit2 := AiGaPopulationScript.accumulate_eval(desc, r2)
	if not is_equal_approx(fit2, 1.875):
		push_error("Second cumulative fit expected 1.875 got %s" % fit2)
		return false
	if int(desc.get("cum_wins", 0)) != 15:
		push_error("cum_wins expected 15")
		return false
	if int(desc.get("cum_draws", 0)) != 1:
		push_error("cum_draws expected 1")
		return false
	var boot: Dictionary = {}
	var fit3 := AiGaPopulationScript.accumulate_eval(boot, r1, 1.8)
	if not is_equal_approx(fit3, 1.9):
		push_error("Bootstrap cumulative fit expected 1.9 got %s" % fit3)
		return false
	return true

func _test_elite_pairs_budget() -> bool:
	if AiEvolveRunner._elite_pairs_per_eval(5) != 2:
		push_error("elite pairs for 5 should be 2")
		return false
	if AiEvolveRunner._elite_pairs_per_eval(4) != 2:
		push_error("elite pairs for 4 should be 2")
		return false
	if AiEvolveRunner._elite_pairs_per_eval(1) != 1:
		push_error("elite pairs for 1 should stay 1")
		return false
	return true

func _test_eval_rank_mark() -> bool:
	if AiEvolveRunner.eval_rank_mark(1.5, 1.1, 1.4) != "!!":
		push_error("expected !! above best elite")
		return false
	if AiEvolveRunner.eval_rank_mark(1.2, 1.1, 1.4) != "+":
		push_error("expected + above worst elite")
		return false
	if AiEvolveRunner.eval_rank_mark(1.0, 1.1, 1.4) != "·":
		push_error("expected · below worst elite")
		return false
	return true

func _test_confirm_report_merge() -> bool:
	var scout := {
		"pair_count": 2,
		"pair_points": 3.0,
		"fitness": 1.5,
		"trainee_wins": 2,
		"trainee_losses": 0,
		"trainee_draws": 2,
		"win_rate": 0.75,
		"trainee_stale_draws": 2,
		"trainee_timeouts": 0,
		"trainee_other_draws": 0,
		"trainee_draft_failures": 0,
		"match_stats": {"games": 4, "stale_draws": 2, "timeouts": 0, "other_draws": 0, "draft_failures": 0},
		"match_rows": [1, 2],
		"legion_rows": [3],
	}
	var confirm := {
		"pair_count": 4,
		"pair_points": 4.0,
		"fitness": 1.0,
		"trainee_wins": 1,
		"trainee_losses": 1,
		"trainee_draws": 6,
		"win_rate": 0.4375,
		"trainee_stale_draws": 6,
		"trainee_timeouts": 0,
		"trainee_other_draws": 0,
		"trainee_draft_failures": 0,
		"match_stats": {"games": 8, "stale_draws": 6, "timeouts": 0, "other_draws": 0, "draft_failures": 0},
		"match_rows": [4, 5],
		"legion_rows": [6],
		"opponent": "pass",
	}
	var merged: Dictionary = AiEvaluator.merge_scout_confirm_reports(scout, confirm)
	if int(merged.get("trainee_wins", 0)) != 3:
		push_error("merged wins expected 3")
		return false
	if int(merged.get("trainee_draws", 0)) != 8:
		push_error("merged draws expected 8")
		return false
	if int(merged.get("trainee_stale_draws", 0)) != 8:
		push_error("merged trainee stale expected 8")
		return false
	if int(merged.get("pair_count", 0)) != 6:
		push_error("merged pair_count expected 6")
		return false
	if not is_equal_approx(float(merged.get("win_rate", 0.0)), 7.0 / 12.0):
		push_error("merged win_rate expected 7/12")
		return false
	if int(merged.get("match_stats", {}).get("stale_draws", 0)) != 8:
		push_error("merged stale_draws expected 8")
		return false
	if int(merged.get("match_rows", []).size()) != 4:
		push_error("merged match_rows expected 4")
		return false
	return true

func _test_evaluator_smoke() -> bool:
	var g = AiGenomeScript.from_hand_v1()
	var report: Dictionary = AiEvaluator.evaluate_genome(g, 1, 3, 75, 1)
	var fitness := float(report.get("fitness", -999.0))
	if fitness < -3.0 or fitness > 5.0:
		push_error("Fitness out of plausible range: %s" % fitness)
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
		push_error("Population should have at least one member")
		return false
	if int(batch.get("evaluations", 0)) < 2:
		push_error("Expected several evaluations")
		return false
	return true

func _test_checkpoint_roundtrip_and_continue() -> bool:
	var run_dir := "res://data/ai/evolve/_test_ckpt_%d" % Time.get_ticks_msec()
	var batch1: Dictionary = AiEvolveRunner.run_session({
		"gens": 1,
		"pop": 2,
		"pairs": 1,
		"map_size": 3,
		"budget": 75,
		"seed": 11,
		"verbose": false,
		"run_dir": run_dir,
		"continue_run": false,
		"arena_pairs": 1,
		"arena_opponents": 1,
		"checkpoint_every": 1,
	})
	if not AiArchiveStore.has_checkpoint(run_dir):
		push_error("Expected checkpoint after first session")
		return false
	if int(batch1.get("generations", 0)) != 1:
		push_error("Expected 1 generation completed")
		return false
	var batch2: Dictionary = AiEvolveRunner.run_session({
		"gens": 1,
		"pop": 2,
		"pairs": 1,
		"map_size": 3,
		"budget": 75,
		"seed": 11,
		"verbose": false,
		"run_dir": run_dir,
		"continue_run": true,
		"arena_pairs": 1,
		"arena_opponents": 1,
		"checkpoint_every": 1,
	})
	if int(batch2.get("generations", 0)) != 2:
		push_error("Continue should reach gen 2, got %s" % batch2.get("generations"))
		return false
	if not batch2.has("vs_cascade"):
		push_error("Expected vs_cascade metric")
		return false
	var abs_dir := ProjectSettings.globalize_path(run_dir)
	for fname in ["checkpoint.json", "history.jsonl", "best_profile.json", "STOP"]:
		var p := abs_dir.path_join(fname)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var bal := abs_dir.path_join("balance")
	if DirAccess.dir_exists_absolute(bal):
		for fname2 in ["matches.csv", "legions.csv"]:
			var p2 := bal.path_join(fname2)
			if FileAccess.file_exists(p2):
				DirAccess.remove_absolute(p2)
		DirAccess.remove_absolute(bal)
	DirAccess.remove_absolute(abs_dir)
	return true

func _test_stop_file() -> bool:
	var run_dir := "res://data/ai/evolve/_test_stop_%d" % Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir))
	AiArchiveStore.request_stop(run_dir)
	if not AiArchiveStore.should_stop(run_dir):
		push_error("STOP file should be detected")
		return false
	AiArchiveStore.clear_stop(run_dir)
	if AiArchiveStore.should_stop(run_dir):
		push_error("STOP file should be cleared")
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_dir))
	return true
