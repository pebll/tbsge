class_name AiBrainRegistry
extends RefCounted

## String id → AiBrain instance. Keep ids stable for CLI / EA configs.

const CascadeBrainScript = preload("res://scripts/ai/brains/cascade_brain.gd")
const GreedyCombatBrainScript = preload("res://scripts/ai/brains/greedy_combat_brain.gd")
const HealOnlyBrainScript = preload("res://scripts/ai/brains/heal_only_brain.gd")
const PassBrainScript = preload("res://scripts/ai/brains/pass_brain.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")
const AiProfileScript = preload("res://scripts/ai/utility/ai_profile.gd")

const KNOWN_IDS: Array[String] = [
	"cascade",
	"utility",
	"curriculum_pass",
	"curriculum_heal",
	"curriculum_heal_ranged",
	"curriculum_greedy",
]

static func create(brain_id: String) -> AiBrain:
	var key := brain_id.strip_edges().to_lower()
	if key.is_empty():
		key = "cascade"
	match key:
		"cascade":
			return CascadeBrainScript.new()
		"utility":
			return UtilityBrainScript.new(AiProfileScript.hand_v1())
		"curriculum_pass", "pass":
			return PassBrainScript.new()
		"curriculum_heal", "heal_only":
			return HealOnlyBrainScript.new(false)
		"curriculum_heal_ranged", "heal_ranged":
			return HealOnlyBrainScript.new(true)
		"curriculum_greedy", "greedy_combat":
			return GreedyCombatBrainScript.new()
		_:
			push_error("Unknown AI brain id '%s'; falling back to cascade" % brain_id)
			return CascadeBrainScript.new()

static func is_known(brain_id: String) -> bool:
	return brain_id.strip_edges().to_lower() in KNOWN_IDS
