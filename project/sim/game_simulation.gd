extends RefCounted

## Game Simulation — 고정 틱으로 하위 Sim을 순서대로 호출하고 런 상태를 가진다.
## Node를 모른다. 같은 seed와 같은 입력이면 같은 결과가 나온다.
##
## 틱 순서: 웨이브 스폰 → Flow Field 재계산(필요 시) → Spatial Grid 재구성 → 적 이동·건물 공격
## → 타워 발사·발사체 명중 → 분열 스폰 → 보상 정산 → 웨이브 완료 판정

const SimConfig := preload("res://sim/sim_config.gd")
const FlowFieldSim := preload("res://sim/flow_field.gd")
const SpatialGridSim := preload("res://sim/spatial_grid.gd")
const BuildingSim := preload("res://sim/building_sim.gd")
const EnemySim := preload("res://sim/enemy_sim.gd")
const CombatSim := preload("res://sim/combat_sim.gd")
const WaveSim := preload("res://sim/wave_sim.gd")
const BuildingCatalog := preload("res://scripts/building_catalog.gd")
const EnemyCatalog := preload("res://scripts/enemy_catalog.gd")

var rng: RandomNumberGenerator
var flow: FlowFieldSim
var grid: SpatialGridSim
var buildings: BuildingSim
var enemies: EnemySim
var combat: CombatSim
var waves: WaveSim

var building_datas: Array = []
var enemy_datas: Array = []

# 런 상태
var seed_value: int = 0
var tick_index: int = 0
var time: float = 0.0
var minerals: int = 0
var kills: int = 0
var game_over: bool = false
var hq_hit_this_tick: bool = false
var buildings_destroyed: PackedInt32Array   # 이번 틱 파괴된 건물 인덱스
var buildings_hit: PackedInt32Array         # 이번 틱 피격된 건물 인덱스 (중복 제거 안 함)
var minerals_gained_this_tick: int = 0
var last_tick_usec: int = 0                 # 프로파일용
var flow_recalc_timer: int = -1

func _init() -> void:
	rng = RandomNumberGenerator.new()
	flow = FlowFieldSim.new()
	grid = SpatialGridSim.new()
	buildings = BuildingSim.new()
	enemies = EnemySim.new()
	combat = CombatSim.new()
	waves = WaveSim.new()
	buildings_destroyed = PackedInt32Array()
	buildings_hit = PackedInt32Array()

## 시작 방어물: 본진 4방향 기관총 타워 (문서 "본진, 기본 방어물 몇 개, 제한된 미네랄")
const STARTING_DEFENSE: Array = [
	[BuildingData.BuildingType.GUN_TOWER, 63, 58],
	[BuildingData.BuildingType.GUN_TOWER, 63, 68],
	[BuildingData.BuildingType.GUN_TOWER, 58, 63],
	[BuildingData.BuildingType.GUN_TOWER, 68, 63],
]

## 새 런. 자원·웨이브·길찾기·공간 검색 상태를 모두 초기화한다.
func start(seed: int, starting_defense: bool = true) -> void:
	seed_value = seed
	rng.seed = seed
	tick_index = 0
	time = 0.0
	minerals = SimConfig.START_MINERALS
	kills = 0
	game_over = false
	hq_hit_this_tick = false
	buildings_destroyed = PackedInt32Array()
	buildings_hit = PackedInt32Array()
	minerals_gained_this_tick = 0
	flow_recalc_timer = -1

	building_datas = BuildingCatalog.create()
	enemy_datas = EnemyCatalog.create()
	buildings.clear_all()
	buildings.set_types(building_datas)
	enemies.clear_all()
	enemies.set_types(enemy_datas)
	combat.clear_all()
	waves.clear_all()
	grid.clear_all()
	flow.clear_all()

	# HQ
	var hq := buildings.place(BuildingData.BuildingType.HQ, SimConfig.HQ_MIN_TILE, SimConfig.HQ_MIN_TILE)
	buildings.hq_index = hq
	var targets := PackedInt32Array()
	for dy in range(SimConfig.HQ_SIZE):
		for dx in range(SimConfig.HQ_SIZE):
			targets.append(SimConfig.tile_index(SimConfig.HQ_MIN_TILE + dx, SimConfig.HQ_MIN_TILE + dy))
	flow.set_targets(targets)
	if starting_defense:
		for entry in STARTING_DEFENSE:
			_place_free(int(entry[0]), int(entry[1]), int(entry[2]))
	flow.recalculate()

