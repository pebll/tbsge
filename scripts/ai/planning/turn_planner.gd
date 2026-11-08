extends RefCounted

## Whole-turn planning for the utility AI (receding horizon).
##
## Before each activation, take the strongest first moves (top candidates of every legion
## that can act), play each one on a copy of the board, let the plain utility policy finish
## the turn there, and score the end of the turn. The real game plays only the winning
## first move, then plans again from the new board. This chooses which legion acts first
## and which target it takes by what the *whole team* gets out of the turn, which per-legion
## scoring can't see (focus fire, who blocks whom, who finishes a wounded target).
##
## Combat rolls inside rollouts use common random numbers: rollout seed s is the same for
## every option, so options differ by the decision, not by luck.

const TurnSimSession = preload("res://scripts/ai/planning/turn_sim_session.gd")
const AiBrainCommand = preload("res://scripts/ai/ai_brain_command.gd")
const ThreatMapScript = preload("res://scripts/ai/threat/threat_map.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const StatusEffectsScript = preload("res://scripts/effects/status_effects.gd")

## First moves tried per legion, and in total per decision.
var options_per_legion: int = 2
var max_options: int = 8
## Rollouts per option (different combat seeds).
var rollouts: int = 2
## Monte Carlo sims per combat estimate inside rollouts (the policy, not the outcome).
var rollout_sims: int = 2
## Wall-clock cap per decision in ms (0 = none). Options are tried strongest first, so a
## cut-off only drops the long shots. The game sets it; benchmarks/tests leave it at 0 so
## results don't depend on machine speed.
var time_budget_ms: int = 0
## Weight of the enemy's best next-turn strikes in the end-of-turn value.
var exposure_weight: float = 0.5
## A wounded unit still strikes at full power: worth this floor of its price.
const WOUNDED_VALUE_FLOOR := 0.6

## Diagnostics (tests / benchmarks).
var plans_made: int = 0
var plans_changed: int = 0
var plan_usec_total: int = 0
var plan_usec_max: int = 0

var _policy = null  # UtilityBrain without planning, used inside rollouts

func _init(policy_brain) -> void:
	_policy = policy_brain

## options: Array of {"legion": Legion (live), "row": scored row with "cand"/"score"}.
## Returns the index of the best option (0 = the greedy choice when values tie).
func choose(session, options: Array) -> int:
	if options.size() <= 1:
		return 0
	plans_made += 1
	var t0 := Time.get_ticks_usec()
	var team: String = options[0]["legion"].team_id
	var best_i := 0
	var best_v := -INF
	for i in range(options.size()):
		if time_budget_ms > 0 and i >= 2 and (Time.get_ticks_usec() - t0) > time_budget_ms * 1000:
			break
		var total := 0.0
		for s in range(rollouts):
			total += _rollout(session, options[i], team, s)
		var v := total / float(rollouts)
		if v > best_v + 1e-6:
			best_v = v
			best_i = i
	if best_i != 0:
		plans_changed += 1
	var dt := Time.get_ticks_usec() - t0
	plan_usec_total += dt
	plan_usec_max = maxi(plan_usec_max, dt)
	return best_i

func _rollout(session, option: Dictionary, team: String, seed_index: int) -> float:
	var sim = TurnSimSession.clone_from(session)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x7a11 + seed_index * 104729 + int(session.turn_manager.turn_index) * 31
	sim.set_match_seed(int(rng.randi()))
	var live: Legion = option["legion"]
	var cand = option["row"]["cand"]
	var legion: Legion = sim.get_legion_at(live.tile_coords)
	if legion == null:
		return -INF
	AiBrainCommand.apply(sim, cand.to_command(), live.tile_coords, legion, rng, null)
	var guard := 0
	while sim.phase == TurnSimSession.Phase.BATTLE and guard < 64:
		guard += 1
		var actionable: Array[Vector2i] = _policy.sort_actionable(sim, sim.get_actionable_coords())
		if actionable.is_empty():
			break
		var coords: Vector2i = actionable[0]
		var L: Legion = sim.get_legion_at(coords)
		if L == null:
			sim.pass_legion_or_force_wait(coords)
			continue
		AiBrainCommand.apply(sim, _policy.decide(sim, L), coords, L, rng, null)
	return evaluate(sim, team, exposure_weight)

## End-of-turn value for `team`: living army value (wounded units count at least
## WOUNDED_VALUE_FLOOR of their price) of ours minus theirs, minus the gold the enemy's
## best strikes could take next turn.
static func evaluate(sim, team: String, p_exposure_weight: float = 0.5) -> float:
	if sim.phase != TurnSimSession.Phase.BATTLE:
		if sim.winner == team:
			return 1e6
		if not String(sim.winner).is_empty():
			return -1e6
	var value := 0.0
	for L in sim.legions:
		if L == null or L.units.is_empty():
			continue
		var v := army_value(L) + future_value_change(L)
		value += v if L.team_id == team else -v
	if p_exposure_weight > 0.0:
		value -= p_exposure_weight * exposure(sim, team)
	return value

## Gold-equivalent of the HP the legion's effects will still cost or give (poison to come,
## regeneration), at the legion's average gold per HP.
static func future_value_change(L: Legion) -> float:
	var delta := StatusEffectsScript.projected_hp_change(L)
	if is_zero_approx(delta):
		return 0.0
	var hp := 0.0
	for u in L.units:
		hp += maxf(0.0, float(u.current_health))
	return delta * army_value(L) / maxf(1.0, hp)

static func army_value(L: Legion) -> float:
	var t := 0.0
	for u in L.units:
		if u == null or u.max_health <= 0.0:
			continue
		var price := float(MinigameRulesScript.unit_price(u.unit_type))
		var frac := clampf(float(u.current_health) / float(u.max_health), 0.0, 1.0)
		t += price * (WOUNDED_VALUE_FLOOR + (1.0 - WOUNDED_VALUE_FLOOR) * frac)
	return t

## Each enemy legion strikes once next turn: sum over enemies of the most gold it could
## take from one of our legions it can reach (strike power capped by that legion's HP).
static func exposure(sim, team: String) -> float:
	var threat = ThreatMapScript.build(sim, team)
	var total := 0.0
	for enemy in sim.legions:
		if enemy == null or enemy.units.is_empty() or enemy.team_id == team:
			continue
		var best := 0.0
		for ours in sim.legions:
			if ours == null or ours.units.is_empty() or ours.team_id != team:
				continue
			var strike: float = threat.enemy_strike_on(enemy, ours.tile_coords)
			if strike <= 0.0:
				continue
			var hp := 0.0
			for u in ours.units:
				hp += maxf(0.0, float(u.current_health))
			var gold_per_hp := army_value(ours) / maxf(1.0, hp)
			best = maxf(best, minf(strike, hp) * gold_per_hp)
		total += best
	return total
