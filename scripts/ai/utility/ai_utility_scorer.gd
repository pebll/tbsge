class_name AiUtilityScorer
extends RefCounted

## Linear utility: sum_i weight_i * feature_i

static func score(features: Dictionary, profile: AiProfile) -> float:
	if profile == null:
		return 0.0
	var total := 0.0
	for key in features.keys():
		total += float(features[key]) * profile.weight_for(String(key))
	return total
