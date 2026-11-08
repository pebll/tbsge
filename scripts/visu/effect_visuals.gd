extends RefCounted

## One lookup for how an effect looks (status or unit trait): icon, colour, letter.
## Status looks come from data/status/*.tres; trait looks live here until traits get
## their own definition files (see doc/design/effects_ux.md).

const StatusDefs = preload("res://scripts/effects/status_defs.gd")
const StatusEffects = preload("res://scripts/effects/status_effects.gd")

const TRAIT_COLORS := {
	"regeneration": Color(0.30, 0.66, 0.36),
	"lifesteal": Color(0.62, 0.12, 0.22),
	"pierce": Color(0.55, 0.55, 0.62),
	"poison_on_hit": Color(0.36, 0.62, 0.22),
	"flying": Color(0.42, 0.62, 0.86),
}

static func look(effect_id: String) -> Dictionary:
	var def = StatusDefs.get_def(effect_id)
	var label := StatusEffects.label(effect_id)
	var col: Color = TRAIT_COLORS.get(effect_id, Color(0.5, 0.4, 0.7))
	var icon: Texture2D = null
	if def != null:
		col = def.color
		icon = def.icon
	return {"color": col, "icon": icon, "letter": label.left(1).to_upper(), "label": label}
