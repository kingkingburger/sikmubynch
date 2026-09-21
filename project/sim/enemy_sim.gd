extends RefCounted

## Enemy Sim — 적 위치·HP·감속을 배열로 관리하고 Flow Field를 따라 이동시킨다.
## 근처(AGGRO_RADIUS 칸)에 건물이 있으면 무엇이든 그쪽으로 틀어 문다. 타워도 예외가 아니다.
## 공격 슬롯이 꽉 찬 건물은 지나친다. 길을 막은 건물 앞에서는 슬롯이 날 때까지 기다린다(밀집).
## 적끼리는 충돌하지 않는다(밀도는 겹침으로 표현).

const SimConfig := preload("res://sim/sim_config.gd")

const MAX := SimConfig.MAX_ENEMIES
const SIZE := SimConfig.MAP_SIZE
const ATTACK_INTERVAL := 1.0
const ENGAGE_DIST := 0.6   # 건물 발자국 가장자리에서 이 거리 안이면 문다 (칸)

# 타입 테이블
var type_count: int = 0
var t_hp: PackedFloat32Array
var t_dps: PackedFloat32Array
var t_speed: PackedFloat32Array
var t_reward: PackedInt32Array
var t_split: PackedInt32Array

# 개체 배열
var alive: PackedInt32Array
var type_id: PackedInt32Array
var pos_x: PackedFloat32Array
var pos_y: PackedFloat32Array
var prev_x: PackedFloat32Array
var prev_y: PackedFloat32Array
var hp: PackedFloat32Array
var max_hp: PackedFloat32Array
var dps: PackedFloat32Array
var speed: PackedFloat32Array
var slow_timer: PackedFloat32Array
var slow_mult: PackedFloat32Array
var attack_timer: PackedFloat32Array
var attack_target: PackedInt32Array   # 건물 인덱스, 없으면 -1
var last_hit_tick: PackedInt32Array
var generation: PackedInt32Array      # 인덱스 재사용 구분용. spawn마다 1 증가
var free_list: PackedInt32Array
var high: int = 0
var alive_count: int = 0
var peak_alive: int = 0

# 이번 틱 결과 (Game Simulation이 소비하고 비운다)
var split_requests: PackedFloat32Array    # [type, x, y, hp_scale, dps_scale, speed_scale] * n
var death_count: int = 0
var death_x: PackedFloat32Array
var death_y: PackedFloat32Array
var death_type: PackedInt32Array
var reward_pending: int = 0
var building_hits: PackedInt32Array       # 이번 틱 공격받은 건물 인덱스 (중복 가능)
var pending_detach: PackedInt32Array      # 죽은 공격자가 놓아야 할 건물 슬롯

func _init() -> void:
	alive = PackedInt32Array()
	alive.resize(MAX)
	type_id = PackedInt32Array()
	type_id.resize(MAX)
	pos_x = PackedFloat32Array()
	pos_x.resize(MAX)
	pos_y = PackedFloat32Array()
	pos_y.resize(MAX)
	prev_x = PackedFloat32Array()
	prev_x.resize(MAX)
	prev_y = PackedFloat32Array()
	prev_y.resize(MAX)
	hp = PackedFloat32Array()
	hp.resize(MAX)
	max_hp = PackedFloat32Array()
	max_hp.resize(MAX)
	dps = PackedFloat32Array()
	dps.resize(MAX)
	speed = PackedFloat32Array()
	speed.resize(MAX)
	slow_timer = PackedFloat32Array()
	slow_timer.resize(MAX)
	slow_mult = PackedFloat32Array()
	slow_mult.resize(MAX)
	attack_timer = PackedFloat32Array()
	attack_timer.resize(MAX)
	attack_target = PackedInt32Array()
	attack_target.resize(MAX)
	last_hit_tick = PackedInt32Array()
	last_hit_tick.resize(MAX)
	generation = PackedInt32Array()
	generation.resize(MAX)
	free_list = PackedInt32Array()
	death_x = PackedFloat32Array()
	death_x.resize(SimConfig.MAX_DEATH_EVENTS)
	death_y = PackedFloat32Array()
	death_y.resize(SimConfig.MAX_DEATH_EVENTS)
	death_type = PackedInt32Array()
	death_type.resize(SimConfig.MAX_DEATH_EVENTS)
	split_requests = PackedFloat32Array()
	building_hits = PackedInt32Array()
	pending_detach = PackedInt32Array()
	clear_all()

func clear_all() -> void:
	alive.fill(0)
	slow_mult.fill(1.0)
	slow_timer.fill(0.0)
	attack_target.fill(-1)
	last_hit_tick.fill(-100)
	generation.fill(0)
	free_list = PackedInt32Array()
	high = 0
	alive_count = 0
	peak_alive = 0
	clear_tick_results()

