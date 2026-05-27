class_name CombatResolver
extends RefCounted

static func _pick_next_attacker(legion: Legion, attacked: Dictionary) -> Unit:
	if legion == null:
		return null
	for u in legion.units:
		if not attacked.has(u):
			return u
	return null

static func resolve_combat(attacking_legion: Legion, defending_legion: Legion, rng_seed: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rng_seed)

	var hits: Array = []
	var deaths: Array = []

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
		var attacker_unit := _pick_next_attacker(current_attacker_legion, attacked)
		if attacker_unit == null:
			# Current side has no remaining attackers. If the other side can still attack, keep it as attacker.
			var other_next := _pick_next_attacker(current_defender_legion, attacked)
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

		var damage := float(attacker_unit.attack)
		target_unit.current_health -= damage

		print("Hit #%d: %s -> %s for %d (target hp %d/%d)" % [
			hit_index,
			current_attacker_legion.unit_type,
			current_defender_legion.unit_type,
			int(damage),
			int(max(0.0, target_unit.current_health)),
			int(target_unit.max_health),
		])

		hits.append({
			"hit_index": hit_index,
			"attacker_legion": current_attacker_legion,
			"defender_legion": current_defender_legion,
			"attacker": attacker_unit,
			"target": target_unit,
			"damage": damage,
		})

		attacked[attacker_unit] = true

		if target_unit.current_health <= 0:
			# Dies immediately and will never attack later.
			current_defender_legion.units.erase(target_unit)
			current_defender_legion.unit_count = current_defender_legion.units.size()
			deaths.append({
				"hit_index": hit_index,
				"legion": current_defender_legion,
				"unit": target_unit,
			})

		hit_index += 1

		# Prefer alternation: swap after each hit.
		# Next loop will "drain" if the next attacker side has no eligible attackers.
		var tmp := current_attacker_legion
		current_attacker_legion = current_defender_legion
		current_defender_legion = tmp

	return {
		"hits": hits,
		"deaths": deaths,
	}

