class_name RewardCard
extends RefCounted

const TraitData := preload("res://scripts/data/trait_data.gd")

enum Rarity { COMMON, RARE, LEGENDARY }
enum EffectType { TRAIT_GRANT, STAT_BUFF, MINERAL_BONUS, UNIT_BUFF, BUILDING_HEAL }

var card_name: String
var description: String
var rarity: Rarity
var effect_type: EffectType
var effect_value: float
var trait_type: int = -1  # For TRAIT_GRANT

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		Rarity.RARE: return Color(0.3, 0.5, 1.0)
		Rarity.LEGENDARY: return Color(1.0, 0.75, 0.1)
	return Color.WHITE

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return Locale.t("rarity_common")
		Rarity.RARE: return Locale.t("rarity_rare")
		Rarity.LEGENDARY: return Locale.t("rarity_legendary")
	return ""

static func generate_pool(wave: int) -> Array:
	var pool: Array = []

	# Common cards
	pool.append(_make_mineral("card_mineral_cache", 50, Rarity.COMMON))
	pool.append(_make_mineral("card_mineral_vein", 80, Rarity.COMMON))
	pool.append(_make_stat("card_fortified_walls", "card_building_hp", EffectType.BUILDING_HEAL, 0.15, Rarity.COMMON, 15))
	pool.append(_make_stat("card_sharp_blades", "card_unit_dps", EffectType.UNIT_BUFF, 0.1, Rarity.COMMON, 10))

	# Trait cards (common)
	var _trait_keys := {
		TraitData.TraitType.FIRE: "trait_fire",
		TraitData.TraitType.ICE: "trait_ice",
		TraitData.TraitType.POISON: "trait_poison",
		TraitData.TraitType.ELECTRIC: "trait_electric",
		TraitData.TraitType.FORTIFY: "trait_fortify",
	}
	for t in [TraitData.TraitType.FIRE, TraitData.TraitType.ICE, TraitData.TraitType.POISON,
			TraitData.TraitType.ELECTRIC, TraitData.TraitType.FORTIFY]:
		var tkey: String = _trait_keys[t]
		var tname: String = Locale.t(tkey)
		var card := RewardCard.new()
		card.card_name = tname + Locale.t("card_essence_suffix")
		card.description = Locale.t_fmt("card_trait_desc", [tname])
		card.rarity = Rarity.COMMON
		card.effect_type = EffectType.TRAIT_GRANT
		card.trait_type = t
		pool.append(card)

	# Rare cards (wave 3+)
	if wave >= 3:
		pool.append(_make_mineral("card_mineral_surge", 150, Rarity.RARE))
		pool.append(_make_stat("card_iron_fortress", "card_building_hp", EffectType.BUILDING_HEAL, 0.3, Rarity.RARE, 30))
		pool.append(_make_stat("card_war_drums", "card_unit_dps", EffectType.UNIT_BUFF, 0.25, Rarity.RARE, 25))

	# Legendary cards (wave 5+)
	if wave >= 5:
		pool.append(_make_mineral("card_motherlode", 300, Rarity.LEGENDARY))
		pool.append(_make_stat("card_titans_blessing", "card_building_hp_heal", EffectType.BUILDING_HEAL, 0.5, Rarity.LEGENDARY, 50))
		pool.append(_make_stat("card_berserker_rage", "card_unit_dps", EffectType.UNIT_BUFF, 0.5, Rarity.LEGENDARY, 50))

	return pool

static func pick_cards(wave: int, count: int = 3) -> Array:
	var pool := generate_pool(wave)
	var picks: Array = []
	for i in count:
		if pool.is_empty():
			break
		# Weighted random: legendary 5%, rare 25%, common 70%
		var roll := randf()
		var target_rarity := Rarity.COMMON
		if roll < 0.05:
			target_rarity = Rarity.LEGENDARY
		elif roll < 0.30:
			target_rarity = Rarity.RARE

		# Find matching rarity, fallback to any
		var candidates: Array = []
		for card in pool:
			if card.rarity == target_rarity:
				candidates.append(card)
		if candidates.is_empty():
			candidates = pool.duplicate()

		var pick: RewardCard = candidates[randi() % candidates.size()]
		picks.append(pick)
		pool.erase(pick)
	return picks

static func _make_mineral(name_key: String, amount: float, r: Rarity) -> RewardCard:
	var card := RewardCard.new()
	card.card_name = Locale.t(name_key)
	card.description = Locale.t_fmt("card_mineral_desc", [int(amount)])
	card.rarity = r
	card.effect_type = EffectType.MINERAL_BONUS
	card.effect_value = amount
	return card

static func _make_stat(name_key: String, desc_key: String, etype: EffectType, val: float, r: Rarity, pct: int = 0) -> RewardCard:
	var card := RewardCard.new()
	card.card_name = Locale.t(name_key)
	card.description = Locale.t_fmt(desc_key, [pct])
	card.rarity = r
	card.effect_type = etype
	card.effect_value = val
	return card
