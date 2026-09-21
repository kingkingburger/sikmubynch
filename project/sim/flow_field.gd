extends RefCounted

## Flow Field — HQ까지의 비용을 BFS로 계산하고 셀별 이동 방향을 만든다.
## 전체 맵을 셀 배열로 다루며 Node를 참조하지 않는다.
##
## 비용은 4방향 BFS(순수 거리)로 계산하고, 방향은 8방향 이웃 중 최저 비용 셀로 잡는다.
## 대각선 방향은 양쪽 직교 셀이 모두 비어 있을 때만 허용해 벽 모서리 관통을 막는다.

const SimConfig := preload("res://sim/sim_config.gd")

const SIZE := SimConfig.MAP_SIZE
const CELLS := SimConfig.CELLS
const UNREACHABLE := 0x3FFFFFFF

const DX8 := [1, -1, 0, 0, 1, 1, -1, -1]
const DY8 := [0, 0, 1, -1, 1, -1, 1, -1]

var cost: PackedInt32Array
var dir_x: PackedFloat32Array
var dir_y: PackedFloat32Array
var blocked: PackedInt32Array      # 셀별 장애물 카운트 (0이면 통과 가능)
var dirty: bool = false
var recalc_count: int = 0

var _queue: PackedInt32Array
var _targets: PackedInt32Array

func _init() -> void:
	cost = PackedInt32Array()
	cost.resize(CELLS)
	dir_x = PackedFloat32Array()
	dir_x.resize(CELLS)
	dir_y = PackedFloat32Array()
	dir_y.resize(CELLS)
	blocked = PackedInt32Array()
	blocked.resize(CELLS)
	_queue = PackedInt32Array()
	_queue.resize(CELLS)
	_targets = PackedInt32Array()
	clear_all()

func clear_all() -> void:
	cost.fill(UNREACHABLE)
	dir_x.fill(0.0)
	dir_y.fill(0.0)
	blocked.fill(0)
	_targets = PackedInt32Array()
	dirty = false
	recalc_count = 0

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

## 타겟(HQ 셀)에서 역방향 BFS. 타겟 셀 자체는 장애물이어도 진입 가능하다.
func recalculate() -> void:
	dirty = false
	recalc_count += 1
	cost.fill(UNREACHABLE)
	var head := 0
	var tail := 0
	for t in _targets:
		if t < 0 or t >= CELLS:
			continue
		if cost[t] == 0:
			continue
		cost[t] = 0
		_queue[tail] = t
		tail += 1

	var size := SIZE
	var cells := CELLS
	while head < tail:
		var cur := _queue[head]
		head += 1
		var cx := cur % size
		var cy := cur / size
		var next_cost := cost[cur] + 1
		# 4방향
		if cx + 1 < size:
			var n := cur + 1
			if blocked[n] == 0 and cost[n] > next_cost:
				cost[n] = next_cost
				if tail < cells:
					_queue[tail] = n
					tail += 1
		if cx - 1 >= 0:
			var n := cur - 1
			if blocked[n] == 0 and cost[n] > next_cost:
				cost[n] = next_cost
				if tail < cells:
					_queue[tail] = n
					tail += 1
		if cy + 1 < size:
			var n := cur + size
			if blocked[n] == 0 and cost[n] > next_cost:
				cost[n] = next_cost
				if tail < cells:
					_queue[tail] = n
					tail += 1
		if cy - 1 >= 0:
			var n := cur - size
			if blocked[n] == 0 and cost[n] > next_cost:
				cost[n] = next_cost
				if tail < cells:
					_queue[tail] = n
					tail += 1

	_build_directions()

func _build_directions() -> void:
	var size := SIZE
	for cy in range(size):
		var row := cy * size
		for cx in range(size):
			var idx := row + cx
			var c := cost[idx]
			if c == UNREACHABLE or c == 0:
				dir_x[idx] = 0.0
				dir_y[idx] = 0.0
				continue
			var best_cost := c
			var best_dx := 0
			var best_dy := 0
			for d in range(8):
				var nx: int = cx + DX8[d]
				var ny: int = cy + DY8[d]
				if nx < 0 or nx >= size or ny < 0 or ny >= size:
					continue
				var n := ny * size + nx
				var nc := cost[n]
				if nc >= best_cost:
					continue
				if d >= 4:
					# 대각선: 양쪽 직교 셀이 열려 있어야 한다
					var ax := cy * size + nx
					var ay := ny * size + cx
					if blocked[ax] > 0 or blocked[ay] > 0:
						continue
				best_cost = nc
				best_dx = DX8[d]
				best_dy = DY8[d]
			if best_dx != 0 and best_dy != 0:
				dir_x[idx] = float(best_dx) * 0.70710678
				dir_y[idx] = float(best_dy) * 0.70710678
			else:
				dir_x[idx] = float(best_dx)
				dir_y[idx] = float(best_dy)

func cost_at(tx: int, ty: int) -> int:
	if not SimConfig.in_bounds(tx, ty):
		return UNREACHABLE
	return cost[ty * SIZE + tx]