## 비용 없이 배치 (시작 방어물). Flow Field는 호출자가 재계산한다.
func _place_free(type: int, tx: int, ty: int) -> int:
	var idx := buildings.place(type, tx, ty)
	if idx < 0:
		return -1
	var s := buildings.t_size[type]
	for dy in range(s):
		for dx in range(s):
			flow.set_blocked(tx + dx, ty + dy, true)
	return idx

# ---------------------------------------------------------------------------
# 플레이어 명령 (표현 계층이 호출)
# ---------------------------------------------------------------------------

func can_place(type: int, tx: int, ty: int) -> bool:
	if game_over or type == BuildingData.BuildingType.HQ:
		return false
	return buildings.can_place(type, tx, ty)

func can_afford(type: int) -> bool:
	if type < 0 or type >= buildings.type_count:
		return false
	return minerals >= buildings.t_cost[type]

## 건물 배치. 성공하면 건물 인덱스, 실패하면 -1.
func place_building(type: int, tx: int, ty: int) -> int:
	if not can_place(type, tx, ty):
		return -1
	if not can_afford(type):
		return -1
	var idx := buildings.place(type, tx, ty)
	if idx < 0:
		return -1
	minerals -= buildings.t_cost[type]
	var s := buildings.t_size[type]
	for dy in range(s):
		for dx in range(s):
			flow.set_blocked(tx + dx, ty + dy, true)
	_schedule_flow_recalc()
	return idx

## 철거. 환불액을 반환한다. HQ는 철거할 수 없다.
func demolish_at(tx: int, ty: int) -> int:
	if game_over:
		return -1
	var idx := buildings.building_at(tx, ty)
	if idx < 0 or idx == buildings.hq_index:
		return -1
	var refund := int(float(buildings.t_cost[buildings.type_id[idx]]) * SimConfig.DEMOLISH_REFUND)
	_remove_building(idx)
	minerals += refund
	return refund

func _remove_building(idx: int) -> void:
	var s := buildings.size[idx]
	var tx := buildings.tile_x[idx]
	var ty := buildings.tile_y[idx]
	buildings.remove(idx)
	for dy in range(s):
		for dx in range(s):
			flow.set_blocked(tx + dx, ty + dy, false)
	_schedule_flow_recalc()

func _schedule_flow_recalc() -> void:
	if flow_recalc_timer < 0:
		flow_recalc_timer = SimConfig.FLOW_RECALC_DELAY_TICKS

# ---------------------------------------------------------------------------
# 틱
# ---------------------------------------------------------------------------

func tick() -> void:
	if game_over:
		return
	var start_usec := Time.get_ticks_usec()
	var dt := SimConfig.TICK_DT
	_clear_tick_results()

	# 1. 웨이브 스폰
	waves.drain_spawns(dt, enemies)

	# 2. Flow Field
	if flow_recalc_timer >= 0:
		flow_recalc_timer -= 1
		if flow_recalc_timer < 0 and flow.dirty:
			flow.recalculate()
	elif flow.dirty:
		flow.recalculate()

	# 3. 공간 그리드
	grid.rebuild(enemies.pos_x, enemies.pos_y, enemies.alive, enemies.high)

	# 4. 적 이동·건물 공격
	enemies.tick(dt, flow, buildings, tick_index)
	_resolve_building_damage()

	# 5. 전투
	if not game_over:
		combat.tick_towers(dt, buildings, enemies, grid)
		combat.tick_projectiles(dt, enemies, grid, tick_index)
		for b in enemies.pending_detach:
			buildings.detach_attacker(b)
		buildings.regen_hq(dt)

	# 6. 분열 스폰
	var sr := enemies.split_requests
	var n := sr.size() / 6
	for i in range(n):
		var base := i * 6
		var ox := rng.randf_range(-0.8, 0.8)
		var oy := rng.randf_range(-0.8, 0.8)
		enemies.spawn(int(sr[base]), sr[base + 1] + ox, sr[base + 2] + oy,
			sr[base + 3], sr[base + 4], sr[base + 5])

	# 7. 보상
	kills += combat.tick_kills
	if enemies.reward_pending > 0:
		minerals += enemies.reward_pending
		minerals_gained_this_tick += enemies.reward_pending

	# 8. 웨이브 진행
	waves.tick(dt, enemies.alive_count, rng)
	if waves.wave_cleared_flag:
		var bonus := waves.clear_bonus(waves.wave_number - 1)
		minerals += bonus
		minerals_gained_this_tick += bonus

	tick_index += 1
	time += dt
	last_tick_usec = Time.get_ticks_usec() - start_usec

