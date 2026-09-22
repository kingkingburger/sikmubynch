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

## 스폰을 끄고 수동 스폰만으로 검증할 때
func quiet_sim(seed_value: int = 20260921) -> GameSimulation:
	var sim := new_sim(seed_value)
	sim.waves.enabled = false
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
	test_pressure_never_rests()
	test_pressure_curve_and_scaling()
	test_determinism()
	test_building_destroyed_unblocks_path()
	test_cannon_splash_and_frost_slow()
	test_flame_tesla_sniper()
	test_attacker_cap_and_hq_regen()
	test_enemies_bite_nearby_towers()
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
	check(sim.waves.stream_spawned == 0, "no spawn before the run starts")
	sim.tick()
	check(sim.enemies_alive() >= 30, "a horde is visible on the very first tick (%d)" % sim.enemies_alive())
	run_ticks(sim, 30 * 10)
	check(sim.enemies_alive() >= 50, "first 10 seconds show a crowd (%d)" % sim.enemies_alive())

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
	var f2 := new_sim().flow
	f2.set_blocked(62, 61, true)
	f2.set_blocked(61, 62, true)
	f2.recalculate()
	var idx := 61 * SimConfig.MAP_SIZE + 61
	var d2 := Vector2(f2.dir_x[idx], f2.dir_y[idx])
	check(not (d2.x > 0.5 and d2.y > 0.5), "no diagonal corner cutting between two blocked orthogonals")

func test_placement_and_demolish() -> void:
	var sim := quiet_sim()
	var gun := BuildingData.BuildingType.GUN_TOWER
	var gun_cost: int = sim.buildings.t_cost[gun]
	var before := sim.minerals
	var idx := sim.place_building(gun, 60, 63)
	check(idx >= 0, "gun tower placed")
	check(sim.minerals == before - gun_cost, "gun tower costs %d" % gun_cost)
	check(sim.place_building(gun, 60, 63) == -1, "cannot place on occupied tile")
	check(sim.place_building(BuildingData.BuildingType.HQ, 10, 10) == -1, "cannot place HQ")
	check(sim.place_building(gun, 63, 63) == -1, "cannot place on HQ")
	check(sim.flow.is_blocked(60, 63), "placed tower blocks flow tile")
	sim.minerals = 0
	check(sim.place_building(BuildingData.BuildingType.BARRICADE, 10, 10) == -1, "cannot afford with 0 minerals")
	var refund := sim.demolish_at(60, 63)
	check(refund == gun_cost / 2, "demolish refunds 50 percent")
	check(sim.minerals == gun_cost / 2, "refund added")
	check(sim.buildings.building_at(60, 63) == -1, "tile freed after demolish")
	check(not sim.flow.is_blocked(60, 63), "demolish unblocks flow tile")
	check(sim.demolish_at(63, 63) == -1, "cannot demolish HQ")
	sim.minerals = 500
	var recalcs := sim.flow.recalc_count
	sim.place_building(BuildingData.BuildingType.WALL, 63, 58)
	run_ticks(sim, SimConfig.FLOW_RECALC_DELAY_TICKS + 2)
	check(sim.flow.recalc_count == recalcs + 1, "flow recalculates once after placement delay")
	# 기본 수입
	var m0 := sim.minerals
	run_ticks(sim, 30 * 5)
	check(sim.minerals >= m0 + int(SimConfig.BASE_INCOME_PER_SEC * 5.0) - 1, "base income pays about %d over 5 seconds" % int(SimConfig.BASE_INCOME_PER_SEC * 5.0))

func test_enemy_reaches_and_attacks_hq() -> void:
	var sim := quiet_sim()
	var e := sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 63.5, 50.0, 1.0, 1.0, 1.0)
	check(e >= 0, "manual spawn")
	var hp0 := sim.hq_hp()
	run_ticks(sim, 30 * 8)
	check(sim.enemies.attack_target[e] == sim.buildings.hq_index, "rusher reaches HQ and targets it")
	check(sim.hq_hp() < hp0, "HQ takes damage")
	check(not sim.game_over, "single rusher does not end the game in 8 seconds")

