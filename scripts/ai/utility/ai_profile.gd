class_name AiProfile
extends Resource

## Weight vector + playtime temperature (EA fitness uses argmax; T is for difficulty later).

const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")

@export var id: String = "hand_v1"
@export var display_name: String = "Hand-tuned v1"
## feature_name -> weight
@export var weights: Dictionary = {}
## Softmax temperature at playtime (0 => argmax). EA evaluation ignores this.
@export var temperature: float = 0.0

func weight_for(feature_name: String) -> float:
	return float(weights.get(feature_name, 0.0))

func set_weight(feature_name: String, value: float) -> void:
	weights[feature_name] = value

static func hand_v1() -> AiProfile:
	var p := AiProfile.new()
	p.id = "hand_v1"
	p.display_name = "Hand-tuned v1"
	p.temperature = 0.0
	p.weights = {
		AiFeatureNames.ENEMY_LOSS_FRAC: 5.0,
		AiFeatureNames.OWN_LOSS_FRAC: -4.5,
		AiFeatureNames.NET_HP_FRAC: 3.5,
		AiFeatureNames.ENEMY_KILL_FRAC: 6.0,
		AiFeatureNames.OWN_DEATH_FRAC: -5.5,
		AiFeatureNames.KILL_PROB: 4.0,
		AiFeatureNames.ENEMY_LOSS_SPREAD: -0.5,
		AiFeatureNames.THREAT_AT_STAND: -3.0,
		AiFeatureNames.THREAT_RELIEF: 2.5,
		AiFeatureNames.LOW_HP_EXPOSURE: -4.0,
		AiFeatureNames.FOCUS_SUPPORT: 1.5,
		AiFeatureNames.FOCUS_LOW_HP: 2.0,
		AiFeatureNames.HEAL_EFFICIENCY: 3.0,
		AiFeatureNames.HEAL_URGENCY: 4.0,
		AiFeatureNames.CLOSER_TO_FOCUS: 2.5,
		AiFeatureNames.ENABLES_ATTACK: 3.0,
		AiFeatureNames.IS_COMBAT: 1.0,
		AiFeatureNames.IS_HEAL: 0.2,
		AiFeatureNames.IS_MOVE: 0.1,
		AiFeatureNames.IS_TELEPORT: 0.5,
		AiFeatureNames.IS_PASS: 0.0,
		AiFeatureNames.IS_TERMINAL: 0.0,
		AiFeatureNames.LEFTOVER_AP_FRAC: 0.5,
		AiFeatureNames.PASS_PENALTY: -8.0,
	}
	return p

func duplicate_profile() -> AiProfile:
	var p := AiProfile.new()
	p.id = id
	p.display_name = display_name
	p.temperature = temperature
	p.weights = weights.duplicate(true)
	return p
