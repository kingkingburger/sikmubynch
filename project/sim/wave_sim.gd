extends RefCounted

## Wave Sim — 끊기지 않는 압박. 두 층으로 이루어진다.
##  - 스트림: 런 시작부터 항상 흐르는 스폰. 초당 스폰 수가 경과 시간에 따라 오른다. 방향은 주기적으로 바뀐다.
##  - 급증: 주기적으로 스트림 위에 겹치는 큰 덩어리(밀도·돌파·폭풍). 규모는 횟수에 따라 2차 곡선.
## 웨이브 라운드·휴식 카운트다운·클리어 판정은 없다. 배율은 웨이브 번호가 아니라 경과 시간으로 오른다.
## 개체 추가는 drain_spawns()가 Enemy Sim에 넘긴다.

const SimConfig := preload("res://sim/sim_config.gd")

enum WaveType { SCOUT, DENSITY, BREACH, STORM }   # SCOUT = 급증 없음(스트림만)
enum Side { NORTH, EAST, SOUTH, WEST }

const SURGE_FIRST_AT := 25.0          # 첫 급증까지
const SURGE_INTERVAL := 40.0          # 급증 간격
const SURGE_SPREAD_SECONDS := 6.0     # 급증 스폰을 펼치는 시간
const STREAM_SHIFT_INTERVAL := 30.0   # 스트림 방향 전환 주기
const EARLY_RING_SECONDS := 75.0      # 이 시간 전에는 본진 주변 링에서 스폰 (첫 10초 안에 보이게)
const RING_RADIUS_MIN := 24.0
const RING_RADIUS_GROWTH := 0.15      # 초당 링 반지름 증가
const STREAM_INITIAL_BURST := 4.0     # 첫 틱에 바로 보이는 적 수
const SIZE := SimConfig.MAP_SIZE

var enabled: bool = true              # false면 스폰하지 않는다 (테스트용)
var time: float = 0.0
var wave_number: int = 0              # 지금까지 시작한 급증 수 (HUD "급증 N")
var wave_type: int = WaveType.SCOUT   # 마지막 급증 타입
var active: bool = false              # 급증 스폰 진행 중
var wave_time: float = 0.0            # 현재 급증 시작 후 경과
var surge_countdown: float = SURGE_FIRST_AT
var spawn_sides: int = 0              # 현재(마지막) 급증의 변 비트마스크
var stream_sides: int = 0xF           # 현재 스트림 변 비트마스크
var stream_timer: float = 0.0
var stream_shift_flag: bool = false   # 이번 틱 스트림 방향이 바뀜
var total_planned: int = 0            # 마지막 급증 규모
var spawned_this_wave: int = 0
var stream_spawned: int = 0
var wave_started_flag: bool = false   # 이번 틱 급증 시작 (배너용)

# 급증 스폰 큐 (병렬 배열)
var q_type: PackedInt32Array
var q_x: PackedFloat32Array
var q_y: PackedFloat32Array
var q_head: int = 0
var _surge_accum: float = 0.0
var _surge_per_second: float = 0.0
var _stream_accum: float = 0.0

func _init() -> void:
	clear_all()

func clear_all() -> void:
	enabled = true
	time = 0.0
	wave_number = 0
	wave_type = WaveType.SCOUT
	active = false
	wave_time = 0.0
	surge_countdown = SURGE_FIRST_AT
	spawn_sides = 0
	stream_sides = 0xF
	stream_timer = STREAM_SHIFT_INTERVAL
	stream_shift_flag = false
	total_planned = 0
	spawned_this_wave = 0
	stream_spawned = 0
	wave_started_flag = false
	_stream_accum = STREAM_INITIAL_BURST
	_clear_queue()

func _clear_queue() -> void:
	q_type = PackedInt32Array()
	q_x = PackedFloat32Array()
	q_y = PackedFloat32Array()
	q_head = 0
	_surge_accum = 0.0
	_surge_per_second = 0.0

func queue_size() -> int:
	return q_type.size() - q_head

func clear_tick_flags() -> void:
	wave_started_flag = false
	stream_shift_flag = false

# ---------------------------------------------------------------------------
# 수식 (모두 경과 시간 기반)
# ---------------------------------------------------------------------------

