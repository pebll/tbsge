extends RefCounted

const BalanceArmyPlanner = preload("res://scripts/balance/balance_army_planner.gd")
const BalanceBattleRunner = preload("res://scripts/balance/balance_battle_runner.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_single_battle_completes():
		return false
	if not _test_multi_legion_planning():
		return false
	if not _test_archer_vs_goblin_battle():
		return false
	print("Success: Balance runner tests")
	return true

func _test_single_battle_completes() -> bool:
	var result: Dictionary = BalanceBattleRunner.run("GOBLIN", "OGRE", 42, 99)
	if not result.get("ok", false):
		push_error("Balance battle failed: %s" % result.get("error", "?"))
		return false
	if result.get("count_a", 0) != 20:
		push_error("Expected 20 goblins for 60 gold, got %d" % result.get("count_a", 0))
		return false
	if result.get("count_b", 0) != 6:
		push_error("Expected 6 ogres for 60 gold, got %d" % result.get("count_b", 0))
		return false
	if int(result.get("legions_a", 0)) < 2:
		push_error("Expected multiple goblin legions, got %d" % result.get("legions_a", 0))
		return false

	var winner_unit_type: String = String(result.get("winner_unit_type", ""))
	var timed_out: bool = result.get("timed_out", false)
	if winner_unit_type.is_empty() and not timed_out:
		push_error("Expected a winner or timeout")
		return false

	var swapped: Dictionary = BalanceBattleRunner.run("GOBLIN", "OGRE", 42, 100, false)
	if not swapped.get("ok", false):
		push_error("Swapped-first battle failed")
		return false
	return true

func _test_multi_legion_planning() -> bool:
	var spider_sizes := BalanceArmyPlanner.plan_legion_sizes("SPIDER", 13, 60, 12.0)
	if spider_sizes.size() != 2:
		push_error("SPIDER should use 2 maxed legions, got %s" % str(spider_sizes))
		return false
	if spider_sizes[0] != 15 or spider_sizes[1] != 5:
		push_error("SPIDER legions should be 15+5 at 60 gold, got %s" % str(spider_sizes))
		return false

	var golem_sizes := BalanceArmyPlanner.plan_legion_sizes("GOLEM", 13, 60, 12.0)
	if golem_sizes.size() != 2:
		push_error("GOLEM should use 2 legions, got %s" % str(golem_sizes))
		return false
	if golem_sizes[0] != 4 or golem_sizes[1] != 2:
		push_error("GOLEM legions should be 4+2, got %s" % str(golem_sizes))
		return false
	return true

func _test_archer_vs_goblin_battle() -> bool:
	## Exercises ranged_attack path in BalanceBattleRunner with seeded RNG.
	var result: Dictionary = BalanceBattleRunner.run("ARCHER", "GOBLIN", 7, 99)
	if not result.get("ok", false):
		push_error("ARCHER vs GOBLIN balance battle failed: %s" % result.get("error", "?"))
		return false
	var winner_unit_type: String = String(result.get("winner_unit_type", ""))
	var timed_out: bool = result.get("timed_out", false)
	if winner_unit_type.is_empty() and not timed_out:
		push_error("Expected ARCHER/GOBLIN winner or timeout")
		return false
	return true
