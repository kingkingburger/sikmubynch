extends Node

const MAP_SIZE := 256
const DIRECTIONS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

var _field: Dictionary = {}
var _cost_field: Dictionary = {}
var _obstacles: Dictionary = {}

func get_field() -> Dictionary:
	return _field

func set_obstacle(pos: Vector2i, is_obstacle: bool) -> void:
	if is_obstacle:
		_obstacles[pos] = true
	else:
		_obstacles.erase(pos)

func set_obstacles_bulk(positions: Array, is_obstacle: bool) -> void:
	for pos in positions:
		set_obstacle(pos, is_obstacle)

func recalculate(targets: Array) -> void:
	_cost_field.clear()
	_field.clear()

	# BFS from target cells outward
	var queue: Array = []
	for t in targets:
		var cell := t as Vector2i
		_cost_field[cell] = 0
		queue.append(cell)

	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_cost: int = _cost_field[current]

		for dir in DIRECTIONS:
			var neighbor: Vector2i = current + dir
			if neighbor.x < 0 or neighbor.x >= MAP_SIZE or neighbor.y < 0 or neighbor.y >= MAP_SIZE:
				continue
			if _obstacles.has(neighbor):
				continue
			# Diagonal cost = 14, cardinal cost = 10
			var move_cost := 14 if (dir.x != 0 and dir.y != 0) else 10
			var new_cost := current_cost + move_cost
			if not _cost_field.has(neighbor) or new_cost < _cost_field[neighbor]:
				_cost_field[neighbor] = new_cost
				queue.append(neighbor)

	# Build direction field from cost field
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
