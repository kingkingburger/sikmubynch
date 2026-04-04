class_name TraitData
extends Resource

enum TraitType { FIRE, ICE, POISON, ELECTRIC, FORTIFY }

static func get_trait_name(t: TraitType) -> String:
	match t:
		TraitType.FIRE: return "Fire"
		TraitType.ICE: return "Ice"
		TraitType.POISON: return "Poison"
		TraitType.ELECTRIC: return "Electric"
		TraitType.FORTIFY: return "Fortify"
	return ""

static func get_trait_color(t: TraitType) -> Color:
	match t:
		TraitType.FIRE: return Color(1.0, 0.3, 0.1)
		TraitType.ICE: return Color(0.3, 0.7, 1.0)
		TraitType.POISON: return Color(0.3, 0.9, 0.2)
		TraitType.ELECTRIC: return Color(0.9, 0.9, 0.2)
		TraitType.FORTIFY: return Color(0.7, 0.7, 0.8)
	return Color.WHITE
