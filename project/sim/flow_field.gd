extends RefCounted

## Flow Field — HQ까지의 비용을 BFS로 계산하고 셀별 이동 방향을 만든다.
## 전체 맵을 셀 배열로 다루며 Node를 참조하지 않는다.
##
## 비용은 4방향 BFS(순수 거리)로 계산하고, 방향은 8방향 이웃 중 최저 비용 셀로 잡는다.
## 대각선 방향은 양쪽 직교 셀이 모두 비어 있을 때만 허용해 벽 모서리 관통을 막는다.
##
## 재계산 분산: 전체 재계산(128×128)은 GDScript에서 수십 ms라 한 틱에 하면 히치가 난다.
## 그래서 뒤쪽 버퍼에 BFS → 방향 순으로 틱마다 정해진 셀 수만큼 진행하고, 끝나면 앞쪽과 바꾼다.
## 적은 계산이 끝날 때까지 이전 필드를 따라간다. 예산은 시간이 아니라 셀 수라 결정적이다.

const SimConfig := preload("res://sim/sim_config.gd")

const SIZE := SimConfig.MAP_SIZE
const CELLS := SimConfig.CELLS
const UNREACHABLE := 0x3FFFFFFF
const DIAG := 0.70710678

## 틱당 예산 (셀 수). BFS 팝과 방향 셀은 비용이 달라 따로 둔다.
const BFS_BUDGET := 4096
const DIR_BUDGET := 2048

enum Phase { IDLE, BFS, DIRS }

# 앞쪽 버퍼: 적 이동이 읽는다
var cost: PackedInt32Array
var dir_x: PackedFloat32Array
var dir_y: PackedFloat32Array
var blocked: PackedInt32Array      # 셀별 장애물 카운트 (0이면 통과 가능)
var dirty: bool = false
var recalc_count: int = 0
var phase: int = Phase.IDLE
var last_step_usec: int = 0        # 마지막 step() 소요 시간 (디버그 지표)

# 뒤쪽 버퍼: 분산 계산 중인 필드
var _b_cost: PackedInt32Array
var _b_dir_x: PackedFloat32Array
var _b_dir_y: PackedFloat32Array
var _queue: PackedInt32Array
var _head: int = 0
var _tail: int = 0
var _row: int = 0
var _targets: PackedInt32Array

func _init() -> void:
	cost = _int_buffer()
	dir_x = _float_buffer()
	dir_y = _float_buffer()
	_b_cost = _int_buffer()
	_b_dir_x = _float_buffer()
	_b_dir_y = _float_buffer()
	blocked = _int_buffer()
	_queue = _int_buffer()
	_targets = PackedInt32Array()
	clear_all()

static func _int_buffer() -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(CELLS)
	return a

static func _float_buffer() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(CELLS)
	return a

func clear_all() -> void:
	cost.fill(UNREACHABLE)
	dir_x.fill(0.0)
	dir_y.fill(0.0)
	blocked.fill(0)
	_targets = PackedInt32Array()
	dirty = false
	recalc_count = 0
	phase = Phase.IDLE

func set_targets(tiles: PackedInt32Array) -> void:
	_targets = tiles.duplicate()
	dirty = true

## 타일 장애물 카운트를 늘리거나 줄인다. 같은 타일에 여러 번 등록해도 마지막 해제 때만 열린다.
func set_blocked(tx: int, ty: int, is_blocked: bool) -> void:
	if not SimConfig.in_bounds(tx, ty):
		return
	var idx := ty * SIZE + tx
	if is_blocked:
		blocked[idx] += 1
	else:
		blocked[idx] = maxi(blocked[idx] - 1, 0)
	dirty = true

func is_blocked(tx: int, ty: int) -> bool:
	if not SimConfig.in_bounds(tx, ty):
		return true
	return blocked[ty * SIZE + tx] > 0

func is_reachable(tx: int, ty: int) -> bool:
	if not SimConfig.in_bounds(tx, ty):
		return false
	return cost[ty * SIZE + tx] != UNREACHABLE

func is_busy() -> bool:
	return phase != Phase.IDLE

## 즉시 전체 재계산 (런 시작·테스트용). 진행 중인 분산 계산은 버리고 새로 한다.
func recalculate() -> void:
	begin()
	while phase != Phase.IDLE:
		_advance(CELLS, CELLS)

## 분산 재계산을 시작한다. 진행 중이면 처음부터 다시 한다 (그사이 장애물이 바뀌었으므로).
func begin() -> void:
	dirty = false
	_b_cost.fill(UNREACHABLE)
	_head = 0
	_tail = 0
	_row = 0
	for t in _targets:
		if t < 0 or t >= CELLS:
			continue
		if _b_cost[t] == 0:
			continue
		_b_cost[t] = 0
		_queue[_tail] = t
		_tail += 1
	phase = Phase.BFS

## 한 틱 분량만 진행한다. 이번 호출로 새 필드가 적용되면 true.
func step() -> bool:
	if phase == Phase.IDLE:
		last_step_usec = 0
		return false
	var t0 := Time.get_ticks_usec()
	var swapped := _advance(BFS_BUDGET, DIR_BUDGET)
	last_step_usec = Time.get_ticks_usec() - t0
	return swapped