func test_towers_kill_and_splitter_children() -> void:
	var sim := quiet_sim()
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
	var reward: int = sim.enemies.t_reward[EnemyData.EnemyType.SPLITTER]
	var income_max := int(SimConfig.BASE_INCOME_PER_SEC * float(died_tick) / 30.0) + 1
	check(sim.minerals >= minerals + reward and sim.minerals <= minerals + reward + income_max, "splitter reward paid")
	check(sim.enemies_alive() == 2, "B01 two mini children spawned on death")
	check(sim.enemies.generation[s] == gen + 1 or sim.enemies.alive[s] == 0, "freed index is reused with a new generation")
	var mini_found := false
	for i in range(sim.enemies.high):
		if sim.enemies.alive[i] != 0 and sim.enemies.type_id[i] == EnemyData.EnemyType.MINI:
			mini_found = true
	check(mini_found, "children are MINI type")

## 압박은 쉬지 않는다: 웨이브·급증 없이 한 흐름으로 온다.
## 5분 동안 10초 창마다 스폰 수가 그 시점 기본 유입률×압박 바닥 아래로 내려가지 않고(잦아듦 없음),
## 압박 천장 위로 튀지도 않는다(덩어리 없음). 그리고 항상 사방에서 온다.
func test_pressure_never_rests() -> void:
	var sim := new_sim(4321)
	sim.minerals = 100000
	# 적이 쌓이지 않게 강한 방어를 두고 스폰만 관찰
	for x in range(50, 78, 2):
		sim.place_building(BuildingData.BuildingType.SNIPER_TOWER, x, 52)
		sim.place_building(BuildingData.BuildingType.SNIPER_TOWER, x, 74)
	for y in range(54, 74, 2):
		sim.place_building(BuildingData.BuildingType.SNIPER_TOWER, 50, y)
		sim.place_building(BuildingData.BuildingType.SNIPER_TOWER, 76, y)
	var window := 10.0
	var lulls := 0
	var bursts := 0
	var windows := 0
	var lowest_ratio := 999.0
	var highest_ratio := 0.0
	var last_total := sim.waves.stream_spawned
	for w in range(30):   # 300초를 10초 창으로
		var t0 := sim.waves.time
		run_ticks(sim, int(30 * window))
		windows += 1
		var got := sim.waves.stream_spawned - last_total
		last_total = sim.waves.stream_spawned
		if w == 0:
			continue   # 첫 창은 시작 무리(STREAM_INITIAL_BURST)가 섞인다
		var base := WaveSim.base_rate(t0 + window * 0.5) * window
		var ratio := float(got) / base
		lowest_ratio = minf(lowest_ratio, ratio)
		highest_ratio = maxf(highest_ratio, ratio)
		if ratio < WaveSim.PRESSURE_MIN * 0.9:
			lulls += 1
		if ratio > WaveSim.PRESSURE_MAX * 1.1:
			bursts += 1
	check(lulls == 0, "no 10-second window fell below the pressure floor (%d lulls of %d, lowest %.2f)" % [lulls, windows, lowest_ratio])
	check(bursts == 0, "no 10-second window spiked above the pressure ceiling (%d bursts, highest %.2f)" % [bursts, highest_ratio])
	check(sim.waves.stream_spawned > 1500, "5 minutes of stream is a horde (%d)" % sim.waves.stream_spawned)
	check(not sim.game_over, "strong defense survives 5 minutes")
	# 스트림은 항상 사방: 어느 변도 전체의 15% 아래로 떨어지지 않는다
	var total_sides := 0
	for c in sim.waves.stream_side_counts:
		total_sides += c
	var min_share := 1.0
	for c in sim.waves.stream_side_counts:
		min_share = minf(min_share, float(c) / maxf(float(total_sides), 1.0))
	check(min_share >= 0.15, "stream comes from all four sides (min share %.2f, counts %s)" % [min_share, str(sim.waves.stream_side_counts)])

