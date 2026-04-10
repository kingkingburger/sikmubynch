extends Node

## 256x256 맵을 반해상도(128x128)로 BFS — 4배 빠름
## 외부 API는 월드 좌표 사용, 내부에서 자동 변환

const MAP_SIZE := 256
const FLOW_RES := 2        # 2x2 월드 셀 → 1 플로우 셀
const FLOW_GRID := 128     # MAP_SIZE / FLOW_RES

const DIRECTIONS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

var _field: Dictionary = {}
var _cost_field: Dictionary = {}
var _obstacles: Dictionary = {}

## 월드 좌표로 장애물 설정
func set_obstacle(world_pos: Vector2i, is_obstacle: bool) -> void:
	var fpos := Vector2i(world_pos.x / FLOW_RES, world_pos.y / FLOW_RES)
	if is_obstacle:
		_obstacles[fpos] = true
	else:
		_obstacles.erase(fpos)

## 월드 좌표에서 이동 방향 조회
func get_direction(world_x: float, world_z: float) -> Vector2:
	var fx := int(world_x) / FLOW_RES
	var fz := int(world_z) / FLOW_RES
	var cell := Vector2i(fx, fz)
	if _field.has(cell):
		return _field[cell]
	return Vector2.ZERO

## 월드 좌표 타겟으로 재계산
func recalculate(world_targets: Array) -> void:
	_cost_field.clear()
	_field.clear()

	# Convert targets to flow coords (deduplicate)
	var queue: Array = []
	var seen: Dictionary = {}
	for t in world_targets:
		var ft := Vector2i(t.x / FLOW_RES, t.y / FLOW_RES)
		if not seen.has(ft):
			seen[ft] = true
			_cost_field[ft] = 0
			queue.append(ft)

	# BFS on 128x128 grid
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_cost: int = _cost_field[current]

		for dir in DIRECTIONS:
			var neighbor: Vector2i = current + dir
			if neighbor.x < 0 or neighbor.x >= FLOW_GRID or neighbor.y < 0 or neighbor.y >= FLOW_GRID:
				continue
			if _obstacles.has(neighbor):
				continue
			var move_cost := 14 if (dir.x != 0 and dir.y != 0) else 10
			var new_cost := current_cost + move_cost
			if not _cost_field.has(neighbor) or new_cost < _cost_field[neighbor]:
				_cost_field[neighbor] = new_cost
				queue.append(neighbor)

	# Build direction field
	for cell in _cost_field:
		if _cost_field[cell] == 0:
			_field[cell] = Vector2.ZERO
			continue
		var best_dir := Vector2.ZERO
		var best_cost: int = _cost_field[cell]
		for dir in DIRECTIONS:
			var neighbor: Vector2i = cell + dir
			if _cost_field.has(neighbor) and _cost_field[neighbor] < best_cost:
				best_cost = _cost_field[neighbor]
				best_dir = Vector2(float(dir.x), float(dir.y)).normalized()
		_field[cell] = best_dir