func clear_tick_results() -> void:
	split_requests = PackedFloat32Array()
	building_hits = PackedInt32Array()
	pending_detach = PackedInt32Array()
	death_count = 0
	reward_pending = 0

func set_types(datas: Array) -> void:
	type_count = datas.size()
	t_hp = PackedFloat32Array()
	t_dps = PackedFloat32Array()
	t_speed = PackedFloat32Array()
	t_reward = PackedInt32Array()
	t_split = PackedInt32Array()
	for d in datas:
		var ed := d as EnemyData
		t_hp.append(ed.max_hp)
		t_dps.append(ed.dps)
		t_speed.append(ed.speed)
		t_reward.append(ed.mineral_reward)
		t_split.append(ed.split_count)

## 스폰. 배율은 웨이브가 정한다. 성공하면 인덱스, 꽉 찼으면 -1.
func spawn(type: int, x: float, y: float, hp_scale: float, dps_scale: float, speed_scale: float) -> int:
	if type < 0 or type >= type_count:
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
	x = clampf(x, 0.5, float(SIZE) - 0.5)
	y = clampf(y, 0.5, float(SIZE) - 0.5)
	pos_x[idx] = x
	pos_y[idx] = y
	prev_x[idx] = x
	prev_y[idx] = y
	hp[idx] = t_hp[type] * hp_scale
	max_hp[idx] = hp[idx]
	dps[idx] = t_dps[type] * dps_scale
	speed[idx] = t_speed[type] * speed_scale
	slow_timer[idx] = 0.0
	slow_mult[idx] = 1.0
	attack_timer[idx] = 0.0
	attack_target[idx] = -1
	last_hit_tick[idx] = -100
	generation[idx] += 1
	alive_count += 1
	if alive_count > peak_alive:
		peak_alive = alive_count
	return idx

## 피해 적용. 죽으면 true. 사망 처리(보상·분열·이벤트)까지 여기서 한다.
func damage(idx: int, amount: float, tick: int) -> bool:
	if idx < 0 or idx >= high or alive[idx] == 0:
		return false
	hp[idx] -= amount
	last_hit_tick[idx] = tick
	if hp[idx] <= 0.0:
		kill(idx)
		return true
	return false

func apply_slow(idx: int, amount: float, duration: float) -> void:
	if idx < 0 or idx >= high or alive[idx] == 0:
		return
	var m := 1.0 - amount
	if m < slow_mult[idx]:
		slow_mult[idx] = m
	if duration > slow_timer[idx]:
		slow_timer[idx] = duration

func kill(idx: int) -> void:
	if idx < 0 or idx >= high or alive[idx] == 0:
		return
	alive[idx] = 0
	alive_count -= 1
	free_list.append(idx)
	if attack_target[idx] >= 0:
		pending_detach.append(attack_target[idx])
		attack_target[idx] = -1
	var t := type_id[idx]
	reward_pending += t_reward[t]
	if death_count < SimConfig.MAX_DEATH_EVENTS:
		death_x[death_count] = pos_x[idx]
		death_y[death_count] = pos_y[idx]
		death_type[death_count] = t
	death_count += 1
	var splits := t_split[t]
	if splits > 0:
		# 자식은 부모 배율을 잇는다 (hp_scale은 부모 max_hp / 기본 hp)
		var hp_scale := max_hp[idx] / t_hp[t]
		var dps_scale := dps[idx] / t_dps[t]
		var speed_scale := speed[idx] / t_speed[t]
		for i in range(splits):
			split_requests.append(float(EnemyData.EnemyType.MINI))
			split_requests.append(pos_x[idx])
			split_requests.append(pos_y[idx])
			split_requests.append(hp_scale)
			split_requests.append(dps_scale)
			split_requests.append(speed_scale)

