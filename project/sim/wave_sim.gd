extends RefCounted

## 압박 스트림 — 웨이브·급증·휴식·카운트다운이 없다. 런 시작부터 끝까지 한 흐름으로 몰려온다.
## 2026-09-22 플레이 판단: "중간에 몰아치지 않는다. 웨이브 개념이 없어야 한다." 주기적 급증은 예고·덩어리·잦아듦으로
## 결국 웨이브였다. 그래서 급증을 없애고 그 물량을 스트림에 녹였다.
##  - 유입률: 초당 스폰 수 = base_rate(경과 시간) × pressure. 경과 시간에 따라 계속 오른다.
##  - 압박 배율(pressure): PRESSURE_MIN~MAX 사이를 천천히 떠돈다. 바닥이 0.9라 잦아드는 순간이 없고, 정점은 예고 없이 온다.
##  - 방향 가중치: 변마다 SIDE_WEIGHT_MIN~MAX를 천천히 떠돈다. 항상 사방에서 오되 한동안 한쪽이 더 두껍다.
##  - 진입로: 변마다 몇 개가 천천히 옮겨가며 스폰이 그 근처에 모여 기둥처럼 보인다.
##  - 스폰 거리: 본진 주변 링에서 시작해 맵 가장자리까지 연속으로 넓어진다. 끊기는 전환이 없다.
## 개체 추가는 drain_spawns()가 Enemy Sim에 넘긴다. 파일·필드 이름(waves)은 호출처 호환을 위해 유지한다.

const SimConfig := preload("res://sim/sim_config.gd")

enum Side { NORTH, EAST, SOUTH, WEST }

const STREAM_INITIAL_BURST := 64.0    # 첫 틱에 바로 보이는 적 수 (시작부터 무리가 보여야 한다)
const INITIAL_RING_RADIUS := 17.0     # 첫 무리는 더 가까이
const RING_RADIUS_MIN := 24.0         # 이후 스폰 링 시작 반지름 (타일)
const RING_RADIUS_GROWTH := 0.25      # 초당 링 반지름 증가. 약 3분이면 가장자리에 닿는다
const RING_RADIUS_MAX := 72.0         # 맵 절반(64)보다 커서 정면 진입로는 가장자리에 붙는다. 맵 밖은 잘라낸다
const LANES_PER_SIDE := 3             # 변마다 진입로 수. 스트림은 항상 사방 12갈래에서 온다
const LANE_SHIFT_INTERVAL := 4.0      # 이 주기마다 진입로 하나가 옮겨간다
const LANE_SPREAD := 0.12             # 진입로 각도 폭 (라디안). 좁을수록 기둥처럼 몰려온다
const PRESSURE_MIN := 0.9             # 압박 배율 바닥. 1.0 아래로 크게 내려가지 않아 "잦아드는 구간"이 없다
const PRESSURE_MAX := 1.5
const PRESSURE_MAX_AT_START := 1.15    # 천장은 첫 PRESSURE_RAMP_SECONDS 동안 여기서 PRESSURE_MAX까지 열린다. 시작 방어만으로 버틸 첫 2분
const PRESSURE_RAMP_SECONDS := 120.0
const PRESSURE_SHIFT_INTERVAL := 20.0 # 이 주기마다 새 목표 배율을 뽑는다
const PRESSURE_DRIFT_PER_SEC := 0.04  # 배율이 목표로 움직이는 최대 속도. 바닥→천장 15초
const SIDE_WEIGHT_MIN := 0.7
const SIDE_WEIGHT_MAX := 1.5
const SIDE_SHIFT_INTERVAL := 12.0     # 이 주기마다 한 변의 목표 가중치를 새로 뽑는다
const SIDE_DRIFT_PER_SEC := 0.06
const HEAVY_SIDE_THRESHOLD := 1.25    # 이 가중치 이상이면 레이더에 "두꺼운 변"으로 표시
const SIZE := SimConfig.MAP_SIZE

var enabled: bool = true              # false면 스폰하지 않는다 (테스트용)
var time: float = 0.0
var pressure: float = 1.0             # 현재 압박 배율
var side_weight: PackedFloat32Array   # 변별 현재 가중치
var stream_spawned: int = 0
var stream_side_counts: PackedInt32Array   # 변별 스폰 수 (사방 분포 검증용)
var _last_side: int = 0

