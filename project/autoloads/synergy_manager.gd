extends Node

signal synergy_changed()

# Track trait counts across all buildings
var _trait_counts: Dictionary = {}  # TraitData.TraitType -> int
var _active_synergies: Dictionary = {}  # TraitData.TraitType -> tier (1-3)
var _cross_synergies: Array = []  # ["elemental_master", "elemental_lord"]

# Synergy thresholds
const TIER_1_COUNT := 2
const TIER_2_COUNT := 4
const TIER_3_COUNT := 6

# Synergy bonuses
const TIER_1_BONUS := 0.2   # +20%
const TIER_2_BONUS := 0.5   # +50% + special
const TIER_3_BONUS := 1.0   # +100% + game changer

func add_trait(trait_type: int) -> void:
	if not _trait_counts.has(trait_type):
		_trait_counts[trait_type] = 0
	_trait_counts[trait_type] += 1
	_recalculate()

func remove_trait(trait_type: int) -> void:
	if _trait_counts.has(trait_type):
		_trait_counts[trait_type] -= 1
		if _trait_counts[trait_type] <= 0:
			_trait_counts.erase(trait_type)
	_recalculate()

func get_trait_count(trait_type: int) -> int:
	return _trait_counts.get(trait_type, 0)

func get_synergy_tier(trait_type: int) -> int:
	return _active_synergies.get(trait_type, 0)

func get_active_synergies() -> Dictionary:
	return _active_synergies.duplicate()

func get_cross_synergies() -> Array:
	return _cross_synergies.duplicate()

func get_dps_multiplier(trait_type: int) -> float:
	var tier := get_synergy_tier(trait_type)
	match tier:
		1: return 1.0 + TIER_1_BONUS
		2: return 1.0 + TIER_2_BONUS
		3: return 1.0 + TIER_3_BONUS
	# Cross synergy bonus
	var bonus := 1.0
	if "elemental_master" in _cross_synergies:
		bonus += 0.15
	if "elemental_lord" in _cross_synergies:
		bonus += 0.30
	return bonus

func get_special_effects(trait_type: int) -> Dictionary:
	var tier := get_synergy_tier(trait_type)
	var effects := {}
	match trait_type:
		TraitData.TraitType.FIRE:
			if tier >= 2:
				effects["burn_dps"] = 3.0  # DoT per second
			if tier >= 3:
				effects["explosion_on_kill"] = true  # Chain explosion
		TraitData.TraitType.ICE:
			if tier >= 1:
				effects["slow_percent"] = 0.15 * tier  # Movement slow
			if tier >= 2:
				effects["freeze_chance"] = 0.1  # Stun
			if tier >= 3:
				effects["blizzard"] = true  # AoE slow field
		TraitData.TraitType.POISON:
			if tier >= 1:
				effects["poison_dps"] = 2.0 * tier  # DoT
			if tier >= 2:
				effects["spread_on_death"] = true  # Spread to nearby
			if tier >= 3:
				effects["armor_shred"] = 0.3  # -30% enemy HP
		TraitData.TraitType.ELECTRIC:
			if tier >= 1:
				effects["chain_count"] = tier  # Chain lightning
			if tier >= 2:
				effects["stun_chance"] = 0.08  # Brief stun
			if tier >= 3:
				effects["overcharge"] = true  # Double attack speed burst
		TraitData.TraitType.FORTIFY:
			if tier >= 1:
				effects["hp_bonus"] = 0.2 * tier  # Building HP
			if tier >= 2:
				effects["regen"] = 2.0  # HP/sec
			if tier >= 3:
				effects["thorns"] = true  # Reflect damage
	return effects

func _recalculate() -> void:
	_active_synergies.clear()
	_cross_synergies.clear()

	for trait_type in _trait_counts:
		var count: int = _trait_counts[trait_type]
		if count >= TIER_3_COUNT:
			_active_synergies[trait_type] = 3
		elif count >= TIER_2_COUNT:
			_active_synergies[trait_type] = 2
		elif count >= TIER_1_COUNT:
			_active_synergies[trait_type] = 1

	# Cross synergies: count distinct active element types (excluding FORTIFY)
	var element_count := 0
	for trait_type in _active_synergies:
		if trait_type != TraitData.TraitType.FORTIFY:
			element_count += 1

	if element_count >= 4:
		_cross_synergies.append("elemental_lord")
	elif element_count >= 3:
		_cross_synergies.append("elemental_master")

	synergy_changed.emit()

func reset() -> void:
	_trait_counts.clear()
	_active_synergies.clear()
	_cross_synergies.clear()
