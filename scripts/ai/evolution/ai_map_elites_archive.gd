class_name AiMapElitesArchive
extends RefCounted

## Compact MAP-Elites grid over aggression × risk (peak strength over fine niches).

const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")

## 2×2 = 4 cells — prefer peak climb over fine behavioral niches for now.
const DEFAULT_BINS := 2
## Soft-win floor: reject timid / draw-bot inserts.
const MIN_CELL_FITNESS := 1.75

var bins_x: int = DEFAULT_BINS
var bins_y: int = DEFAULT_BINS
## cell_key -> { fitness, genome, descriptor, evaluations }
var cells: Dictionary = {}

func _init(p_bins_x: int = DEFAULT_BINS, p_bins_y: int = DEFAULT_BINS) -> void:
	bins_x = maxi(1, p_bins_x)
	bins_y = maxi(1, p_bins_y)

func cell_key(descriptor: Dictionary) -> String:
	var ax := _bin(float(descriptor.get("aggression", 0.0)), bins_x)
	var ay := _bin(float(descriptor.get("risk", 0.0)), bins_y)
	return "%d_%d" % [ax, ay]

func cell_fitness(descriptor: Dictionary) -> float:
	var key := cell_key(descriptor)
	if not cells.has(key):
		return -INF
	return float(cells[key].get("fitness", -INF))

## True if this fitness would insert/replace (ignores confirm re-eval).
func would_improve(fitness: float, descriptor: Dictionary) -> bool:
	if cells.is_empty():
		return true
	if fitness < MIN_CELL_FITNESS:
		return false
	var cur := cell_fitness(descriptor)
	return fitness > cur

## Insert if fitness clears the floor (or archive is empty). `force` bypasses the floor (migration).
func try_insert(
	genome: AiGenome,
	fitness: float,
	descriptor: Dictionary,
	force: bool = false
) -> bool:
	if not force and fitness < MIN_CELL_FITNESS and not cells.is_empty():
		return false
	var key := cell_key(descriptor)
	if cells.has(key):
		var cur: Dictionary = cells[key]
		if fitness <= float(cur.get("fitness", -INF)):
			cur["evaluations"] = int(cur.get("evaluations", 0)) + 1
			cells[key] = cur
			return false
	cells[key] = {
		"fitness": fitness,
		"genome": genome.duplicate_genome(),
		"descriptor": descriptor.duplicate(true),
		"evaluations": 1,
	}
	return true

func size() -> int:
	return cells.size()

## Fitness-proportionate parent pick among elites at/above the floor (fallback = champion).
func random_elite(rng: RandomNumberGenerator) -> AiGenome:
	var keys: Array = []
	var weights: Array[float] = []
	var total := 0.0
	for key in cells.keys():
		var row: Dictionary = cells[key]
		var fit := float(row.get("fitness", -INF))
		if fit < MIN_CELL_FITNESS:
			continue
		# Emphasize stronger elites (squared surplus over floor).
		var w := pow(maxf(0.05, fit - MIN_CELL_FITNESS + 0.25), 2.0)
		keys.append(key)
		weights.append(w)
		total += w
	if keys.is_empty() or total <= 0.0:
		return best_genome()
	var pick := rng.randf() * total
	var acc := 0.0
	for i in range(keys.size()):
		acc += weights[i]
		if pick <= acc:
			var g: AiGenome = cells[keys[i]]["genome"]
			return g.duplicate_genome()
	var last: AiGenome = cells[keys[keys.size() - 1]]["genome"]
	return last.duplicate_genome()

func best_fitness() -> float:
	var best := -INF
	for key in cells.keys():
		best = maxf(best, float(cells[key].get("fitness", -INF)))
	return best

func best_genome() -> AiGenome:
	var best_fit := -INF
	var best_g: AiGenome = null
	for key in cells.keys():
		var row: Dictionary = cells[key]
		var fit := float(row.get("fitness", -INF))
		if fit >= best_fit:
			best_fit = fit
			best_g = row["genome"]
	if best_g == null:
		return AiGenomeScript.from_hand_v1()
	return best_g.duplicate_genome()

## Drop cells below the floor, always keeping the current champion.
func prune_weak_cells() -> int:
	if cells.is_empty():
		return 0
	var champ_key := ""
	var best_fit := -INF
	for key in cells.keys():
		var fit := float(cells[key].get("fitness", -INF))
		if fit >= best_fit:
			best_fit = fit
			champ_key = String(key)
	var removed := 0
	var keep: Dictionary = {}
	for key in cells.keys():
		var row: Dictionary = cells[key]
		var fit := float(row.get("fitness", -INF))
		if String(key) == champ_key or fit >= MIN_CELL_FITNESS:
			keep[String(key)] = row
		else:
			removed += 1
	cells = keep
	return removed

## Rebuild into a new bin grid (e.g. 3×3 → 2×2 on continue).
func remap_bins(new_bins_x: int, new_bins_y: int) -> AiMapElitesArchive:
	var neu := AiMapElitesArchive.new(new_bins_x, new_bins_y)
	for key in cells.keys():
		var row: Dictionary = cells[key]
		neu.try_insert(
			row["genome"],
			float(row.get("fitness", 0.0)),
			row.get("descriptor", {}),
			true
		)
	neu.prune_weak_cells()
	return neu

## Top elites by fitness.
func top_elites(limit: int = 5) -> Array:
	var summary := to_summary()
	var out: Array = []
	for i in range(mini(limit, summary.size())):
		var row: Dictionary = summary[i]
		var cell: Dictionary = cells.get(String(row["cell"]), {})
		if cell.is_empty():
			continue
		out.append({
			"cell": row["cell"],
			"fitness": float(row["fitness"]),
			"genome": (cell["genome"] as AiGenome).duplicate_genome(),
			"descriptor": row.get("descriptor", {}),
		})
	return out

func to_summary() -> Array:
	var out: Array = []
	for key in cells.keys():
		var row: Dictionary = cells[key]
		out.append({
			"cell": key,
			"fitness": float(row.get("fitness", 0.0)),
			"descriptor": row.get("descriptor", {}),
			"evaluations": int(row.get("evaluations", 0)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["fitness"]) > float(b["fitness"])
	)
	return out

func to_dict() -> Dictionary:
	var cell_data: Dictionary = {}
	for key in cells.keys():
		var row: Dictionary = cells[key]
		var g: AiGenome = row["genome"]
		cell_data[String(key)] = {
			"fitness": float(row.get("fitness", 0.0)),
			"evaluations": int(row.get("evaluations", 0)),
			"descriptor": row.get("descriptor", {}),
			"genome": g.to_dict(),
		}
	return {
		"bins_x": bins_x,
		"bins_y": bins_y,
		"cells": cell_data,
	}

static func from_dict(data: Dictionary) -> AiMapElitesArchive:
	var archive := AiMapElitesArchive.new(
		int(data.get("bins_x", DEFAULT_BINS)),
		int(data.get("bins_y", DEFAULT_BINS))
	)
	var cell_data: Dictionary = data.get("cells", {})
	for key in cell_data.keys():
		var row: Dictionary = cell_data[key]
		archive.cells[String(key)] = {
			"fitness": float(row.get("fitness", 0.0)),
			"evaluations": int(row.get("evaluations", 0)),
			"descriptor": row.get("descriptor", {}),
			"genome": AiGenomeScript.from_dict(row.get("genome", {})),
		}
	return archive

static func _bin(value: float, bins: int) -> int:
	var v := clampf(value, 0.0, 0.999999)
	return int(floor(v * float(bins)))
