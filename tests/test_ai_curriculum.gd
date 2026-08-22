extends RefCounted

const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const AiCurriculumScript = preload("res://scripts/ai/curriculum/ai_curriculum.gd")
const AiDuelRunner = preload("res://scripts/balance/ai_duel_runner.gd")
const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiEvolveRunner = preload("res://scripts/ai/evolution/ai_evolve_runner.gd")
const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiGaPopulationScript = preload("res://scripts/ai/evolution/ai_ga_population.gd")
const CurriculumTrackerScript = preload("res://scripts/ai/curriculum/curriculum_tracker.gd")
const DraftScenarioScript = preload("res://scripts/ai/curriculum/draft_scenario.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_pass_bot_loses_to_utility():
		return false
	if not _test_mirror_draft_same_composition():
		return false
	if not _test_curriculum_eval_smoke():
		return false
	if not _test_tracker_promotion():
		return false
	if not _test_eval_cum_promotion_gate():
		return false
	if not _test_retain_win_rate():
		return false
	if not _test_promotion_audit_pairs():
		return false
	if not _test_retention_on_confirm():
		return false
	if not _test_rehearsal_focus_from_audit():
		return false
	if not _test_mixed_eval_rehearsal():
		return false
	if not _test_promotion_cum_excludes_rehearsal():
		return false
	if not _test_curriculum_draw_scoring():
		return false
	if not _test_curriculum_evolve_smoke():
		return false
	print("Success: curriculum tests")
	return true

func _test_pass_bot_loses_to_utility() -> bool:
	var tracker := CurriculumTrackerScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var g = AiGenomeScript.from_hand_v1()
	var report: Dictionary = AiEvaluator.evaluate_for_curriculum(g, tracker, rng, 2, 3, 75, 2)
	var wr := float(report.get("win_rate", 0.0))
	if wr < 0.5:
		push_error("Utility should beat pass bot (win_rate=%.2f)" % wr)
		return false
	return true

func _test_mirror_draft_same_composition() -> bool:
	var pass_a: AiBrain = AiBrainRegistry.create("curriculum_pass")
	var pass_b: AiBrain = AiBrainRegistry.create("curriculum_pass")
	var draft = DraftScenarioScript.mirror_seed()
	var r: Dictionary = AiDuelRunner.run_one(55, 3, 75, pass_a, pass_b, draft)
	if int(r.get("team_turns", 0)) <= 0 and not bool(r.get("draft_failed", false)):
		push_error("Mirror draft battle should run (turns=%d)" % int(r.get("team_turns", 0)))
		return false
	if bool(r.get("draft_failed", false)):
		push_error("Mirror draft failed: %s" % String(r.get("fail_reason", "?")))
		return false
	var green_gold := float(r.get("gold_start_green", 0.0))
	var blue_gold := float(r.get("gold_start_blue", 0.0))
	if not is_equal_approx(green_gold, blue_gold):
		push_error("Mirrored draft should equalize gold: g=%.1f b=%.1f" % [green_gold, blue_gold])
		return false
	return true

func _test_curriculum_eval_smoke() -> bool:
	var tracker := CurriculumTrackerScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var g = AiGenomeScript.from_hand_v1()
	var report: Dictionary = AiEvaluator.evaluate_for_curriculum(g, tracker, rng, 1, 3, 75, 1)
	var fit := float(report.get("fitness", -1.0))
	if fit < 0.0:
		push_error("Curriculum fitness should be non-negative vs pass bot, got %.3f" % fit)
		return false
	if String(report.get("curriculum_stage", "")) != "pass_mirror":
		push_error("Expected pass_mirror stage, got %s" % report.get("curriculum_stage"))
		return false
	return true

func _test_tracker_promotion() -> bool:
	var tracker := CurriculumTrackerScript.new()
	var stage: Dictionary = AiCurriculumScript.stage_at(0)
	tracker.set_last_promote_audit({"promotion_passed": false})
	if tracker.should_promote(stage):
		push_error("Should not promote without a passing audit")
		return false
	tracker.set_last_promote_audit({"promotion_passed": true})
	if not tracker.should_promote(stage):
		push_error("Should promote when audit passed")
		return false
	tracker.promote("pass_mirror", 1, 1.0)
	if tracker.stage_index != 1:
		push_error("Expected stage index 1 after promote")
		return false
	return true

func _test_eval_cum_promotion_gate() -> bool:
	var stage: Dictionary = AiCurriculumScript.stage_at(1)
	var desc := {
		"cum_wins": 20,
		"cum_losses": 0,
		"cum_draws": 2,
		"cum_pair_count": 11,
	}
	if not AiGaPopulationScript.eval_meets_promotion(desc, stage):
		push_error("Eval cum should pass pass_random gate at ~95%% wr")
		return false
	var weak := {"cum_wins": 7, "cum_losses": 0, "cum_draws": 3, "cum_pair_count": 5}
	if AiGaPopulationScript.eval_meets_promotion(weak, stage):
		push_error("Eval cum should fail with too few wins")
		return false
	return true

func _test_retain_win_rate() -> bool:
	var pass_mirror: Dictionary = AiCurriculumScript.stage_at(0)
	if not is_equal_approx(AiCurriculumScript.retain_win_rate(pass_mirror), 0.80):
		push_error("pass_mirror retain should be 80%%")
		return false
	var pass_random: Dictionary = AiCurriculumScript.stage_at(1)
	if not is_equal_approx(AiCurriculumScript.retain_win_rate(pass_random), 0.78):
		push_error("pass_random retain should be 78%%")
		return false
	return true

func _test_promotion_audit_pairs() -> bool:
	if AiEvaluator.audit_pairs_for_min_games(10) != 5:
		push_error("Expected 5 pairs for 10-game audit")
		return false
	if AiEvaluator.audit_pairs_for_min_games(8) != 4:
		push_error("Expected 4 pairs for 8-game audit")
		return false
	return true

func _test_retention_on_confirm() -> bool:
	var tracker := CurriculumTrackerScript.new()
	tracker.stage_index = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var g = AiGenomeScript.from_hand_v1()
	var retention: Dictionary = AiEvaluator.evaluate_curriculum_retention(g, tracker, rng, 3, 75, 99)
	var stages: Array = retention.get("stages", [])
	if stages.size() != 1:
		push_error("Expected 1 retention stage at index 1, got %d" % stages.size())
		return false
	if String((stages[0] as Dictionary).get("stage_id", "")) != "pass_mirror":
		push_error("Expected pass_mirror retention replay")
		return false
	return true

func _test_rehearsal_focus_from_audit() -> bool:
	var tracker := CurriculumTrackerScript.new()
	tracker.stage_index = 3
	tracker.set_last_promote_audit({
		"promotion_passed": false,
		"retention": {
			"passed": false,
			"stages": [
				{
					"stage_index": 0,
					"stage_id": "pass_mirror",
					"win_rate": 0.95,
					"passed": true,
				},
				{
					"stage_index": 2,
					"stage_id": "heal_mirror",
					"win_rate": 0.58,
					"passed": false,
				},
				{
					"stage_index": 1,
					"stage_id": "pass_random",
					"win_rate": 0.72,
					"passed": false,
				},
			],
		},
	})
	var worst: Array = tracker.rehearsal_stages_worst_first()
	if worst.size() != 2:
		push_error("Expected 2 failed rehearsal stages, got %d" % worst.size())
		return false
	if int(worst[0]) != 2:
		push_error("Worst-first should lead with heal_mirror (index 2), got %d" % int(worst[0]))
		return false
	if int(worst[1]) != 1:
		push_error("Second rehearsal should be pass_random (index 1), got %d" % int(worst[1]))
		return false
	var data: Dictionary = tracker.to_dict()
	var loaded = CurriculumTrackerScript.from_dict(data)
	var loaded_worst: Array = loaded.rehearsal_stages_worst_first()
	if loaded_worst.size() != 2 or int(loaded_worst[0]) != 2:
		push_error("Rehearsal focus should survive serialize round-trip")
		return false
	return true

func _test_mixed_eval_rehearsal() -> bool:
	var tracker := CurriculumTrackerScript.new()
	tracker.stage_index = 3
	tracker.set_last_promote_audit({
		"promotion_passed": false,
		"retention": {
			"passed": false,
			"stages": [
				{"stage_index": 2, "stage_id": "heal_mirror", "win_rate": 0.58, "passed": false},
			],
		},
	})
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var g = AiGenomeScript.from_hand_v1()
	var report: Dictionary = AiEvaluator.evaluate_for_curriculum(g, tracker, rng, 2, 3, 75, 3)
	if int(report.get("pair_count", 0)) != 2:
		push_error("Mixed eval should still run 2 pairs, got %d" % int(report.get("pair_count", 0)))
		return false
	var rehearsal: Variant = report.get("rehearsal_stages", [])
	var has_heal := false
	if typeof(rehearsal) == TYPE_PACKED_STRING_ARRAY:
		has_heal = (rehearsal as PackedStringArray).has("heal_mirror")
	elif typeof(rehearsal) == TYPE_ARRAY:
		has_heal = (rehearsal as Array).has("heal_mirror")
	if not has_heal:
		push_error("Expected heal_mirror in rehearsal_stages, got %s" % str(rehearsal))
		return false
	if String(report.get("curriculum_stage", "")) != "heal_ranged_random":
		push_error("Current stage should remain heal_ranged_random")
		return false
	return true

func _test_promotion_cum_excludes_rehearsal() -> bool:
	var reports: Array = [
		{
			"pair_points": 2.0,
			"pair_count": 1,
			"win_rate": 1.0,
			"trainee_wins": 2,
			"trainee_losses": 0,
			"trainee_draws": 0,
			"curriculum_stage": "heal_ranged_random",
		},
		{
			"pair_points": -1.0,
			"pair_count": 1,
			"win_rate": 0.0,
			"trainee_wins": 0,
			"trainee_losses": 0,
			"trainee_draws": 2,
			"trainee_stale_draws": 2,
			"curriculum_stage": "heal_mirror",
		},
	]
	var merged: Dictionary = AiEvaluator.merge_curriculum_eval_reports(reports, 3)
	if int(merged.get("trainee_draws", 0)) != 2:
		push_error("Fitness batch should include rehearsal draws")
		return false
	if int(merged.get("promotion_trainee_wins", 0)) != 2:
		push_error("Promotion cum should only count current-stage wins")
		return false
	if int(merged.get("promotion_trainee_draws", 0)) != 0:
		push_error("Promotion cum should exclude rehearsal draws")
		return false
	var desc := {"cum_wins": 0, "cum_losses": 0, "cum_draws": 0, "cum_pair_count": 0}
	AiGaPopulationScript.accumulate_eval(desc, merged)
	if int(desc.get("cum_wins", 0)) != 2 or int(desc.get("cum_draws", 0)) != 0:
		push_error("accumulate_eval should use promotion_trainee_* for cum W/L/D")
		return false
	if int(desc.get("cum_pair_count", 0)) != 2:
		push_error("accumulate_eval should count all pairs toward fitness")
		return false
	return true

func _test_curriculum_draw_scoring() -> bool:
	const CurriculumScoreScript = preload("res://scripts/ai/curriculum/curriculum_score.gd")
	var stale := {
		"winner": "",
		"stale_draw": true,
		"gold_start_green": 100.0,
		"gold_end_green": 100.0,
		"gold_start_blue": 100.0,
		"gold_end_blue": 100.0,
	}
	if not is_equal_approx(CurriculumScoreScript.simple_draw_score(stale, true), -0.5):
		push_error("Full-army stale draw should score -0.5")
		return false
	var bloody := stale.duplicate(true)
	bloody["gold_end_green"] = 5.0
	bloody["gold_end_blue"] = 5.0
	if not is_equal_approx(CurriculumScoreScript.simple_draw_score(bloody, true), 0.45):
		push_error("Low-army draw should score near 0.5")
		return false
	return true

func _test_curriculum_evolve_smoke() -> bool:
	var batch: Dictionary = AiEvolveRunner.run_session({
		"gens": 1,
		"pop": 2,
		"pairs": 1,
		"map_size": 3,
		"budget": 75,
		"seed": 88,
		"verbose": false,
		"run_dir": "",
		"continue_run": false,
		"arena_pairs": 1,
		"arena_opponents": 1,
		"curriculum": true,
		"no_promote": true,
	})
	if int(batch.get("evaluations", 0)) < 2:
		push_error("Curriculum evolve should run evaluations")
		return false
	if String(batch.get("curriculum_stage", "")).is_empty():
		push_error("Expected curriculum_stage in batch result")
		return false
	return true
