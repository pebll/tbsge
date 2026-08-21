class_name AiMatchScore
extends RefCounted

## Rich EA match scoring: reward fast wins + surviving gold; punish idle draws.

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

## Team turns without HP damage before forced draw.
const STALE_TEAM_TURNS_FOR_DRAW := 5

const WIN_BASE := 1.0
const SPEED_WEIGHT := 0.35
const VALUE_WEIGHT := 0.35
## Reference team-turns for speed factor (faster than this → full speed bonus).
const SPEED_REF_TURNS := 40.0

const DRAW_PENALTY := 0.45
## Extra draw punishment scaled by your remaining gold fraction (idle with army left).
const DRAW_VALUE_SCALE := 0.40

const LOSS_SCORE := 0.0

## Score for one side of a finished match. Higher is better (can be negative on draws).
static func score_for_side(result: Dictionary, side_is_green: bool) -> float:
	var my_key := "green" if side_is_green else "blue"
	var opp_key := "blue" if side_is_green else "green"
	var my_start := maxf(1.0, float(result.get("gold_start_%s" % my_key, 1.0)))
	var my_end := maxf(0.0, float(result.get("gold_end_%s" % my_key, 0.0)))
	var my_frac := clampf(my_end / my_start, 0.0, 1.0)
	var turns := float(result.get("team_turns", 0))
	var speed := clampf(1.0 - turns / SPEED_REF_TURNS, 0.0, 1.0)

	var winner := String(result.get("winner", ""))
	var is_draw := (
		bool(result.get("timed_out", false))
		or bool(result.get("stale_draw", false))
		or winner.is_empty()
	)
	if is_draw:
		# Both sides get a negative term; more remaining value ⇒ worse (should have fought).
		return -DRAW_PENALTY - DRAW_VALUE_SCALE * my_frac

	var i_won := (winner == "GREEN" and side_is_green) or (winner == "BLUE" and not side_is_green)
	if i_won:
		return WIN_BASE + SPEED_WEIGHT * speed + VALUE_WEIGHT * my_frac
	return LOSS_SCORE

## 1 win / 0 loss / 0.5 draw — for win-rate style arena debug.
static func outcome_rate(result: Dictionary, side_is_green: bool) -> float:
	var winner := String(result.get("winner", ""))
	if (
		bool(result.get("timed_out", false))
		or bool(result.get("stale_draw", false))
		or winner.is_empty()
	):
		return 0.5
	if winner == "GREEN":
		return 1.0 if side_is_green else 0.0
	if winner == "BLUE":
		return 0.0 if side_is_green else 1.0
	return 0.5

static func team_living_gold(session, team_id: String) -> float:
	if session == null:
		return 0.0
	var total := 0.0
	for legion in session.legions:
		if legion == null or legion.units.is_empty():
			continue
		if legion.team_id != team_id:
			continue
		total += float(MinigameRulesScript.legion_cost(legion.unit_type, legion.units.size()))
	return total

static func step_dealt_damage(result: Dictionary) -> bool:
	if not result.get("ok", false):
		return false
	var events: Array = result.get("events", [])
	if not ("combat_resolved" in events):
		return false
	var combat: Dictionary = result.get("payload", {}).get("combat", {})
	for hit in combat.get("hits", []):
		if hit is Dictionary and float(hit.get("hp_lost", 0.0)) > 0.0:
			return true
	return false