## 유입 곡선·배율·드리프트. 압박 배율과 변 가중치는 범위 안에서 천천히만 움직이고, 스폰 링은 가장자리까지 닿는다.
func test_pressure_curve_and_scaling() -> void:
	check(WaveSim.base_rate(0.0) >= 4.0, "stream starts thick (%.1f/s)" % WaveSim.base_rate(0.0))
	check(WaveSim.base_rate(600.0) > WaveSim.base_rate(0.0) * 3.0, "base rate rises over 10 minutes")
	check(WaveSim.base_rate(300.0) > WaveSim.base_rate(120.0) and WaveSim.base_rate(120.0) > WaveSim.base_rate(0.0), "base rate is monotonic")
	check(WaveSim.hp_scale(0.0) == 1.0 and WaveSim.hp_scale(600.0) > 2.0, "HP scales with time")
	var comp0 := WaveSim.composition(0.0)
	check(comp0[1] == 0.0 and comp0[2] == 0.0, "no tanks or splitters at time 0")
	var comp5 := WaveSim.composition(300.0)
	check(comp5[1] > 0.15 and comp5[2] > 0.15, "tanks and splitters join the stream after 5 minutes")
	# 배율·가중치 드리프트: 10분을 돌리며 범위와 틱당 변화량을 본다
	var waves := WaveSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var dt := SimConfig.TICK_DT
	var p_min := 99.0
	var p_max := 0.0
	var p_jump := 0.0
	var w_min := 99.0
	var w_max := 0.0
	var w_jump := 0.0
	var last_p := waves.pressure
	var last_w := waves.side_weight.duplicate()
	for i in range(30 * 600):
		waves.tick(dt, 0, rng)
		p_min = minf(p_min, waves.pressure)
		p_max = maxf(p_max, waves.pressure)
		p_jump = maxf(p_jump, absf(waves.pressure - last_p))
		last_p = waves.pressure
		for sd in range(4):
			w_min = minf(w_min, waves.side_weight[sd])
			w_max = maxf(w_max, waves.side_weight[sd])
			w_jump = maxf(w_jump, absf(waves.side_weight[sd] - last_w[sd]))
			last_w[sd] = waves.side_weight[sd]
	check(p_min >= WaveSim.PRESSURE_MIN - 0.001 and p_max <= WaveSim.PRESSURE_MAX + 0.001, "pressure stays in [%.2f, %.2f] (saw %.2f..%.2f)" % [WaveSim.PRESSURE_MIN, WaveSim.PRESSURE_MAX, p_min, p_max])
	check(p_max - p_min > 0.25, "pressure actually drifts (%.2f..%.2f)" % [p_min, p_max])
	check(p_jump <= WaveSim.PRESSURE_DRIFT_PER_SEC * dt + 0.0001, "pressure never jumps (max per-tick %.4f)" % p_jump)
	check(w_min >= WaveSim.SIDE_WEIGHT_MIN - 0.001 and w_max <= WaveSim.SIDE_WEIGHT_MAX + 0.001, "side weights stay in range (%.2f..%.2f)" % [w_min, w_max])
	check(w_jump <= WaveSim.SIDE_DRIFT_PER_SEC * dt + 0.0001, "side weights never jump (max per-tick %.4f)" % w_jump)
	# 스폰 링: 시작은 본진 근처, 3분 뒤에는 가장자리에도 닿는다. 항상 맵 안.
	var near := WaveSim.new()
	var far := WaveSim.new()
	far.time = 240.0
	var near_max := 0.0
	var edge_hits := 0
	var inside := true
	var c := SimConfig.HQ_CENTER
	for i in range(300):
		var p := near._spawn_position(rng)
		near_max = maxf(near_max, (p - c).length())
		var q := far._spawn_position(rng)
		if q.x <= 1.0 or q.y <= 1.0 or q.x >= float(SimConfig.MAP_SIZE) - 1.0 or q.y >= float(SimConfig.MAP_SIZE) - 1.0:
			edge_hits += 1
		if q.x < 0.0 or q.y < 0.0 or q.x > float(SimConfig.MAP_SIZE) or q.y > float(SimConfig.MAP_SIZE):
			inside = false
	check(near_max < 32.0, "first spawns are close to the HQ (max %.1f tiles)" % near_max)
	check(edge_hits > 60, "after 4 minutes many spawns come from the map edge (%d of 300)" % edge_hits)
	check(inside, "spawns never leave the map")

