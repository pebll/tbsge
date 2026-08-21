class_name AiDuelReport
extends RefCounted

## CSV export + console summary for headless AI vs AI batches.
## Unit metrics are per legion appearance (not per game) so draft frequency does not skew rates.

const DEFAULT_OUT_ROOT := "res://data/ai_duel"

static func write_csvs(out_dir: String, batch: Dictionary) -> Dictionary:
	var paths := {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var match_path := "%s/matches.csv" % out_dir
	var legion_path := "%s/legions.csv" % out_dir
	_write_matches_csv(match_path, batch.get("match_rows", []))
	_write_legions_csv(legion_path, batch.get("legion_rows", []))
	paths["matches"] = match_path
	paths["legions"] = legion_path
	return paths

static func print_extended_report(batch: Dictionary, csv_paths: Dictionary = {}) -> void:
	print("")
	print("=== AI vs AI Duel Report ===")
	var games: int = int(batch.get("games", 0))
	var pair_count: int = int(batch.get("pair_count", games))
	var total_turns: int = int(batch.get("total_turns", 0))
	var avg_turns := float(total_turns) / float(maxi(games, 1))
	var elapsed_ms: int = int(batch.get("elapsed_ms", 0))
	var brain_a := String(batch.get("brain_a", "cascade"))
	var brain_b := String(batch.get("brain_b", "cascade"))
	print("Brains: %s vs %s | Mirror: %s" % [
		brain_a,
		brain_b,
		"yes" if bool(batch.get("mirror", false)) else "no",
	])
	print("Seeds: %d | Matches: %d | Map size: %d | Budget: %d | Wall time: %.2fs" % [
		pair_count,
		games,
		int(batch.get("map_size", 0)),
		int(batch.get("budget", 0)),
		float(elapsed_ms) / 1000.0,
	])
	print("%s wins: %d (%d%%) | %s wins: %d (%d%%) | Draws: %d (%d%%)" % [
		brain_a, int(batch.get("brain_a_wins", 0)), _pct(int(batch.get("brain_a_wins", 0)), games),
		brain_b, int(batch.get("brain_b_wins", 0)), _pct(int(batch.get("brain_b_wins", 0)), games),
		int(batch.get("draws", 0)), _pct(int(batch.get("draws", 0)), games),
	])
	if batch.has("brain_a_pair_score"):
		var pair_score := float(batch.get("brain_a_pair_score", 0.0))
		var max_per_pair := 2.0 if bool(batch.get("mirror", false)) else 1.0
		print(
			"Mirrored pair score (%s): %.3f / %.1f (win-rate equiv %.1f%%)"
			% [brain_a, pair_score, max_per_pair, 100.0 * pair_score / max_per_pair]
		)
	print("Seat bias — GREEN wins: %d (%d%%) | BLUE wins: %d (%d%%)" % [
		int(batch.get("green_wins", 0)), _pct(int(batch.get("green_wins", 0)), games),
		int(batch.get("blue_wins", 0)), _pct(int(batch.get("blue_wins", 0)), games),
	])
	print("Avg team turns: %.1f | Timeouts: %d" % [avg_turns, int(batch.get("timeouts", 0))])

	if not csv_paths.is_empty():
		print("")
		print("CSV output:")
		for key in csv_paths.keys():
			print("  %s: %s" % [key, csv_paths[key]])

	var unit_stats: Array = _aggregate_unit_stats(batch.get("legion_rows", []))
	if unit_stats.is_empty():
		print("")
		print("(No legion-level stats — no completed battles.)")
		return

	var min_apps := maxi(1, int(round(float(games) * 0.05)))
	print("")
	print("--- Unit type stats (per legion appearance; relative to pick rate) ---")
	print(_pad_row(["Unit", "Apps", "Team win%", "Dmg dealt", "Dmg taken", "Survival%"], [16, 6, 10, 10, 10, 10]))
	for row in unit_stats:
		print(_pad_row([
			String(row["unit_type"]),
			str(int(row["appearances"])),
			"%.1f" % float(row["team_win_rate"] * 100.0),
			"%.1f" % float(row["avg_damage_dealt"]),
			"%.1f" % float(row["avg_damage_received"]),
			"%.1f" % float(row["avg_survival"] * 100.0),
		], [16, 6, 10, 10, 10, 10]))

	var filtered: Array = []
	for row in unit_stats:
		if int(row["appearances"]) >= min_apps:
			filtered.append(row)

	print("")
	print("--- Highlights (min %d appearances) ---" % min_apps)
	if filtered.is_empty():
		filtered = unit_stats
	_print_highlight(filtered, "Highest team win rate", "team_win_rate", true)
	_print_highlight(filtered, "Lowest team win rate", "team_win_rate", false)
	_print_highlight(filtered, "Most avg damage dealt", "avg_damage_dealt", true)
	_print_highlight(filtered, "Most avg damage taken", "avg_damage_received", true)
	_print_highlight(filtered, "Best survival", "avg_survival", true)

static func make_run_dir(root: String = DEFAULT_OUT_ROOT) -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var dir := "%s/run_%s" % [root, stamp]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	return dir

static func _aggregate_unit_stats(legion_rows: Array) -> Array:
	var by_type: Dictionary = {}
	for row in legion_rows:
		var unit_type := String(row.get("unit_type", ""))
		if unit_type.is_empty():
			continue
		if not by_type.has(unit_type):
			by_type[unit_type] = {
				"unit_type": unit_type,
				"appearances": 0,
				"team_wins": 0,
				"damage_dealt_sum": 0.0,
				"damage_received_sum": 0.0,
				"survival_sum": 0.0,
			}
		var bucket: Dictionary = by_type[unit_type]
		bucket["appearances"] = int(bucket["appearances"]) + 1
		if bool(row.get("team_won", false)):
			bucket["team_wins"] = int(bucket["team_wins"]) + 1
		bucket["damage_dealt_sum"] = float(bucket["damage_dealt_sum"]) + float(row.get("damage_dealt", 0))
		bucket["damage_received_sum"] = float(bucket["damage_received_sum"]) + float(row.get("damage_received", 0))
		var start_u := maxi(1, int(row.get("start_units", 1)))
		var end_u := int(row.get("end_units", 0))
		bucket["survival_sum"] = float(bucket["survival_sum"]) + float(end_u) / float(start_u)

	var out: Array = []
	for unit_type in by_type.keys():
		var b: Dictionary = by_type[unit_type]
		var apps := maxi(1, int(b["appearances"]))
		out.append({
			"unit_type": unit_type,
			"appearances": apps,
			"team_win_rate": float(b["team_wins"]) / float(apps),
			"avg_damage_dealt": float(b["damage_dealt_sum"]) / float(apps),
			"avg_damage_received": float(b["damage_received_sum"]) / float(apps),
			"avg_survival": float(b["survival_sum"]) / float(apps),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["unit_type"]) < String(b["unit_type"])
	)
	return out

static func _print_highlight(rows: Array, title: String, field: String, higher_is_better: bool) -> void:
	if rows.is_empty():
		return
	var best: Dictionary = rows[0]
	for row in rows:
		var v := float(row.get(field, 0.0))
		var bv := float(best.get(field, 0.0))
		if higher_is_better and v > bv:
			best = row
		elif not higher_is_better and v < bv:
			best = row
	print("  %s: %s (n=%d)" % [
		title,
		String(best["unit_type"]),
		int(best["appearances"]),
	])

static func _write_matches_csv(path: String, rows: Array) -> void:
	var headers := [
		"game_id", "pair_index", "mirror_index", "a_is_green",
		"brain_a", "brain_b", "green_brain", "blue_brain",
		"map_size", "budget", "map_seed", "combat_seed",
		"team_turns", "elapsed_ms", "winner", "timed_out",
		"survivors_green", "survivors_blue",
		"green_legions", "blue_legions",
		"green_draft", "blue_draft",
	]
	var lines: PackedStringArray = [_csv_line(headers)]
	for row in rows:
		lines.append(_csv_line([
			row.get("game_id", 0),
			row.get("pair_index", 0),
			row.get("mirror_index", 0),
			row.get("a_is_green", true),
			row.get("brain_a", ""),
			row.get("brain_b", ""),
			row.get("green_brain", ""),
			row.get("blue_brain", ""),
			row.get("map_size", 0),
			row.get("budget", 0),
			row.get("map_seed", 0),
			row.get("combat_seed", 0),
			row.get("team_turns", 0),
			row.get("elapsed_ms", 0),
			row.get("winner", ""),
			row.get("timed_out", false),
			row.get("survivors_green", 0),
			row.get("survivors_blue", 0),
			row.get("green_legions", 0),
			row.get("blue_legions", 0),
			row.get("green_draft", ""),
			row.get("blue_draft", ""),
		]))
	_write_text(path, "\n".join(lines) + "\n")

static func _write_legions_csv(path: String, rows: Array) -> void:
	var headers := [
		"game_id", "legion_id", "team", "unit_type",
		"start_x", "start_y", "start_units", "end_units",
		"damage_dealt", "damage_received", "team_won",
	]
	var lines: PackedStringArray = [_csv_line(headers)]
	for row in rows:
		var coords: Vector2i = row.get("start_coords", Vector2i.ZERO)
		lines.append(_csv_line([
			row.get("game_id", 0),
			row.get("legion_id", ""),
			row.get("team", ""),
			row.get("unit_type", ""),
			coords.x,
			coords.y,
			row.get("start_units", 0),
			row.get("end_units", 0),
			"%.2f" % float(row.get("damage_dealt", 0)),
			"%.2f" % float(row.get("damage_received", 0)),
			row.get("team_won", false),
		]))
	_write_text(path, "\n".join(lines) + "\n")

static func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write %s" % path)
		return
	file.store_string(text)
	file.close()

static func _csv_line(values: Array) -> String:
	var parts: PackedStringArray = []
	for v in values:
		parts.append(_csv_cell(v))
	return ",".join(parts)

static func _csv_cell(value: Variant) -> String:
	var text := str(value)
	if text.find(",") >= 0 or text.find("\"") >= 0 or text.find("\n") >= 0:
		return '"%s"' % text.replace("\"", "\"\"")
	return text

static func _pct(count: int, total: int) -> int:
	if total <= 0:
		return 0
	return int(round(float(count) / float(total) * 100.0))

static func _pad_row(cols: Array, widths: Array) -> String:
	var parts: PackedStringArray = []
	for i in range(cols.size()):
		var w: int = int(widths[i]) if i < widths.size() else 8
		var text := String(cols[i])
		if text.length() >= w:
			parts.append(text.substr(0, w))
		else:
			parts.append(text + " ".repeat(w - text.length()))
	return "  ".join(parts)
