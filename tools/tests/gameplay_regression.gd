extends SceneTree

## 렌더러 없는 시뮬레이션 회귀 검증. 씬을 띄우지 않고 sim만 돌린다.
## 실행: godot --headless --path project --script ../tools/tests/gameplay_regression.gd

const GameSimulation := preload("res://sim/game_simulation.gd")
const SimConfig := preload("res://sim/sim_config.gd")
const WaveSim := preload("res://sim/wave_sim.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: ", label)

## 테스트 기본은 시작 방어물 없이 (개별 적 이동·공격 검증이 타워에 방해받지 않도록)
func new_sim(seed_value: int = 20260921, starting_defense: bool = false) -> GameSimulation:
	var sim := GameSimulation.new()
	sim.start(seed_value, starting_defense)
	return sim

func run_ticks(sim: GameSimulation, n: int) -> void:
	for i in range(n):
		sim.tick()

func _run() -> void:
	test_start_state()
	test_flow_field()
	test_placement_and_demolish()
	test_enemy_reaches_and_attacks_hq()
	test_towers_kill_and_splitter_children()
	test_wave_completion_waits_for_children()
	test_determinism()
	test_building_destroyed_unblocks_path()
	test_cannon_splash_and_frost_slow()
	test_stress_500()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_start_state() -> void:
	var sim := new_sim()
	check(sim.minerals == SimConfig.START_MINERALS, "start minerals")
	check(sim.buildings.hq_index >= 0, "HQ placed")
	check(sim.buildings.building_at(63, 63) == sim.buildings.hq_index, "HQ occupies center tile")
	check(sim.buildings.building_at(61, 63) == -1, "tile next to HQ is free")
	check(is_equal_approx(sim.hq_hp(), 2500.0), "HQ HP 2500")
	check(sim.buildings.alive_count == 1, "no starting defense when disabled")
	var sim_def := GameSimulation.new()
	sim_def.start(1, true)
	check(sim_def.buildings.alive_count == 5, "starting defense: HQ + 4 gun towers")
	check(sim_def.flow.is_reachable(0, 0), "starting defense keeps corner reachable")
	check(sim.enemies_alive() == 0, "no enemies before first tick")
	check(sim.flow.is_reachable(0, 0), "corner is reachable from HQ")
	check(sim.flow.cost_at(63, 63) == 0, "HQ cell cost 0")
	check(not sim.game_over, "not game over at start")
	sim.tick()
	check(sim.waves.active and sim.waves.wave_number == 1, "wave 1 starts on first tick")
	check(sim.waves.wave_type == WaveSim.WaveType.SCOUT, "wave 1 is scout")
	run_ticks(sim, 30)
	check(sim.enemies_alive() > 0, "enemies spawn within a second")

func test_flow_field() -> void:
	var sim := new_sim()
	var f := sim.flow
	f.set_blocked(10, 10, true)
	f.set_blocked(10, 10, true)
	f.set_blocked(11, 10, true)
	f.set_blocked(10, 10, false)
	check(f.is_blocked(10, 10), "B03 double-registered tile stays blocked after one release")
	f.set_blocked(10, 10, false)
	check(not f.is_blocked(10, 10), "B03 last release unblocks")
	f.set_blocked(11, 10, false)
	# 벽으로 완전히 둘러싸면 도달 불가
	for x in range(60, 67):
		f.set_blocked(x, 60, true)
		f.set_blocked(x, 66, true)
	for y in range(61, 66):
		f.set_blocked(60, y, true)
		f.set_blocked(66, y, true)
	f.recalculate()
	check(not f.is_reachable(5, 5), "fully walled HQ is unreachable from outside")
	check(f.is_reachable(61, 61), "inside the wall ring is reachable")
	# 한 칸 열면 다시 도달
	f.set_blocked(63, 60, false)
	f.recalculate()
	check(f.is_reachable(5, 5), "opening one gap restores reachability")
	var d := Vector2(f.dir_x[5 * SimConfig.MAP_SIZE + 5], f.dir_y[5 * SimConfig.MAP_SIZE + 5])
	check(d.length() > 0.9 and d.x > 0.0 and d.y > 0.0, "direction at (5,5) points toward HQ")
	# 대각선 모서리 관통 금지: (20,20)이 막히고 (21,20),(20,21)이 막혔으면 (21,21)에서 대각선으로 (20,20)... 방향은 직교여야 함
	var f2 := new_sim().flow
	f2.set_blocked(62, 61, true)
	f2.set_blocked(61, 62, true)
	f2.recalculate()
	var idx := 61 * SimConfig.MAP_SIZE + 61
	var d2 := Vector2(f2.dir_x[idx], f2.dir_y[idx])
	check(not (d2.x > 0.5 and d2.y > 0.5), "no diagonal corner cutting between two blocked orthogonals")

