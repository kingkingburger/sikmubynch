extends Node

const TraitData := preload("res://scripts/data/trait_data.gd")

signal combat_event_triggered(event_name: String, description: String)
signal choice_event_triggered(event_name: String, description: String, choices: Array)

# --- Combat Events (auto-triggered during waves) ---
enum CombatEvent { MINERAL_RUSH, SPEED_SURGE, ENEMY_ENRAGE, BUILDING_REGEN, BONUS_WAVE }

var _active_combat_effects: Dictionary = {}

func trigger_random_combat_event() -> void:
	var events := [
		CombatEvent.MINERAL_RUSH,
		CombatEvent.SPEED_SURGE,
		CombatEvent.ENEMY_ENRAGE,
		CombatEvent.BUILDING_REGEN,
		CombatEvent.BONUS_WAVE,
	]
	var event: CombatEvent = events[randi() % events.size()]
	_apply_combat_event(event)

func _apply_combat_event(event: CombatEvent) -> void:
	match event:
		CombatEvent.MINERAL_RUSH:
			GameManager.add_minerals(40)
			combat_event_triggered.emit("Mineral Rush", "Bonus +40 minerals!")
		CombatEvent.SPEED_SURGE:
			_active_combat_effects["speed_surge"] = 1.3  # 30% faster enemies
			combat_event_triggered.emit("Speed Surge", "Enemies move 30% faster this wave!")
		CombatEvent.ENEMY_ENRAGE:
			_active_combat_effects["enemy_enrage"] = 1.5  # 50% more enemy DPS
			combat_event_triggered.emit("Enemy Enrage", "Enemies deal 50% more damage!")
		CombatEvent.BUILDING_REGEN:
			_heal_all_buildings(0.3)
			combat_event_triggered.emit("Field Repair", "All buildings healed 30%!")
		CombatEvent.BONUS_WAVE:
			combat_event_triggered.emit("Bonus Wave", "Double mineral rewards this wave!")
			_active_combat_effects["bonus_minerals"] = 2.0

func get_enemy_speed_mult() -> float:
	return _active_combat_effects.get("speed_surge", 1.0)

func get_enemy_dps_mult() -> float:
	return _active_combat_effects.get("enemy_enrage", 1.0)

func get_mineral_mult() -> float:
	return _active_combat_effects.get("bonus_minerals", 1.0)

func clear_combat_effects() -> void:
	_active_combat_effects.clear()

func _heal_all_buildings(percent: float) -> void:
	var buildings := get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if is_instance_valid(b) and b.has_method("take_damage"):
			var max_hp: float = b.get_effective_max_hp() if b.has_method("get_effective_max_hp") else 100.0
			b.current_hp = minf(b.current_hp + max_hp * percent, max_hp)

# --- Choice Events (between waves, player picks) ---
enum ChoiceEvent { GAMBLE, SACRIFICE, EMPOWER, TRADE, CHALLENGE }

func trigger_random_choice_event() -> void:
	var events := [
		ChoiceEvent.GAMBLE,
		ChoiceEvent.SACRIFICE,
		ChoiceEvent.EMPOWER,
		ChoiceEvent.TRADE,
		ChoiceEvent.CHALLENGE,
	]
	var event: ChoiceEvent = events[randi() % events.size()]
	_present_choice_event(event)

func _present_choice_event(event: ChoiceEvent) -> void:
	match event:
		ChoiceEvent.GAMBLE:
			choice_event_triggered.emit("Gamble",
				"Risk minerals for a bigger reward?",
				[{"label": "Bet 50 → Win 150", "id": "gamble_accept"},
				 {"label": "Pass", "id": "gamble_pass"}])
		ChoiceEvent.SACRIFICE:
			choice_event_triggered.emit("Sacrifice",
				"Sacrifice a building for power?",
				[{"label": "Sacrifice → +200 minerals", "id": "sacrifice_accept"},
				 {"label": "Keep all", "id": "sacrifice_pass"}])
		ChoiceEvent.EMPOWER:
			choice_event_triggered.emit("Empower",
				"Spend minerals to buff all units?",
				[{"label": "Pay 80 → Units +30% DPS (permanent)", "id": "empower_accept"},
				 {"label": "Save minerals", "id": "empower_pass"}])
		ChoiceEvent.TRADE:
			choice_event_triggered.emit("Trade",
				"A merchant offers a deal.",
				[{"label": "Pay 60 → Random trait essence", "id": "trade_accept"},
				 {"label": "No thanks", "id": "trade_pass"}])
		ChoiceEvent.CHALLENGE:
			choice_event_triggered.emit("Challenge",
				"Face a harder wave for better rewards?",
				[{"label": "Accept Challenge (+50% enemies, +100% rewards)", "id": "challenge_accept"},
				 {"label": "Normal wave", "id": "challenge_pass"}])

func resolve_choice(choice_id: String) -> String:
	match choice_id:
		"gamble_accept":
			if GameManager.spend_minerals(50):
				if randf() < 0.6:
					GameManager.add_minerals(150)
					return "Won 150 minerals!"
				else:
					return "Lost the bet..."
			return "Not enough minerals!"
		"gamble_pass":
			return "Played it safe."
		"sacrifice_accept":
			var buildings := get_tree().get_nodes_in_group("buildings")
			var candidates: Array = []
			for b in buildings:
				if is_instance_valid(b) and b.has_method("demolish") and not b.is_in_group("hq"):
					candidates.append(b)
			if candidates.size() > 0:
				var target = candidates[randi() % candidates.size()]
				target.die()
				GameManager.add_minerals(200)
				return "Building sacrificed! +200 minerals"
			return "No buildings to sacrifice!"
		"sacrifice_pass":
			return "Buildings preserved."
		"empower_accept":
			if GameManager.spend_minerals(80):
				_active_combat_effects["unit_dps_perm"] = _active_combat_effects.get("unit_dps_perm", 0.0) + 0.3
				return "Units empowered! +30% DPS"
			return "Not enough minerals!"
		"empower_pass":
			return "Minerals saved."
		"trade_accept":
			if GameManager.spend_minerals(60):
				var trait_type: int = randi() % 5
				SynergyManager.add_trait(trait_type)
				return "Gained %s trait!" % TraitData.get_trait_name(trait_type)
			return "Not enough minerals!"
		"trade_pass":
			return "Maybe next time."
		"challenge_accept":
			_active_combat_effects["challenge_enemy_mult"] = 1.5
			_active_combat_effects["challenge_reward_mult"] = 2.0
			return "Challenge accepted! Brace yourself!"
		"challenge_pass":
			return "Normal wave incoming."
	return ""

func get_unit_dps_perm_bonus() -> float:
	return _active_combat_effects.get("unit_dps_perm", 0.0)

func add_unit_dps_perm_bonus(amount: float) -> void:
	_active_combat_effects["unit_dps_perm"] = get_unit_dps_perm_bonus() + amount

func get_challenge_enemy_mult() -> float:
	return _active_combat_effects.get("challenge_enemy_mult", 1.0)

func get_challenge_reward_mult() -> float:
	return _active_combat_effects.get("challenge_reward_mult", 1.0)

func clear_challenge() -> void:
	_active_combat_effects.erase("challenge_enemy_mult")
	_active_combat_effects.erase("challenge_reward_mult")

func reset() -> void:
	_active_combat_effects.clear()
