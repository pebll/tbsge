class_name GreedyCombatBrain
extends AiBrain

## Greedy closest-enemy combat without healing (curriculum stages 6–7).

const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")

func _init() -> void:
	id = "curriculum_greedy"
	display_name = "Curriculum Greedy Combat"

func decide(session, legion: Legion) -> Dictionary:
	return AttackNearestEnemyBehavior.decide_combat_only(session, legion)

func sort_actionable(session, actionable: Array[Vector2i]) -> Array[Vector2i]:
	return AttackNearestEnemyBehavior.sort_actionable_by_enemy_distance(session, actionable)