func test_determinism() -> void:
	var a := new_sim(777)
	var b := new_sim(777)
	for sim in [a, b]:
		sim.minerals = 2000
		sim.place_building(BuildingData.BuildingType.GUN_TOWER, 60, 60)
		sim.place_building(BuildingData.BuildingType.CANNON_TOWER, 66, 60)
		sim.place_building(BuildingData.BuildingType.FROST_TOWER, 60, 66)
		sim.place_building(BuildingData.BuildingType.TESLA_TOWER, 66, 66)
		sim.place_building(BuildingData.BuildingType.FLAME_TOWER, 63, 59)
		sim.place_building(BuildingData.BuildingType.SNIPER_TOWER, 63, 68)
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
	var sim := quiet_sim()
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
	var sim := quiet_sim()
	sim.minerals = 5000
	sim.place_building(BuildingData.BuildingType.CANNON_TOWER, 63, 54)
	for i in range(10):
		sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 62.5 + float(i % 4) * 0.4, 50.0 + float(i / 4) * 0.4, 1.0, 1.0, 0.01)
	var explosions := 0
	var max_kills := 0
	for t in range(30 * 6):
		sim.tick()
		if sim.combat.explosion_count > 0:
			explosions += sim.combat.explosion_count
			max_kills = maxi(max_kills, sim.combat.explosion_kills[0])
	check(explosions > 0, "cannon fires shells")
	check(max_kills >= 3, "Q-SYS-12 one shell kills several clustered rushers (%d)" % max_kills)

	var sim2 := quiet_sim()
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

## 새 타워 3종: 화염(반경 즉발), 전격(연쇄), 저격(관통·최대 HP 우선)
func test_flame_tesla_sniper() -> void:
	# 화염: 반경 안 10마리가 한 번에 맞는다
	var sim := quiet_sim()
	sim.minerals = 5000
	sim.place_building(BuildingData.BuildingType.FLAME_TOWER, 63, 54)
	for i in range(10):
		sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 62.0 + float(i % 5) * 0.6, 56.0 + float(i / 5) * 0.6, 1.0, 1.0, 0.01)
	var flames := 0
	for t in range(6):
		sim.tick()
		flames += sim.combat.flame_count
	check(flames > 0, "flame tower fires (%d)" % flames)
	var hurt := 0
	for i in range(sim.enemies.high):
		if sim.enemies.alive[i] != 0 and sim.enemies.hp[i] < sim.enemies.max_hp[i]:
			hurt += 1
	check(hurt >= 8, "flame hits the whole cluster at once (%d)" % hurt)

	# 전격: 한 발이 여러 마리로 튄다
	var sim2 := quiet_sim()
	sim2.minerals = 5000
	sim2.place_building(BuildingData.BuildingType.TESLA_TOWER, 63, 54)
	for i in range(8):
		sim2.enemies.spawn(EnemyData.EnemyType.RUSHER, 61.0 + float(i) * 0.9, 58.0, 1.0, 1.0, 0.01)
	var max_bolts := 0
	for t in range(30 * 2):
		sim2.tick()
		max_bolts = maxi(max_bolts, sim2.combat.bolt_count)
	check(max_bolts >= 4, "tesla chains through several enemies (%d bolts)" % max_bolts)

	# 저격: 탱크(최대 HP)를 우선하고, 한 줄로 선 적을 관통한다
	var sim3 := quiet_sim()
	sim3.minerals = 5000
	sim3.place_building(BuildingData.BuildingType.SNIPER_TOWER, 63, 54)
	var r1 := sim3.enemies.spawn(EnemyData.EnemyType.RUSHER, 63.5, 58.0, 1.0, 1.0, 0.01)
	var tank := sim3.enemies.spawn(EnemyData.EnemyType.TANK, 63.5, 62.0, 1.0, 1.0, 0.01)
	var r2 := sim3.enemies.spawn(EnemyData.EnemyType.RUSHER, 63.5, 60.0, 1.0, 1.0, 0.01)
	var r_side := sim3.enemies.spawn(EnemyData.EnemyType.RUSHER, 58.0, 58.0, 1.0, 1.0, 0.01)
	var beams := 0
	for t in range(30 * 2):
		sim3.tick()
		beams += sim3.combat.beam_count
		if beams > 0:
			break
	check(beams > 0, "sniper fires a beam")
	check(sim3.enemies.hp[tank] < sim3.enemies.max_hp[tank], "sniper hits the tank (highest HP)")
	check(sim3.enemies.alive[r1] == 0 and sim3.enemies.alive[r2] == 0, "beam pierces rushers standing in line")
	check(sim3.enemies.alive[r_side] != 0 and sim3.enemies.hp[r_side] == sim3.enemies.max_hp[r_side], "beam misses the rusher off the line")

