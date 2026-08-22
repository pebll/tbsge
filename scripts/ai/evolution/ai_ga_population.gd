class_name AiGaPopulation
extends RefCounted

## Standard GA population: ranked genomes with fitness (no MAP niches).

const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiMapElitesArchiveScript = preload("res://scripts/ai/evolution/ai_map_elites_archive.gd")

const ELITE_COUNT := 6
const TOURNAMENT_K := 3
const DEFAULT_POP := 16

## members: Array[{ genome: AiGenome, fitness: float, descriptor: Dictionary }]
var members: Array = []

func size() -> int:
	return members.size()

func clear() -> void:
	members.clear()

func add_member(genome, fitness: float, descriptor: Dictionary = {}) -> void:
	members.append({
		"genome": genome.duplicate_genome(),
		"fitness": fitness,
		"descriptor": descriptor.duplicate(true),
	})

## Merge one eval batch into cumulative pair stats; returns updated mean fitness.
static func accumulate_eval(
	descriptor: Dictionary,
	report: Dictionary,
	bootstrap_fit: float = -INF
) -> float:
	var pts := float(report.get("pair_points", 0.0))
	var pc := int(report.get("pair_count", 0))
	if pc <= 0:
		if bootstrap_fit > -INF:
			return bootstrap_fit
		return float(descriptor.get("fitness", 0.0))
	var cum_pts := float(descriptor.get("cum_pair_points", 0.0))
	var cum_pc := int(descriptor.get("cum_pair_count", 0))
	if cum_pc <= 0 and bootstrap_fit > -INF:
		cum_pts = bootstrap_fit * float(pc)
		cum_pc = pc
	cum_pts += pts
	cum_pc += pc
	descriptor["cum_pair_points"] = cum_pts
	descriptor["cum_pair_count"] = cum_pc
	descriptor["fitness_evals"] = int(descriptor.get("fitness_evals", 0)) + 1
	var promo_w := int(report.get("promotion_trainee_wins", report.get("trainee_wins", 0)))
	var promo_l := int(report.get("promotion_trainee_losses", report.get("trainee_losses", 0)))
	var promo_d := int(report.get("promotion_trainee_draws", report.get("trainee_draws", 0)))
	descriptor["cum_wins"] = int(descriptor.get("cum_wins", 0)) + promo_w
	descriptor["cum_losses"] = int(descriptor.get("cum_losses", 0)) + promo_l
	descriptor["cum_draws"] = int(descriptor.get("cum_draws", 0)) + promo_d
	descriptor["cum_stale_draws"] = (
		int(descriptor.get("cum_stale_draws", 0))
		+ int(report.get("promotion_trainee_stale_draws", report.get("trainee_stale_draws", 0)))
	)
	descriptor["cum_timeouts"] = (
		int(descriptor.get("cum_timeouts", 0))
		+ int(report.get("promotion_trainee_timeouts", report.get("trainee_timeouts", 0)))
	)
	descriptor["cum_other_draws"] = (
		int(descriptor.get("cum_other_draws", 0))
		+ int(report.get("promotion_trainee_other_draws", report.get("trainee_other_draws", 0)))
	)
	descriptor["cum_draft_failures"] = (
		int(descriptor.get("cum_draft_failures", 0))
		+ int(report.get("promotion_trainee_draft_failures", report.get("trainee_draft_failures", 0)))
	)
	var fit := cum_pts / float(cum_pc)
	descriptor["fitness"] = fit
	return fit

## Lifetime trainee W/L/D stored on a member descriptor (after accumulate_eval calls).
static func cumulative_wld(descriptor: Dictionary) -> Dictionary:
	return {
		"wins": int(descriptor.get("cum_wins", 0)),
		"losses": int(descriptor.get("cum_losses", 0)),
		"draws": int(descriptor.get("cum_draws", 0)),
	}

static func cumulative_win_rate(descriptor: Dictionary) -> float:
	var wld: Dictionary = cumulative_wld(descriptor)
	var total := int(wld.get("wins", 0)) + int(wld.get("losses", 0)) + int(wld.get("draws", 0))
	if total <= 0:
		return 0.0
	return (float(wld.get("wins", 0)) + 0.5 * float(wld.get("draws", 0))) / float(total)

static func eval_cum_games(descriptor: Dictionary) -> int:
	var wld: Dictionary = cumulative_wld(descriptor)
	return int(wld.get("wins", 0)) + int(wld.get("losses", 0)) + int(wld.get("draws", 0))

