extends Node

## 공간 분할 그리드 — O(N²) → O(N) 근접 탐색
## 64x64 맵을 CELL_SIZE 단위 셀로 분할. 엔티티는 자기 셀에 등록.
## 근접 탐색 시 인접 셀만 검색하여 O(N*k) (k = 셀 내 평균 엔티티 수)

const CELL_SIZE := 4.0  # 4x4 단위 셀 → 16x16 그리드
const GRID_W := 16      # 64 / 4

# 그룹별 그리드: { "enemies": { Vector2i: [node, ...] }, "units": { ... } }
var _grids: Dictionary = {}

func _ready() -> void:
	_grids["enemies"] = {}
	_grids["units"] = {}
	_grids["buildings"] = {}

func reset() -> void:
	for group_name in _grids:
		_grids[group_name].clear()

# -- 등록/해제 --

func register(node: Node3D, group_name: String) -> void:
	var cell := _pos_to_cell(node.global_position)
	var grid: Dictionary = _grids.get(group_name, {})
	if not grid.has(cell):
		grid[cell] = []
	grid[cell].append(node)

func unregister(node: Node3D, group_name: String) -> void:
	var cell := _pos_to_cell(node.global_position)
	var grid: Dictionary = _grids.get(group_name, {})
	if grid.has(cell):
		grid[cell].erase(node)
		if grid[cell].is_empty():
			grid.erase(cell)

func update_position(node: Node3D, old_pos: Vector3, group_name: String) -> void:
	var old_cell := _pos_to_cell(old_pos)
	var new_cell := _pos_to_cell(node.global_position)
	if old_cell == new_cell:
		return
	var grid: Dictionary = _grids.get(group_name, {})
	# Remove from old cell
	if grid.has(old_cell):
		grid[old_cell].erase(node)
		if grid[old_cell].is_empty():
			grid.erase(old_cell)
	# Add to new cell
	if not grid.has(new_cell):
		grid[new_cell] = []
	grid[new_cell].append(node)

# -- 탐색 --

## 지정 위치에서 range 내 가장 가까운 엔티티 반환
func find_nearest(pos: Vector3, group_name: String, range_val: float) -> Node3D:
	var grid: Dictionary = _grids.get(group_name, {})
	if grid.is_empty():
		return null
	var center_cell := _pos_to_cell(pos)
	var cell_range := int(ceil(range_val / CELL_SIZE))
	var best: Node3D = null
	var best_dist_sq := range_val * range_val

	for dx in range(-cell_range, cell_range + 1):
		for dz in range(-cell_range, cell_range + 1):
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dz)
			if not grid.has(cell):
				continue
			for node in grid[cell]:
				if not is_instance_valid(node):
					continue
				if node.get("_dead") or node.get("_destroyed"):
					continue
				var dist_sq := pos.distance_squared_to(node.global_position)
				if dist_sq < best_dist_sq:
					best = node
					best_dist_sq = dist_sq
	return best

## 지정 위치에서 range 내 모든 엔티티 반환
func find_in_range(pos: Vector3, group_name: String, range_val: float) -> Array:
	var grid: Dictionary = _grids.get(group_name, {})
	if grid.is_empty():
		return []
	var center_cell := _pos_to_cell(pos)
	var cell_range := int(ceil(range_val / CELL_SIZE))
	var range_sq := range_val * range_val
	var result: Array = []

	for dx in range(-cell_range, cell_range + 1):
		for dz in range(-cell_range, cell_range + 1):
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dz)
			if not grid.has(cell):
				continue
			for node in grid[cell]:
				if not is_instance_valid(node):
					continue
				if node.get("_dead") or node.get("_destroyed"):
					continue
				if pos.distance_squared_to(node.global_position) <= range_sq:
					result.append(node)
	return result

## 지정 위치에서 range 내 엔티티 존재 여부 (가장 빠름)
func has_any_in_range(pos: Vector3, group_name: String, range_val: float) -> bool:
	var grid: Dictionary = _grids.get(group_name, {})
	if grid.is_empty():
		return false
	var center_cell := _pos_to_cell(pos)
	var cell_range := int(ceil(range_val / CELL_SIZE))
	var range_sq := range_val * range_val

	for dx in range(-cell_range, cell_range + 1):
		for dz in range(-cell_range, cell_range + 1):
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dz)
			if not grid.has(cell):
				continue
			for node in grid[cell]:
				if not is_instance_valid(node):
					continue
				if node.get("_dead") or node.get("_destroyed"):
					continue
				if pos.distance_squared_to(node.global_position) <= range_sq:
					return true
	return false

# -- 내부 --

func _pos_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(
		clampi(int(pos.x / CELL_SIZE), 0, GRID_W - 1),
		clampi(int(pos.z / CELL_SIZE), 0, GRID_W - 1)
	)