func _advance(bfs_budget: int, dir_budget: int) -> bool:
	if phase == Phase.BFS:
		_bfs(bfs_budget)
		return false
	if phase == Phase.DIRS:
		_directions(dir_budget)
		if _row >= SIZE:
			_swap()
			return true
	return false

## 타겟(HQ 셀)에서 역방향 BFS. 타겟 셀 자체는 장애물이어도 진입 가능하다.
func _bfs(budget: int) -> void:
	var c := _b_cost
	var q := _queue
	var blk := blocked
	var size := SIZE
	var head := _head
	var tail := _tail
	var stop := mini(head + budget, CELLS)
	while head < tail and head < stop:
		var cur := q[head]
		head += 1
		var cx := cur % size
		var next_cost := c[cur] + 1
		# 4방향. 각 셀은 한 번만 큐에 들어가므로 tail은 CELLS를 넘지 않는다
		if cx + 1 < size:
			var n := cur + 1
			if blk[n] == 0 and c[n] > next_cost:
				c[n] = next_cost
				q[tail] = n
				tail += 1
		if cx > 0:
			var n := cur - 1
			if blk[n] == 0 and c[n] > next_cost:
				c[n] = next_cost
				q[tail] = n
				tail += 1
		if cur + size < CELLS:
			var n := cur + size
			if blk[n] == 0 and c[n] > next_cost:
				c[n] = next_cost
				q[tail] = n
				tail += 1
		if cur >= size:
			var n := cur - size
			if blk[n] == 0 and c[n] > next_cost:
				c[n] = next_cost
				q[tail] = n
				tail += 1
	_b_cost = c
	_queue = q
	_head = head
	_tail = tail
	if head >= tail:
		phase = Phase.DIRS
		_row = 0

## 행 단위로 방향을 채운다. 이웃 8개를 펼쳐 쓴다 (루프·상수 배열 인덱싱이 GDScript에서 느리다).
## 4방향 BFS 거리에서 대각선 이웃은 최대 2 낮으므로, c-2 대각선을 찾으면 더 볼 필요가 없다.
func _directions(budget_cells: int) -> void:
	var c := _b_cost
	var blk := blocked
	var out_x := _b_dir_x
	var out_y := _b_dir_y
	var size := SIZE
	var rows := maxi(budget_cells / size, 1)
	var end_row := mini(_row + rows, size)
	for cy in range(_row, end_row):
		var row := cy * size
		var has_n := cy > 0
		var has_s := cy + 1 < size
		for cx in range(size):
			var idx := row + cx
			var cc := c[idx]
			if cc == UNREACHABLE or cc == 0:
				out_x[idx] = 0.0
				out_y[idx] = 0.0
				continue
			var has_w := cx > 0
			var has_e := cx + 1 < size
			# 직교 이웃: 열려 있는지도 대각선 판정에 쓴다
			var ce := c[idx + 1] if has_e else UNREACHABLE
			var cw := c[idx - 1] if has_w else UNREACHABLE
			var cs := c[idx + size] if has_s else UNREACHABLE
			var cn := c[idx - size] if has_n else UNREACHABLE
			var open_e := has_e and blk[idx + 1] == 0
			var open_w := has_w and blk[idx - 1] == 0
			var open_s := has_s and blk[idx + size] == 0
			var open_n := has_n and blk[idx - size] == 0
			var best := cc
			var bx := 0
			var by := 0
			# 원래 순서(동·서·남·북·남동·북동·남서·북서)와 같은 우선순위를 지킨다
			if ce < best:
				best = ce; bx = 1; by = 0
			if cw < best:
				best = cw; bx = -1; by = 0
			if cs < best:
				best = cs; bx = 0; by = 1
			if cn < best:
				best = cn; bx = 0; by = -1
			var target := cc - 2
			if best > target:
				if open_e and open_s:
					var d := c[idx + size + 1]
					if d < best:
						best = d; bx = 1; by = 1
				if best > target and open_e and open_n:
					var d := c[idx - size + 1]
					if d < best:
						best = d; bx = 1; by = -1
				if best > target and open_w and open_s:
					var d := c[idx + size - 1]
					if d < best:
						best = d; bx = -1; by = 1
				if best > target and open_w and open_n:
					var d := c[idx - size - 1]
					if d < best:
						best = d; bx = -1; by = -1
			if bx != 0 and by != 0:
				out_x[idx] = float(bx) * DIAG
				out_y[idx] = float(by) * DIAG
			else:
				out_x[idx] = float(bx)
				out_y[idx] = float(by)
	_b_dir_x = out_x
	_b_dir_y = out_y
	_row = end_row

func _swap() -> void:
	var tc := cost
	cost = _b_cost
	_b_cost = tc
	var tx := dir_x
	dir_x = _b_dir_x
	_b_dir_x = tx
	var ty := dir_y
	dir_y = _b_dir_y
	_b_dir_y = ty
	phase = Phase.IDLE
	recalc_count += 1

func cost_at(tx: int, ty: int) -> int:
	if not SimConfig.in_bounds(tx, ty):
		return UNREACHABLE
	return cost[ty * SIZE + tx]
