extends RefCounted

## Wave Sim — 웨이브 규모·타입·구성·방향을 계산하고 스폰 큐를 관리한다.
## 개체 추가는 Spawner 역할인 drain_spawns()가 Enemy Sim에 넘긴다. 웨이브는 무한이다.

const SimConfig := preload("res://sim/sim_config.gd")

enum WaveType { SCOUT, DENSITY, BREACH, STORM }
enum Side { NORTH, EAST, SOUTH, WEST }

const WAVE_INTERVAL := 8.0          # 클리어 후 다음 웨이브까지
const WAVE_OVERLAP_TIME := 45.0     # 이 시간이 지나면 적이 남아 있어도 다음 웨이브가 겹친다
const SPAWN_SPREAD_SECONDS := 7.0   # 웨이브 스폰을 펼치는 시간
const EARLY_WAVE_MAX := 3
const SIZE := SimConfig.MAP_SIZE

var wave_number: int = 1
var wave_type: int = WaveType.SCOUT
var active: bool = false
var between: bool = false
var countdown: float = 0.0
var wave_time: float = 0.0
var spawn_sides: int = 0            # Side 비트마스크 (HUD 경고용)
var total_planned: int = 0
var spawned_this_wave: int = 0
var waves_cleared: int = 0
var wave_started_flag: bool = false # 이번 틱 웨이브 시작 (HUD 배너용)
var wave_cleared_flag: bool = false

# 스폰 큐 (병렬 배열)
var q_type: PackedInt32Array
var q_x: PackedFloat32Array
var q_y: PackedFloat32Array
var q_hp: PackedFloat32Array
var q_dps: PackedFloat32Array
var q_speed: PackedFloat32Array
var q_head: int = 0
var _spawn_accum: float = 0.0
var _spawn_per_second: float = 0.0

func _init() -> void:
	clear_all()

func clear_all() -> void:
	wave_number = 1
	wave_type = WaveType.SCOUT
	active = false
	between = false
	countdown = 0.0
	wave_time = 0.0
	spawn_sides = 0
	total_planned = 0
	spawned_this_wave = 0
	waves_cleared = 0
	wave_started_flag = false
	wave_cleared_flag = false
	_clear_queue()

func _clear_queue() -> void:
	q_type = PackedInt32Array()
	q_x = PackedFloat32Array()
	q_y = PackedFloat32Array()
	q_hp = PackedFloat32Array()
	q_dps = PackedFloat32Array()
	q_speed = PackedFloat32Array()
	q_head = 0
	_spawn_accum = 0.0
	_spawn_per_second = 0.0

func queue_size() -> int:
	return q_type.size() - q_head

func clear_tick_flags() -> void:
	wave_started_flag = false
	wave_cleared_flag = false

# ---------------------------------------------------------------------------
# 수식
# ---------------------------------------------------------------------------

static func type_for_wave(w: int) -> int:
	if w <= 1:
		return WaveType.SCOUT
	match (w - 2) % 3:
		0: return WaveType.DENSITY
		1: return WaveType.BREACH
		_: return WaveType.STORM

## 규모 곡선: 1웨이브 12, 7웨이브 폭풍 ~107, 13웨이브 폭풍 ~280, 19웨이브 폭풍 ~530.
## 수입(처치 보상)이 규모에 비례하므로 총 HP/타워 DPS 비율이 대체로 일정하게 유지된다.
static func base_count(w: int) -> int:
	var n := float(w - 1)
	return int(12.0 + 6.0 * n + 0.8 * n * n)

static func type_multiplier(t: int) -> float:
	match t:
		WaveType.SCOUT: return 1.0
		WaveType.DENSITY: return 1.2
		WaveType.BREACH: return 0.8
		WaveType.STORM: return 1.4
	return 1.0

static func enemy_count(w: int) -> int:
	return int(float(base_count(w)) * type_multiplier(type_for_wave(w)))

static func hp_scale(w: int) -> float:
	var n := float(w - 1)
	return 1.0 + 0.10 * n + 0.008 * n * n

static func dps_scale(w: int) -> float:
	return 1.0 + 0.06 * float(w - 1)

static func speed_scale(w: int) -> float:
	return minf(1.0 + 0.015 * float(w - 1), 1.3)

## 타입별 구성 비율 [rusher, tank, splitter]. 웨이브 초반에는 탱크·스플리터가 없다.
static func composition(w: int, t: int) -> PackedFloat32Array:
	var rusher := 1.0
	var tank := 0.0
	var splitter := 0.0
	match t:
		WaveType.SCOUT:
			rusher = 1.0
		WaveType.DENSITY:
			rusher = 0.85
			splitter = 0.15
		WaveType.BREACH:
			rusher = 0.4
			tank = 0.45
			splitter = 0.15
		WaveType.STORM:
			rusher = 0.6
			tank = 0.2
			splitter = 0.2
	if w < 2:
		rusher += splitter
		splitter = 0.0
	if w < 3:
		rusher += tank
		tank = 0.0
	return PackedFloat32Array([rusher, tank, splitter])

