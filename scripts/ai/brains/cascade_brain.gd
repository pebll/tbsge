class_name CascadeBrain
extends AiBrain

## Current shipped AI: priority cascade + greedy net-HP scoring.

const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")

func _init() -> void:
	id = "cascade"
	display_name = "Cascade"

func decide(session, legion: Legion) -> Dictionary:
	return AttackNearestEnemyBehavior.decide(session, legion)

func sort_actionable(session, actionable: Array[Vector2i]) -> Array[Vector2i]:
	return AttackNearestEnemyBehavior.sort_actionable_by_enemy_distance(session, actionable)
