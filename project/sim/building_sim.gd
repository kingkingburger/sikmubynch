extends RefCounted

## Building Sim — 건물 HP·위치·타일 점유를 배열로 관리한다.
## 건물 Node(표현 계층)는 이 인덱스를 들고 HP를 읽기만 한다.

const SimConfig := preload("res://sim/sim_config.gd")

const MAX := SimConfig.MAX_BUILDINGS
const SIZE := SimConfig.MAP_SIZE
const ATTACKERS_PER_TILE := 4
const HQ_REGEN_PER_SEC := 4.0
const AGGRO_RADIUS := 2             # 적이 경로를 벗어나 물러 가는 거리 (칸, 체비셰프)

# 타입 테이블 (BuildingData를 펼친 것)
var type_count: int = 0
var t_cost: PackedInt32Array
var t_hp: PackedFloat32Array
var t_size: PackedInt32Array
var t_damage: PackedFloat32Array
var t_rate: PackedFloat32Array
var t_range: PackedFloat32Array
var t_splash: PackedFloat32Array
var t_slow: PackedFloat32Array
var t_slow_dur: PackedFloat32Array
var t_slow_radius: PackedFloat32Array
var t_proj_kind: PackedInt32Array
var t_proj_speed: PackedFloat32Array
var t_is_tower: PackedInt32Array
var t_mode: PackedInt32Array          # BuildingData.AttackMode
var t_chain: PackedInt32Array
var t_chain_radius: PackedFloat32Array
var t_beam_width: PackedFloat32Array
var t_prefer_hp: PackedInt32Array

# 개체 배열
var alive: PackedInt32Array
var type_id: PackedInt32Array
var hp: PackedFloat32Array
var max_hp: PackedFloat32Array
var tile_x: PackedInt32Array
var tile_y: PackedInt32Array
var size: PackedInt32Array
var cooldown: PackedFloat32Array
var last_hit_tick: PackedInt32Array
var last_fire_tick: PackedInt32Array  # 총구 섬광용. 렌더러가 읽는다
var attackers: PackedInt32Array     # 현재 이 건물을 공격 중인 적 수
var attacker_cap: PackedInt32Array  # 동시 공격 상한 (타일당 ATTACKERS_PER_TILE)
var grid: PackedInt32Array          # 타일 → 건물 인덱스, 없으면 -1
var near_building: PackedInt32Array # 타일 → AGGRO_RADIUS 안에서 가장 가까운 건물, 없으면 -1
var near_dist: PackedInt32Array     # 그 건물까지 거리(칸)
var near_dirty: bool = false        # 배치·철거 후 rebuild_near 필요
var free_list: PackedInt32Array
var high: int = 0
var alive_count: int = 0
var hq_index: int = -1

func _init() -> void:
	alive = PackedInt32Array()
	alive.resize(MAX)
	type_id = PackedInt32Array()
	type_id.resize(MAX)
	hp = PackedFloat32Array()
	hp.resize(MAX)
	max_hp = PackedFloat32Array()
	max_hp.resize(MAX)
	tile_x = PackedInt32Array()
	tile_x.resize(MAX)
	tile_y = PackedInt32Array()
	tile_y.resize(MAX)
	size = PackedInt32Array()
	size.resize(MAX)
	cooldown = PackedFloat32Array()
	cooldown.resize(MAX)
	last_hit_tick = PackedInt32Array()
	last_hit_tick.resize(MAX)
	last_fire_tick = PackedInt32Array()
	last_fire_tick.resize(MAX)
	attackers = PackedInt32Array()
	attackers.resize(MAX)
	attacker_cap = PackedInt32Array()
	attacker_cap.resize(MAX)
	grid = PackedInt32Array()
	grid.resize(SimConfig.CELLS)
	near_building = PackedInt32Array()
	near_building.resize(SimConfig.CELLS)
	near_dist = PackedInt32Array()
	near_dist.resize(SimConfig.CELLS)
	free_list = PackedInt32Array()
	clear_all()

func clear_all() -> void:
	alive.fill(0)
	grid.fill(-1)
	near_building.fill(-1)
	near_dist.fill(0)
	near_dirty = false
	cooldown.fill(0.0)
	last_hit_tick.fill(-100)
	last_fire_tick.fill(-100)
	attackers.fill(0)
	attacker_cap.fill(0)
	free_list = PackedInt32Array()
	high = 0
	alive_count = 0
	hq_index = -1

func set_types(datas: Array) -> void:
	type_count = datas.size()
	t_cost = PackedInt32Array()
	t_hp = PackedFloat32Array()
	t_size = PackedInt32Array()
	t_damage = PackedFloat32Array()
	t_rate = PackedFloat32Array()
	t_range = PackedFloat32Array()
	t_splash = PackedFloat32Array()
	t_slow = PackedFloat32Array()
	t_slow_dur = PackedFloat32Array()
	t_slow_radius = PackedFloat32Array()
	t_proj_kind = PackedInt32Array()
	t_proj_speed = PackedFloat32Array()
	t_is_tower = PackedInt32Array()
	t_mode = PackedInt32Array()
	t_chain = PackedInt32Array()
	t_chain_radius = PackedFloat32Array()
	t_beam_width = PackedFloat32Array()
	t_prefer_hp = PackedInt32Array()
	for d in datas:
		var bd := d as BuildingData
		t_cost.append(bd.cost)
		t_hp.append(bd.max_hp)
		t_size.append(bd.size)
		t_damage.append(bd.damage)
		t_rate.append(bd.attack_rate)
		t_range.append(bd.attack_range)
		t_splash.append(bd.splash_radius)
		t_slow.append(bd.slow_amount)
		t_slow_dur.append(bd.slow_duration)
		t_slow_radius.append(bd.slow_radius)
		t_proj_kind.append(int(bd.projectile_kind))
		t_proj_speed.append(bd.projectile_speed)
		t_is_tower.append(1 if bd.is_tower() else 0)
		t_mode.append(int(bd.attack_mode))
		t_chain.append(bd.chain_count)
		t_chain_radius.append(bd.chain_radius)
		t_beam_width.append(bd.beam_width)
		t_prefer_hp.append(1 if bd.prefer_high_hp else 0)

