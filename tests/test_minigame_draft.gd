extends RefCounted

const MinigameSession = preload("res://scripts/minigame/minigame_session.gd")
const MinigameConfig = preload("res://scripts/minigame/minigame_config.gd")
const DraftState = preload("res://scripts/minigame/draft_state.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_budget_and_validation():
		return false
	if not _test_hidden_opponent_draft():
		return false
	if not _test_both_ready_starts_battle():
		return false
	print("Success: Minigame draft tests")
	return true

func _load_config():
	return load("res://data/minigame/duel_r3.tres") as MinigameConfig

func _test_budget_and_validation() -> bool:
	var session := MinigameSession.new(_load_config())
	var slots: Array = session.get_deploy_slots("GREEN")
	if slots.is_empty():
		push_error("Expected GREEN deploy slots")
		return false
	var coords: Vector2i = slots[0]

	var too_many := session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": coords,
		"unit_type": "ARCHER",
		"unit_count": 9,
	})
	if too_many["ok"]:
		push_error("Expected failure when exceeding legion size")
		return false

	var ok := session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": coords,
		"unit_type": "ARCHER",
		"unit_count": 4,
	})
	if not ok["ok"]:
		push_error("Expected valid archer placement: %s" % ok["error"])
		return false

	var draft = session.drafts["GREEN"] as DraftState
	if draft.remaining_budget != 50 - 12:
		push_error("Expected remaining budget 38, got %d" % draft.remaining_budget)
		return false

	var overspend := session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": slots[1],
		"unit_type": "OGRE",
		"unit_count": 4,
	})
	if overspend["ok"]:
		push_error("Expected overspend failure")
		return false
	return true

func _test_hidden_opponent_draft() -> bool:
	var session := MinigameSession.new(_load_config())
	var green_slots: Array = session.get_deploy_slots("GREEN")
	session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": green_slots[0],
		"unit_type": "MAGE",
		"unit_count": 2,
	})

	var blue_view := session.get_view_state("BLUE")
	var opponent: Dictionary = blue_view.get("opponent_GREEN", {})
	if opponent.has("placements"):
		push_error("Opponent draft details should be hidden")
		return false
	if int(opponent.get("slots_used", -1)) != 1:
		push_error("Opponent slots_used should be 1")
		return false
	return true

func _test_both_ready_starts_battle() -> bool:
	var session := MinigameSession.new(_load_config())
	var green_slots: Array = session.get_deploy_slots("GREEN")
	var blue_slots: Array = session.get_deploy_slots("BLUE")

	session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": green_slots[0],
		"unit_type": "ARCHER",
		"unit_count": 3,
	})
	var green_ready := session.apply({"type": "draft_ready", "team": "GREEN"})
	if not green_ready["ok"]:
		push_error("GREEN ready failed: %s" % green_ready["error"])
		return false
	if session.phase != MinigameSession.Phase.DRAFT:
		push_error("Expected draft to continue for BLUE")
		return false

	session.apply({
		"type": "draft_set_legion",
		"team": "BLUE",
		"coords": blue_slots[0],
		"unit_type": "AXEMAN",
		"unit_count": 2,
	})
	var blue_ready := session.apply({"type": "draft_ready", "team": "BLUE"})
	if not blue_ready["ok"]:
		push_error("BLUE ready failed: %s" % blue_ready["error"])
		return false
	if session.phase != MinigameSession.Phase.BATTLE:
		push_error("Expected battle phase after both ready")
		return false
	if session.legions.size() != 2:
		push_error("Expected 2 legions on board")
		return false
	return true