static func eval_meets_promotion(descriptor: Dictionary, stage: Dictionary) -> bool:
	var min_games := int(stage.get("promote_min_games", 12))
	if eval_cum_games(descriptor) < min_games:
		return false
	return cumulative_win_rate(descriptor) >= float(stage.get("promote_win_rate", 0.85))

## Clear scout/confirm cumulative stats when curriculum stage advances.
static func reset_stage_eval_cum(descriptor: Dictionary) -> void:
	descriptor["cum_wins"] = 0
	descriptor["cum_losses"] = 0
	descriptor["cum_draws"] = 0
	descriptor["cum_stale_draws"] = 0
	descriptor["cum_timeouts"] = 0
	descriptor["cum_other_draws"] = 0
	descriptor["cum_draft_failures"] = 0
	descriptor["cum_pair_points"] = 0.0
	descriptor["cum_pair_count"] = 0
	descriptor["fitness_evals"] = 0

func best_fitness() -> float:
	if members.is_empty():
		return -INF
	var best := -INF
	for m in members:
		best = maxf(best, float(m.get("fitness", -INF)))
	return best

func best_genome():
	if members.is_empty():
		return AiGenomeScript.from_hand_v1()
	sort_desc()
	return (members[0]["genome"] as AiGenome).duplicate_genome()

func sort_desc() -> void:
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("fitness", -INF)) > float(b.get("fitness", -INF))
	)

func median_fitness() -> float:
	if members.is_empty():
		return 0.0
	sort_desc()
	var mid := members.size() / 2
	return float(members[mid].get("fitness", 0.0))

## Confirm re-eval when scout is near/above current best.
func would_confirm(fitness: float) -> bool:
	if members.is_empty():
		return true
	return fitness >= best_fitness() - 0.05

func tournament_select(rng: RandomNumberGenerator):
	if members.is_empty():
		return AiGenomeScript.from_hand_v1()
	var best_i := rng.randi() % members.size()
	var best_fit := float(members[best_i].get("fitness", -INF))
	for _k in range(TOURNAMENT_K - 1):
		var j := rng.randi() % members.size()
		var fit := float(members[j].get("fitness", -INF))
		if fit > best_fit:
			best_fit = fit
			best_i = j
	return (members[best_i]["genome"] as AiGenome).duplicate_genome()

## Random member genome (for arena / elite opponents).
func random_genome(rng: RandomNumberGenerator, skip_best: bool = false):
	if members.is_empty():
		return AiGenomeScript.from_hand_v1()
	if members.size() == 1 or not skip_best:
		return (members[rng.randi() % members.size()]["genome"] as AiGenome).duplicate_genome()
	sort_desc()
	var i := 1 + rng.randi() % (members.size() - 1)
	return (members[i]["genome"] as AiGenome).duplicate_genome()

func top_genomes(limit: int) -> Array:
	sort_desc()
	var out: Array = []
	for i in range(mini(limit, members.size())):
		out.append((members[i]["genome"] as AiGenome).duplicate_genome())
	return out

func to_summary(limit: int = 8) -> Array:
	sort_desc()
	var out: Array = []
	for i in range(mini(limit, members.size())):
		var m: Dictionary = members[i]
		var d: Dictionary = m.get("descriptor", {})
		out.append({
			"rank": i + 1,
			"fitness": float(m.get("fitness", 0.0)),
			"descriptor": d,
		})
	return out

func to_dict() -> Dictionary:
	var rows: Array = []
	for m in members:
		var g: AiGenome = m["genome"]
		rows.append({
			"fitness": float(m.get("fitness", 0.0)),
			"descriptor": m.get("descriptor", {}),
			"genome": g.to_dict(),
		})
	return {"members": rows}

static func from_dict(data: Dictionary):
	var pop = new()
	var rows: Array = data.get("members", [])
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any
		pop.add_member(
			AiGenomeScript.from_dict(row.get("genome", {})),
			float(row.get("fitness", 0.0)),
			row.get("descriptor", {})
		)
	return pop

## Bootstrap GA pop from an old MAP-Elites checkpoint archive dict.
static func from_map_archive_dict(archive_data: Dictionary, target_size: int, rng: RandomNumberGenerator):
	var pop = new()
	var archive = AiMapElitesArchiveScript.from_dict(archive_data)
	var elites: Array = archive.top_elites(maxi(target_size, archive.size()))
	for row in elites:
		pop.add_member(row["genome"], float(row.get("fitness", 0.0)), row.get("descriptor", {}))
	while pop.size() < target_size:
		var base = pop.best_genome() if pop.size() > 0 else AiGenomeScript.from_hand_v1()
		pop.add_member(base.mutate(rng, 0.5, 0.5), -INF, {})
	return pop
