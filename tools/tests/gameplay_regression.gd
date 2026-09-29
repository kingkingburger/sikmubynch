extends SceneTree

## 시뮬레이션 코어 회귀 검증. 씬 없이 sim만 돌린다.
## 여기에는 "깨지면 게임이 망가지는" 불변식만 둔다. 밸런스 수치(유입 곡선, 재생량, 사거리 등)는 넣지 않는다.
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

## 스폰을 끄고 수동 스폰만으로 검증할 때 (시작 방어물 없음, 본진 주포 끔 — 개별 동작을 따로 보기 위해)
func quiet_sim(seed_value: int = 20260921) -> GameSimulation:
	var sim := GameSimulation.new()
	sim.start(seed_value, false)
	sim.waves.enabled = false
	sim.buildings.t_is_tower[BuildingData.BuildingType.HQ] = 0
	return sim

func run_ticks(sim: GameSimulation, n: int) -> void:
	for i in range(n):
		sim.tick()

## 건설 뒤 분산 재계산이 끝나 새 필드가 적용될 때까지 돌린다
func settle_flow(sim: GameSimulation) -> void:
	run_ticks(sim, SimConfig.FLOW_RECALC_DELAY_TICKS + 1)
	var n := 0
	while (sim.flow.is_busy() or sim.flow.dirty) and n < 120:
		sim.tick()
		n += 1

func _run() -> void:
	test_start_state()
	test_flow_field()
	test_placement_and_demolish()
	test_enemy_reaches_hq()
	test_hq_defends_itself()
	test_kill_reward_and_split()
	test_every_tower_deals_damage()
	test_blocked_path_breaks_open()
	test_stream_never_stops()
	test_determinism()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_start_state() -> void:
	var sim := GameSimulation.new()
	sim.start(20260921, false)
	check(sim.buildings.building_at(63, 63) == sim.buildings.hq_index, "HQ occupies the center")
	check(sim.flow.is_reachable(0, 0), "map corner can reach the HQ")
	sim.tick()
	check(sim.enemies_alive() > 0, "a horde appears on the first tick")

func test_flow_field() -> void:
	var f := quiet_sim().flow
	for x in range(60, 67):
		f.set_blocked(x, 60, true)
		f.set_blocked(x, 66, true)
	for y in range(61, 66):
		f.set_blocked(60, y, true)
		f.set_blocked(66, y, true)
	f.recalculate()
	check(not f.is_reachable(5, 5), "fully walled HQ is unreachable")
	f.set_blocked(63, 60, false)
	f.recalculate()
	check(f.is_reachable(5, 5), "opening one gap restores reachability")
	# 분산 재계산 결과는 한 번에 계산한 것과 같아야 한다
	var fa := quiet_sim().flow
	var fb := quiet_sim().flow
	for x in range(40, 90):
		fa.set_blocked(x, 50, true)
		fb.set_blocked(x, 50, true)
	fb.recalculate()
	fa.begin()
	var steps := 0
	while fa.is_busy() and steps < 100:
		fa.step()
		steps += 1
	check(fa.cost == fb.cost and fa.dir_x == fb.dir_x and fa.dir_y == fb.dir_y, "distributed recalculation matches a full one")

func test_placement_and_demolish() -> void:
	var sim := quiet_sim()
	var gun := BuildingData.BuildingType.GUN_TOWER
	var cost: int = sim.buildings.t_cost[gun]
	var before := sim.minerals
	check(sim.place_building(gun, 60, 63) >= 0 and sim.minerals == before - cost, "placing spends minerals")
	check(sim.place_building(gun, 60, 63) == -1, "occupied tile is rejected")
	check(sim.flow.is_blocked(60, 63), "building blocks the path")
	sim.minerals = 0
	check(sim.place_building(BuildingData.BuildingType.BARRICADE, 10, 10) == -1, "cannot build without minerals")
	check(sim.demolish_at(60, 63) > 0 and not sim.flow.is_blocked(60, 63), "demolish refunds and unblocks")
	check(sim.demolish_at(63, 63) == -1, "HQ cannot be demolished")

func test_enemy_reaches_hq() -> void:
	var sim := quiet_sim()
	sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 63.5, 50.0, 1.0, 1.0, 1.0)
	var hp0 := sim.hq_hp()
	run_ticks(sim, 30 * 8)
	check(sim.hq_hp() < hp0, "an enemy walks to the HQ and damages it")

## 본진은 스스로 싸운다: 타워가 하나도 없어도 다가오는 무리를 처치한다 (초반에 그냥 밀리지 않게)
func test_hq_defends_itself() -> void:
	var sim := GameSimulation.new()
	sim.start(20260921, false)
	sim.waves.enabled = false
	for i in range(10):
		sim.enemies.spawn(EnemyData.EnemyType.RUSHER, 62.0 + float(i % 5) * 0.6, 50.0 + float(i / 5) * 0.6, 1.0, 1.0, 1.0)
	run_ticks(sim, 30 * 6)
	check(sim.kills >= 8, "HQ kills approaching rushers on its own (%d of 10)" % sim.kills)