## 이동과 건물 공격. buildings는 BuildingSim, flow는 FlowField.
func tick(dt: float, flow, buildings, tick_index: int) -> void:
	var size := SIZE
	var fsize := float(size)
	var hq_x: float = SimConfig.HQ_CENTER.x
	var hq_y: float = SimConfig.HQ_CENTER.y
	var grid: PackedInt32Array = buildings.grid
	var b_alive: PackedInt32Array = buildings.alive
	var near_b: PackedInt32Array = buildings.near_building
	var b_cap: PackedInt32Array = buildings.attacker_cap
	var b_tx: PackedInt32Array = buildings.tile_x
	var b_ty: PackedInt32Array = buildings.tile_y
	var b_size: PackedInt32Array = buildings.size
	var dir_x: PackedFloat32Array = flow.dir_x
	var dir_y: PackedFloat32Array = flow.dir_y
	var cost: PackedInt32Array = flow.cost
	var unreachable: int = flow.UNREACHABLE

	for i in range(high):
		if alive[i] == 0:
			continue
		var x := pos_x[i]
		var y := pos_y[i]
		prev_x[i] = x
		prev_y[i] = y

		if slow_timer[i] > 0.0:
			slow_timer[i] -= dt
			if slow_timer[i] <= 0.0:
				slow_timer[i] = 0.0
				slow_mult[i] = 1.0

		# 공격 중
		var target := attack_target[i]
		if target >= 0:
			if b_alive[target] == 0:
				attack_target[i] = -1
			else:
				attack_timer[i] -= dt
				if attack_timer[i] <= 0.0:
					attack_timer[i] = ATTACK_INTERVAL
					buildings.damage(target, dps[i], tick_index)
					building_hits.append(target)
				continue

		var cx := int(x)
		var cy := int(y)
		var cell := cy * size + cx
		var mx := 0.0
		var my := 0.0

		# 근처 건물: 슬롯이 남아 있으면 그쪽으로 틀고, 발자국에 닿으면 문다
		var steer := false
		var nb := near_b[cell]
		# attackers는 이 루프 안에서 바뀌므로 (Packed 배열은 값 복사) 직접 읽는다
		if nb >= 0 and b_alive[nb] != 0 and buildings.attackers[nb] < b_cap[nb]:
			var bs := float(b_size[nb])
			var bx0 := float(b_tx[nb])
			var by0 := float(b_ty[nb])
			var px := clampf(x, bx0, bx0 + bs)
			var py := clampf(y, by0, by0 + bs)
			var ddx := px - x
			var ddy := py - y
			var dist := sqrt(ddx * ddx + ddy * ddy)
			if dist <= ENGAGE_DIST:
				_try_engage(i, nb, buildings)
				if attack_target[i] == nb:
					continue
			elif dist > 0.001:
				mx = ddx / dist
				my = ddy / dist
				steer = true

		# 이동 방향 (근처 건물이 없으면 Flow Field)
		if steer:
			pass
		elif cost[cell] == unreachable:
			mx = hq_x - x
			my = hq_y - y
			var l := sqrt(mx * mx + my * my)
			if l > 0.001:
				mx /= l
				my /= l
		else:
			mx = dir_x[cell]
			my = dir_y[cell]
		if mx == 0.0 and my == 0.0:
			# 목표 셀(HQ) 위에 있음. HQ를 공격한다.
			var b := grid[cell]
			if b >= 0 and b_alive[b] != 0:
				_try_engage(i, b, buildings)
			continue

		var step := speed[i] * slow_mult[i] * dt
		var nx := x + mx * step
		var ny := y + my * step
		if nx < 0.5:
			nx = 0.5
		elif nx > fsize - 0.5:
			nx = fsize - 0.5
		if ny < 0.5:
			ny = 0.5
		elif ny > fsize - 0.5:
			ny = fsize - 0.5
		var ncx := int(nx)
		var ncy := int(ny)
		if ncx != cx or ncy != cy:
			var b := grid[ncy * size + ncx]
			if b >= 0 and b_alive[b] != 0:
				_try_engage(i, b, buildings)
				continue
			# 대각선으로 셀을 바꿀 때 모서리 관통 방지
			if ncx != cx and ncy != cy:
				var bx := grid[cy * size + ncx]
				var by := grid[ncy * size + cx]
				if bx >= 0 and b_alive[bx] != 0:
					_try_engage(i, bx, buildings)
					continue
				if by >= 0 and b_alive[by] != 0:
					_try_engage(i, by, buildings)
					continue
		pos_x[i] = nx
		pos_y[i] = ny

## 건물 공격 슬롯을 얻으면 공격 상태로. 상한이면 제자리에서 기다린다(밀집 표현).
func _try_engage(i: int, b: int, buildings) -> void:
	if buildings.try_attach_attacker(b):
		attack_target[i] = b
		attack_timer[i] = 0.0

## 결정론 검증용 상태 해시
func state_hash() -> int:
	var h := 0
	for i in range(high):
		if alive[i] == 0:
			continue
		h = (h * 31 + int(pos_x[i] * 1000.0)) & 0x7FFFFFFF
		h = (h * 31 + int(pos_y[i] * 1000.0)) & 0x7FFFFFFF
		h = (h * 31 + int(hp[i] * 10.0)) & 0x7FFFFFFF
	return h
