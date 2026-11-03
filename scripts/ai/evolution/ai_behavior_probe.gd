class_name AiBehaviorProbe
extends RefCounted

## Collects behavioral descriptors while a UtilityBrain decides (MAP-Elites axes).

var decisions: int = 0
var combat_decisions: int = 0
var threat_sum: float = 0.0
var focus_support_sum: float = 0.0
var focus_samples: int = 0

func reset() -> void:
	decisions = 0
	combat_decisions = 0
	threat_sum = 0.0
	focus_support_sum = 0.0
	focus_samples = 0

func record(features: Dictionary, action_id: String) -> void:
	decisions += 1
	threat_sum += float(features.get("threat_at_stand", 0.0))
	if action_id in ["melee_attack", "ranged_attack"]:
		combat_decisions += 1
		focus_support_sum += float(features.get("focus_support", 0.0))
		focus_samples += 1

## Returns { aggression, risk, support_focus } in [0,1].
func descriptor() -> Dictionary:
	var aggression := 0.0
	if decisions > 0:
		aggression = float(combat_decisions) / float(decisions)
	var risk := 0.0
	if decisions > 0:
		risk = threat_sum / float(decisions)
	var support := 0.0
	if focus_samples > 0:
		support = focus_support_sum / float(focus_samples)
	return {
		"aggression": clampf(aggression, 0.0, 1.0),
		"risk": clampf(risk, 0.0, 1.0),
		"support_focus": clampf(support, 0.0, 1.0),
	}
