class_name AiBrainRegistry
extends RefCounted

## String id → AiBrain instance. Keep ids stable for CLI / EA configs.

const CascadeBrainScript = preload("res://scripts/ai/brains/cascade_brain.gd")
const GreedyCombatBrainScript = preload("res://scripts/ai/brains/greedy_combat_brain.gd")
const HealOnlyBrainScript = preload("res://scripts/ai/brains/heal_only_brain.gd")
const PassBrainScript = preload("res://scripts/ai/brains/pass_brain.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")
const AiProfileScript = preload("res://scripts/ai/utility/ai_profile.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")

## Profile the in-game "utility" brain ships with; hand_v1 when absent.
const DEFAULT_UTILITY_PROFILE := "res://data/ai/profiles/utility_default.json"
## Best GA-evolved weights, shipped for the in-game "Utility (evolved)" opponent.
const EVOLVED_UTILITY_PROFILE := "res://data/ai/profiles/utility_evolved.json"
const UTILITY_FILE_PREFIX := "utility:"

const KNOWN_IDS: Array[String] = [
	"cascade",
	"utility",
	"utility_hand",
	"utility_evolved",
	"utility_v0",
	"utility_planner",
	"utility_hand_greedy",
	"curriculum_pass",
	"curriculum_heal",
	"curriculum_heal_ranged",
	"curriculum_greedy",
]

static func create(brain_id: String) -> AiBrain:
	var trimmed := brain_id.strip_edges()
	if trimmed.to_lower().begins_with(UTILITY_FILE_PREFIX):
		return _utility_from_file(trimmed.substr(UTILITY_FILE_PREFIX.length()))
	var key := trimmed.to_lower()
	if key.is_empty():
		key = "cascade"
	match key:
		"cascade":
			return CascadeBrainScript.new()
		"utility":
			return _planning(UtilityBrainScript.new(default_utility_profile()))
		"utility_hand", "hand_v1", "utility_planner":
			return _planning(UtilityBrainScript.new(AiProfileScript.hand_v1()))
		"utility_evolved":
			return _planning(_utility_from_file(EVOLVED_UTILITY_PROFILE))
		"utility_hand_greedy":
			return UtilityBrainScript.new(AiProfileScript.hand_v1())
		"utility_v0":
			return utility_v0()
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

## Hand-tuned AI as it was before 0.1 team play (no focus-fire / cover features, legions
## ordered by best score only). Reference opponent for the version ladder.
static func utility_v0() -> AiBrain:
	var profile: AiProfile = AiProfileScript.hand_v1()
	profile.id = "hand_v0"
	profile.set_weight(AiFeatureNames.TEAM_FINISH, 0.0)
	profile.set_weight(AiFeatureNames.COVER_ALLY, 0.0)
	var brain = UtilityBrainScript.new(profile)
	brain.role_ordering = false
	return brain

## The in-game utility opponents plan whole turns (TurnPlanner). Evolution and the
## "utility:<file>" / "*_greedy" ids stay per-legion greedy (fast, for tuning).
static func _planning(brain) -> AiBrain:
	brain.turn_planning = true
	return brain

static func is_known(brain_id: String) -> bool:
	var key := brain_id.strip_edges().to_lower()
	return key in KNOWN_IDS or key.begins_with(UTILITY_FILE_PREFIX)

static func default_utility_profile() -> AiProfile:
	var shipped: AiProfile = AiProfileScript.load_json(DEFAULT_UTILITY_PROFILE)
	return shipped if shipped != null else AiProfileScript.hand_v1()

static func _utility_from_file(path: String) -> AiBrain:
	var profile: AiProfile = AiProfileScript.load_json(path)
	if profile == null:
		push_error("Could not load utility profile '%s'; using the default profile" % path)
		profile = default_utility_profile()
	return UtilityBrainScript.new(profile)