func _clear_tick_results() -> void:
	enemies.clear_tick_results()
	combat.clear_tick_results()
	waves.clear_tick_flags()
	hq_hit_this_tick = false
	buildings_destroyed = PackedInt32Array()
	buildings_hit = PackedInt32Array()
	minerals_gained_this_tick = 0

func _resolve_building_damage() -> void:
	var hits := enemies.building_hits
	if hits.is_empty():
		return
	buildings_hit = hits
	var hq := buildings.hq_index
	for idx in hits:
		if idx == hq:
			hq_hit_this_tick = true
		if buildings.alive[idx] != 0 and buildings.hp[idx] <= 0.0:
			if idx == hq:
				buildings.remove(idx)
				buildings_destroyed.append(idx)
				game_over = true
			else:
				buildings_destroyed.append(idx)
				_remove_building(idx)

# ---------------------------------------------------------------------------
# 조회
# ---------------------------------------------------------------------------

func hq_hp() -> float:
	return buildings.hq_hp()

func hq_max_hp() -> float:
	return buildings.hq_max_hp()

func enemies_alive() -> int:
	return enemies.alive_count

func peak_alive() -> int:
	return enemies.peak_alive

## 결정론 검증용 상태 해시
func state_hash() -> int:
	var h := enemies.state_hash()
	h = (h * 31 + minerals) & 0x7FFFFFFF
	h = (h * 31 + kills) & 0x7FFFFFFF
	h = (h * 31 + waves.wave_number) & 0x7FFFFFFF
	h = (h * 31 + int(hq_hp())) & 0x7FFFFFFF
	h = (h * 31 + combat.p_alive_count) & 0x7FFFFFFF
	return h

## 디버그·스트레스: 적을 즉시 추가한다. ring_radius > 0이면 HQ 주변 링에, 아니면 맵 가장자리에.
func debug_spawn(count: int, type: int = EnemyData.EnemyType.RUSHER, ring_radius: float = -1.0) -> int:
	var spawned := 0
	var w := waves.wave_number
	var m := float(SimConfig.MAP_SIZE)
	for i in range(count):
		var x := 0.0
		var y := 0.0
		if ring_radius > 0.0:
			var a := rng.randf() * TAU
			var r := ring_radius + rng.randf_range(-3.0, 3.0)
			x = clampf(SimConfig.HQ_CENTER.x + cos(a) * r, 1.0, m - 1.0)
			y = clampf(SimConfig.HQ_CENTER.y + sin(a) * r, 1.0, m - 1.0)
		else:
			var side := rng.randi_range(0, 3)
			var along := rng.randf_range(1.0, m - 1.0)
			x = along
			y = 0.6
			match side:
				1:
					x = m - 0.6
					y = along
				2:
					y = m - 0.6
				3:
					x = 0.6
					y = along
		if enemies.spawn(type, x, y, WaveSim.hp_scale(w), WaveSim.dps_scale(w), WaveSim.speed_scale(w)) >= 0:
			spawned += 1
	return spawned