func building_at(tx: int, ty: int) -> int:
	if not SimConfig.in_bounds(tx, ty):
		return -1
	return grid[ty * SIZE + tx]

func can_place(type: int, tx: int, ty: int) -> bool:
	if type < 0 or type >= type_count:
		return false
	var s := t_size[type]
	for dy in range(s):
		for dx in range(s):
			var x := tx + dx
			var y := ty + dy
			if not SimConfig.in_bounds(x, y):
				return false
			if grid[y * SIZE + x] >= 0:
				return false
	return true

## 배치. 성공하면 인덱스, 실패하면 -1.
func place(type: int, tx: int, ty: int) -> int:
	if not can_place(type, tx, ty):
		return -1
	var idx := -1
	if free_list.size() > 0:
		idx = free_list[free_list.size() - 1]
		free_list.resize(free_list.size() - 1)
	else:
		if high >= MAX:
			return -1
		idx = high
		high += 1
	alive[idx] = 1
	type_id[idx] = type
	hp[idx] = t_hp[type]
	max_hp[idx] = t_hp[type]
	tile_x[idx] = tx
	tile_y[idx] = ty
	size[idx] = t_size[type]
	cooldown[idx] = 0.0
	last_hit_tick[idx] = -100
	last_fire_tick[idx] = -100
	attackers[idx] = 0
	var s := t_size[type]
	# 둘레 타일 수 × 타일당 상한 (1×1은 4, 3×3은 8칸 둘레 → 32는 과해서 절반)
	attacker_cap[idx] = ATTACKERS_PER_TILE * s if s == 1 else ATTACKERS_PER_TILE * s * 2
	for dy in range(s):
		for dx in range(s):
			grid[(ty + dy) * SIZE + tx + dx] = idx
	alive_count += 1
	near_dirty = true
	return idx

func remove(idx: int) -> void:
	if idx < 0 or idx >= high or alive[idx] == 0:
		return
	alive[idx] = 0
	var s := size[idx]
	var tx := tile_x[idx]
	var ty := tile_y[idx]
	for dy in range(s):
		for dx in range(s):
			grid[(ty + dy) * SIZE + tx + dx] = -1
	free_list.append(idx)
	alive_count -= 1
	near_dirty = true
	if idx == hq_index:
		hq_index = -1

## 타일마다 AGGRO_RADIUS 안의 가장 가까운 건물을 기록한다. 적이 틱마다 한 번 읽는다.
## 건물 수 × 발자국 × (2R+1)² 이라 Flow Field BFS보다 훨씬 싸다. 배치·철거 직후 즉시 갱신한다.
func rebuild_near() -> void:
	near_dirty = false
	near_building.fill(-1)
	near_dist.fill(0)
	var r := AGGRO_RADIUS
	for b in range(high):
		if alive[b] == 0:
			continue
		var s := size[b]
		var x0 := tile_x[b] - r
		var y0 := tile_y[b] - r
		var x1 := tile_x[b] + s - 1 + r
		var y1 := tile_y[b] + s - 1 + r
		for y in range(maxi(y0, 0), mini(y1, SIZE - 1) + 1):
			# 발자국까지의 체비셰프 거리
			var ddy := 0
			if y < tile_y[b]:
				ddy = tile_y[b] - y
			elif y > tile_y[b] + s - 1:
				ddy = y - (tile_y[b] + s - 1)
			for x in range(maxi(x0, 0), mini(x1, SIZE - 1) + 1):
				var ddx := 0
				if x < tile_x[b]:
					ddx = tile_x[b] - x
				elif x > tile_x[b] + s - 1:
					ddx = x - (tile_x[b] + s - 1)
				var d := maxi(ddx, ddy)
				var cell := y * SIZE + x
				var cur := near_building[cell]
				if cur < 0 or d < near_dist[cell]:
					near_building[cell] = b
					near_dist[cell] = d

## 피해 적용. 파괴되면 true.
func damage(idx: int, amount: float, tick: int) -> bool:
	if idx < 0 or idx >= high or alive[idx] == 0:
		return false
	hp[idx] -= amount
	last_hit_tick[idx] = tick
	return hp[idx] <= 0.0

func center_x(idx: int) -> float:
	return float(tile_x[idx]) + float(size[idx]) * 0.5

func center_y(idx: int) -> float:
	return float(tile_y[idx]) + float(size[idx]) * 0.5

## 공격 슬롯 확보. 상한이면 false.
func try_attach_attacker(idx: int) -> bool:
	if attackers[idx] >= attacker_cap[idx]:
		return false
	attackers[idx] += 1
	return true

func detach_attacker(idx: int) -> void:
	if idx >= 0 and idx < high and attackers[idx] > 0:
		attackers[idx] -= 1

func regen_hq(dt: float) -> void:
	if hq_index < 0:
		return
	hp[hq_index] = minf(hp[hq_index] + HQ_REGEN_PER_SEC * dt, max_hp[hq_index])

func hq_hp() -> float:
	if hq_index < 0:
		return 0.0
	return hp[hq_index]

func hq_max_hp() -> float:
	if hq_index < 0:
		return 0.0
	return max_hp[hq_index]
