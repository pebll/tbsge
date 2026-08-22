class_name DraftScenario
extends RefCounted

## Controls how armies are drafted in headless duels / EA evals.

enum Mode {
	RANDOM,
	MIRROR_SEED,
}

const AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
const SelfScript = preload("res://scripts/ai/curriculum/draft_scenario.gd")

var mode: Mode = Mode.RANDOM

static func random():
	var s = SelfScript.new()
	s.mode = Mode.RANDOM
	return s

static func mirror_seed():
	var s = SelfScript.new()
	s.mode = Mode.MIRROR_SEED
	return s

static func from_string(raw: String):
	var key := raw.strip_edges().to_lower()
	match key:
		"mirror", "mirror_seed", "mirrored":
			return mirror_seed()
		_:
			return random()

func mode_id() -> String:
	match mode:
		Mode.MIRROR_SEED:
			return "mirror_seed"
		_:
			return "random"

## Apply draft commands for all teams. Returns error string or "" on success.
static func apply_drafts(session, team_ids: Array, rng: RandomNumberGenerator, scenario) -> String:
	if scenario == null:
		scenario = random()
	match scenario.mode:
		Mode.MIRROR_SEED:
			return _apply_mirror_seed(session, team_ids, rng)
		_:
			return _apply_random(session, team_ids, rng)

static func _apply_random(session, team_ids: Array, rng: RandomNumberGenerator) -> String:
	for team_id in team_ids:
		for cmd in AiDrafter.build_draft_commands(session, String(team_id), rng):
			var result: Dictionary = session.apply(cmd)
			if not result.get("ok", false):
				return String(result.get("error", "Draft failed for %s" % team_id))
	return ""

static func _apply_mirror_seed(session, team_ids: Array, rng: RandomNumberGenerator) -> String:
	if team_ids.size() < 2:
		return _apply_random(session, team_ids, rng)
	var green_id := String(team_ids[0])
	var blue_id := String(team_ids[1])
	for cmd in AiDrafter.build_draft_commands(session, green_id, rng):
		var result: Dictionary = session.apply(cmd)
		if not result.get("ok", false):
			return String(result.get("error", "Green draft failed"))
	var green_draft = session.drafts.get(green_id)
	if green_draft == null:
		return "Mirror draft: missing green draft state"
	var green_placements: Array = []
	for placement in green_draft.placements:
		if placement == null:
			continue
		green_placements.append({
			"unit_type": placement.unit_type,
			"unit_count": placement.unit_count,
		})
	if green_placements.is_empty():
		return "Mirror draft: green produced no legions"
	var blue_slots: Array = session.get_deploy_slots(blue_id)
	for i in range(green_placements.size()):
		if i >= blue_slots.size():
			break
		var placement: Dictionary = green_placements[i]
		var blue_cmd := {
			"type": "draft_set_legion",
			"team": blue_id,
			"coords": blue_slots[i],
			"unit_type": placement["unit_type"],
			"unit_count": placement["unit_count"],
		}
		var blue_result: Dictionary = session.apply(blue_cmd)
		if not blue_result.get("ok", false):
			return String(blue_result.get("error", "Blue mirror draft failed"))
	var ready: Dictionary = session.apply({"type": "draft_ready", "team": blue_id})
	if not ready.get("ok", false):
		return String(ready.get("error", "Blue draft_ready failed"))
	return ""