var _stream_accum: float = 0.0
var _pressure_target: float = 1.0
var _pressure_timer: float = 0.0
var _side_target: PackedFloat32Array
var _side_timer: float = 0.0
# 진입로: 변마다 LANES_PER_SIDE개의 각도. 스트림이 점이 아니라 기둥으로 보이게 한다
var _lane_angle: PackedFloat32Array
var _lane_timer: float = 0.0

func _init() -> void:
	clear_all()

func clear_all() -> void:
	enabled = true
	time = 0.0
	pressure = 1.0
	_pressure_target = 1.0
	_pressure_timer = PRESSURE_SHIFT_INTERVAL
	side_weight = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	_side_target = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	_side_timer = SIDE_SHIFT_INTERVAL
	stream_spawned = 0
	stream_side_counts = PackedInt32Array([0, 0, 0, 0])
	_stream_accum = STREAM_INITIAL_BURST
	_lane_angle = PackedFloat32Array()
	_lane_angle.resize(4 * LANES_PER_SIDE)
	for side in range(4):
		for k in range(LANES_PER_SIDE):
			# 처음에는 변을 고르게 나눈 진입로. 이후 하나씩 무작위로 옮겨간다
			var frac := (float(k) + 0.5) / float(LANES_PER_SIDE)
			_lane_angle[side * LANES_PER_SIDE + k] = _side_base_angle(side) + (frac - 0.5) * PI * 0.44
	_lane_timer = LANE_SHIFT_INTERVAL

# ---------------------------------------------------------------------------
# 수식 (모두 경과 시간 기반)
# ---------------------------------------------------------------------------

## 기본 유입률(초당 스폰 수). m = 경과 분. 0분 4.0 → 2분 6.7 → 5분 12.8 → 10분 28 → 15분 49.8
## 압박 배율 평균 1.2를 곱하면 첫 1분 총량은 예전 스트림+첫 급증과 같고(다만 덩어리 없이 고르게), 중반부터는 예전 합계와 비슷하다.
## 같은 총량이어도 연속 스트림은 타워가 쉬지 못해 더 맵다. 시작값은 플레이로 다시 정한다.
static func base_rate(t: float) -> float:
	var m := t / 60.0
	return 4.0 + 1.1 * m + 0.13 * m * m

## 지금 이 순간의 유입률 (HUD·디버그)
func spawn_rate() -> float:
	return base_rate(time) * pressure

static func hp_scale(t: float) -> float:
	var m := t / 60.0
	return 1.0 + 0.12 * m + 0.012 * m * m

static func dps_scale(t: float) -> float:
	return 1.0 + 0.06 * (t / 60.0)

static func speed_scale(t: float) -> float:
	return minf(1.0 + 0.015 * (t / 60.0), 1.3)

## 구성 비율 [rusher, tank, splitter]. 초반에는 탱크·스플리터가 없다.
## 급증을 없애면서 예전 돌파·폭풍 급증이 넣던 탱크 몫을 스트림에 합쳤다.
static func composition(t: float) -> PackedFloat32Array:
	var m := t / 60.0
	var splitter_gate := clampf((m - 0.75) / 1.5, 0.0, 1.0)
	var tank_gate := clampf((m - 1.5) / 2.0, 0.0, 1.0)
	var splitter := 0.18 * splitter_gate
	var tank := 0.18 * tank_gate
	return PackedFloat32Array([1.0 - tank - splitter, tank, splitter])

static func _roll_type(rng: RandomNumberGenerator, comp: PackedFloat32Array) -> int:
	var roll := rng.randf()
	if roll < comp[1]:
		return EnemyData.EnemyType.TANK
	if roll < comp[1] + comp[2]:
		return EnemyData.EnemyType.SPLITTER
	return EnemyData.EnemyType.RUSHER

## 가중치가 HEAVY_SIDE_THRESHOLD 이상인 변 비트마스크 (레이더 경고용)
func heavy_sides() -> int:
	var mask := 0
	for s in range(4):
		if side_weight[s] >= HEAVY_SIDE_THRESHOLD:
			mask |= 1 << s
	return mask

# ---------------------------------------------------------------------------
# 진행
# ---------------------------------------------------------------------------

static func _side_base_angle(side: int) -> float:
	match side:
		Side.NORTH: return -PI * 0.5
		Side.EAST: return 0.0
		Side.SOUTH: return PI * 0.5
	return PI

