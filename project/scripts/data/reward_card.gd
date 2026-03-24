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
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.LEGENDARY: return "Legendary"
	return ""

static func generate_pool(wave: int) -> Array:
	var pool: Array = []

	# Common cards
	pool.append(_make_mineral("Mineral Cache", 50, Rarity.COMMON))
	pool.append(_make_mineral("Mineral Vein", 80, Rarity.COMMON))
	pool.append(_make_stat("Fortified Walls", "All buildings +15% HP", EffectType.BUILDING_HEAL, 0.15, Rarity.COMMON))
	pool.append(_make_stat("Sharp Blades", "All units +10% DPS", EffectType.UNIT_BUFF, 0.1, Rarity.COMMON))

	# Trait cards (common)
	for t in [TraitData.TraitType.FIRE, TraitData.TraitType.ICE, TraitData.TraitType.POISON,
			TraitData.TraitType.ELECTRIC, TraitData.TraitType.FORTIFY]:
		var tname: String = TraitData.get_trait_name(t)
		var card := RewardCard.new()
		card.card_name = tname + " Essence"
		card.description = "Grant " + tname + " trait to a random tower"
		card.rarity = Rarity.COMMON
		card.effect_type = EffectType.TRAIT_GRANT
		card.trait_type = t
		pool.append(card)

	# Rare cards (wave 3+)
	if wave >= 3:
		pool.append(_make_mineral("Mineral Surge", 150, Rarity.RARE))
		pool.append(_make_stat("Iron Fortress", "All buildings +30% HP", EffectType.BUILDING_HEAL, 0.3, Rarity.RARE))
		pool.append(_make_stat("War Drums", "All units +25% DPS", EffectType.UNIT_BUFF, 0.25, Rarity.RARE))

	# Legendary cards (wave 5+)
	if wave >= 5:
		pool.append(_make_mineral("Motherlode", 300, Rarity.LEGENDARY))
		pool.append(_make_stat("Titan's Blessing", "All buildings +50% HP + heal", EffectType.BUILDING_HEAL, 0.5, Rarity.LEGENDARY))
		pool.append(_make_stat("Berserker Rage", "All units +50% DPS", EffectType.UNIT_BUFF, 0.5, Rarity.LEGENDARY))

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

static func _make_mineral(n: String, amount: float, r: Rarity) -> RewardCard:
	var card := RewardCard.new()
	card.card_name = n
	card.description = "+%d minerals" % [int(amount)]
	card.rarity = r
	card.effect_type = EffectType.MINERAL_BONUS
	card.effect_value = amount
	return card

static func _make_stat(n: String, desc: String, etype: EffectType, val: float, r: Rarity) -> RewardCard:
	var card := RewardCard.new()
	card.card_name = n
	card.description = desc
	card.rarity = r
	card.effect_type = etype
	card.effect_value = val
	return card
