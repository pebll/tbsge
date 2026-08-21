class_name AiFeatureNames
extends RefCounted

## Stable feature ids — genome / profile keys. Keep names stable across EA runs.

const ENEMY_LOSS_FRAC := "enemy_loss_frac"
const OWN_LOSS_FRAC := "own_loss_frac"
const NET_HP_FRAC := "net_hp_frac"
const FOCUS_SUPPORT := "focus_support"
const FOCUS_LOW_HP := "focus_low_hp"
const HEAL_EFFICIENCY := "heal_efficiency"
const HEAL_URGENCY := "heal_urgency"
const CLOSER_TO_FOCUS := "closer_to_focus"
const ENABLES_ATTACK := "enables_attack"
const IS_COMBAT := "is_combat"
const IS_HEAL := "is_heal"
const IS_MOVE := "is_move"
const IS_TELEPORT := "is_teleport"
const IS_PASS := "is_pass"
const IS_TERMINAL := "is_terminal"
const LEFTOVER_AP_FRAC := "leftover_ap_frac"
const PASS_PENALTY := "pass_penalty"

static func all_names() -> Array[String]:
	return [
		ENEMY_LOSS_FRAC,
		OWN_LOSS_FRAC,
		NET_HP_FRAC,
		FOCUS_SUPPORT,
		FOCUS_LOW_HP,
		HEAL_EFFICIENCY,
		HEAL_URGENCY,
		CLOSER_TO_FOCUS,
		ENABLES_ATTACK,
		IS_COMBAT,
		IS_HEAL,
		IS_MOVE,
		IS_TELEPORT,
		IS_PASS,
		IS_TERMINAL,
		LEFTOVER_AP_FRAC,
		PASS_PENALTY,
	]