## 진입로 하나를 무작위로 골라 옮긴다. 전부 한꺼번에 바꾸지 않아 사방의 흐름이 끊기지 않는다.
func _shift_one_lane(rng: RandomNumberGenerator) -> void:
	var lane := rng.randi_range(0, 4 * LANES_PER_SIDE - 1)
	var side := lane / LANES_PER_SIDE
	_lane_angle[lane] = _side_base_angle(side) + rng.randf_range(-PI * 0.22, PI * 0.22)

## 변 가중치로 변을 하나 고른다. 가중치 바닥이 0보다 커서 어떤 변도 비지 않는다.
func _pick_side(rng: RandomNumberGenerator) -> int:
	var total := side_weight[0] + side_weight[1] + side_weight[2] + side_weight[3]
	var roll := rng.randf() * total
	for s in range(3):
		roll -= side_weight[s]
		if roll < 0.0:
			return s
	return 3

## 스폰 위치. 본진 중심에서 시간에 따라 넓어지는 링 위, 그 변의 진입로 근처.
## 링이 맵보다 커지면 맵 안으로 잘라 자연히 가장자리 스폰이 된다 (전환 시점 없음).
func _spawn_position(rng: RandomNumberGenerator) -> Vector2:
	var side := _pick_side(rng)
	_last_side = side
	var radius := minf(RING_RADIUS_MIN + time * RING_RADIUS_GROWTH, RING_RADIUS_MAX) + rng.randf_range(-3.0, 3.0)
	if time <= 0.0:
		radius = INITIAL_RING_RADIUS + rng.randf_range(-2.5, 2.5)
	var lane := side * LANES_PER_SIDE + rng.randi_range(0, LANES_PER_SIDE - 1)
	var angle := _lane_angle[lane] + rng.randf_range(-LANE_SPREAD, LANE_SPREAD)
	var pos := SimConfig.HQ_CENTER + Vector2(cos(angle), sin(angle)) * radius
	return Vector2(clampf(pos.x, 0.6, float(SIZE) - 0.6), clampf(pos.y, 0.6, float(SIZE) - 0.6))

## 이번 틱 스폰할 개체를 Enemy Sim에 넣는다. 스폰한 수를 반환한다.
func drain_spawns(dt: float, enemies, rng: RandomNumberGenerator) -> int:
	if not enabled:
		return 0
	var hs := hp_scale(time)
	var ds := dps_scale(time)
	var ss := speed_scale(time)
	var spawned := 0
	_stream_accum += spawn_rate() * dt
	var n := int(_stream_accum)
	if n > 0:
		_stream_accum -= float(n)
		var comp := composition(time)
		for i in range(n):
			var pos := _spawn_position(rng)
			if enemies.spawn(_roll_type(rng, comp), pos.x, pos.y, hs, ds, ss) < 0:
				break
			spawned += 1
			stream_spawned += 1
			stream_side_counts[_last_side] += 1
	return spawned

## 압박 진행. 배율·변 가중치·진입로가 천천히 떠돈다. 급격한 점프나 멈춤은 없다.
func tick(dt: float, _enemies_alive: int, rng: RandomNumberGenerator) -> void:
	if not enabled:
		return
	time += dt
	_lane_timer -= dt
	if _lane_timer <= 0.0:
		_lane_timer = LANE_SHIFT_INTERVAL
		_shift_one_lane(rng)
	_pressure_timer -= dt
	if _pressure_timer <= 0.0:
		_pressure_timer = PRESSURE_SHIFT_INTERVAL
		var ceiling := lerpf(PRESSURE_MAX_AT_START, PRESSURE_MAX, clampf(time / PRESSURE_RAMP_SECONDS, 0.0, 1.0))
		_pressure_target = rng.randf_range(PRESSURE_MIN, ceiling)
	pressure = move_toward(pressure, _pressure_target, PRESSURE_DRIFT_PER_SEC * dt)
	_side_timer -= dt
	if _side_timer <= 0.0:
		_side_timer = SIDE_SHIFT_INTERVAL
		_side_target[rng.randi_range(0, 3)] = rng.randf_range(SIDE_WEIGHT_MIN, SIDE_WEIGHT_MAX)
	for s in range(4):
		side_weight[s] = move_toward(side_weight[s], _side_target[s], SIDE_DRIFT_PER_SEC * dt)
