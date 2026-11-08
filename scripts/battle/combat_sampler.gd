class_name CombatSampler
extends RefCounted

## The one Monte Carlo loop over the real CombatResolver. The UI preview
## (BattleExpectationEstimator: min–max ranges) and the AI (CombatExpectation: means,
## kill/wipe odds) only summarise these samples differently, so a rule change in the
## resolver reaches both automatically.

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const CombatSimSnapshot = preload("res://scripts/battle/combat_sim_snapshot.gd")
const StatusEffects = preload("res://scripts/effects/status_effects.gd")

## Fixed per-index seeds: the same N always yields the same samples (stable previews,
## common random numbers across AI candidates).
const SEED_BASE := 10007
const SEED_STRIDE := 7919

## Returns one Dictionary per simulation:
##   enemy_hp_lost, own_hp_lost (float, >= 0), enemy_deaths, own_deaths (int),
##   enemy_wiped, own_wiped (bool),
##   enemy_future_loss, own_future_loss (float, >= 0): HP the statuses this fight leaves
##   behind (e.g. poison) are still expected to cost, beyond what they cost before it
## Originals are never mutated (each sim runs on clones).
static func sample(
	attacker: Legion,
	defender: Legion,
	mode: String,
	distance: int,
	n: int
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if attacker == null or defender == null or n <= 0:
		return out
	var atk_hp0 := total_hp(attacker)
	var def_hp0 := total_hp(defender)
	var atk_n0 := attacker.units.size()
	var def_n0 := defender.units.size()
	var atk_proj0 := StatusEffects.projected_hp_change(attacker)
	var def_proj0 := StatusEffects.projected_hp_change(defender)
	for i in range(n):
		var sim_a := CombatSimSnapshot.clone_legion(attacker)
		var sim_d := CombatSimSnapshot.clone_legion(defender)
		CombatResolver.resolve_combat(
			sim_a,
			sim_d,
			SEED_BASE + i * SEED_STRIDE,
			{"mode": mode, "distance": distance}
		)
		out.append({
			"enemy_hp_lost": maxf(0.0, def_hp0 - total_hp(sim_d)),
			"own_hp_lost": maxf(0.0, atk_hp0 - total_hp(sim_a)),
			"enemy_deaths": maxi(0, def_n0 - sim_d.units.size()),
			"own_deaths": maxi(0, atk_n0 - sim_a.units.size()),
			"enemy_wiped": sim_d.units.is_empty(),
			"own_wiped": sim_a.units.is_empty(),
			"enemy_future_loss": maxf(0.0, def_proj0 - StatusEffects.projected_hp_change(sim_d)),
			"own_future_loss": maxf(0.0, atk_proj0 - StatusEffects.projected_hp_change(sim_a)),
		})
	return out

static func total_hp(legion: Legion) -> float:
	var t := 0.0
	if legion == null:
		return t
	for u in legion.units:
		if u:
			t += maxf(0.0, float(u.current_health))
	return t
