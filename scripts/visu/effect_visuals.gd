extends RefCounted

## One lookup for how an effect looks (status or unit trait): icon, emoji placeholder,
## colour, name and one-line rule. Status looks come from data/status/*.tres; trait looks
## live here (names/rules from the keyword glossary) until traits get definition files.

const StatusDefs = preload("res://scripts/effects/status_defs.gd")
const StatusEffects = preload("res://scripts/effects/status_effects.gd")
const UnitTraits = preload("res://scripts/effects/unit_traits.gd")

const TRAIT_COLORS := {
	"regeneration": Color(0.30, 0.66, 0.36),
	"lifesteal": Color(0.62, 0.12, 0.22),
	"pierce": Color(0.55, 0.55, 0.62),
	"poison_on_hit": Color(0.36, 0.62, 0.22),
	"flying": Color(0.42, 0.62, 0.86),
}
## Placeholders until the icons exist.
const TRAIT_EMOJI := {
	"flying": "🪶",
	"regeneration": "🌿",
	"lifesteal": "🩸",
	"pierce": "🗡️",
	"poison_on_hit": "🐍",
}

static func look(effect_id: String) -> Dictionary:
	var def = StatusDefs.get_def(effect_id)
	var label := StatusEffects.label(effect_id)
	var col: Color = TRAIT_COLORS.get(effect_id, Color(0.5, 0.4, 0.7))
	var icon: Texture2D = null
	var emoji: String = String(TRAIT_EMOJI.get(effect_id, ""))
	var rule := ""
	if def != null:
		col = def.color
		icon = def.icon
		emoji = String(def.emoji)
		rule = String(def.description)
	elif effect_id in UnitTraits.ALL:
		rule = KeywordDefs.get_definition(UnitTraits.keyword_id(effect_id))
	var mark := emoji if not emoji.is_empty() else label.left(1).to_upper()
	return {"color": col, "icon": icon, "emoji": emoji, "mark": mark, "label": label, "rule": rule}

## Abilities list: one "emoji Name: rule" line per trait the unit type has.
static func ability_lines_for_type(type_id: String) -> PackedStringArray:
	return _lines(UnitTraits.for_type(type_id))

static func ability_lines_for_legion(legion: Legion) -> PackedStringArray:
	return _lines(UnitTraits.for_legion(legion))

static func _lines(ids: Array[String]) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		var l := look(id)
		out.append("%s %s: %s" % [l["mark"], l["label"], l["rule"]])
	return out
