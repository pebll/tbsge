class_name AiActionScorer
extends RefCounted

## Estimates net HP delta for a candidate action this activation.
## Score ≈ enemy_hp_lost + own_hp_gained - own_hp_lost.

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const ActionParams = preload("res://scripts/actions/action_params.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")

static func score_action(
	session,
	legion: Legion,
	action_id: String,
	to_coords: Vector2i
) -> float:
	match action_id:
		"melee_attack":
			return _score_combat(session, legion, to_coords, CombatResolver.MODE_MELEE, 1)
		"ranged_attack":
			var dist := HexPathfinder.hex_distance(legion.tile_coords, to_coords)
			return _score_combat(session, legion, to_coords, CombatResolver.MODE_RANGED, dist)
		"self_heal", "heal_ally":
			return float(_estimate_heal(session, legion, action_id, to_coords))
		"teleport":
			return _score_teleport(session, legion, to_coords)
		_:
			return 0.0

static func _score_teleport(session, legion: Legion, to_coords: Vector2i) -> float:
	## Prefer blinks that enable a fight, then that close on soft targets.
	var score := 0.0
	var enemies: Array = []
	for L in session.legions:
		if L.team_id != legion.team_id and not L.units.is_empty():
			enemies.append(L)
	if enemies.is_empty():
		return -INF

	# Simulate standing at destination for target checks via temporary coords.
	var old := legion.tile_coords
	legion.tile_coords = to_coords
	var tile_old: Tile = session.grid.get(old)
	var tile_new: Tile = session.grid.get(to_coords)
	var prev_new_legion = tile_new.legion if tile_new else null
	if tile_old and tile_old.legion == legion:
		tile_old.legion = null
	if tile_new:
		tile_new.legion = legion

	var melee_targets: Array = session.get_action_targets(legion, "melee_attack")
	var ranged_targets: Array = session.get_action_targets(legion, "ranged_attack")
	if not melee_targets.is_empty() or not ranged_targets.is_empty():
		score += 20.0
		for t in melee_targets:
			score += 5.0 + _focus_hp_bonus(session.get_legion_at(t))
		for t in ranged_targets:
			score += 4.0 + _focus_hp_bonus(session.get_legion_at(t))
	else:
		# Closer to preferred enemy is still useful.
		var best_close := INF
		for e in enemies:
			best_close = minf(best_close, float(HexPathfinder.hex_distance(to_coords, e.tile_coords)))
		score += 8.0 - best_close

	# Restore occupancy.
	legion.tile_coords = old
	if tile_old:
		tile_old.legion = legion
	if tile_new:
		tile_new.legion = prev_new_legion
	return score

static func _focus_hp_bonus(target: Legion) -> float:
	if target == null:
		return 0.0
	var bonus := 0.0
	if not is_frontline(target):
		bonus += 3.0
	var hp := 0.0
	for u in target.units:
		if u:
			hp += float(u.current_health)
	bonus += 4.0 / maxf(1.0, hp)
	return bonus

static func _score_combat(
	session,
	attacker: Legion,
	defender_coords: Vector2i,
	mode: String,
	distance: int
) -> float:
	var defender: Legion = session.get_legion_at(defender_coords)
	if defender == null:
		return -INF
	var est := _estimate_combat_damage(attacker, defender, mode, distance)
	return float(est["enemy_loss"]) - float(est["own_loss"])

static func _estimate_combat_damage(
	attacker: Legion,
	defender: Legion,
	mode: String,
	distance: int
) -> Dictionary:
	# Approximate alternating strikes using living unit counts / attack power.
	var atk_units: Array = []
	for u in attacker.units:
		if u == null:
			continue
		if mode == CombatResolver.MODE_RANGED:
			if u.attack_range >= distance and u.ranged_attack > 0:
				atk_units.append({"dmg": float(u.ranged_attack), "hp": float(u.current_health)})
		else:
			atk_units.append({"dmg": float(u.attack), "hp": float(u.current_health)})

	var def_units: Array = []
	for u in defender.units:
		if u == null:
			continue
		if mode == CombatResolver.MODE_RANGED:
			# Defender can return fire only if they have ranged that reaches.
			if u.attack_range >= distance and u.ranged_attack > 0:
				def_units.append({"dmg": float(u.ranged_attack), "hp": float(u.current_health)})
			else:
				def_units.append({"dmg": 0.0, "hp": float(u.current_health)})
		else:
			def_units.append({"dmg": float(u.attack), "hp": float(u.current_health)})

	var enemy_loss := 0.0
	var own_loss := 0.0
	var ai := 0
	var di := 0
	var side_atk := true
	var guard := 0
	while guard < 64:
		guard += 1
		_prune_dead(atk_units)
		_prune_dead(def_units)
		if atk_units.is_empty() or def_units.is_empty():
			break
		if side_atk:
			if ai >= atk_units.size():
				side_atk = false
				continue
			var dmg: float = float(atk_units[ai]["dmg"])
			ai += 1
			if dmg <= 0.0:
				side_atk = false
				continue
			var dealt := _apply_dmg_to_front(def_units, dmg)
			enemy_loss += dealt
			side_atk = false
		else:
			if di >= def_units.size():
				break
			var dmg2: float = float(def_units[di]["dmg"])
			di += 1
			if dmg2 <= 0.0:
				side_atk = true
				continue
			var dealt2 := _apply_dmg_to_front(atk_units, dmg2)
			own_loss += dealt2
			side_atk = true
		if ai >= atk_units.size() and di >= def_units.size():
			break
	return {"enemy_loss": enemy_loss, "own_loss": own_loss}

static func _apply_dmg_to_front(units: Array, dmg: float) -> float:
	if units.is_empty() or dmg <= 0.0:
		return 0.0
	var hp: float = float(units[0]["hp"])
	var dealt: float = minf(hp, dmg)
	units[0]["hp"] = hp - dealt
	return dealt

static func _prune_dead(units: Array) -> void:
	var i := 0
	while i < units.size():
		if float(units[i]["hp"]) <= 0.0:
			units.remove_at(i)
		else:
			i += 1

static func _estimate_heal(session, legion: Legion, action_id: String, to_coords: Vector2i) -> int:
	var action = ActionDefs.get_def(action_id)
	if action == null:
		return 0
	var heal_amount := ActionParams.resolve_int(legion, action, "heal_amount", action.heal_amount)
	var target: Legion = legion
	if action_id == "heal_ally":
		target = session.get_legion_at(to_coords)
	if target == null:
		return 0
	var missing_total := 0
	for tu in target.units:
		if tu:
			missing_total += maxi(0, int(tu.max_health) - int(tu.current_health))
	var potential := heal_amount * legion.units.size()
	return mini(missing_total, potential)

static func _total_hp(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += float(u.current_health)
	return t

static func is_frontline(legion: Legion) -> bool:
	if legion == null:
		return true
	var ids := ActionDefs.legion_action_ids(legion)
	var has_ranged := "ranged_attack" in ids
	var has_heal := "heal_ally" in ids or "self_heal" in ids
	var has_melee := "melee_attack" in ids
	if has_ranged and not has_melee:
		return false
	if has_heal and has_ranged:
		return false
	if has_heal and not has_melee:
		return false
	return true
