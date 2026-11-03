class_name HealOnlyBrain
extends AiBrain

## Curriculum heal-only opponent: self/ally heal if legal, else pass.

const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const AiActionScorer = preload("res://scripts/ai/ai_action_scorer.gd")

var ranged_targets_only: bool = false

func _init(p_ranged_only: bool = false) -> void:
	ranged_targets_only = p_ranged_only
	id = "curriculum_heal_ranged" if ranged_targets_only else "curriculum_heal"
	display_name = "Curriculum Heal Ranged" if ranged_targets_only else "Curriculum Heal"

func decide(session, legion: Legion) -> Dictionary:
	if legion == null or legion.units.is_empty() or not session.can_act_legion(legion):
		return _pass(legion, "cannot act")
	var enemies: Array = []
	for other in session.legions:
		if other == null or other.units.is_empty():
			continue
		if other.team_id == legion.team_id:
			continue
		enemies.append(other)
	if enemies.is_empty():
		return _pass(legion, "no enemies")
	var heal := _best_heal(session, legion, enemies)
	if not heal.is_empty():
		return heal
	return _pass(legion, "no heal")

func _best_heal(session, legion: Legion, enemies: Array) -> Dictionary:
	var best_score := -INF
	var best_cmd: Dictionary = {}
	for action_id in ["self_heal", "heal_ally"]:
		if action_id not in ActionDefs.legion_action_ids(legion):
			continue
		for to_coords in session.get_action_targets(legion, action_id):
			var target: Legion = legion if action_id == "self_heal" else session.get_legion_at(to_coords)
			if target == null or target.units.is_empty():
				continue
			if ranged_targets_only and not _legion_has_ranged(target):
				continue
			var score := AiActionScorer.score_action(session, legion, action_id, to_coords)
			if score > best_score:
				best_score = score
				best_cmd = {
					"type": "use_action",
					"action_id": action_id,
					"from": legion.tile_coords,
					"to": to_coords,
					"score": score,
					"reason": "curriculum heal %.1f" % score,
				}
	return best_cmd

static func _legion_has_ranged(legion: Legion) -> bool:
	return "ranged_attack" in ActionDefs.legion_action_ids(legion)

static func _pass(legion: Legion, reason: String) -> Dictionary:
	return {
		"type": "pass",
		"coords": legion.tile_coords if legion else Vector2i.ZERO,
		"reason": reason,
	}
