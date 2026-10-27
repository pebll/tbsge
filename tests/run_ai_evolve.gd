extends SceneTree

## Headless GA evolve with checkpoint / continue / stop.
##
## Fresh:
##   ./run_ai_evolve.sh --name long1 --gens 50 --pop 12 --pairs 4
## Continue:
##   ./run_ai_evolve.sh --continue --name long1 --gens 50
## Status:
##   ./run_ai_evolve.sh --status --name long1
## Request stop (other terminal while a run is going):
##   ./run_ai_evolve.sh --request-stop --name long1

const AiArchiveStore = preload("res://scripts/ai/evolution/ai_archive_store.gd")

const DEFAULT_GENS := 10
const DEFAULT_POP := 16
const DEFAULT_PAIRS := 4
const DEFAULT_MAP := 3
const DEFAULT_BUDGET := 75
const DEFAULT_SEED := 42
const DEFAULT_ARENA_PAIRS := 2
const DEFAULT_ARENA_OPPONENTS := 3
const DEFAULT_ARENA_EVERY := 10
const DEFAULT_ELITES := 6
const DEFAULT_CORES := 2

func _initialize() -> void:
	if _wants_help():
		_print_help()
		quit(0)
		return

	var run_name := _resolve_run_name()
	var run_dir := _parse_string("--run-dir", "")
	if run_dir.is_empty() and not run_name.is_empty():
		run_dir = "%s/%s" % [AiArchiveStore.DEFAULT_ROOT, run_name]

	var needs_named := (
		_has_flag("--continue")
		or _has_flag("--status")
		or _has_flag("--request-stop")
		or _has_flag("--balance")
	)
	if run_dir.is_empty() and needs_named:
		print("ERROR: --name required for continue/status/request-stop")
		quit(2)
		return

	if _has_flag("--request-stop"):
		AiArchiveStore.request_stop(run_dir)
		print("Wrote STOP file for run '%s' (%s)" % [run_name, AiArchiveStore.stop_path(run_dir)])
		quit(0)
		return

	var runner = load("res://scripts/ai/evolution/ai_evolve_runner.gd")
	if _has_flag("--status"):
		runner.print_status(run_dir)
		quit(0)
		return
	if _has_flag("--balance"):
		runner.print_balance(run_dir)
		quit(0)
		return
	if _has_flag("--plot"):
		var plot_last := _parse_int("--last", 0)
		var plot_out := _parse_string("--plot-out", "")
		var AiEvolveHistoryScript = load("res://scripts/ai/evolution/ai_evolve_history.gd")
		if run_dir.is_empty():
			print("ERROR: --name required for --plot")
			quit(2)
			return
		var plot_result: Dictionary = AiEvolveHistoryScript.plot_run(run_dir, plot_last, plot_out)
		if bool(plot_result.get("ok", false)):
			print("Plot: %s" % plot_result.get("png", ""))
			print("CSV:  %s" % plot_result.get("csv", ""))
		else:
			print("Plot failed: %s" % plot_result.get("error", "?"))
			if plot_result.has("csv"):
				print("CSV:  %s" % plot_result.get("csv"))
		quit(0 if plot_result.get("ok", false) else 1)
		return

	var gens := _parse_int("--gens", DEFAULT_GENS)
	var pop := _parse_int("--pop", DEFAULT_POP)
	var elites := _parse_int("--elites", DEFAULT_ELITES)
	var pairs := _parse_int("--pairs", DEFAULT_PAIRS)
	var map_size := _parse_int("--map-size", DEFAULT_MAP)
	var budget := _parse_int("--budget", DEFAULT_BUDGET)
	var seed := _parse_int("--seed", DEFAULT_SEED)
	var arena_pairs := _parse_int("--arena-pairs", DEFAULT_ARENA_PAIRS)
	var arena_opponents := _parse_int("--arena-opponents", DEFAULT_ARENA_OPPONENTS)
	var arena_every := _parse_int("--arena-every", DEFAULT_ARENA_EVERY)
	var promote_every := _parse_int("--promote-every", 5)
	var checkpoint_every := _parse_int("--checkpoint-every", 1)
	var cores := _parse_int("--cores", DEFAULT_CORES)
	cores = mini(cores, maxi(1, OS.get_processor_count()))
	var continue_run := _has_flag("--continue")
	var verbose := not _has_flag("--quiet")
	var legacy_teacher := _has_flag("--legacy-teacher")
	var no_promote := _has_flag("--no-promote")
	var force_stage := _parse_string("--stage", "")
	var debug_duel := _has_flag("--debug-duel")
	var curriculum_enabled := not _has_flag("--no-curriculum")
	var persist := (
		_has_flag("--persist")
		or continue_run
		or not run_name.is_empty()
		or not run_dir.is_empty()
	)

	if persist and run_dir.is_empty():
		run_dir = AiArchiveStore.make_run_dir()
		run_name = run_dir.get_file()

	elites = mini(elites, pop)

	var cli_overrides := _cli_overrides_for_continue(continue_run, {
		"pairs": pairs,
		"pop": pop,
		"elites": elites,
		"map_size": map_size,
		"budget": budget,
		"arena_pairs": arena_pairs,
		"arena_opponents": arena_opponents,
		"arena_every": arena_every,
		"promote_every": promote_every,
		"cores": cores,
	})
	if continue_run and AiArchiveStore.has_checkpoint(run_dir):
		var ckpt: Dictionary = AiArchiveStore.load_checkpoint(run_dir)
		var ckpt_cfg: Dictionary = ckpt.get("config", {})
		if not cli_overrides.has("pairs"):
			pairs = int(ckpt_cfg.get("pairs", pairs))
		if not cli_overrides.has("pop"):
			pop = int(ckpt_cfg.get("pop", pop))
		if not cli_overrides.has("elites"):
			elites = int(ckpt_cfg.get("elites", elites))
		if not cli_overrides.has("cores"):
			cores = int(ckpt_cfg.get("cores", cores))
		elites = mini(elites, pop)

	print(
		"GA evolve: gens=%d pop=%d elites=%d pairs=%d map=%d budget=%d seed=%d arena_every=%d cores=%d curriculum=%s"
		% [gens, pop, elites, pairs, map_size, budget, seed, arena_every, cores, "on" if curriculum_enabled and not legacy_teacher else "off"]
	)
	if not run_dir.is_empty():
		var label := run_name if not run_name.is_empty() else run_dir
		print("Run: %s%s → %s" % [label, " (continue)" if continue_run else "", run_dir])
		print("Stop: ./run_ai_evolve.sh --request-stop --name %s" % label)

	var batch: Dictionary = runner.run_session({
		"gens": gens,
		"pop": pop,
		"elites": elites,
		"pairs": pairs,
		"map_size": map_size,
		"budget": budget,
		"seed": seed,
		"verbose": verbose,
		"run_dir": run_dir,
		"continue_run": continue_run,
		"arena_pairs": arena_pairs,
		"arena_opponents": arena_opponents,
		"arena_every": arena_every,
		"promote_every": promote_every,
		"checkpoint_every": checkpoint_every,
		"curriculum": curriculum_enabled,
		"legacy_teacher": legacy_teacher,
		"no_promote": no_promote,
		"force_stage": force_stage,
		"debug_duel": debug_duel,
		"cores": cores,
		"cli_overrides": cli_overrides,
	})
	runner.print_report(batch)
	quit(0)

