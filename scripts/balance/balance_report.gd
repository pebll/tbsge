class_name BalanceReport
extends RefCounted

const BalanceBattleRunner = preload("res://scripts/balance/balance_battle_runner.gd")

static func format(result: Dictionary) -> String:
	var lines: PackedStringArray = []
	var seeds: int = int(result.get("seeds_per_matchup", 0))
	var unit_ids: Array = result.get("unit_ids", [])
	var matchups: Array = result.get("matchups", [])

	lines.append("=== Unit Balance Report ===")
	lines.append("Budget: 60 gold per side | Map: duel r3 (real terrain) | AI: attack-nearest")
	lines.append("Armies: max-fill legions sequentially until 60 gold is spent")
	lines.append("Seeds per matchup: %d | First turn alternates per seed | Timeouts = draw" % seeds)
	lines.append("")
	lines.append(_format_army_layout(unit_ids, result.get("legion_counts", {})))
	lines.append("")

	lines.append(_format_matrix(unit_ids, matchups))
	lines.append("")
	lines.append("--- Matchup details ---")
	for summary in matchups:
		lines.append(_format_matchup_line(summary))

	return "\n".join(lines)

static func _format_matrix(unit_ids: Array, matchups: Array) -> String:
	if unit_ids.is_empty():
		return "(no units)"

	var lookup: Dictionary = {}
	for summary in matchups:
		var unit_a: String = summary["unit_a"]
		var unit_b: String = summary["unit_b"]
		lookup["%s|%s" % [unit_a, unit_b]] = summary

	var matrix_lines: PackedStringArray = []
	var col_width := 7
	var header := "        "
	for unit_b in unit_ids:
		header += _pad_short(unit_b, col_width)
	matrix_lines.append("Row unit win % (alternating first turn, timeouts = draw)")
	matrix_lines.append(header)

	for unit_a in unit_ids:
		var row := _pad_short(unit_a, 8)
		for unit_b in unit_ids:
			if unit_a == unit_b:
				row += _pad_short("-", col_width)
				continue
			var summary = lookup.get("%s|%s" % [unit_a, unit_b])
			if summary == null:
				row += _pad_short("?", col_width)
			else:
				row += _pad_short("%d%%" % int(round(summary["win_rate_a"] * 100.0)), col_width)
		matrix_lines.append(row)

	return "\n".join(matrix_lines)

static func _format_army_layout(unit_ids: Array, legion_counts: Dictionary) -> String:
	var lines: PackedStringArray = ["--- Army layout (60 gold) ---"]
	for unit_id in unit_ids:
		var count: int = BalanceBattleRunner.army_count_for_budget(unit_id) if legion_counts.has(unit_id) else 0
		var legions: int = int(legion_counts.get(unit_id, 0))
		lines.append("%s: %d units in %d legion(s)" % [unit_id, count, legions])
	return "\n".join(lines)

static func _format_matchup_line(summary: Dictionary) -> String:
	var unit_a: String = summary["unit_a"]
	var unit_b: String = summary["unit_b"]
	var count_a: int = summary["count_a"]
	var count_b: int = summary["count_b"]
	var legions_a: int = int(summary.get("legions_a", 1))
	var legions_b: int = int(summary.get("legions_b", 1))
	var wins_a: int = summary["wins_a"]
	var wins_b: int = summary["wins_b"]
	var draws: int = summary["draws"]
	var trials: int = summary["trials"]
	var avg_turns: float = summary["avg_turns"]
	var timed_out: int = summary["timed_out"]

	var line := "%s (%du/%dL) vs %s (%du/%dL): %d/%d wins (%.0f%%)" % [
		unit_a,
		count_a,
		legions_a,
		unit_b,
		count_b,
		legions_b,
		wins_a,
		trials,
		summary["win_rate_a"] * 100.0,
	]
	if wins_b > 0 or draws > 0:
		line += " | opponent %d" % wins_b
		if draws > 0:
			line += ", draws %d" % draws
	line += " | avg %.1f team turns" % avg_turns
	return line

static func _pad_short(text: String, width: int) -> String:
	if text.length() >= width:
		return text.substr(0, width)
	return text + " ".repeat(width - text.length())