func test_placement_and_demolish() -> void:
	var sim := new_sim()
	var gun := BuildingData.BuildingType.GUN_TOWER
	var before := sim.minerals
	var idx := sim.place_building(gun, 60, 63)
	check(idx >= 0, "gun tower placed")
	check(sim.minerals == before - 50, "gun tower costs 50")
	check(sim.place_building(gun, 60, 63) == -1, "cannot place on occupied tile")
	check(sim.place_building(BuildingData.BuildingType.HQ, 10, 10) == -1, "cannot place HQ")
	check(sim.place_building(gun, 63, 63) == -1, "cannot place on HQ")
	check(sim.flow.is_blocked(60, 63), "placed tower blocks flow tile")
	sim.minerals = 0
	check(sim.place_building(BuildingData.BuildingType.BARRICADE, 10, 10) == -1, "cannot afford with 0 minerals")
	var refund := sim.demolish_at(60, 63)
	check(refund == 25, "demolish refunds 50 percent")
	check(sim.minerals == 25, "refund added")
	check(sim.buildings.building_at(60, 63) == -1, "tile freed after demolish")
	check(not sim.flow.is_blocked(60, 63), "flow tile unblocked after demolish")
	check(sim.demolish_at(63, 63) == -1, "HQ cannot be demolished")
	# 배치 후 지연 재계산
	sim.minerals = 500
	var recalcs := sim.flow.recalc_count
	sim.place_building(BuildingData.BuildingType.WALL, 63, 58)
	run_ticks(sim, SimConfig.FLOW_RECALC_DELAY_TICKS + 2)
	check(sim.flow.recalc_count == recalcs + 1, "flow recalculates once after placement delay")

func test_enemy_reaches_and_attacks_hq() -> void:
	var sim := new_sim()
	sim.waves.active = true   # 웨이브 자동 시작을 막기 위해 활성 상태로 두고 큐는 비운다
	sim.waves.wave_time = -1000.0
	var e := sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 63.5, 50.0, 1.0, 1.0, 1.0)
	check(e >= 0, "manual spawn")
	var hp0 := sim.hq_hp()
	run_ticks(sim, 30 * 8)
	check(sim.enemies.attack_target[e] == sim.buildings.hq_index, "rusher reaches HQ and targets it")
	check(sim.hq_hp() < hp0, "HQ takes damage")
	check(not sim.game_over, "single rusher does not end the game in 8 seconds")

func test_towers_kill_and_splitter_children() -> void:
	var sim := new_sim()
	sim.waves.active = true
	sim.waves.wave_time = -1000.0
	sim.minerals = 1000
	check(sim.place_building(BuildingData.BuildingType.GUN_TOWER, 63, 55) >= 0, "gun tower near path")
	var minerals := sim.minerals
	var kills := sim.kills
	var s := sim.enemies.spawn(EnemyData.EnemyType.SPLITTER, 63.5, 52.0, 1.0, 1.0, 1.0)
	check(s >= 0, "splitter spawned")
	var gen := sim.enemies.generation[s]
	var ticks := 0
	var died_tick := -1
	while ticks < 30 * 10:
		sim.tick()
		ticks += 1
		if sim.enemies.alive[s] == 0 or sim.enemies.generation[s] != gen:
			died_tick = ticks
			break
	check(died_tick > 0, "gun tower kills splitter within 10 seconds")
	check(sim.kills == kills + 1, "kill counted once")
	check(sim.minerals == minerals + 5, "splitter reward 5")
	check(sim.enemies_alive() == 2, "B01 two mini children spawned on death")
	check(sim.enemies.generation[s] == gen + 1 or sim.enemies.alive[s] == 0, "freed index is reused with a new generation")
	var mini_found := false
	for i in range(sim.enemies.high):
		if sim.enemies.alive[i] != 0 and sim.enemies.type_id[i] == EnemyData.EnemyType.MINI:
			mini_found = true
	check(mini_found, "children are MINI type")

