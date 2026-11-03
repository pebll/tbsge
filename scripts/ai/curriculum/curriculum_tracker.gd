class_name CurriculumTracker
extends RefCounted

## Curriculum stage index + promotion history + hall-of-fame.

const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const SelfScript = preload("res://scripts/ai/curriculum/curriculum_tracker.gd")

var stage_index: int = 0
var history: Array = []
var last_promote_audit: Dictionary = {}
var rehearsal_stage_indices: Array = []
var hall_of_fame: Array = []
var promotions_blocked: bool = false

func should_promote(_stage: Dictionary) -> bool:
	if promotions_blocked:
		return false
	if last_promote_audit.is_empty():
		return false
	return bool(last_promote_audit.get("promotion_passed", false))

func set_last_promote_audit(audit: Dictionary) -> void:
	last_promote_audit = audit.duplicate(true)
	_sync_rehearsal_focus()

func _sync_rehearsal_focus() -> void:
	rehearsal_stage_indices.clear()
	var retention: Dictionary = last_promote_audit.get("retention", {})
	for row in retention.get("stages", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if bool((row as Dictionary).get("passed", true)):
			continue
		rehearsal_stage_indices.append(int((row as Dictionary).get("stage_index", -1)))
	rehearsal_stage_indices = rehearsal_stage_indices.filter(func(i: int) -> bool: return i >= 0)

func rehearsal_stages_worst_first() -> Array[int]:
	var rows: Array = []
	var retention: Dictionary = last_promote_audit.get("retention", {})
	for row in retention.get("stages", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if bool(d.get("passed", true)):
			continue
		rows.append(d)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("win_rate", 0.0)) < float(b.get("win_rate", 0.0))
	)
	var out: Array[int] = []
	for row in rows:
		out.append(int(row.get("stage_index", -1)))
	if out.is_empty():
		for idx in rehearsal_stage_indices:
			out.append(int(idx))
	return out

func promote(stage_id: String, at_gen: int, win_rate: float) -> void:
	history.append({
		"stage": stage_id,
		"promoted_at_gen": at_gen,
		"win_rate": win_rate,
		"games": int(last_promote_audit.get("audit_games", 0)),
		"audit": last_promote_audit.duplicate(true),
	})
	stage_index += 1
	last_promote_audit = {}
	rehearsal_stage_indices.clear()

func add_hall_of_fame(genome: AiGenome, stage_id: String, at_gen: int) -> void:
	if genome == null:
		return
	hall_of_fame.append({
		"gen": at_gen,
		"stage": stage_id,
		"weights": genome.weights.duplicate(true),
	})
	while hall_of_fame.size() > 8:
		hall_of_fame.pop_front()

func random_hof_genome(rng: RandomNumberGenerator) -> AiGenome:
	if hall_of_fame.is_empty():
		return null
	var entry: Dictionary = hall_of_fame[rng.randi() % hall_of_fame.size()]
	var g := AiGenomeScript.new()
	g.weights = (entry.get("weights", {}) as Dictionary).duplicate(true)
	return g

func to_dict() -> Dictionary:
	return {
		"stage_index": stage_index,
		"history": history.duplicate(true),
		"last_promote_audit": last_promote_audit.duplicate(true),
		"rehearsal_stage_indices": rehearsal_stage_indices.duplicate(),
		"hall_of_fame": hall_of_fame.duplicate(true),
		"promotions_blocked": promotions_blocked,
	}

static func from_dict(data: Dictionary):
	var t = SelfScript.new()
	t.stage_index = int(data.get("stage_index", 0))
	t.history = (data.get("history", []) as Array).duplicate(true)
	t.last_promote_audit = (data.get("last_promote_audit", {}) as Dictionary).duplicate(true)
	t.rehearsal_stage_indices = (data.get("rehearsal_stage_indices", []) as Array).duplicate()
	if t.rehearsal_stage_indices.is_empty() and not t.last_promote_audit.is_empty():
		t._sync_rehearsal_focus()
	t.hall_of_fame = (data.get("hall_of_fame", []) as Array).duplicate(true)
	t.promotions_blocked = bool(data.get("promotions_blocked", false))
	return t
