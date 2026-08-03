extends RefCounted

const TurnManager = preload("res://scripts/core/turn_manager.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_team_alternation():
		return false
	if not _test_actionable_and_wait():
		return false
	if not _test_tab_cycle():
		return false
	if not _test_clear_wait_and_end_turn_clears_waits():
		return false
	print("Success: Turn manager tests")
	return true

func _test_team_alternation() -> bool:
	var team_order: Array[String] = ["GREEN", "BLUE"]
	var tm := TurnManager.new(team_order)
	tm.start_match("GREEN")
	var g := Legion.new("GOBLIN", 1, Vector2i.ZERO, "GREEN")
	var b := Legion.new("GOBLIN", 1, Vector2i.ONE, "BLUE")
	g.current_ap = 0
	b.current_ap = 0
	var legions: Array[Legion] = [g, b]

	var next: String = tm.end_team_turn(legions)
	if next != "BLUE":
		push_error("Expected BLUE turn after GREEN")
		return false
	if b.current_ap != b.max_ap:
		push_error("BLUE legion should refresh AP")
		return false
	if g.current_ap != 0:
		push_error("GREEN legion should not refresh on BLUE turn")
		return false
	return true

func _test_actionable_and_wait() -> bool:
	var green_only: Array[String] = ["GREEN"]
	var tm := TurnManager.new(green_only)
	tm.start_match("GREEN")
	var active := Legion.new("GOBLIN", 1, Vector2i(0, 0), "GREEN")
	var spent := Legion.new("GOBLIN", 1, Vector2i(1, 0), "GREEN")
	var waited := Legion.new("GOBLIN", 1, Vector2i(2, 0), "GREEN")
	spent.current_ap = 0
	var legions: Array[Legion] = [active, spent, waited]

	var actionable := tm.get_actionable_coords(legions)
	if actionable.size() != 2:
		push_error("Expected active + waited legions with AP in actionable list")
		return false

	tm.wait_legion(Vector2i(2, 0))
	actionable = tm.get_actionable_coords(legions)
	if actionable.size() != 1 or actionable[0] != Vector2i(0, 0):
		push_error("Waited legion should be excluded from actionable list")
		return false
	return true

func _test_tab_cycle() -> bool:
	var green_only: Array[String] = ["GREEN"]
	var tm := TurnManager.new(green_only)
	tm.start_match("GREEN")
	var a := Legion.new("GOBLIN", 1, Vector2i(0, 0), "GREEN")
	var b := Legion.new("GOBLIN", 1, Vector2i(1, 0), "GREEN")
	var legions: Array[Legion] = [a, b]

	var first: Vector2i = tm.tab_next(legions)
	var second: Vector2i = tm.tab_next(legions)
	if first == TurnManager.INVALID_COORDS or second == TurnManager.INVALID_COORDS:
		push_error("tab_next should return valid coords")
		return false
	if first == second:
		push_error("tab_next should cycle between legions")
		return false
	return true

func _test_clear_wait_and_end_turn_clears_waits() -> bool:
	var teams: Array[String] = ["GREEN", "BLUE"]
	var tm := TurnManager.new(teams)
	tm.start_match("GREEN")
	var a := Legion.new("GOBLIN", 1, Vector2i(0, 0), "GREEN")
	var b := Legion.new("GOBLIN", 1, Vector2i(1, 0), "BLUE")
	a.current_ap = 0
	var legions: Array[Legion] = [a, b]

	tm.wait_legion(Vector2i(0, 0))
	tm.wait_legion(Vector2i(3, 3))
	if Vector2i(0, 0) not in tm.waited_coords:
		push_error("wait_legion should record coords")
		return false

	tm.clear_wait(Vector2i(0, 0))
	if Vector2i(0, 0) in tm.waited_coords:
		push_error("clear_wait should remove coords")
		return false
	if Vector2i(3, 3) not in tm.waited_coords:
		push_error("clear_wait should only remove the given coords")
		return false

	tm.end_team_turn(legions)
	if not tm.waited_coords.is_empty():
		push_error("end_team_turn should clear all waited coords")
		return false
	return true
