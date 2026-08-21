extends SceneTree

## Headless MAP-Elites evolve with checkpoint / continue / stop.
##
## Fresh:
##   ./run_ai_evolve.sh --gens 50 --pop 12 --pairs 2 --run-name long1
## Continue:
##   ./run_ai_evolve.sh --continue --run-dir res://data/ai/evolve/long1 --gens 50
## Status:
##   ./run_ai_evolve.sh --status --run-dir res://data/ai/evolve/long1
## Request stop (other terminal while a run is going):
##   ./run_ai_evolve.sh --request-stop --run-dir res://data/ai/evolve/long1

const AiArchiveStore = preload("res://scripts/ai/evolution/ai_archive_store.gd")

const DEFAULT_GENS := 10
const DEFAULT_POP := 8
const DEFAULT_PAIRS := 2
const DEFAULT_MAP := 3
const DEFAULT_BUDGET := 75
const DEFAULT_SEED := 42
const DEFAULT_ARENA_PAIRS := 2
const DEFAULT_ARENA_OPPONENTS := 3

func _initialize() -> void:
	if _wants_help():
		_print_help()
		quit(0)
		return

	var run_dir := _parse_string("--run-dir", "")
	var run_name := _parse_string("--run-name", "")
	if run_dir.is_empty() and not run_name.is_empty():
		run_dir = "%s/%s" % [AiArchiveStore.DEFAULT_ROOT, run_name]
	if run_dir.is_empty() and (_has_flag("--continue") or _has_flag("--status") or _has_flag("--request-stop")):
		print("ERROR: --run-dir or --run-name required for continue/status/request-stop")
		quit(2)
		return

	if _has_flag("--request-stop"):
		AiArchiveStore.request_stop(run_dir)
		print("Wrote STOP file: %s" % AiArchiveStore.stop_path(run_dir))
		quit(0)
		return

	var runner = load("res://scripts/ai/evolution/ai_evolve_runner.gd")
	if _has_flag("--status"):
		runner.print_status(run_dir)
		quit(0)
		return

	var gens := _parse_int("--gens", DEFAULT_GENS)
	var pop := _parse_int("--pop", DEFAULT_POP)
	var pairs := _parse_int("--pairs", DEFAULT_PAIRS)
	var map_size := _parse_int("--map-size", DEFAULT_MAP)
	var budget := _parse_int("--budget", DEFAULT_BUDGET)
	var seed := _parse_int("--seed", DEFAULT_SEED)
	var arena_pairs := _parse_int("--arena-pairs", DEFAULT_ARENA_PAIRS)
	var arena_opponents := _parse_int("--arena-opponents", DEFAULT_ARENA_OPPONENTS)
	var checkpoint_every := _parse_int("--checkpoint-every", 1)
	var continue_run := _has_flag("--continue")
	var verbose := not _has_flag("--quiet")
	var persist := _has_flag("--persist") or continue_run or not run_name.is_empty() or not run_dir.is_empty()

	if persist and run_dir.is_empty():
		run_dir = AiArchiveStore.make_run_dir()

	print(
		"MAP-Elites evolve: gens=%d pop=%d pairs=%d map=%d budget=%d seed=%d"
		% [gens, pop, pairs, map_size, budget, seed]
	)
	if not run_dir.is_empty():
		print("Run dir: %s%s" % [run_dir, " (continue)" if continue_run else ""])
		print("Stop: touch %s  or  ./run_ai_evolve.sh --request-stop --run-dir %s" % [
			AiArchiveStore.stop_path(run_dir), run_dir
		])

	var batch: Dictionary = runner.run_session({
		"gens": gens,
		"pop": pop,
		"pairs": pairs,
		"map_size": map_size,
		"budget": budget,
		"seed": seed,
		"verbose": verbose,
		"run_dir": run_dir,
		"continue_run": continue_run,
		"arena_pairs": arena_pairs,
		"arena_opponents": arena_opponents,
		"checkpoint_every": checkpoint_every,
	})
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
	print("MAP-Elites utility-weight evolve (headless)")
	print("")
	print("Usage:")
	print("  ./run_ai_evolve.sh --gens 50 --pop 12 --pairs 2 --run-name long1")
	print("  ./run_ai_evolve.sh --continue --run-dir res://data/ai/evolve/long1 --gens 50")
	print("  ./run_ai_evolve.sh --status --run-dir res://data/ai/evolve/long1")
	print("  ./run_ai_evolve.sh --request-stop --run-dir res://data/ai/evolve/long1")
	print("")
	print("Options:")
	print("  --gens N              Generations to run now (default %d)" % DEFAULT_GENS)
	print("  --pop N               Offspring per generation (default %d)" % DEFAULT_POP)
	print("  --pairs N             Mirrored pairs per fitness eval (default %d)" % DEFAULT_PAIRS)
	print("  --arena-pairs N       Pairs for champion vs cascade/arena (default %d)" % DEFAULT_ARENA_PAIRS)
	print("  --arena-opponents N   Archive elites in arena (default %d)" % DEFAULT_ARENA_OPPONENTS)
	print("  --run-name NAME       Persist under data/ai/evolve/NAME")
	print("  --run-dir PATH        Explicit run directory")
	print("  --persist             Force creating a timestamped run dir")
	print("  --continue            Resume from checkpoint in --run-dir")
	print("  --status              Print checkpoint metrics and exit")
	print("  --request-stop        Write STOP so a running job exits after the current gen")
	print("  --checkpoint-every N  Save every N gens (default 1)")
	print("  --quiet               Less logging")
	print("")
	print("Fitness during search: vs cascade (0..2). Debug prints champion win%% vs cascade + arena.")
