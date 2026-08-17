extends RefCounted

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const DraftState = preload("res://scripts/minigame/draft_state.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_budget_and_validation():
		return false
	if not _test_hidden_opponent_draft():
		return false
	if not _test_both_ready_starts_battle():
		return false
	if not _test_ai_drafts_multiple_legions():
		return false
	if not _test_ai_draft_prefers_maxed_stacks():
		return false
	if not _test_ai_draft_spends_large_budget():
		return false
	print("Success: Minigame draft tests")
	return true

func _test_budget_and_validation() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var slots: Array = session.get_deploy_slots(team_a_id)
	if slots.is_empty():
		push_error("Expected deploy slots for %s" % team_a_id)
		return false
	var coords: Vector2i = slots[0]

	var too_many: Dictionary = session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": coords,
		"unit_type": "GOBLIN",
		"unit_count": 13,
	})
	if too_many["ok"]:
		push_error("Expected failure when exceeding legion size")
		return false

	var ok: Dictionary = session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": coords,
		"unit_type": "GOBLIN",
		"unit_count": 4,
	})
	if not ok["ok"]:
		push_error("Expected valid goblin placement: %s" % ok["error"])
		return false

	var draft = session.drafts[team_a_id] as DraftState
	if draft.remaining_budget != 50 - 12:
		push_error("Expected remaining budget 38, got %d" % draft.remaining_budget)
		return false

	var overspend: Dictionary = session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": slots[1],
		"unit_type": "GOLEM",
		"unit_count": 4,
	})
	if overspend["ok"]:
		push_error("Expected overspend failure")
		return false
	return true

func _test_hidden_opponent_draft() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a_id)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": slots_a[0],
		"unit_type": "ASSASSIN",
		"unit_count": 2,
	})

	var blue_view: Dictionary = session.get_view_state(team_b_id)
	var opponent: Dictionary = blue_view.get("opponent_%s" % team_a_id, {})
	if opponent.has("placements"):
		push_error("Opponent draft details should be hidden")
		return false
	if int(opponent.get("slots_used", -1)) != 1:
		push_error("Opponent slots_used should be 1")
		return false
	return true

func _test_both_ready_starts_battle() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a_id)
	var slots_b: Array = session.get_deploy_slots(team_b_id)

	session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": slots_a[0],
		"unit_type": "GOBLIN",
		"unit_count": 3,
	})
	var green_ready: Dictionary = session.apply({"type": "draft_ready", "team": team_a_id})
	if not green_ready["ok"]:
		push_error("%s ready failed: %s" % [team_a_id, green_ready["error"]])
		return false
	if session.phase != MinigameSessionScript.Phase.DRAFT:
		push_error("Expected draft to continue for %s" % team_b_id)
		return false

	session.apply({
		"type": "draft_set_legion",
		"team": team_b_id,
		"coords": slots_b[0],
		"unit_type": "GOBLIN",
		"unit_count": 2,
	})
	var blue_ready: Dictionary = session.apply({"type": "draft_ready", "team": team_b_id})
	if not blue_ready["ok"]:
		push_error("%s ready failed: %s" % [team_b_id, blue_ready["error"]])
		return false
	if session.phase != MinigameSessionScript.Phase.BATTLE:
		push_error("Expected battle phase after both ready")
		return false
	if session.legions.size() != 2:
		push_error("Expected 2 legions on board")
		return false
	return true

func _test_ai_drafts_multiple_legions() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a_id)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": slots_a[0],
		"unit_type": "GOBLIN",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_a_id})

	var AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cmds: Array = AiDrafter.build_draft_commands(session, team_b_id, rng)
	for cmd in cmds:
		var result: Dictionary = session.apply(cmd)
		if not result["ok"]:
			push_error("AI draft command failed: %s" % result["error"])
			return false

	var draft: DraftState = session.drafts[team_b_id] as DraftState
	if draft.placements.size() < 2:
		push_error("AI should draft at least two legions (got %d)" % draft.placements.size())
		return false
	return true

## Sample many AI drafts: stacks should trend fat (no fixed legion-count cap).
func _test_ai_draft_prefers_maxed_stacks() -> bool:
	var AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
	var total_legions := 0
	var total_units := 0
	var samples := 24
	for i in range(samples):
		var session := MinigameTestHelpersScript.prepare_session()
		var team_a_id: String = MinigameTestHelpersScript.team_a(session)
		var team_b_id: String = MinigameTestHelpersScript.team_b(session)
		var slots_a: Array = session.get_deploy_slots(team_a_id)
		session.apply({
			"type": "draft_set_legion",
			"team": team_a_id,
			"coords": slots_a[0],
			"unit_type": "GOBLIN",
			"unit_count": 1,
		})
		session.apply({"type": "draft_ready", "team": team_a_id})
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i * 17
		for cmd in AiDrafter.build_draft_commands(session, team_b_id, rng):
			var result: Dictionary = session.apply(cmd)
			if not result["ok"]:
				push_error("AI draft failed in fill-bias sample: %s" % result.get("error"))
				return false
		var draft: DraftState = session.drafts[team_b_id] as DraftState
		total_legions += draft.placements.size()
		for p in draft.placements:
			total_units += int(p.unit_count)

	var avg_units_per_legion := float(total_units) / float(maxi(1, total_legions))
	if avg_units_per_legion < 2.5:
		push_error("Expected AI avg units/legion >= 2.5, got %.2f" % avg_units_per_legion)
		return false
	return true

## Impossible-style gold: keep opening stacks until almost all budget is spent.
func _test_ai_draft_spends_large_budget() -> bool:
	var AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
	var session := MinigameTestHelpersScript.prepare_session()
	session.config.budget = 200
	session.config.ai_budget_mult = 2.0
	# Rebuild drafts with the inflated AI budget.
	session.drafts.clear()
	for team_id in session.config.team_ids:
		session.drafts[team_id] = DraftState.new(team_id, session.config.budget_for_team(team_id))

	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	var ai_budget := int(session.drafts[team_b_id].remaining_budget)
	if ai_budget < 350:
		push_error("Expected large AI budget (~400), got %d" % ai_budget)
		return false

	var slots_a: Array = session.get_deploy_slots(team_a_id)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": slots_a[0],
		"unit_type": "GOBLIN",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_a_id})

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for cmd in AiDrafter.build_draft_commands(session, team_b_id, rng):
		var result: Dictionary = session.apply(cmd)
		if not result["ok"]:
			push_error("AI large-budget draft failed: %s" % result.get("error"))
			return false

	var draft: DraftState = session.drafts[team_b_id] as DraftState
	var remaining := int(draft.remaining_budget)
	var cheapest := MinigameRulesScript.unit_price("GOBLIN")
	# Allow leftover smaller than one cheapest unit (can't always spend exact).
	if remaining >= cheapest * 2:
		push_error(
			"AI should spend most of a large budget (remaining %d, budget %d, stacks %d)"
			% [remaining, ai_budget, draft.placements.size()]
		)
		return false
	if draft.placements.size() < 5:
		push_error(
			"Large budget should open many maxed stacks, got %d" % draft.placements.size()
		)
		return false
	return true