func test_wave_completion_waits_for_children() -> void:
	var sim := new_sim()
	sim.tick()
	# 큐를 비우고 스플리터 하나만 남긴다
	sim.waves._clear_queue()
	for i in range(sim.enemies.high):
		if sim.enemies.alive[i] != 0:
			sim.enemies.kill(i)
	sim.enemies.clear_tick_results()
	sim.minerals = 1000
	sim.place_building(BuildingData.BuildingType.GUN_TOWER, 63, 55)
	var s := sim.enemies.spawn(EnemyData.EnemyType.SPLITTER, 63.5, 52.0, 1.0, 1.0, 1.0)
	var gen := sim.enemies.generation[s]
	var wave := sim.waves.wave_number
	var ticks := 0
	var died := false
	while ticks < 300:
		sim.tick()
		ticks += 1
		if sim.enemies.alive[s] == 0 or sim.enemies.generation[s] != gen:
			died = true
			break
	check(died, "splitter died")
	check(sim.waves.wave_number == wave and sim.waves.active, "B01 wave not cleared while children alive")
	ticks = 0
	while sim.enemies_alive() > 0 and ticks < 600:
		sim.tick()
		ticks += 1
	check(sim.enemies_alive() == 0, "children killed")
	check(sim.waves.wave_number == wave + 1 and sim.waves.between, "B01 wave clears once after all children die")
	var minerals := sim.minerals
	run_ticks(sim, int(WaveSim.WAVE_INTERVAL * 30.0) + 2)
	check(sim.waves.active and sim.waves.wave_number == wave + 1, "next wave starts after countdown")
	check(sim.minerals >= minerals, "clear bonus was paid before next wave")

func test_determinism() -> void:
	var a := new_sim(777)
	var b := new_sim(777)
	for sim in [a, b]:
		sim.minerals = 2000
		sim.place_building(BuildingData.BuildingType.GUN_TOWER, 60, 60)
		sim.place_building(BuildingData.BuildingType.CANNON_TOWER, 66, 60)
		sim.place_building(BuildingData.BuildingType.FROST_TOWER, 60, 66)
		for x in range(58, 69):
			sim.place_building(BuildingData.BuildingType.BARRICADE, x, 57)
	run_ticks(a, 30 * 40)
	run_ticks(b, 30 * 40)
	check(a.state_hash() == b.state_hash(), "Q-SYS-7 same seed gives same state after 40 seconds")
	check(a.kills == b.kills and a.minerals == b.minerals, "Q-SYS-7 kills and minerals match")
	check(a.kills > 0, "towers killed something in 40 seconds")
	var c := new_sim(778)
	c.minerals = 2000
	c.place_building(BuildingData.BuildingType.GUN_TOWER, 60, 60)
	run_ticks(c, 30 * 40)
	check(c.state_hash() != a.state_hash(), "different seed gives different state")

