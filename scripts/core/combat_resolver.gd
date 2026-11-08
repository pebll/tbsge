class_name CombatResolver
extends RefCounted

const StatusEffects = preload("res://scripts/effects/status_effects.gd")
const TerrainRules = preload("res://scripts/terrain/terrain_rules.gd")

const MODE_MELEE := "melee"
const MODE_RANGED := "ranged"

## Per-hit stdout trace. Off by default (sims run thousands of combats, some on worker
## threads); set CombatResolver.quiet = false while debugging a fight.
static var quiet: bool = true

static func _pick_next_attacker(
	legion: Legion,
	attacked: Dictionary,
	mode: String,
	distance: int
) -> Unit:
	if legion == null:
		return null
	for u in legion.units:
		if attacked.has(u):
			continue
		if _unit_can_strike(u, mode, distance):
			return u
	return null

static func _unit_can_strike(unit: Unit, mode: String, distance: int) -> bool:
	if unit == null:
		return false
	if mode == MODE_RANGED:
		return unit.attack_range >= distance and unit.ranged_attack > 0
	return true

static func _strike_damage(unit: Unit, mode: String) -> float:
	if mode == MODE_RANGED:
		return float(unit.ranged_attack)
	return float(unit.attack)

static func resolve_combat(
	attacking_legion: Legion,
	defending_legion: Legion,
	rng_seed: int = 0,
	options: Dictionary = {}
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rng_seed)

	var mode: String = String(options.get("mode", MODE_MELEE))
	var distance: int = int(options.get("distance", 1))

	var hits: Array = []
	var deaths: Array = []
	var status_events: Array = []
	var with_statuses := StatusEffects.any_statuses(attacking_legion, defending_legion)
	# Terrain each side stands on (TerrainRules.combat_options); empty = no terrain effects.
	var terrain_of := {
		attacking_legion: String(options.get("attacker_terrain", "")),
		defending_legion: String(options.get("defender_terrain", "")),
	}
	var with_terrain := not (String(terrain_of[attacking_legion]).is_empty() and String(terrain_of[defending_legion]).is_empty())

	# Track which specific Unit objects already attacked (no unit hits twice per combat).
	var attacked := {}

	var current_attacker_legion: Legion = attacking_legion
	var current_defender_legion: Legion = defending_legion

	var hit_index := 0

	while true:
		# Stop if there's nobody to hit.
		if current_defender_legion == null or current_defender_legion.units.size() == 0:
			break
		if current_attacker_legion == null or current_attacker_legion.units.size() == 0:
			break

		# Pick attacker; if this side is exhausted, let the other side "drain" its remaining attackers.
		var attacker_unit := _pick_next_attacker(current_attacker_legion, attacked, mode, distance)
		if attacker_unit == null:
			# Current side has no remaining attackers. If the other side can still attack, keep it as attacker.
			var other_next := _pick_next_attacker(current_defender_legion, attacked, mode, distance)
			if other_next == null:
				break
			# Swap roles (drain).
			var tmp_d := current_defender_legion
			current_defender_legion = current_attacker_legion
			current_attacker_legion = tmp_d
			attacker_unit = other_next
			# Re-check there's still a valid target.
			if current_defender_legion.units.size() == 0:
				break

		# Pick a random target among currently alive units.
		var target_index := rng.randi_range(0, current_defender_legion.units.size() - 1)
		var target_unit: Unit = current_defender_legion.units[target_index]

		var raw_damage := _strike_damage(attacker_unit, mode)
		if with_statuses:
			raw_damage = StatusEffects.strike_damage(
				current_attacker_legion, attacker_unit, current_defender_legion, target_unit, mode, raw_damage
			)
		if with_terrain:
			raw_damage = TerrainRules.modify_strike(
				attacker_unit, String(terrain_of.get(current_attacker_legion, "")),
				target_unit, String(terrain_of.get(current_defender_legion, "")), mode, raw_damage
			)
		var shield_result: Dictionary
		if with_statuses and StatusEffects.pierces(attacker_unit):
			# Pierce: the strike ignores the shield and breaks it.
			target_unit.shield_remaining = 0
			shield_result = {"applied": maxf(0.0, raw_damage), "absorbed": 0.0}
		else:
			shield_result = target_unit.absorb_damage(raw_damage)
		var damage: float = shield_result["applied"]
		var shield_absorbed: float = shield_result["absorbed"]
		var hp_before: float = float(target_unit.current_health)
		target_unit.current_health -= damage
		var hp_after: float = float(target_unit.current_health)
		var hp_lost: float = clampf(hp_before - maxf(0.0, hp_after), 0.0, hp_before)

		var hit_log := "Hit #%d: %s -> %s for %d" % [
			hit_index,
			current_attacker_legion.unit_type,
			current_defender_legion.unit_type,
			int(damage),
		]
		if mode == MODE_RANGED:
			hit_log += " [ranged d=%d]" % distance
		if shield_absorbed > 0.0:
			hit_log += " (%d absorbed by shield)" % int(shield_absorbed)
		hit_log += " (target hp %d/%d)" % [
			int(max(0.0, target_unit.current_health)),
			int(target_unit.max_health),
		]
		if not quiet:
			print(hit_log)

		hits.append({
			"hit_index": hit_index,
			"attacker_legion": current_attacker_legion,
			"defender_legion": current_defender_legion,
			"attacker": attacker_unit,
			"target": target_unit,
			"raw_damage": raw_damage,
			"shield_absorbed": shield_absorbed,
			"damage": damage,
			"target_hp_before": hp_before,
			"target_hp_after": hp_after,
			"hp_lost": hp_lost,
			"combat_mode": mode,
			"distance": distance,
		})

		attacked[attacker_unit] = true
		if with_statuses:
			var hit_events: Array = StatusEffects.after_hit(hits[hits.size() - 1])
			# Also on the hit row, so playback can show lifesteal / poison on that strike.
			hits[hits.size() - 1]["status_events"] = hit_events
			status_events.append_array(hit_events)

		if target_unit.current_health <= 0:
			# Dies immediately and will never attack later.
			current_defender_legion.units.erase(target_unit)
			deaths.append({
				"hit_index": hit_index,
				"legion": current_defender_legion,
				"unit": target_unit,
			})
			if with_statuses:
				status_events.append_array(StatusEffects.after_death(current_defender_legion, target_unit))

		hit_index += 1

		# Prefer alternation: swap after each hit.
		# Next loop will "drain" if the next attacker side has no eligible attackers.
		var tmp := current_attacker_legion
		current_attacker_legion = current_defender_legion
		current_defender_legion = tmp

	return {
		"hits": hits,
		"deaths": deaths,
		## Effects triggered by status hooks during this fight (StatusEffects event shape).
		"status_events": status_events,
		"combat_mode": mode,
		"distance": distance,
	}
