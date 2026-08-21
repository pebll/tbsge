extends SceneTree

## Headless AI vs AI bulk runner.
## Usage:
##   ./run_ai_duel.sh [--games N] [--map-size 3|4|5] [--budget N]
##     [--brain-a cascade] [--brain-b cascade] [--no-mirror] [--verbose] [--out-dir PATH]

const DEFAULT_GAMES := 100
const DEFAULT_MAP_SIZE := 3
const DEFAULT_BUDGET := 75
const DEFAULT_BRAIN := "cascade"

func _initialize() -> void:
	if _wants_help():
		_print_help()
		quit(0)
		return

	var games := _parse_int("--games", DEFAULT_GAMES)
	var map_size := _parse_int("--map-size", DEFAULT_MAP_SIZE)
	var budget := _parse_int("--budget", DEFAULT_BUDGET)
	var brain_a := _parse_string("--brain-a", DEFAULT_BRAIN)
	var brain_b := _parse_string("--brain-b", DEFAULT_BRAIN)
	var mirror := not _has_flag("--no-mirror")
	var verbose := _has_flag("--verbose")
	var out_dir := _parse_string("--out-dir", "")

	var runner = load("res://scripts/balance/ai_duel_runner.gd")
	var report = load("res://scripts/balance/ai_duel_report.gd")
	if out_dir.is_empty():
		out_dir = report.make_run_dir()
	var batch: Dictionary = runner.run_batch(
		games, map_size, budget, verbose, out_dir, brain_a, brain_b, mirror
	)
	runner.print_report(batch)
	quit(0)

func _parse_string(flag: String, default_value: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg := String(args[i])
		if arg == flag and i + 1 < args.size():
			return String(args[i + 1])
		if arg.begins_with(flag + "="):
			return arg.substr(flag.length() + 1)
	return default_value

func _parse_int(flag: String, default_value: int) -> int:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg := String(args[i])
		if arg == flag and i + 1 < args.size():
			return maxi(1, int(args[i + 1]))
		if arg.begins_with(flag + "="):
			return maxi(1, int(arg.substr(flag.length() + 1)))
	return default_value

func _has_flag(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if String(arg) == flag:
			return true
	return false

func _wants_help() -> bool:
	return _has_flag("--help") or _has_flag("-h")

func _print_help() -> void:
	print("AI vs AI bulk duel runner (headless)")
	print("")
	print("Usage:")
	print("  ./run_ai_duel.sh [--games N] [--map-size 3|4|5] [--budget N]")
	print("    [--brain-a ID] [--brain-b ID] [--no-mirror] [--verbose] [--out-dir PATH]")
	print("")
	print("Options:")
	print("  --games N      Seed scenarios to run (default: %d)" % DEFAULT_GAMES)
	print("                 With mirror (default), each seed plays twice with brains swapped.")
	print("  --map-size N   Hex map radius (default: %d)" % DEFAULT_MAP_SIZE)
	print("  --budget N     Gold per side (default: %d)" % DEFAULT_BUDGET)
	print("  --brain-a ID   Brain on side A (default: %s)" % DEFAULT_BRAIN)
	print("  --brain-b ID   Brain on side B (default: %s)" % DEFAULT_BRAIN)
	print("  --no-mirror    Disable seat-swap rematch (one match per seed)")
	print("  --verbose      Print per-match results")
	print("  --out-dir PATH Folder for matches.csv + legions.csv (default: data/ai_duel/run_<timestamp>)")
	print("  --help         Show this help")
	print("")
	print("Known brains: cascade, utility")
