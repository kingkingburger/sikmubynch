extends SceneTree

var failures: Array[String] = []
var checks := 0
var game
var gm
var flow
var spatial
var synergy
var events
var feel

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: ", label)

func fresh_game() -> void:
	change_scene_to_file("res://scenes/main/game.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game.set_process(false)
	game._wave_active = false
	game._spawn_queue.clear()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	game.enemies_alive = 0
	await process_frame
	spatial._grids["enemies"].clear()

func live_enemies() -> Array:
	return get_nodes_in_group("enemies").filter(func(enemy): return not enemy._dead)

func _run() -> void:
	gm = root.get_node("GameManager")
	flow = root.get_node("FlowField")
	spatial = root.get_node("SpatialGrid")
	synergy = root.get_node("SynergyManager")
	events = root.get_node("EventManager")
	feel = root.get_node("GameFeel")
	seed(20260908)
	await test_run_and_pathfinding()
	await test_pause_rewards_and_input()
	await test_rewards_and_synergies()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_run_and_pathfinding() -> void:
	await fresh_game()
	var wave = load("res://scripts/wave_director.gd")
	game.queue_enemy_spawn(wave.create_enemy_templates(2)[1], Vector3(110, 0, 110))
	game._wave_active = true
	game._process_spawn_queue()
	check(game.enemies_alive == 1, "normal spawn increments count")
	live_enemies()[0]._die()
	game._check_wave_completion()
	check(gm.wave_number == 1 and game._spawn_queue.size() == 2, "B01 pending split children prevent clear")
	game._process_spawn_queue()
	check(game.enemies_alive == 2 and live_enemies().size() == 2, "B01 split count matches living children")
	for enemy in live_enemies():
		enemy._die()
	await process_frame
	await process_frame
	check(gm.wave_number == 2 and game.enemies_alive == 0, "B01 clear only after all children die")
	game._check_wave_completion()
	check(gm.wave_number == 2, "B01 clear is not duplicated")

	await fresh_game()
	flow.set_obstacle(Vector2i(10, 10), true)
	flow.set_obstacle(Vector2i(10, 10), true)
	flow.set_obstacle(Vector2i(11, 10), true)
	flow.set_obstacle(Vector2i(10, 10), false)
	check(flow._obstacles.has(Vector2i(5, 5)), "B03 adjacent occupied tile stays blocked")
	flow.set_obstacle(Vector2i(11, 10), false)
	check(not flow._obstacles.has(Vector2i(5, 5)), "B03 last tile unblocks; duplicate registration is idempotent")
	for i in 10:
		flow.set_obstacle(Vector2i(20 + i, 20), true)
		game._on_restart()
		await process_frame
		await process_frame
		game = current_scene
		check(flow._obstacles.is_empty() and flow._world_obstacles.is_empty(), "B02 restart %d clears obstacles" % i)
		check(gm.wave_number == 1 and gm.minerals == 150 and not gm.is_game_over, "restart %d resets run state" % i)
		check(not flow._field.is_empty(), "restart %d recalculates directions" % i)

	await fresh_game()
	var unit = load("res://scenes/units/unit.tscn").instantiate()
	unit.data = load("res://scripts/data/unit_data.gd").new()
	unit.data.speed = 30.0
	unit.position = Vector3(40, 0, 40)
	game.add_child(unit)
	unit._patrol_target = Vector3(65, 0, 40)
	var first_cell = spatial._pos_to_cell(unit.global_position)
	for i in 60:
		await process_frame
	unit.set_physics_process(false)
	check(spatial._pos_to_cell(unit.global_position) != first_cell, "B04 fixture moved across cells")
	check(spatial.find_in_range(unit.global_position, "units", 0.5).has(unit), "B04 moving unit is searchable at current position")
	unit._die()
	check(not spatial.find_in_range(unit.global_position, "units", 0.5).has(unit), "B04 dead unit is removed")
	game._on_esc_title()
	await process_frame
	await process_frame
	for i in 600:
		await process_frame
	current_scene._on_start()
	await process_frame
	await process_frame
	check(gm.game_time < 0.1, "B16 title waiting time is excluded from new run")

func test_pause_rewards_and_input() -> void:
	await fresh_game()
	game._spawn_wave()
	var queued = game._spawn_queue.size()
	feel.toggle_pause()
	game._process(0.0)
	game._process_spawn_queue()
	check(game._spawn_queue.size() == queued and game.enemies_alive == 0, "B06 paused spawn queue is frozen")
	feel.hitstop(0.04)
	feel._process(0.0)
	check(Engine.time_scale == 0.0, "B06 hitstop cannot resume a paused game")
	game._toggle_esc_menu()
	game._on_esc_resume()
	check(feel.paused, "ESC resume preserves manual pause")
	feel.toggle_pause()
	check(not feel.paused, "manual pause resumes explicitly")
	feel.reset()
	game._process_spawn_queue()
	check(game.enemies_alive == 3, "B06 spawning resumes")
	var enemy = live_enemies()[0]
	enemy._attack_target = game._hq
	enemy._attack_timer = 0.0
	var hp = game._hq.current_hp
	feel.toggle_pause()
	enemy._physics_process(0.0)
	for i in 60:
		await process_frame
	check(game._hq.current_hp == hp, "B06 paused enemy cannot deal damage")

	await fresh_game()
	game._on_wave_cleared()
	var countdown = game._wave_countdown
	var before_time = gm.game_time
	for i in 660:
		game._process(1.0 / 60.0)
		await process_frame
	check(game._awaiting_card and not game._wave_active and game.enemies_alive == 0, "B05 unselected cards do not start next wave")
	check(game._wave_countdown == countdown and gm.game_time == before_time, "B05 card choice freezes run time and countdown")
	game._on_choice_event("Gamble", "Risk minerals for a bigger reward?", [{"label": "Pass", "id": "gamble_pass"}])
	check(game._ui._card_panel.visible and not game._ui._choice_panel.visible, "C02 only reward card is shown first")
	game._toggle_esc_menu()
	game._on_card_selected(0)
	check(game._awaiting_card, "ESC blocks reward callbacks behind menu")
	game._on_esc_resume()
	check(feel.paused and Engine.time_scale == 0.0, "ESC resume preserves reward pause")
	game._on_card_skip()
	check(not game._ui._card_panel.visible and game._ui._choice_panel.visible, "C02 choice appears after card skip")
	check(game._awaiting_choice and feel.paused, "C02 queued choice retains pause")
	game._on_choice_selected(-1)
	check(game._awaiting_choice, "invalid choice index is rejected")
	game._on_choice_selected(0)
	check(not game._awaiting_choice and not feel.paused, "choice completion resumes countdown")
	game._process(11.0)
	check(game._wave_active, "next wave starts after all selections finish")

	await fresh_game()
	var reward = load("res://scripts/data/reward_card.gd")
	game._pending_cards = [reward.generate_pool(1)[0]]
	game._awaiting_card = true
	feel.set_pause_reason("reward", true)
	var minerals = gm.minerals
	game._on_card_selected(-1)
	check(gm.minerals == minerals, "negative reward index is rejected")
	game._on_card_selected(0)
	game._on_card_selected(0)
	check(gm.minerals == minerals + 35, "reward can be applied only once")
	check(not feel.paused, "card selection resumes game")

	await fresh_game()
	var point = game._camera.unproject_position(Vector3(124.5, 0, 124.5))
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	game._input(press)
	check(not game._dragging, "UI-consumed press cannot start world drag")
	for state in ["reward", "choice", "esc", "game_over"]:
		game._awaiting_card = state == "reward"
		game._awaiting_choice = state == "choice"
		game._esc_visible = state == "esc"
		gm.is_game_over = state == "game_over"
		minerals = gm.minerals
		game._dragging = true
		game._input(press)
		game._unhandled_input(press)
		game._handle_left_click(point)
		game._try_drag_build(point)
		game._handle_right_click(point)
		check(gm.minerals == minerals and game._buildings_count == 1, "B07 %s blocks field mutations" % state)
		check(not game._dragging, "B07 %s cancels drag" % state)
	gm.is_game_over = false
	game._esc_visible = false
	game._awaiting_card = false
	game._awaiting_choice = false
	game._handle_left_click(point)
	check(gm.minerals == 140 and game._buildings_count == 2, "field input works after modal closes")

func spawn_enemy(pos: Vector3 = Vector3(100, 0, 100)):
	var wave = load("res://scripts/wave_director.gd")
	game.queue_enemy_spawn(wave.create_enemy_templates(1)[0], pos)
	game._process_spawn_queue()
	var enemy = live_enemies().back()
	enemy.set_physics_process(false)
	return enemy

func test_rewards_and_synergies() -> void:
	await fresh_game()
	var reward = load("res://scripts/data/reward_card.gd")
	game._apply_card(reward.generate_pool(1)[3])
	events.resolve_choice("empower_accept")
	check(is_equal_approx(events.get_unit_dps_perm_bonus(), 0.38), "B08 card and event permanent bonuses stack")
	events.clear_combat_effects()
	check(is_equal_approx(events.get_unit_dps_perm_bonus(), 0.38), "B08 wave cleanup preserves permanent bonus")
	game._on_restart()
	await process_frame
	await process_frame
	check(events.get_unit_dps_perm_bonus() == 0.0, "B08 new run resets permanent bonus")

	await fresh_game()
	for count in [1, 3, 5]:
		synergy.reset()
		for i in count:
			synergy.add_trait(0)
		var expected = {1: 1.2, 3: 1.5, 5: 2.0}[count]
		check(is_equal_approx(synergy.get_dps_multiplier(0), expected), "B09 base tier at %d essences" % count)
		synergy.add_trait(1)
		synergy.add_trait(2)
		check(is_equal_approx(synergy.get_dps_multiplier(0), expected + 0.15), "B09 three-element bonus at %d essences" % count)
		synergy.add_trait(3)
		check(is_equal_approx(synergy.get_dps_multiplier(0), expected + 0.3), "B09 four-element bonus at %d essences" % count)
	for count in [1, 3, 5]:
		synergy.reset()
		for i in count:
			synergy.add_trait(4)
		game._hq.current_hp = game._hq.get_effective_max_hp()
		var maximum = game._hq.current_hp
		game._hq._process(1.0 / 60.0)
		check(is_equal_approx(game._hq.current_hp, maximum), "B10 fortified HQ retains full HP at %d essences" % count)
		game._hq.current_hp -= 10.0
		game._hq._process(1.0)
		check(game._hq.current_hp > maximum - 10.0 and game._hq.current_hp <= maximum, "B10 HQ regenerates under effective limit")

	await fresh_game()
	game._hq.current_hp = 500.0
	game._apply_card(reward.generate_pool(1)[2])
	check(is_equal_approx(game._hq.get_effective_max_hp(), 1100.0), "B14 HP card increases maximum")
	check(is_equal_approx(game._hq.current_hp, 600.0), "B14 HP increase preserves missing HP")
	var tower = game.tower_scene.instantiate()
	tower.data = game._building_datas[1]
	tower.position = Vector3(124, 0, 124)
	tower.add_to_group("buildings")
	game.add_child(tower)
	check(is_equal_approx(tower.current_hp, 110.0), "B14 future buildings start with buffed full HP")
	tower.level_up()
	check(is_equal_approx(tower.get_effective_max_hp(), 143.0), "B14 level and HP reward multiply")
	game._hq.current_hp = 100.0
	var legendary = reward.generate_pool(5).filter(func(card): return card.heal_fraction > 0.0)[0]
	game._apply_card(legendary)
	check(is_equal_approx(game._hq.get_effective_max_hp(), 1450.0), "B14 maximum HP rewards accumulate")
	check(is_equal_approx(game._hq.current_hp, 957.5), "B14 legendary additionally heals 35 percent of new maximum")
	events.clear_combat_effects()
	check(is_equal_approx(game._hq.get_effective_max_hp(), 1450.0), "B14 maximum HP bonus survives wave cleanup")
	synergy.add_trait(4)
	check(is_equal_approx(game._hq.get_effective_max_hp(), 1740.0), "B14 fortify multiplies permanent HP bonus")
	await fresh_game()
	check(game._hq.get_effective_max_hp() == 1000.0, "B14 next run resets maximum HP bonus")
	var fire = reward.generate_pool(1)[4]
	game._apply_card(fire)
	check(synergy.get_trait_count(0) == 1 and get_nodes_in_group("buildings").size() == 1, "B15 global essence is valid without a tower")
	check(not fire.description.contains("랜덤 타워"), "B15 description does not promise a random target")
	synergy.add_trait(1)
	check(synergy.get_primary_attack_trait() == 0, "B15 tied essences retain first acquired element")
	synergy.add_trait(1)
	check(synergy.get_primary_attack_trait() == 1, "B15 leading essence changes common attack element")

	await fresh_game()
	events._apply_combat_event(events.CombatEvent.BONUS_WAVE)
	var enemy = spawn_enemy()
	var minerals = gm.minerals
	enemy._die()
	var orbs = game.get_children().filter(func(node): return node.get_script() == load("res://scenes/effects/mineral_orb.gd"))
	check(orbs.size() == 1 and orbs[0].amount == 6, "B11 normal game path creates doubled reward orb")
	events.clear_combat_effects()
	orbs[0]._process(2.0)
	check(gm.minerals == minerals + 6, "B11 orb keeps death-time amount after event ends")
	enemy = spawn_enemy(Vector3(110, 0, 110))
	for connection in enemy.drop_mineral.get_connections():
		enemy.drop_mineral.disconnect(connection.callable)
	events._apply_combat_event(events.CombatEvent.BONUS_WAVE)
	events.resolve_choice("challenge_accept")
	minerals = gm.minerals
	enemy._die()
	check(gm.minerals == minerals + 12, "B11 direct reward combines bonus wave and challenge")
	check(events.get_challenge_reward_mult() == 2.0, "challenge clear bonus remains separate")
	events.clear_combat_effects()
	check(events.get_enemy_mineral_reward(3) == 3, "B11 normal reward restored after event")

	for count in [1, 3]:
		for lethal_hit in [false, true]:
			await fresh_game()
			for i in count:
				synergy.add_trait(2)
			var poisoned = spawn_enemy()
			var neighbor = spawn_enemy(Vector3(101, 0, 100))
			var projectile = load("res://scenes/projectiles/projectile.tscn").instantiate()
			projectile.target = poisoned
			projectile.damage = 100.0 if lethal_hit else 1.0
			projectile.trait_effects = synergy.get_special_effects(2)
			game.add_child(projectile)
			projectile.set_process(false)
			projectile._on_hit()
			if not lethal_hit:
				poisoned._die()
			check((neighbor._poison_dps > 0.0) == (count >= 3), "B12 poison spread count=%d lethal=%s" % [count, lethal_hit])
			projectile.queue_free()

	await fresh_game()
	var unit_script = load("res://scripts/data/unit_data.gd")
	var unit_scene = load("res://scenes/units/unit.tscn")
	events.add_unit_dps_perm_bonus(0.3)
	for unit_type in 4:
		var unit = unit_scene.instantiate()
		unit.data = unit_script.new()
		unit.data.unit_type = unit_type
		unit.data.dps = 12.0
		unit.position = Vector3(100, 0, 100)
		game.add_child(unit)
		unit.set_physics_process(false)
		check(is_equal_approx(unit._get_attack_damage(), 15.6), "B13 damage bonus includes unit type %d" % unit_type)
		if unit_type == 3:
			var victim = spawn_enemy(Vector3(101, 0, 100))
			var hp = victim.current_hp
			unit._bomber_explode()
			check(is_equal_approx(hp - victim.current_hp, 15.6), "B13 bomber explosion uses buffed damage")
		else:
			unit.queue_free()
