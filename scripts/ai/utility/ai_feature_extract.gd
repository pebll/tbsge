class_name AiFeatureExtract
extends RefCounted

## Build a normalized feature dict for one candidate.

const AiActionScorer = preload("res://scripts/ai/ai_action_scorer.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
const AiMatchScore = preload("res://scripts/ai/evolution/ai_match_score.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const ActionParams = preload("res://scripts/actions/action_params.gd")

## Combat estimate for one (attacker, defender, action, from, to). `sim_count` < 0 falls back to the
## global default. A non-null `memo` (owned by the caller, one board snapshot) caches estimates;
## the key includes the sim count so brains with different counts never share an entry.
static func estimate(
	attacker: Legion,
	defender: Legion,
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i,
	sim_count: int = -1,
	memo = null
) -> Dictionary:
	var n := CombatExpectation.get_sim_count() if sim_count < 0 else maxi(1, sim_count)
	if memo == null:
		return CombatExpectation.estimate_combat(attacker, defender, action_id, from_coords, to_coords, n)
	var key := "%d|%d|%s|%s|%s|%d" % [
		attacker.get_instance_id(), defender.get_instance_id(), action_id, from_coords, to_coords, n,
	]
	if memo.has(key):
		return memo[key]
	var est: Dictionary = CombatExpectation.estimate_combat(
		attacker, defender, action_id, from_coords, to_coords, n
	)
	memo[key] = est
	return est

## Expected gold destroyed minus gold lost, divided by a fixed team scale, in [-1, 1].
## Gold per HP of a legion = legion_cost(unit_type, units.size()) / total max HP of its units,
## i.e. its purchase price spread evenly over its hit points (cost is price * unit count).
static func trade_value(est: Dictionary, attacker: Legion, defender: Legion, scale: float) -> float:
	var gained := float(est.get("enemy_loss_mean", 0.0)) * _gold_per_hp(defender)
	var lost := float(est.get("own_loss_mean", 0.0)) * _gold_per_hp(attacker)
	return clampf((gained - lost) / maxf(1.0, scale), -1.0, 1.0)

static func _gold_per_hp(legion: Legion) -> float:
	if legion == null or legion.units.is_empty():
		return 0.0
	return float(MinigameRulesScript.legion_cost(legion.unit_type, legion.units.size())) / _max_hp(legion)

## Average living gold of the two teams in the fight; the same for every candidate in a decision.
static func _trade_scale(session, attacker: Legion, defender: Legion) -> float:
	return 0.5 * (
		AiMatchScore.team_living_gold(session, attacker.team_id)
		+ AiMatchScore.team_living_gold(session, defender.team_id)
	)

## `sim_count` / `memo`: see estimate(). Both are per call so concurrent brains never share state.
static func extract(
	session, legion: Legion, ctx: AiContext, cand: AiCandidate, sim_count: int = -1, memo = null
) -> Dictionary:
	var feats: Dictionary = {}
	for name in AiFeatureNames.all_names():
		feats[name] = 0.0

	var action_id := _effective_action(cand)
	var stand := cand.stand_coords()
	var target_coords := cand.followup_to if not cand.followup_action_id.is_empty() else cand.to

	feats[AiFeatureNames.IS_PASS] = 1.0 if action_id == "pass" else 0.0
	feats[AiFeatureNames.PASS_PENALTY] = 1.0 if action_id == "pass" else 0.0
	feats[AiFeatureNames.IS_MOVE] = 1.0 if cand.action_id == "move" and cand.followup_action_id.is_empty() else 0.0
	feats[AiFeatureNames.IS_TELEPORT] = 1.0 if action_id == "teleport" else 0.0
	feats[AiFeatureNames.IS_COMBAT] = 1.0 if action_id in ["melee_attack", "ranged_attack"] else 0.0
	feats[AiFeatureNames.IS_HEAL] = 1.0 if action_id in ["self_heal", "heal_ally"] else 0.0

	var terminal := action_id in ["melee_attack", "ranged_attack", "self_heal", "heal_ally", "teleport"]
	feats[AiFeatureNames.IS_TERMINAL] = 1.0 if terminal else 0.0

	var move_cost := 0
	if cand.action_id == "move" and cand.path.size() >= 2:
		move_cost = cand.path.size() - 1
	var ap_after := maxi(0, legion.current_ap - move_cost - (1 if action_id != "move" and action_id != "pass" else 0))
	if action_id == "move":
		ap_after = maxi(0, legion.current_ap - move_cost)
	# Passing must not be rewarded for the AP it wastes.
	feats[AiFeatureNames.LEFTOVER_AP_FRAC] = (
		0.0 if action_id == "pass" else float(ap_after) / float(maxi(1, legion.max_ap))
	)

	var focus_dist_before := ctx.dist_to_focus(legion.tile_coords)
	var focus_dist_after := ctx.dist_to_focus(stand)
	var denom := maxf(1.0, ctx.map_radius_approx)
	var progress := focus_dist_before - focus_dist_after
	if cand.action_id == "move":
		progress += _displaced_ally_progress(session, legion, ctx, cand.path)
	feats[AiFeatureNames.CLOSER_TO_FOCUS] = clampf(
		progress / denom, -1.0, 1.0
	)

	_fill_threat(ctx, legion, stand, feats)

	if action_id in ["melee_attack", "ranged_attack"]:
		_fill_combat(session, legion, stand, target_coords, action_id, feats, sim_count, memo)
	elif action_id in ["self_heal", "heal_ally"]:
		_fill_heal(session, legion, stand, target_coords, action_id, feats)
	elif action_id == "teleport":
		feats[AiFeatureNames.ENABLES_ATTACK] = (
			1.0 if _has_combat_from(session, legion, stand) else 0.0
		)
	elif cand.action_id == "move":
		feats[AiFeatureNames.ENABLES_ATTACK] = (
			1.0 if not cand.followup_action_id.is_empty() or _has_combat_from(session, legion, stand)
			else 0.0
		)
		if not cand.followup_action_id.is_empty() and cand.followup_action_id in ["melee_attack", "ranged_attack"]:
			_fill_combat(
			session, legion, stand, cand.followup_to, cand.followup_action_id, feats, sim_count, memo
		)
			feats[AiFeatureNames.IS_COMBAT] = 1.0
			feats[AiFeatureNames.IS_MOVE] = 0.0
			feats[AiFeatureNames.IS_TERMINAL] = 1.0

	return feats

## Moving onto an ally swaps it into the previous path tile; count its (usually negative)
## progress so shuffling allies in a corridor is not mistaken for advancing.
static func _displaced_ally_progress(session, legion: Legion, ctx: AiContext, path: Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		var occupant: Legion = session.get_legion_at(path[i])
		if occupant == null or occupant == legion or occupant.team_id != legion.team_id:
			continue
		total += ctx.dist_to_focus(path[i]) - ctx.dist_to_focus(path[i - 1])
	return total

static func _effective_action(cand: AiCandidate) -> String:
	if not cand.followup_action_id.is_empty():
		return cand.followup_action_id
	return cand.action_id

static func _fill_threat(ctx: AiContext, legion: Legion, stand: Vector2i, feats: Dictionary) -> void:
	if ctx == null or ctx.threat == null or legion == null:
		return
	var threat_before: float = ctx.threat.threat_frac(legion.tile_coords)
	var threat_stand: float = ctx.threat.threat_frac(stand)
	feats[AiFeatureNames.THREAT_AT_STAND] = threat_stand
	feats[AiFeatureNames.THREAT_RELIEF] = clampf(threat_before - threat_stand, -1.0, 1.0)
	var hp_frac := _total_hp(legion) / _max_hp(legion)
	var frailty := clampf(1.0 - hp_frac, 0.0, 1.0)
	feats[AiFeatureNames.LOW_HP_EXPOSURE] = frailty * threat_stand

static func _fill_combat(
	session,
	legion: Legion,
	from_coords: Vector2i,
	to_coords: Vector2i,
	action_id: String,
	feats: Dictionary,
	sim_count: int,
	memo
) -> void:
	var defender: Legion = session.get_legion_at(to_coords)
	if defender == null:
		return
	var restored := _push_coords(session, legion, from_coords)
	var est: Dictionary = estimate(legion, defender, action_id, from_coords, to_coords, sim_count, memo)
	_pop_coords(session, legion, restored)

	var def_hp := maxf(1.0, float(est.get("defender_hp", 1.0)))
	var own_hp := maxf(1.0, float(est.get("attacker_hp", 1.0)))
	var def_units := maxf(1.0, float(est.get("defender_units", 1)))
	var atk_units := maxf(1.0, float(est.get("attacker_units", 1)))
	var enemy_loss := float(est.get("enemy_loss_mean", 0.0))
	var own_loss := float(est.get("own_loss_mean", 0.0))

	feats[AiFeatureNames.ENEMY_LOSS_FRAC] = clampf(enemy_loss / def_hp, 0.0, 1.0)
	feats[AiFeatureNames.OWN_LOSS_FRAC] = clampf(own_loss / own_hp, 0.0, 1.0)
	feats[AiFeatureNames.NET_HP_FRAC] = clampf(
		(enemy_loss / def_hp) - (own_loss / own_hp), -1.0, 1.0
	)
	feats[AiFeatureNames.ENEMY_KILL_FRAC] = clampf(
		float(est.get("enemy_kills_mean", 0.0)) / def_units, 0.0, 1.0
	)
	feats[AiFeatureNames.OWN_DEATH_FRAC] = clampf(
		float(est.get("own_deaths_mean", 0.0)) / atk_units, 0.0, 1.0
	)
	feats[AiFeatureNames.KILL_PROB] = clampf(float(est.get("kill_prob", 0.0)), 0.0, 1.0)
	feats[AiFeatureNames.WIPE_PROB] = clampf(float(est.get("wipe_prob", 0.0)), 0.0, 1.0)
	feats[AiFeatureNames.TRADE_VALUE] = trade_value(
		est, legion, defender, _trade_scale(session, legion, defender)
	)
	feats[AiFeatureNames.ENEMY_LOSS_SPREAD] = clampf(
		float(est.get("enemy_loss_spread", 0.0)) / def_hp, 0.0, 1.0
	)
	feats[AiFeatureNames.FOCUS_SUPPORT] = 0.0 if AiActionScorer.is_frontline(defender) else 1.0
	feats[AiFeatureNames.FOCUS_LOW_HP] = 1.0 - clampf(_total_hp(defender) / _max_hp(defender), 0.0, 1.0)
	feats[AiFeatureNames.ENABLES_ATTACK] = 1.0

static func _fill_heal(
	session,
	legion: Legion,
	_from_coords: Vector2i,
	to_coords: Vector2i,
	action_id: String,
	feats: Dictionary
) -> void:
	var target: Legion = legion if action_id == "self_heal" else session.get_legion_at(to_coords)
	if target == null:
		return
	var action = ActionDefs.get_def(action_id)
	if action == null:
		return
	var heal_amount := ActionParams.resolve_int(legion, action, "heal_amount", action.heal_amount)
	var missing := 0.0
	var cur := 0.0
	var mx := 0.0
	var worst_unit_frac := 1.0
	for u in target.units:
		if u == null:
			continue
		var uh := float(u.current_health)
		var um := float(u.max_health)
		cur += uh
		mx += um
		missing += maxf(0.0, um - uh)
		if um > 0.0:
			worst_unit_frac = minf(worst_unit_frac, uh / um)
	var potential := float(heal_amount * legion.units.size())
	var healed := minf(missing, potential)
	feats[AiFeatureNames.HEAL_EFFICIENCY] = healed / maxf(1.0, mx)
	var stack_frac := cur / maxf(1.0, mx)
	feats[AiFeatureNames.HEAL_URGENCY] = clampf(1.0 - minf(stack_frac, worst_unit_frac), 0.0, 1.0)

static func _has_combat_from(session, legion: Legion, at_coords: Vector2i) -> bool:
	var restored: Dictionary = _push_coords(session, legion, at_coords)
	var melee_targets: Array = session.get_action_targets(legion, "melee_attack")
	var ranged_targets: Array = session.get_action_targets(legion, "ranged_attack")
	var has_combat: bool = (not melee_targets.is_empty()) or (not ranged_targets.is_empty())
	_pop_coords(session, legion, restored)
	return has_combat

static func _push_coords(session, legion: Legion, at_coords: Vector2i) -> Dictionary:
	var old := legion.tile_coords
	if at_coords == old:
		return {"moved": false}
	var tile_old: Tile = session.grid.get(old)
	var tile_new: Tile = session.grid.get(at_coords)
	var prev_new = tile_new.legion if tile_new else null
	legion.tile_coords = at_coords
	if tile_old and tile_old.legion == legion:
		tile_old.legion = null
	if tile_new:
		tile_new.legion = legion
	return {
		"moved": true,
		"old": old,
		"tile_old": tile_old,
		"tile_new": tile_new,
		"prev_new": prev_new,
	}

static func _pop_coords(session, legion: Legion, restored: Dictionary) -> void:
	if not bool(restored.get("moved", false)):
		return
	legion.tile_coords = restored["old"]
	var tile_old: Tile = restored.get("tile_old")
	var tile_new: Tile = restored.get("tile_new")
	if tile_old:
		tile_old.legion = legion
	if tile_new:
		tile_new.legion = restored.get("prev_new")

static func _total_hp(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += float(u.current_health)
	return t

static func _max_hp(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += float(u.max_health)
	return maxf(1.0, t)