## 스트림 초당 스폰 수. m = 경과 분. 0분 0.8 → 5분 4.3 → 10분 10 → 15분 19
static func stream_rate(t: float) -> float:
	var m := t / 60.0
	return 0.8 + 0.45 * m + 0.05 * m * m

## 급증 k번째 기본 규모. 3번째 폭풍 ~75, 9번째 폭풍 ~270, 15번째 폭풍 ~480
static func surge_base(k: int) -> int:
	var n := float(k)
	return int(12.0 + 7.0 * n + 0.9 * n * n)

static func type_for_surge(k: int) -> int:
	match (k - 1) % 3:
		0: return WaveType.DENSITY
		1: return WaveType.BREACH
		_: return WaveType.STORM

static func type_multiplier(t: int) -> float:
	match t:
		WaveType.DENSITY: return 1.2
		WaveType.BREACH: return 0.8
		WaveType.STORM: return 1.5
	return 1.0

static func surge_count(k: int) -> int:
	return int(float(surge_base(k)) * type_multiplier(type_for_surge(k)))

static func hp_scale(t: float) -> float:
	var m := t / 60.0
	return 1.0 + 0.12 * m + 0.012 * m * m

static func dps_scale(t: float) -> float:
	return 1.0 + 0.06 * (t / 60.0)

static func speed_scale(t: float) -> float:
	return minf(1.0 + 0.015 * (t / 60.0), 1.3)

## 타입별 구성 비율 [rusher, tank, splitter]. 초반에는 탱크·스플리터가 없다.
static func composition(t: float, surge_type: int) -> PackedFloat32Array:
	var m := t / 60.0
	var splitter_gate := clampf((m - 0.75) / 1.5, 0.0, 1.0)
	var tank_gate := clampf((m - 1.5) / 2.0, 0.0, 1.0)
	var tank := 0.0
	var splitter := 0.0
	match surge_type:
		WaveType.SCOUT:        # 스트림
			splitter = 0.15 * splitter_gate
			tank = 0.12 * tank_gate
		WaveType.DENSITY:
			splitter = 0.2 * splitter_gate
			tank = 0.05 * tank_gate
		WaveType.BREACH:
			splitter = 0.15 * splitter_gate
			tank = 0.5 * tank_gate
		WaveType.STORM:
			splitter = 0.2 * splitter_gate
			tank = 0.25 * tank_gate
	return PackedFloat32Array([1.0 - tank - splitter, tank, splitter])

static func _roll_type(rng: RandomNumberGenerator, comp: PackedFloat32Array) -> int:
	var roll := rng.randf()
	if roll < comp[1]:
		return EnemyData.EnemyType.TANK
	if roll < comp[1] + comp[2]:
		return EnemyData.EnemyType.SPLITTER
	return EnemyData.EnemyType.RUSHER

# ---------------------------------------------------------------------------
# 진행
# ---------------------------------------------------------------------------

func start_surge(rng: RandomNumberGenerator) -> void:
	wave_number += 1
	wave_type = type_for_surge(wave_number)
	var count := surge_count(wave_number)
	var comp := composition(time, wave_type)
	spawn_sides = _pick_surge_sides(rng)
	_clear_queue()
	for i in range(count):
		var pos := _side_position(rng, spawn_sides, wave_type == WaveType.BREACH)
		q_type.append(_roll_type(rng, comp))
		q_x.append(pos.x)
		q_y.append(pos.y)
	total_planned = count
	spawned_this_wave = 0
	_surge_per_second = maxf(float(count) / SURGE_SPREAD_SECONDS, 4.0)
	_surge_accum = 1.0
	active = true
	wave_time = 0.0
	wave_started_flag = true
	surge_countdown = SURGE_INTERVAL

func _pick_surge_sides(rng: RandomNumberGenerator) -> int:
	match wave_type:
		WaveType.BREACH:
			return 1 << rng.randi_range(0, 3)
		WaveType.STORM:
			return 0xF
		_:
			var a := 1 << rng.randi_range(0, 3)
			var b := 1 << rng.randi_range(0, 3)
			return a | b

