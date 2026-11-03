class_name AiDuelTrace
extends RefCounted

## Optional headless duel / utility-AI trace (enable via --debug-duel).

static var enabled: bool = false
static var log_utility: bool = true
static var log_draft: bool = true
static var log_match: bool = true
static var max_utility_lines_per_game: int = 24

static var _utility_lines_this_game: int = 0
static var _game_serial: int = 0

static func reset_game() -> void:
	_utility_lines_this_game = 0
	_game_serial += 1

static func draft_fail(reason: String, game_index: int = -1) -> void:
	if not enabled or not log_draft:
		return
	print("[duel-trace] game=%d DRAFT FAIL: %s" % [game_index, reason])

static func match_end(result: Dictionary, green_brain_id: String, blue_brain_id: String) -> void:
	if not enabled or not log_match:
		return
	var fail := String(result.get("fail_reason", ""))
	var turns := int(result.get("team_turns", 0))
	var winner := String(result.get("winner", ""))
	var kind := "ok"
	if not fail.is_empty():
		kind = "fail"
	elif bool(result.get("stale_draw", false)):
		kind = "stale"
	elif bool(result.get("timed_out", false)):
		kind = "timeout"
	elif winner.is_empty():
		kind = "draw"
	print(
		"[duel-trace] game=%d %s | %s vs %s | turns=%d winner=%s g=%.0f/%.0f gold%s"
		% [
			int(result.get("game_index", -1)),
			kind,
			green_brain_id,
			blue_brain_id,
			turns,
			winner if not winner.is_empty() else "-",
			float(result.get("gold_start_green", 0.0)),
			float(result.get("gold_start_blue", 0.0)),
			(" | " + fail) if not fail.is_empty() else "",
		]
	)

static func utility_decision(
	team_id: String,
	coords: Vector2i,
	chosen: Dictionary,
	top_scored: Array,
	legion: Legion
) -> void:
	if not enabled or not log_utility:
		return
	if _utility_lines_this_game >= max_utility_lines_per_game:
		return
	_utility_lines_this_game += 1
	var action := String(chosen.get("action_id", chosen.get("type", "pass")))
	if chosen.has("followup_action_id") and not String(chosen.get("followup_action_id", "")).is_empty():
		action = "%s->%s" % [action, String(chosen.get("followup_action_id"))]
	var score := float(chosen.get("score", 0.0))
	var parts: PackedStringArray = PackedStringArray()
	for i in range(mini(3, top_scored.size())):
		var row: Dictionary = top_scored[i]
		var cand = row.get("cand")
		var aid := "pass"
		if cand != null:
			aid = cand.action_id if cand.followup_action_id.is_empty() else cand.followup_action_id
		parts.append("%s=%.1f" % [aid, float(row.get("score", 0.0))])
	print(
		"[util-trace] g%d %s @ %s -> %s u=%.2f [%s]"
		% [_game_serial, team_id, coords, action, score, ", ".join(parts)]
	)
