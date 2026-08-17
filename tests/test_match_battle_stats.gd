extends RefCounted

const MatchBattleStats = preload("res://scripts/battle/match_battle_stats.gd")
const MinigameRules = preload("res://scripts/minigame/minigame_rules.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_combat_aggregation_and_gold():
		return false
	if not _test_mvp_tie_break():
		return false
	if not _test_empty_report():
		return false
	print("Success: match battle stats / end report")
	return true

func _test_combat_aggregation_and_gold() -> bool:
	var green_gob := Legion.new("GOBLIN", 4, Vector2i(0, 0), "GREEN")
	var blue_gob := Legion.new("GOBLIN", 4, Vector2i(1, 0), "BLUE")
	var green_mage := Legion.new("MAGE", 2, Vector2i(0, 1), "GREEN")
	var session := _FakeSession.new([green_gob, blue_gob, green_mage])

	var stats := MatchBattleStats.new()
	stats.begin(session)

	# Goblin deals 10 to blue goblin; mage deals 5; blue goblin deals 3 back to green goblin.
	stats.record_apply(_combat_result([
		_hit(green_gob, blue_gob, 10.0),
		_hit(green_mage, blue_gob, 5.0),
		_hit(blue_gob, green_gob, 3.0),
	]))

	# Simulate losses: green goblin 4→2, blue wiped, mage untouched.
	while green_gob.units.size() > 2:
		green_gob.units.pop_back()
	blue_gob.units.clear()

	var report := stats.build_report("GREEN")
	if report.is_empty():
		push_error("Expected non-empty report")
		return false

	var by_type: Array = report.get("by_type", [])
	if by_type.size() != 2:
		push_error("Expected Goblin + Mage type rows, got %d" % by_type.size())
		return false

	var goblin_row: Dictionary = {}
	var mage_row: Dictionary = {}
	for row in by_type:
		match String(row.get("unit_type", "")):
			"GOBLIN":
				goblin_row = row
			"MAGE":
				mage_row = row
	if goblin_row.is_empty() or mage_row.is_empty():
		push_error("Missing type rows in report")
		return false

	if int(goblin_row["green_lost"]) != 2 or int(goblin_row["green_start"]) != 4:
		push_error("Green goblin losses expected 2/4")
		return false
	if int(goblin_row["blue_lost"]) != 4 or int(goblin_row["blue_start"]) != 4:
		push_error("Blue goblin losses expected 4/4")
		return false
	if int(mage_row["green_lost"]) != 0 or int(mage_row["green_start"]) != 2:
		push_error("Green mage should be intact 0/2")
		return false
	if int(mage_row["blue_start"]) != 0:
		push_error("Blue should have no mage start")
		return false

	var gob_price := MinigameRules.unit_price("GOBLIN")
	var expected_green_gold := 2 * gob_price
	var expected_blue_gold := 4 * gob_price
	if int(report["green_gold_lost"]) != expected_green_gold:
		push_error("Green gold lost expected %d got %d" % [expected_green_gold, int(report["green_gold_lost"])])
		return false
	if int(report["blue_gold_lost"]) != expected_blue_gold:
		push_error("Blue gold lost expected %d got %d" % [expected_blue_gold, int(report["blue_gold_lost"])])
		return false
	if int(report["wiped_blue"]) != 1 or int(report["wiped_green"]) != 0:
		push_error("Expected wiped stacks green=0 blue=1")
		return false

	var mvp: Dictionary = report.get("mvp", {})
	if String(mvp.get("unit_type", "")) != "GOBLIN" or String(mvp.get("team", "")) != "GREEN":
		push_error("MVP should be green goblin (10 dmg), got %s" % str(mvp))
		return false
	if not is_equal_approx(float(mvp.get("damage_dealt", 0.0)), 10.0):
		push_error("MVP damage dealt expected 10, got %s" % mvp.get("damage_dealt"))
		return false
	if not is_equal_approx(float(mvp.get("damage_received", 0.0)), 3.0):
		push_error("MVP damage received expected 3")
		return false

	var csv := stats.legion_rows_for_csv(0, "GREEN")
	if csv.size() != 3:
		push_error("CSV should have 3 legion rows")
		return false
	return true

func _test_mvp_tie_break() -> bool:
	var a := Legion.new("GOBLIN", 2, Vector2i(0, 0), "GREEN")
	var b := Legion.new("GOBLIN", 2, Vector2i(1, 0), "BLUE")
	var c := Legion.new("ARCHER", 2, Vector2i(0, 1), "GREEN")
	var stats := MatchBattleStats.new()
	stats.begin(_FakeSession.new([a, b, c]))

	# Both green stacks deal 20; archer took less → better net → MVP.
	stats.record_apply(_combat_result([
		_hit(a, b, 20.0),
		_hit(c, b, 20.0),
		_hit(b, a, 8.0),
		_hit(b, c, 2.0),
	]))

	var report := stats.build_report("GREEN")
	var mvp: Dictionary = report.get("mvp", {})
	if String(mvp.get("unit_type", "")) != "ARCHER":
		push_error("Tie-break MVP should be Archer (same dealt, less taken), got %s" % str(mvp))
		return false
	return true

func _test_empty_report() -> bool:
	var stats := MatchBattleStats.new()
	var report := stats.build_report("GREEN")
	if not report.is_empty():
		push_error("Empty tracker should yield empty report")
		return false
	# Smoke: empty report dict is safe for UI contract.
	if report.has("by_type"):
		push_error("Empty report should not have by_type")
		return false
	return true

func _hit(attacker: Legion, defender: Legion, hp_lost: float) -> Dictionary:
	return {
		"attacker_legion": attacker,
		"defender_legion": defender,
		"hp_lost": hp_lost,
	}

func _combat_result(hits: Array) -> Dictionary:
	return {
		"ok": true,
		"events": ["combat_resolved"],
		"payload": {"combat": {"hits": hits}},
	}

class _FakeSession:
	var legions: Array = []

	func _init(legs: Array) -> void:
		legions = legs
