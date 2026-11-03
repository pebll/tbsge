class_name AiEvolveBalanceLog
extends RefCounted

## Collects duel match/legion rows during EA and persists duel-style balance CSVs.

const AiDuelReport = preload("res://scripts/balance/ai_duel_report.gd")

const BALANCE_SUBDIR := "balance"
const SUMMARY_EVERY_GENS := 10

var match_rows: Array = []
var legion_rows: Array = []
var game_serial: int = 0
## Snapshot of best fitness at last interim print (for delta).
var last_summary_best: float = -INF
var last_summary_gen: int = 0

func balance_dir(run_dir: String) -> String:
	return "%s/%s" % [run_dir, BALANCE_SUBDIR]

func ingest_report(report: Dictionary) -> void:
	var local_map: Dictionary = {}
	for mr_any in report.get("match_rows", []):
		if typeof(mr_any) != TYPE_DICTIONARY:
			continue
		var mr: Dictionary = (mr_any as Dictionary).duplicate(true)
		var local_id := int(mr.get("game_id", 0))
		game_serial += 1
		local_map[local_id] = game_serial
		mr["game_id"] = game_serial
		match_rows.append(mr)
	for lr_any in report.get("legion_rows", []):
		if typeof(lr_any) != TYPE_DICTIONARY:
			continue
		var lr: Dictionary = (lr_any as Dictionary).duplicate(true)
		var local_id := int(lr.get("game_id", 0))
		if local_map.has(local_id):
			lr["game_id"] = int(local_map[local_id])
		else:
			game_serial += 1
			lr["game_id"] = game_serial
		legion_rows.append(lr)

func save(run_dir: String) -> Dictionary:
	if run_dir.is_empty():
		return {}
	var out := balance_dir(run_dir)
	return AiDuelReport.write_csvs(out, {
		"match_rows": match_rows,
		"legion_rows": legion_rows,
	})

func load_from_dir(run_dir: String) -> void:
	match_rows.clear()
	legion_rows.clear()
	game_serial = 0
	if run_dir.is_empty():
		return
	var dir := balance_dir(run_dir)
	var matches_path := "%s/matches.csv" % dir
	var legions_path := "%s/legions.csv" % dir
	if FileAccess.file_exists(matches_path):
		match_rows = _read_matches_csv(matches_path)
	if FileAccess.file_exists(legions_path):
		legion_rows = _read_legions_csv(legions_path)
	for mr in match_rows:
		game_serial = maxi(game_serial, int(mr.get("game_id", 0)))
	for lr in legion_rows:
		game_serial = maxi(game_serial, int(lr.get("game_id", 0)))

func to_batch_dict() -> Dictionary:
	var games := match_rows.size()
	var total_turns := 0
	var timeouts := 0
	var draws := 0
	for mr in match_rows:
		total_turns += int(mr.get("team_turns", 0))
		if bool(mr.get("timed_out", false)):
			timeouts += 1
		if (
			bool(mr.get("stale_draw", false))
			or bool(mr.get("timed_out", false))
			or String(mr.get("winner", "")).is_empty()
		):
			draws += 1
	return {
		"games": games,
		"pair_count": games,
		"total_turns": total_turns,
		"timeouts": timeouts,
		"draws": draws,
		"match_rows": match_rows,
		"legion_rows": legion_rows,
		"brain_a": "evolve",
		"brain_b": "mixed",
		"mirror": true,
		"map_size": 0,
		"budget": 0,
		"elapsed_ms": 0,
		"green_wins": 0,
		"blue_wins": 0,
		"brain_a_wins": 0,
		"brain_b_wins": 0,
	}

func print_full_balance_report(run_dir: String = "") -> void:
	var batch := to_batch_dict()
	var csv_paths := {}
	if not run_dir.is_empty():
		csv_paths = {
			"matches": "%s/matches.csv" % balance_dir(run_dir),
			"legions": "%s/legions.csv" % balance_dir(run_dir),
		}
	print("")
	print("=== Evolve balance (unit / draft stats from EA games) ===")
	print(
		"Matches: %d | Draws: %d | Timeouts: %d | Avg turns: %.1f"
		% [
			int(batch["games"]),
			int(batch["draws"]),
			int(batch["timeouts"]),
			float(batch["total_turns"]) / float(maxi(int(batch["games"]), 1)),
		]
	)
	AiDuelReport.print_unit_stats_section(batch)
	if not csv_paths.is_empty():
		print("")
		print("CSV:")
		for key in csv_paths.keys():
			print("  %s: %s" % [key, csv_paths[key]])

func print_interim_balance_insights() -> void:
	var batch := to_batch_dict()
	var games := int(batch.get("games", 0))
	if games <= 0:
		print("  Balance: (no matches yet)")
		return
	print(
		"  Balance: matches=%d draws=%d (%.0f%%) avg_turns=%.1f"
		% [
			games,
			int(batch["draws"]),
			100.0 * float(batch["draws"]) / float(maxi(games, 1)),
			float(batch["total_turns"]) / float(maxi(games, 1)),
		]
	)
	AiDuelReport.print_unit_highlights(batch, mini(5, maxi(1, int(round(float(games) * 0.03)))))

static func should_print_summary(generations_completed: int) -> bool:
	return generations_completed > 0 and generations_completed % SUMMARY_EVERY_GENS == 0

func _read_matches_csv(path: String) -> Array:
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return rows
	var header := true
	var cols: PackedStringArray = PackedStringArray()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		if header:
			cols = parts
			header = false
			continue
		var row := {}
		for i in range(mini(cols.size(), parts.size())):
			row[String(cols[i])] = _parse_csv_cell(String(parts[i]))
		rows.append(row)
	f.close()
	return rows

func _read_legions_csv(path: String) -> Array:
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return rows
	var header := true
	var cols: PackedStringArray = PackedStringArray()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		if header:
			cols = parts
			header = false
			continue
		var row := {}
		for i in range(mini(cols.size(), parts.size())):
			row[String(cols[i])] = _parse_csv_cell(String(parts[i]))
		# Reconstruct start_coords for aggregation compatibility.
		if row.has("start_x") and row.has("start_y"):
			row["start_coords"] = Vector2i(int(row["start_x"]), int(row["start_y"]))
		if row.has("team_won"):
			row["team_won"] = _as_bool(row["team_won"])
		rows.append(row)
	f.close()
	return rows

static func _parse_csv_cell(text: String) -> Variant:
	if text == "true":
		return true
	if text == "false":
		return false
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return float(text)
	return text

static func _as_bool(v: Variant) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	return String(v).to_lower() in ["true", "1", "yes"]
