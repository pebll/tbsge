class_name AiEvolveHistory
extends RefCounted

## Load evolve run history + build series for plots / summaries.

const AiArchiveStore = preload("res://scripts/ai/evolution/ai_archive_store.gd")
const AiGaPopulationScript = preload("res://scripts/ai/evolution/ai_ga_population.gd")

const STAGE_IDS: Array = [
	"pass_mirror",
	"pass_random",
	"heal_mirror",
	"heal_ranged_random",
	"heal_random",
	"greedy_mirror",
	"greedy_random",
	"cascade_mirror",
	"cascade_random",
	"self_play",
]

static func load_history_rows(run_dir: String) -> Array:
	var path := AiArchiveStore.history_path(run_dir)
	if not FileAccess.file_exists(path):
		return []
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			rows.append(parsed)
	f.close()
	return rows

static func load_checkpoint(run_dir: String) -> Dictionary:
	if not AiArchiveStore.has_checkpoint(run_dir):
		return {}
	return AiArchiveStore.load_checkpoint(run_dir)

static func promotion_timeline(checkpoint: Dictionary) -> Array:
	var out: Array = [{"gen": 0, "stage_id": STAGE_IDS[0]}]
	var cur: Dictionary = checkpoint.get("curriculum", {})
	for entry in cur.get("history", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var promoted_stage := String(entry.get("stage", ""))
		var idx := STAGE_IDS.find(promoted_stage)
		if idx < 0 or idx + 1 >= STAGE_IDS.size():
			continue
		out.append({
			"gen": int(entry.get("promoted_at_gen", 0)),
			"stage_id": STAGE_IDS[idx + 1],
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("gen", 0)) < int(b.get("gen", 0))
	)
	return out

static func stage_at_gen(gen: int, timeline: Array) -> String:
	var stage_id := String(STAGE_IDS[0])
	for entry in timeline:
		if int(entry.get("gen", 0)) <= gen:
			stage_id = String(entry.get("stage_id", stage_id))
		else:
			break
	return stage_id

static func enrich_rows(rows: Array, checkpoint: Dictionary) -> Array:
	var timeline := promotion_timeline(checkpoint)
	var enriched: Array = []
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = (row as Dictionary).duplicate(true)
		var gen := int(e.get("gen", 0))
		e["inferred_stage"] = stage_at_gen(gen, timeline)
		if String(e.get("curriculum_stage", "")).is_empty():
			e["curriculum_stage"] = e["inferred_stage"]
		enriched.append(e)
	return enriched

static func slice_last_gens(rows: Array, last_n: int) -> Array:
	if last_n <= 0 or rows.is_empty():
		return rows.duplicate(true)
	var max_gen := int((rows[-1] as Dictionary).get("gen", rows.size() - 1))
	var min_gen := maxi(0, max_gen - last_n + 1)
	var out: Array = []
	for row in rows:
		if int(row.get("gen", 0)) >= min_gen:
			out.append(row)
	return out

static func build_plot_series(run_dir: String, last_n_gens: int = 0) -> Dictionary:
	var checkpoint := load_checkpoint(run_dir)
	var rows: Array = enrich_rows(load_history_rows(run_dir), checkpoint)
	if last_n_gens > 0:
		rows = slice_last_gens(rows, last_n_gens)
	var gens: Array = []
	var fitness: Array = []
	var vs_cascade: Array = []
	var vs_arena: Array = []
	var champ_wr: Array = []
	var stages: Array = []
	for row in rows:
		gens.append(int(row.get("gen", 0)))
		fitness.append(float(row.get("best_fitness", 0.0)))
		vs_cascade.append(float(row.get("vs_cascade", 0.0)))
		vs_arena.append(float(row.get("vs_arena_fitness", row.get("vs_arena", 0.0))))
		champ_wr.append(float(row.get("champ_cum_wr", row.get("curriculum_rolling_wr", 0.0))))
		stages.append(String(row.get("inferred_stage", row.get("curriculum_stage", ""))))
	return {
		"run_dir": run_dir,
		"checkpoint": checkpoint,
		"rows": rows,
		"gens": gens,
		"fitness": fitness,
		"vs_cascade": vs_cascade,
		"vs_arena": vs_arena,
		"champ_cum_wr": champ_wr,
		"stages": stages,
		"timeline": promotion_timeline(checkpoint),
	}

static func export_plot_csv(run_dir: String, out_path: String, last_n_gens: int = 0) -> bool:
	var series: Dictionary = build_plot_series(run_dir, last_n_gens)
	var rows: Array = series.get("rows", [])
	if rows.is_empty():
		return false
	var lines: PackedStringArray = PackedStringArray([
		"gen,best_fitness,vs_cascade,vs_arena_fitness,champ_cum_wr,inferred_stage,evaluations"
	])
	for row in rows:
		lines.append(
			"%d,%.6f,%.6f,%.6f,%.6f,%s,%d"
			% [
				int(row.get("gen", 0)),
				float(row.get("best_fitness", 0.0)),
				float(row.get("vs_cascade", 0.0)),
				float(row.get("vs_arena_fitness", row.get("vs_arena", 0.0))),
				float(row.get("champ_cum_wr", 0.0)),
				String(row.get("inferred_stage", "")),
				int(row.get("evaluations", 0)),
			]
		)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return true

static func plot_run(run_dir: String, last_n_gens: int = 0, out_png: String = "") -> Dictionary:
	var series: Dictionary = build_plot_series(run_dir, last_n_gens)
	if series.get("gens", []).is_empty():
		return {"ok": false, "error": "no history rows"}
	if out_png.is_empty():
		out_png = "%s/plots/evolve_history.png" % run_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/plots" % run_dir))
	var csv_path := "%s/plots/evolve_history.csv" % run_dir
	export_plot_csv(run_dir, csv_path, last_n_gens)
	var py := ProjectSettings.globalize_path("res://tools/plot_evolve_history.py")
	if not FileAccess.file_exists("res://tools/plot_evolve_history.py"):
		return {"ok": false, "error": "plot script missing", "csv": csv_path, "series": series}
	var args: PackedStringArray = PackedStringArray([py, run_dir, csv_path, out_png])
	if last_n_gens > 0:
		args.append(str(last_n_gens))
	var exit_code := OS.execute("python3", args, [], false, true)
	if exit_code != 0:
		return {"ok": false, "error": "python plot failed (exit %d)" % exit_code, "csv": csv_path, "series": series}
	return {"ok": true, "png": out_png, "csv": csv_path, "series": series}

static func weight_delta(a: Dictionary, b: Dictionary) -> Array:
	var keys: Array = []
	for k in a.keys():
		var sk := String(k)
		if not keys.has(sk):
			keys.append(sk)
	for k in b.keys():
		var sk := String(k)
		if not keys.has(sk):
			keys.append(sk)
	var rows: Array = []
	for k in keys:
		var av := float(a.get(k, 0.0))
		var bv := float(b.get(k, 0.0))
		rows.append({"name": k, "a": av, "b": bv, "delta": bv - av})
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return abs(float(x.get("delta", 0.0))) > abs(float(y.get("delta", 0.0)))
	)
	return rows

static func print_weight_delta_summary(
	label_a: String,
	weights_a: Dictionary,
	label_b: String,
	weights_b: Dictionary,
	top_n: int = 12
) -> void:
	print("=== Weight delta: %s -> %s ===" % [label_a, label_b])
	for row in weight_delta(weights_a, weights_b).slice(0, top_n):
		print(
			"  %-18s %+.3f -> %+.3f  (%+.3f)"
			% [
				String(row.get("name", "")),
				float(row.get("a", 0.0)),
				float(row.get("b", 0.0)),
				float(row.get("delta", 0.0)),
			]
		)