func test_attacker_cap_and_hq_regen() -> void:
	var sim := quiet_sim()
	for i in range(40):
		sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 60.0 + float(i % 8), 52.0 + float(i / 8) * 0.5, 100.0, 1.0, 1.0)
	run_ticks(sim, 30 * 8)
	var hq := sim.buildings.hq_index
	check(sim.buildings.attackers[hq] <= sim.buildings.attacker_cap[hq], "attackers on HQ never exceed the cap")
	check(sim.buildings.attackers[hq] > 0, "some rushers are attacking the HQ")
	var waiting := 0
	for i in range(sim.enemies.high):
		if sim.enemies.alive[i] != 0 and sim.enemies.attack_target[i] < 0:
			waiting += 1
	check(waiting > 0, "excess rushers wait behind the front (%d)" % waiting)
	var sim2 := quiet_sim()
	sim2.buildings.hp[sim2.buildings.hq_index] = 1000.0
	run_ticks(sim2, 30 * 10)
	check(sim2.hq_hp() > 1000.0 and sim2.hq_hp() < 1100.0, "HQ regenerates slowly (%.0f)" % sim2.hq_hp())

## 적은 길을 막은 벽만이 아니라 경로 근처의 타워도 문다. 슬롯이 꽉 찬 건물은 지나쳐 본진으로 간다.
func test_enemies_bite_nearby_towers() -> void:
	var sim := quiet_sim()
	sim.minerals = 1000
	# 북쪽에서 내려오는 길(x=63) 옆 2칸에 타워. 길을 막지 않는다
	var tower := sim.place_building(BuildingData.BuildingType.GUN_TOWER, 65, 50)
	check(tower >= 0, "tower placed beside the path")
	run_ticks(sim, 1)
	check(sim.buildings.near_building[50 * SimConfig.MAP_SIZE + 63] == tower, "path cell 2 tiles away sees the tower")
	check(sim.buildings.near_building[50 * SimConfig.MAP_SIZE + 60] == -1, "cell 5 tiles away does not")
	for i in range(40):
		sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 62.5 + float(i % 3) * 0.5, 40.0 + float(i / 3) * 0.4, 100.0, 1.0, 1.0)
	run_ticks(sim, 30 * 8)
	var tower_hp: float = sim.buildings.hp[tower]
	check(tower_hp < sim.buildings.max_hp[tower], "rushers bite the tower even though it does not block the path (hp %.0f)" % tower_hp)
	check(sim.buildings.attackers[tower] <= sim.buildings.attacker_cap[tower], "tower attackers never exceed the cap")
	var hq := sim.buildings.hq_index
	check(sim.buildings.attackers[hq] > 0 or sim.hq_hp() < 2500.0, "rushers that found the tower full moved on to the HQ")
	var on_hq_cells := 0
	for i in range(sim.enemies.high):
		if sim.enemies.alive[i] == 0:
			continue
		if sim.buildings.building_at(int(sim.enemies.pos_x[i]), int(sim.enemies.pos_y[i])) == hq:
			on_hq_cells += 1
	check(on_hq_cells == 0, "attackers stop at the HQ edge instead of standing on it (%d)" % on_hq_cells)

func test_stress_500() -> void:
	var sim := new_sim(4242)
	sim.minerals = 100000
	for x in range(54, 74, 2):
		sim.place_building(BuildingData.BuildingType.GUN_TOWER, x, 56)
		sim.place_building(BuildingData.BuildingType.CANNON_TOWER, x, 70)
	for y in range(56, 72, 2):
		sim.place_building(BuildingData.BuildingType.FROST_TOWER, 54, y)
		sim.place_building(BuildingData.BuildingType.TESLA_TOWER, 72, y)
	for x in range(56, 72, 4):
		sim.place_building(BuildingData.BuildingType.FLAME_TOWER, x, 58)
		sim.place_building(BuildingData.BuildingType.SNIPER_TOWER, x, 68)
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