## Prefer --name; accept --run-name as alias.
func _resolve_run_name() -> String:
	var name := _parse_string("--name", "")
	if name.is_empty():
		name = _parse_string("--run-name", "")
	return name.strip_edges()

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

func _has_option(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		var s := String(arg)
		if s == flag or s.begins_with(flag + "="):
			return true
	return false

## On --continue, only keys present on the CLI replace checkpoint config.
func _cli_overrides_for_continue(continue_run: bool, values: Dictionary) -> Dictionary:
	if not continue_run:
		return {}
	var flags := {
		"pairs": "--pairs",
		"pop": "--pop",
		"elites": "--elites",
		"map_size": "--map-size",
		"budget": "--budget",
		"arena_pairs": "--arena-pairs",
		"arena_opponents": "--arena-opponents",
		"arena_every": "--arena-every",
		"promote_every": "--promote-every",
		"cores": "--cores",
	}
	var out := {}
	for key in flags:
		if _has_option(flags[key]):
			out[key] = values[key]
	return out

func _wants_help() -> bool:
	return _has_flag("--help") or _has_flag("-h")

func _print_help() -> void:
	print("GA utility-weight evolve (headless)")
	print("")
	print("Usage:")
	print("  ./run_ai_evolve.sh --name long1 --gens 50 --pop 12 --pairs 4")
	print("  ./run_ai_evolve.sh --continue --name long1 --gens 50")
	print("  ./run_ai_evolve.sh --status --name long1")
	print("  ./run_ai_evolve.sh --balance --name long1")
	print("  ./run_ai_evolve.sh --request-stop --name long1")
	print("")
	print("Options:")
	print("  --name NAME           Run id under data/ai/evolve/NAME (preferred)")
	print("  --gens N              Generations to run now (default %d)" % DEFAULT_GENS)
	print("  --pop N               Population size (default %d)" % DEFAULT_POP)
	print("  --elites N            Elite re-eval slots per gen (default %d, capped at pop)" % DEFAULT_ELITES)
	print("  --pairs N             Mirrored pairs per fitness eval (default %d)" % DEFAULT_PAIRS)
	print("  --cores N             Parallel eval worker threads (default %d)" % DEFAULT_CORES)
	print("  --arena-pairs N       Pairs for champion vs cascade/pop (default %d)" % DEFAULT_ARENA_PAIRS)
	print("  --arena-opponents N   Pop members in arena (default %d)" % DEFAULT_ARENA_OPPONENTS)
	print("  --arena-every N       Run arena every N gens (default %d)" % DEFAULT_ARENA_EVERY)
	print("  --promote-every N     Curriculum promotion check every N gens (default 5)")
	print("  --continue            Resume from checkpoint for --name (migrates old MAP runs)")
	print("                        Omit --pairs/--pop/etc. to keep checkpoint values; pass them to override")
	print("  --status              Print checkpoint metrics and exit")
	print("  --balance             Print unit/balance report from saved EA games")
	print("  --plot                Plot fitness / win rate from history.jsonl (needs --name)")
	print("  --last N              With --plot: only last N generations (default: all)")
	print("  --plot-out PATH       With --plot: output PNG path (default RUN/plots/evolve_history.png)")
	print("  --request-stop        Write STOP so a running job exits after the current gen")
	print("  --checkpoint-every N  Save every N gens (default 1)")
	print("  --no-curriculum       Use legacy cascade teacher instead of staged bots")
	print("  --legacy-teacher      Alias for --no-curriculum")
	print("  --stage ID            Force curriculum stage (e.g. pass_mirror, cascade_random)")
	print("  --no-promote          Stay on current stage (debug / ablation)")
	print("  --debug-duel          Trace draft failures + utility top-3 scores per legion act")
	print("  --persist             Timestamped run dir if --name omitted")
	print("  --run-dir PATH        Override path (optional; prefer --name)")
	print("  --quiet               Less logging")
	print("")
	print("Algo: generational GA (elite re-eval + tournament). Every 10 gens: interim summary.")
