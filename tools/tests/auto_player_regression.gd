extends SceneTree

const GameSimulation := preload("res://sim/game_simulation.gd")
const AutoPlayer := preload("res://sim/auto_player.gd")
const SimConfig := preload("res://sim/sim_config.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: ", label)

func _run() -> void:
	_test_commands()
	_test_rebuilding()
	var first := _play(4242, true)
	var repeated := _play(4242, true)
	check(first == repeated, "same seed and bot decisions reproduce the run")
	check(first.built > 0 and first.spent > 0, "bot builds with normal starting resources and income")
	for seed_value in [4242, 20260921]:
		var idle := _play(seed_value, false)
		var automated: Dictionary = first if seed_value == 4242 else _play(seed_value, true)
		print("AUTO PLAY seed=%d idle=%s auto=%s (simulation limit 180s)" % [seed_value, idle, automated])
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_commands() -> void:
	var sim := GameSimulation.new()
	sim.start(4242)
	sim.waves.enabled = false
	for i in range(30):
		sim.enemies.spawn(EnemyData.EnemyType.TANK, 76.5, 63.5, 1.0, 1.0, 1.0)
	var bot := AutoPlayer.new()
	var before := sim.state_hash()
	var minerals := sim.minerals
	var command := bot.next_command(sim)
	check(sim.state_hash() == before and sim.minerals == minerals, "deciding does not mutate simulation or resources")
	check(not command.is_empty() and command.tile.x > SimConfig.HQ_CENTER.x, "bot reinforces the direction with nearby enemies")
	if not command.is_empty():
		var idx := sim.place_building(command.type, command.tile.x, command.tile.y)
		check(idx >= 0 and sim.minerals == minerals - sim.buildings.t_cost[command.type], "bot command pays the real construction cost")
	check(bot.next_command(sim).is_empty(), "bot limits decisions within the same simulation tick")
	sim.minerals = 0
	sim.tick_index += AutoPlayer.DECISION_TICKS
	check(bot.next_command(sim).is_empty() and sim.minerals == 0, "bot waits when it cannot afford construction")
	sim.minerals = minerals
	sim.game_over = true
	sim.tick_index += AutoPlayer.DECISION_TICKS
	check(bot.next_command(sim).is_empty(), "bot stops at game over")

func _test_rebuilding() -> void:
	var sim := GameSimulation.new()
	sim.start(4242)
	sim.waves.enabled = false
	# 동쪽 시작 타워를 실제 전투로 파괴한다.
	var tower := sim.buildings.building_at(68, 63)
	sim.buildings.hp[tower] = 1.0
	var enemy := sim.enemies.spawn(EnemyData.EnemyType.TANK, 69.5, 63.5, 1.0, 1.0, 1.0)
	sim.enemies.attack_target[enemy] = tower
	sim.enemies.attack_gen[enemy] = sim.buildings.generation[tower]
	sim.enemies.attack_timer[enemy] = 0.0
	sim.tick()
	check(sim.buildings.alive[tower] == 0, "combat destroys a starting tower")
	var command := AutoPlayer.new().next_command(sim)
	check(not command.is_empty() and command.tile == Vector2i(68, 63), "bot rebuilds the destroyed position on the weakened side")
	if not command.is_empty():
		check(sim.place_building(command.type, command.tile.x, command.tile.y) >= 0, "rebuild succeeds through the normal placement API")

func _play(seed_value: int, automated: bool) -> Dictionary:
	var sim := GameSimulation.new()
	sim.start(seed_value)
	var bot := AutoPlayer.new()
	for t in range(180 * SimConfig.TICK_RATE):
		sim.tick()
		if sim.game_over:
			break
		if automated:
			var command := bot.next_command(sim)
			if not command.is_empty():
				sim.place_building(command.type, command.tile.x, command.tile.y)
	return {"time": snappedf(sim.time, 0.1), "kills": sim.kills, "built": sim.buildings_built,
		"spent": sim.minerals_spent, "hq_hp": snappedf(sim.hq_hp(), 0.1), "hash": sim.state_hash()}