func test_building_destroyed_unblocks_path() -> void:
	var sim := new_sim()
	sim.waves.active = true
	sim.waves.wave_time = -1000.0
	sim.minerals = 5000
	# HQ 북쪽을 바리케이드로 막고 적을 북쪽에 둔다 (완전 봉쇄)
	for x in range(58, 70):
		sim.place_building(BuildingData.BuildingType.BARRICADE, x, 58)
		sim.place_building(BuildingData.BuildingType.BARRICADE, x, 69)
	for y in range(59, 69):
		sim.place_building(BuildingData.BuildingType.BARRICADE, 58, y)
		sim.place_building(BuildingData.BuildingType.BARRICADE, 69, y)
	run_ticks(sim, SimConfig.FLOW_RECALC_DELAY_TICKS + 2)
	check(not sim.flow.is_reachable(63, 40), "walled HQ unreachable")
	for i in range(12):
		sim.enemies.spawn(EnemyData.EnemyType.TANK, 62.0 + float(i % 3), 50.0, 3.0, 3.0, 1.0)
	var buildings_before := sim.buildings.alive_count
	var ticks := 0
	while sim.buildings.alive_count == buildings_before and ticks < 30 * 60:
		sim.tick()
		ticks += 1
	check(sim.buildings.alive_count < buildings_before, "tanks break a barricade when path is blocked")
	run_ticks(sim, SimConfig.FLOW_RECALC_DELAY_TICKS + 2)
	check(sim.flow.is_reachable(63, 40), "destroyed barricade reopens the path")

func test_cannon_splash_and_frost_slow() -> void:
	var sim := new_sim()
	sim.waves.active = true
	sim.waves.wave_time = -1000.0
	sim.minerals = 5000
	sim.place_building(BuildingData.BuildingType.CANNON_TOWER, 63, 54)
	var ids: Array = []
	for i in range(10):
		ids.append(sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 62.5 + float(i % 4) * 0.4, 50.0 + float(i / 4) * 0.4, 1.0, 1.0, 0.01))
	var explosions := 0
	var max_kills := 0
	for t in range(30 * 6):
		sim.tick()
		if sim.combat.explosion_count > 0:
			explosions += sim.combat.explosion_count
			max_kills = maxi(max_kills, sim.combat.explosion_kills[0])
	check(explosions > 0, "cannon fires shells")
	check(max_kills >= 3, "Q-SYS-12 one shell kills several clustered rushers (%d)" % max_kills)

	var sim2 := new_sim()
	sim2.waves.active = true
	sim2.waves.wave_time = -1000.0
	sim2.minerals = 5000
	sim2.place_building(BuildingData.BuildingType.FROST_TOWER, 63, 54)
	var e := sim2.enemies.spawn(EnemyData.EnemyType.TANK, 63.5, 51.0, 10.0, 1.0, 0.5)
	var slowed := false
	for t in range(30 * 5):
		sim2.tick()
		if sim2.enemies.alive[e] != 0 and sim2.enemies.slow_mult[e] < 0.6:
			slowed = true
			break
	check(slowed, "frost tower slows the tank")

func test_stress_500() -> void:
	var sim := new_sim(4242)
	sim.minerals = 100000
	for x in range(54, 74, 2):
		sim.place_building(BuildingData.BuildingType.GUN_TOWER, x, 56)
		sim.place_building(BuildingData.BuildingType.CANNON_TOWER, x, 70)
	for y in range(56, 72, 2):
		sim.place_building(BuildingData.BuildingType.FROST_TOWER, 54, y)
		sim.place_building(BuildingData.BuildingType.GUN_TOWER, 72, y)
	sim.debug_spawn(500)
	check(sim.enemies_alive() >= 500, "500 enemies spawned")
	var worst := 0
	var total := 0
	var n := 30 * 10
	for i in range(n):
		sim.tick()
		worst = maxi(worst, sim.last_tick_usec)
		total += sim.last_tick_usec
	print("STRESS 500: avg tick %.2f ms, worst %.2f ms, alive %d, kills %d" % [
		float(total) / float(n) / 1000.0, float(worst) / 1000.0, sim.enemies_alive(), sim.kills])
	check(float(total) / float(n) < 33000.0, "500 enemies: average tick under 33 ms (30Hz budget)")
	check(sim.kills > 0, "towers kill during stress")
	check(sim.enemies.peak_alive >= 500, "peak alive recorded")
