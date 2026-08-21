class_name AiMapElitesArchive
extends RefCounted

## 2D MAP-Elites grid over aggression × risk.

const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")

var bins_x: int = 5
var bins_y: int = 5
## cell_key -> { fitness, genome, descriptor, evaluations }
var cells: Dictionary = {}

func _init(p_bins_x: int = 5, p_bins_y: int = 5) -> void:
	bins_x = maxi(1, p_bins_x)
	bins_y = maxi(1, p_bins_y)

func cell_key(descriptor: Dictionary) -> String:
	var ax := _bin(float(descriptor.get("aggression", 0.0)), bins_x)
	var ay := _bin(float(descriptor.get("risk", 0.0)), bins_y)
	return "%d_%d" % [ax, ay]

func try_insert(genome: AiGenome, fitness: float, descriptor: Dictionary) -> bool:
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

func random_elite(rng: RandomNumberGenerator) -> AiGenome:
	var keys: Array = cells.keys()
	if keys.is_empty():
		return AiGenomeScript.from_hand_v1()
	var key = keys[rng.randi() % keys.size()]
	var row: Dictionary = cells[key]
	var g: AiGenome = row["genome"]
	return g.duplicate_genome()

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

## Top elites by fitness, excluding an optional genome cell match by weights id.
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
		int(data.get("bins_x", 5)),
		int(data.get("bins_y", 5))
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
