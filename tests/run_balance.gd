extends SceneTree

const DEFAULT_SEEDS := 5

func _initialize() -> void:
	var seeds := _parse_seeds(DEFAULT_SEEDS)
	if _wants_help():
		_print_help()
		quit(0)
		return

	var simulator = load("res://scripts/balance/balance_simulator.gd")
	var result: Dictionary = simulator.run(seeds)
	simulator.print_report(result)
	quit(0)

func _parse_seeds(default_value: int) -> int:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg := String(args[i])
		if arg == "--seeds" and i + 1 < args.size():
			return maxi(1, int(args[i + 1]))
		if arg.begins_with("--seeds="):
			return maxi(1, int(arg.substr("--seeds=".length())))
	return default_value

func _wants_help() -> bool:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text in ["--help", "-h"]:
			return true
	return false

func _print_help() -> void:
	print("Unit balance tester (headless, map + AI)")
	print("")
	print("Usage:")
	print("  ./run_balance.sh [--seeds N]")
	print("")
	print("Options:")
	print("  --seeds N   Number of map seeds per matchup (default: %d)" % DEFAULT_SEEDS)
	print("  --help      Show this help")
