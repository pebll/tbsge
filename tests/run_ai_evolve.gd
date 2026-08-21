extends SceneTree

## Headless MAP-Elites evolve runner.
## Usage: ./run_ai_evolve.sh [--gens N] [--pop N] [--pairs N] [--map-size N] [--budget N] [--seed N] [--verbose]

const DEFAULT_GENS := 2
const DEFAULT_POP := 4
const DEFAULT_PAIRS := 1
const DEFAULT_MAP := 3
const DEFAULT_BUDGET := 75
const DEFAULT_SEED := 42

func _initialize() -> void:
	if _wants_help():
		_print_help()
		quit(0)
		return

	var gens := _parse_int("--gens", DEFAULT_GENS)
	var pop := _parse_int("--pop", DEFAULT_POP)
	var pairs := _parse_int("--pairs", DEFAULT_PAIRS)
	var map_size := _parse_int("--map-size", DEFAULT_MAP)
	var budget := _parse_int("--budget", DEFAULT_BUDGET)
	var seed := _parse_int("--seed", DEFAULT_SEED)
	var verbose := _has_flag("--verbose") or true

	var runner = load("res://scripts/ai/evolution/ai_evolve_runner.gd")
	print(
		"MAP-Elites evolve: gens=%d pop=%d pairs=%d map=%d budget=%d seed=%d"
		% [gens, pop, pairs, map_size, budget, seed]
	)
	var batch: Dictionary = runner.run(gens, pop, pairs, map_size, budget, seed, verbose)
	runner.print_report(batch)
	quit(0)

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
	print("  ./run_ai_evolve.sh [--gens N] [--pop N] [--pairs N] [--map-size N] [--budget N] [--seed N]")
	print("")
	print("Fitness: mirrored pair score vs cascade (0..2). Selection inside EA is argmax.")