func _shift_stream(rng: RandomNumberGenerator) -> void:
	var a := 1 << rng.randi_range(0, 3)
	var b := 1 << rng.randi_range(0, 3)
	var sides := a | b
	if sides == stream_sides:
		sides = 1 << ((rng.randi_range(0, 3) + 1) % 4)
	stream_sides = sides
	stream_shift_flag = true

## 변 비트마스크 중 하나를 골라 스폰 위치. 초반에는 본진 주변 링, 이후에는 맵 가장자리.
func _side_position(rng: RandomNumberGenerator, sides: int, focused: bool) -> Vector2:
	var list: Array = []
	for s in range(4):
		if sides & (1 << s) != 0:
			list.append(s)
	if list.is_empty():
		list = [0, 1, 2, 3]
	var side: int = list[rng.randi_range(0, list.size() - 1)]
	var hq := SimConfig.HQ_CENTER
	if time < EARLY_RING_SECONDS:
		var radius := RING_RADIUS_MIN + time * RING_RADIUS_GROWTH + rng.randf_range(-3.0, 3.0)
		var base := 0.0
		match side:
			Side.NORTH: base = -PI * 0.5
			Side.EAST: base = 0.0
			Side.SOUTH: base = PI * 0.5
			_: base = PI
		var spread := PI * 0.125 if focused else PI * 0.25
		var angle := base + rng.randf_range(-spread, spread)
		var pos := hq + Vector2(cos(angle), sin(angle)) * radius
		return Vector2(clampf(pos.x, 1.0, float(SIZE) - 1.0), clampf(pos.y, 1.0, float(SIZE) - 1.0))
	var span_min := 1.0
	var span_max := float(SIZE) - 1.0
	if focused:
		span_min = float(SIZE) * 0.3
		span_max = float(SIZE) * 0.7
	var along := rng.randf_range(span_min, span_max)
	match side:
		Side.NORTH: return Vector2(along, 0.6)
		Side.EAST: return Vector2(float(SIZE) - 0.6, along)
		Side.SOUTH: return Vector2(along, float(SIZE) - 0.6)
		_: return Vector2(0.6, along)

## 이번 틱 스폰할 개체를 Enemy Sim에 넣는다(스트림 + 급증 큐). 스폰한 수를 반환한다.
func drain_spawns(dt: float, enemies, rng: RandomNumberGenerator) -> int:
	if not enabled:
		return 0
	var hs := hp_scale(time)
	var ds := dps_scale(time)
	var ss := speed_scale(time)
	var spawned := 0
	# 스트림
	_stream_accum += stream_rate(time) * dt
	var n := int(_stream_accum)
	if n > 0:
		_stream_accum -= float(n)
		var comp := composition(time, WaveType.SCOUT)
		for i in range(n):
			var pos := _side_position(rng, stream_sides, false)
			if enemies.spawn(_roll_type(rng, comp), pos.x, pos.y, hs, ds, ss) < 0:
				break
			spawned += 1
			stream_spawned += 1
	# 급증 큐
	if q_head < q_type.size():
		_surge_accum += _surge_per_second * dt
		var m := int(_surge_accum)
		if m > 0:
			_surge_accum -= float(m)
			while m > 0 and q_head < q_type.size():
				if enemies.spawn(q_type[q_head], q_x[q_head], q_y[q_head], hs, ds, ss) < 0:
					break
				q_head += 1
				m -= 1
				spawned += 1
				spawned_this_wave += 1
			if q_head >= q_type.size():
				_clear_queue()
				active = false
	return spawned

## 압박 상태 진행. 급증 시작과 스트림 방향 전환을 판단한다.
func tick(dt: float, _enemies_alive: int, rng: RandomNumberGenerator) -> void:
	if not enabled:
		return
	time += dt
	if active:
		wave_time += dt
	stream_timer -= dt
	if stream_timer <= 0.0:
		stream_timer = STREAM_SHIFT_INTERVAL
		_shift_stream(rng)
	surge_countdown -= dt
	if surge_countdown <= 0.0:
		start_surge(rng)

## 다음 급증까지 남은 초 (HUD)
func seconds_to_surge() -> float:
	return maxf(surge_countdown, 0.0)
