extends RefCounted

## Counter tags: a small, fixed vocabulary of what a unit *is*. Authored per unit in
## data/units/*.tres (`tags`), defined for players in data/keyword_glossary.tres
## (keyword id "tag_<id>"), and read by tooltips now and by draft / tech generator / AI later.
## ranged / support / shielded / mobile follow from stats and are checked in
## tests/test_unit_tags.gd; armored / swarm / striker are design judgment (guidelines below).

const RANGED := "ranged"      ## can shoot (ranged attack)
const SUPPORT := "support"    ## heals, buffs allies or curses enemies
const SHIELDED := "shielded"  ## shield absorbs the first hit each turn
const ARMORED := "armored"    ## high HP per unit (about 16+)
const SWARM := "swarm"        ## many cheap units (about price 4 or less)
const STRIKER := "striker"    ## damage dealer: hits hard for its cost (assassin, demon, ogre, rider)
const MOBILE := "mobile"      ## 3+ AP or teleport
const FLYER := "flyer"        ## reserved: arrives with flying in 0.3

const ALL: Array[String] = [RANGED, SUPPORT, SHIELDED, ARMORED, SWARM, STRIKER, MOBILE, FLYER]

static func is_known(tag: String) -> bool:
	return tag in ALL

static func keyword_id(tag: String) -> String:
	return "tag_" + tag

static func label(tag: String) -> String:
	return KeywordDefs.get_label(keyword_id(tag))

static func for_type(type_id: String) -> Array[String]:
	var def: UnitDefinition = UnitDefs.get_def(type_id)
	var out: Array[String] = []
	if def != null:
		for t in def.tags:
			out.append(String(t))
	return out

## Union over the unit types present, in ALL order (stable for display).
static func for_legion(legion: Legion) -> Array[String]:
	var present := {}
	if legion != null:
		for type_id in legion.unit_types():
			for t in for_type(type_id):
				present[t] = true
	var out: Array[String] = []
	for t in ALL:
		if present.has(t):
			out.append(t)
	return out

static func has_tag(legion: Legion, tag: String) -> bool:
	return tag in for_legion(legion)

## "Ranged · Support"
static func labels_line(tags: Array[String]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for t in tags:
		parts.append(label(t))
	return " · ".join(parts)

## Tags then abilities, for the info panel and unit tooltips: "Ranged · Poison strikes".
static func descriptor_line_for_type(type_id: String) -> String:
	var UnitTraitsScript = load("res://scripts/effects/unit_traits.gd")
	var parts: PackedStringArray = PackedStringArray()
	for t in for_type(type_id):
		parts.append(label(t))
	for k in UnitTraitsScript.for_type(type_id):
		parts.append(UnitTraitsScript.label(k))
	return " · ".join(parts)

static func descriptor_line_for_legion(legion: Legion) -> String:
	var UnitTraitsScript = load("res://scripts/effects/unit_traits.gd")
	var parts: PackedStringArray = PackedStringArray()
	for t in for_legion(legion):
		parts.append(label(t))
	for k in UnitTraitsScript.for_legion(legion):
		parts.append(UnitTraitsScript.label(k))
	return " · ".join(parts)