## 처치: 한 번만 세고, 보상이 들어오고, 분열체는 자식을 남긴다
func test_kill_reward_and_split() -> void:
	var sim := quiet_sim()
	sim.minerals = 1000
	sim.place_building(BuildingData.BuildingType.GUN_TOWER, 63, 55)
	var minerals := sim.minerals
	var s := sim.enemies.spawn(EnemyData.EnemyType.SPLITTER, 63.5, 52.0, 1.0, 1.0, 1.0)
	var gen := sim.enemies.generation[s]
	var ticks := 0
	while ticks < 30 * 10 and sim.enemies.alive[s] != 0 and sim.enemies.generation[s] == gen:
		sim.tick()
		ticks += 1
	check(sim.kills == 1, "kill counted exactly once (%d)" % sim.kills)
	check(sim.minerals >= minerals + int(sim.enemies.t_reward[EnemyData.EnemyType.SPLITTER]), "kill reward paid")
	check(sim.enemies_alive() == 2, "splitter leaves two children (%d)" % sim.enemies_alive())

## 타워 6종이 각각 적에게 피해를 준다 (발사 방식 4가지 경로가 모두 산다)
func test_every_tower_deals_damage() -> void:
	for type in [BuildingData.BuildingType.GUN_TOWER, BuildingData.BuildingType.CANNON_TOWER,
			BuildingData.BuildingType.FROST_TOWER, BuildingData.BuildingType.FLAME_TOWER,
			BuildingData.BuildingType.TESLA_TOWER, BuildingData.BuildingType.SNIPER_TOWER]:
		var sim := quiet_sim()
		sim.minerals = 5000
		sim.place_building(type, 63, 54)
		for i in range(6):
			sim.enemies.spawn(EnemyData.EnemyType.TANK, 62.5 + float(i % 3) * 0.6, 56.5 + float(i / 3) * 0.6, 50.0, 1.0, 0.01)
		run_ticks(sim, 30 * 3)
		var hurt := 0
		for i in range(sim.enemies.high):
			if sim.enemies.alive[i] != 0 and sim.enemies.hp[i] < sim.enemies.max_hp[i]:
				hurt += 1
		check(hurt > 0, "%s damages enemies" % (sim.building_datas[type] as BuildingData).building_name)

## 완전히 막힌 본진: 적이 벽을 부수고, 부서지면 길이 다시 열린다 (적이 영원히 멈추지 않는다)
func test_blocked_path_breaks_open() -> void:
	var sim := quiet_sim()
	sim.minerals = 5000
	for x in range(58, 70):
		sim.place_building(BuildingData.BuildingType.BARRICADE, x, 58)
		sim.place_building(BuildingData.BuildingType.BARRICADE, x, 69)
	for y in range(59, 69):
		sim.place_building(BuildingData.BuildingType.BARRICADE, 58, y)
		sim.place_building(BuildingData.BuildingType.BARRICADE, 69, y)
	settle_flow(sim)
	for i in range(12):
		sim.enemies.spawn(EnemyData.EnemyType.TANK, 62.0 + float(i % 3), 50.0, 3.0, 3.0, 1.0)
	var before := sim.buildings.alive_count
	var ticks := 0
	while sim.buildings.alive_count == before and ticks < 30 * 60:
		sim.tick()
		ticks += 1
	check(sim.buildings.alive_count < before, "enemies break through a sealed wall")
	settle_flow(sim)
	check(sim.flow.is_reachable(63, 40), "a broken wall reopens the path")

## 압박은 끊기지 않는다: 5분 동안 10초 창마다 스폰이 있다. WaveSim만 가짜 적 배열로 돌린다.
class FakeEnemies extends RefCounted:
	var alive_count: int = 0
	func spawn(_t: int, _x: float, _y: float, _hs: float, _ds: float, _ss: float) -> int:
		alive_count += 1
		return 0

func test_stream_never_stops() -> void:
	var waves := WaveSim.new()
	var fake := FakeEnemies.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dt := SimConfig.TICK_DT
	var lulls := 0
	var last := 0
	for i in range(30 * 300):
		waves.drain_spawns(dt, fake, rng)
		waves.tick(dt, fake.alive_count, rng)
		fake.alive_count -= int(float(fake.alive_count) * 0.3 * dt)   # 강한 방어가 무리를 계속 지운다
		if (i + 1) % 300 == 0:
			if waves.stream_spawned == last:
				lulls += 1
			last = waves.stream_spawned
	check(lulls == 0, "stream spawns in every 10-second window (%d lulls)" % lulls)

## 같은 seed는 같은 결과 (리플레이·버그 재현의 전제)
func test_determinism() -> void:
	var hashes: Array = []
	for n in 2:
		var sim := GameSimulation.new()
		sim.start(777)
		sim.minerals = 2000
		sim.place_building(BuildingData.BuildingType.GUN_TOWER, 60, 60)
		sim.place_building(BuildingData.BuildingType.CANNON_TOWER, 66, 60)
		sim.place_building(BuildingData.BuildingType.TESLA_TOWER, 66, 66)
		run_ticks(sim, 30 * 20)
		hashes.append(sim.state_hash())
	check(hashes[0] == hashes[1], "same seed gives the same state")
