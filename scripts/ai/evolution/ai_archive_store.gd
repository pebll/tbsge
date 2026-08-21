class_name AiArchiveStore
extends RefCounted

## Persist evolve checkpoints under data/ai/evolve/<run_id>/.

const DEFAULT_ROOT := "res://data/ai/evolve"
const CHECKPOINT_NAME := "checkpoint.json"
const HISTORY_NAME := "history.jsonl"
const STOP_NAME := "STOP"
const BEST_NAME := "best_profile.json"

static func make_run_dir(root: String = DEFAULT_ROOT, run_name: String = "") -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var name := run_name.strip_edges()
	if name.is_empty():
		name = "run_%s" % stamp
	var dir := "%s/%s" % [root, name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	return dir

static func checkpoint_path(run_dir: String) -> String:
	return "%s/%s" % [run_dir, CHECKPOINT_NAME]

static func history_path(run_dir: String) -> String:
	return "%s/%s" % [run_dir, HISTORY_NAME]

static func stop_path(run_dir: String) -> String:
	return "%s/%s" % [run_dir, STOP_NAME]

static func best_path(run_dir: String) -> String:
	return "%s/%s" % [run_dir, BEST_NAME]

static func has_checkpoint(run_dir: String) -> bool:
	return FileAccess.file_exists(checkpoint_path(run_dir))

static func request_stop(run_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir))
	var f := FileAccess.open(stop_path(run_dir), FileAccess.WRITE)
	if f == null:
		push_error("Failed to write STOP at %s" % stop_path(run_dir))
		return
	f.store_string("stop requested at %s\n" % Time.get_datetime_string_from_system())
	f.close()

static func clear_stop(run_dir: String) -> void:
	var abs_path := ProjectSettings.globalize_path(stop_path(run_dir))
	if FileAccess.file_exists(stop_path(run_dir)):
		DirAccess.remove_absolute(abs_path)

static func should_stop(run_dir: String) -> bool:
	return FileAccess.file_exists(stop_path(run_dir))

static func save_checkpoint(run_dir: String, state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir))
	var path := checkpoint_path(run_dir)
	var json := JSON.stringify(state, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to write checkpoint %s" % path)
		return false
	f.store_string(json)
	f.close()
	# Best profile snapshot for easy inspection / shipping.
	var best_weights: Dictionary = state.get("best_weights", {})
	if not best_weights.is_empty():
		var bf := FileAccess.open(best_path(run_dir), FileAccess.WRITE)
		if bf:
			bf.store_string(JSON.stringify({
				"id": "evolved_best",
				"weights": best_weights,
				"fitness": state.get("best_fitness", 0.0),
				"vs_cascade": state.get("last_metrics", {}).get("vs_cascade", 0.0),
				"vs_arena": state.get("last_metrics", {}).get("vs_arena", 0.0),
			}, "\t"))
			bf.close()
	return true

static func load_checkpoint(run_dir: String) -> Dictionary:
	var path := checkpoint_path(run_dir)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to read checkpoint %s" % path)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Checkpoint JSON invalid: %s" % path)
		return {}
	return parsed

static func append_history(run_dir: String, metrics: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir))
	var path := history_path(run_dir)
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to append history %s" % path)
		return
	f.seek_end()
	f.store_line(JSON.stringify(metrics))
	f.close()
