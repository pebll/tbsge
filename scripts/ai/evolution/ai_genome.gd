class_name AiGenome
extends RefCounted

## Weight vector genome aligned with AiFeatureNames.

const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const AiProfileScript = preload("res://scripts/ai/utility/ai_profile.gd")

var weights: Dictionary = {}

static func from_profile(profile: AiProfile) -> AiGenome:
	var g := AiGenome.new()
	for name in AiFeatureNames.all_names():
		g.weights[name] = profile.weight_for(name)
	return g

static func from_hand_v1() -> AiGenome:
	return from_profile(AiProfileScript.hand_v1())

func to_profile(profile_id: String = "evolved") -> AiProfile:
	var p := AiProfile.new()
	p.id = profile_id
	p.display_name = profile_id
	p.temperature = 0.0
	p.weights = weights.duplicate(true)
	return p

func duplicate_genome() -> AiGenome:
	var g := AiGenome.new()
	g.weights = weights.duplicate(true)
	return g

func mutate(rng: RandomNumberGenerator, sigma: float = 0.35, gene_chance: float = 0.35) -> AiGenome:
	var child := duplicate_genome()
	for name in AiFeatureNames.all_names():
		if rng.randf() > gene_chance:
			continue
		var base := float(child.weights.get(name, 0.0))
		child.weights[name] = clampf(base + rng.randfn() * sigma, -12.0, 12.0)
	return child

func to_dict() -> Dictionary:
	return {"weights": weights.duplicate(true)}

static func from_dict(data: Dictionary) -> AiGenome:
	var g := AiGenome.new()
	var w: Dictionary = data.get("weights", {})
	for name in AiFeatureNames.all_names():
		g.weights[name] = float(w.get(name, 0.0))
	return g

static func crossover(a: AiGenome, b: AiGenome, rng: RandomNumberGenerator) -> AiGenome:
	var child := AiGenome.new()
	for name in AiFeatureNames.all_names():
		var pick_a := rng.randf() < 0.5
		child.weights[name] = float((a.weights if pick_a else b.weights).get(name, 0.0))
	return child
