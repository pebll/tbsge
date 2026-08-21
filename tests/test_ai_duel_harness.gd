extends RefCounted

const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const AiDuelRunner = preload("res://scripts/balance/ai_duel_runner.gd")
const CascadeBrainScript = preload("res://scripts/ai/brains/cascade_brain.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_registry_creates_cascade():
		return false
	if not _test_mirrored_pair_same_seed_drafts():
		return false
	if not _test_batch_mirror_counts():
		return false
	print("Success: AI duel harness (brains + mirror)")
	return true

func _test_registry_creates_cascade() -> bool:
	var brain: AiBrain = AiBrainRegistry.create("cascade")
	if brain == null or brain.id != "cascade":
		push_error("Expected cascade brain from registry")
		return false
	if brain.get_script() != CascadeBrainScript:
		push_error("cascade id should yield CascadeBrain script")
		return false
	return true

## Same game_index → identical drafts/map regardless of which brain sits where.
func _test_mirrored_pair_same_seed_drafts() -> bool:
	var cascade_a: AiBrain = AiBrainRegistry.create("cascade")
	var cascade_b: AiBrain = AiBrainRegistry.create("cascade")
	var r1: Dictionary = AiDuelRunner.run_one(0, 3, 75, cascade_a, cascade_b)
	var r2: Dictionary = AiDuelRunner.run_one(0, 3, 75, cascade_b, cascade_a)
	var m1: Dictionary = r1.get("match_row", {})
	var m2: Dictionary = r2.get("match_row", {})
	if int(m1.get("map_seed", -1)) != int(m2.get("map_seed", -2)):
		push_error("Mirrored runs should share map_seed")
		return false
	if String(m1.get("green_draft", "")) != String(m2.get("green_draft", "x")):
		push_error("Mirrored runs should share green draft")
		return false
	if String(m1.get("blue_draft", "")) != String(m2.get("blue_draft", "x")):
		push_error("Mirrored runs should share blue draft")
		return false
	if String(m1.get("green_brain", "")) != "cascade" or String(m2.get("green_brain", "")) != "cascade":
		push_error("Both seats use cascade in this self-play check")
		return false
	return true

func _test_batch_mirror_counts() -> bool:
	var batch: Dictionary = AiDuelRunner.run_batch(
		2, 3, 75, false, "", "cascade", "cascade", true
	)
	if int(batch.get("pair_count", 0)) != 2:
		push_error("Expected 2 pairs")
		return false
	if int(batch.get("games", 0)) != 4:
		push_error("Mirror batch should run 2 matches per pair")
		return false
	if int(batch.get("match_rows", []).size()) != 4:
		push_error("Expected 4 match rows")
		return false
	var score := float(batch.get("brain_a_pair_score", -1.0))
	# Equal brains: average points per pair in [0, 2]; self-play should land near 1.
	if score < 0.0 or score > 2.0:
		push_error("Pair score out of range: %s" % score)
		return false
	return true