# ---------------------------------------------------------------------------
# 진행
# ---------------------------------------------------------------------------

func start_wave(rng: RandomNumberGenerator) -> void:
	_clear_queue()
	wave_type = type_for_wave(wave_number)
	var count := enemy_count(wave_number)
	var comp := composition(wave_number, wave_type)
	var hs := hp_scale(wave_number)
	var ds := dps_scale(wave_number)
	var ss := speed_scale(wave_number)
	spawn_sides = _pick_sides(rng)
	for i in range(count):
		var roll := rng.randf()
		var type := EnemyData.EnemyType.RUSHER
		if roll < comp[1]:
			type = EnemyData.EnemyType.TANK
		elif roll < comp[1] + comp[2]:
			type = EnemyData.EnemyType.SPLITTER
		var pos := _spawn_position(rng)
		q_type.append(type)
		q_x.append(pos.x)
		q_y.append(pos.y)
		q_hp.append(hs)
		q_dps.append(ds)
		q_speed.append(ss)
	total_planned = count
	spawned_this_wave = 0
	_spawn_per_second = maxf(float(count) / SPAWN_SPREAD_SECONDS, 3.0)
	_spawn_accum = 1.0
	active = true
	between = false
	wave_time = 0.0
	wave_started_flag = true

func _pick_sides(rng: RandomNumberGenerator) -> int:
	match wave_type:
		WaveType.BREACH:
			return 1 << rng.randi_range(0, 3)
		WaveType.STORM:
			return 0xF
		_:
			if wave_number <= EARLY_WAVE_MAX:
				return 0xF
			var a := 1 << rng.randi_range(0, 3)
			var b := 1 << rng.randi_range(0, 3)
			return a | b

func _spawn_position(rng: RandomNumberGenerator) -> Vector2:
	var hq := SimConfig.HQ_CENTER
	if wave_number <= EARLY_WAVE_MAX and wave_type != WaveType.BREACH:
		var radius := 22.0 + float(wave_number - 1) * 8.0 + rng.randf_range(-3.0, 4.0)
		var angle := rng.randf() * TAU
		var pos := hq + Vector2(cos(angle), sin(angle)) * radius
		return Vector2(
			clampf(pos.x, 1.0, float(SIZE) - 1.0),
			clampf(pos.y, 1.0, float(SIZE) - 1.0)
		)
	# 선택된 변 중 하나에서 스폰
	var sides: Array = []
	for s in range(4):
		if spawn_sides & (1 << s) != 0:
			sides.append(s)
	if sides.is_empty():
		sides = [0, 1, 2, 3]
	var side: int = sides[rng.randi_range(0, sides.size() - 1)]
	var span_min := 1.0
	var span_max := float(SIZE) - 1.0
	if wave_type == WaveType.BREACH:
		# 돌파: 변의 가운데 40%에 집중
		span_min = float(SIZE) * 0.3
		span_max = float(SIZE) * 0.7
	var along := rng.randf_range(span_min, span_max)
	match side:
		Side.NORTH: return Vector2(along, 0.6)
		Side.EAST: return Vector2(float(SIZE) - 0.6, along)
		Side.SOUTH: return Vector2(along, float(SIZE) - 0.6)
		_: return Vector2(0.6, along)

## 큐에서 이번 틱 스폰할 개체를 Enemy Sim에 넣는다. 스폰한 수를 반환한다.
func drain_spawns(dt: float, enemies) -> int:
	if q_head >= q_type.size():
		return 0
	_spawn_accum += _spawn_per_second * dt
	var n := int(_spawn_accum)
	if n <= 0:
		return 0
	_spawn_accum -= float(n)
	var spawned := 0
	while n > 0 and q_head < q_type.size():
		var idx: int = enemies.spawn(q_type[q_head], q_x[q_head], q_y[q_head],
			q_hp[q_head], q_dps[q_head], q_speed[q_head])
		if idx < 0:
			break
		q_head += 1
		n -= 1
		spawned += 1
	spawned_this_wave += spawned
	if q_head >= q_type.size():
		_clear_queue()
	return spawned

## 웨이브 상태 진행. 클리어·다음 웨이브 시작을 판단한다.
func tick(dt: float, enemies_alive: int, rng: RandomNumberGenerator) -> void:
	if between:
		countdown -= dt
		if countdown <= 0.0:
			start_wave(rng)
		return
	if not active:
		start_wave(rng)
		return
	wave_time += dt
	if enemies_alive <= 0 and queue_size() == 0:
		active = false
		between = true
		countdown = WAVE_INTERVAL
		waves_cleared += 1
		wave_cleared_flag = true
		wave_number += 1
		return
	if wave_time >= WAVE_OVERLAP_TIME and queue_size() == 0:
		# 적이 남아 있어도 다음 압박이 겹친다
		wave_number += 1
		start_wave(rng)

func clear_bonus(w: int) -> int:
	return 20 + w * 8
