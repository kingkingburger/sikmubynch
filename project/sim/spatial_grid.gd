extends RefCounted

## Spatial Grid — 적 인덱스를 셀 단위 연결 리스트로 등록해 근접 탐색을 O(N·k)로 만든다.
## 매 틱 rebuild()로 전체를 다시 채운다. 할당 없이 PackedInt32Array만 쓴다.

const SimConfig := preload("res://sim/sim_config.gd")

const CELL_SIZE := 4.0
const GRID_W := SimConfig.MAP_SIZE / 4   # 32
const GRID_CELLS := GRID_W * GRID_W

var head: PackedInt32Array
var next: PackedInt32Array
var registered: int = 0

func _init() -> void:
	head = PackedInt32Array()
	head.resize(GRID_CELLS)
	head.fill(-1)
	next = PackedInt32Array()
	next.resize(SimConfig.MAX_ENEMIES)
	next.fill(-1)

func clear_all() -> void:
	head.fill(-1)
	registered = 0

## 살아 있는 적을 전부 다시 등록한다.
func rebuild(pos_x: PackedFloat32Array, pos_y: PackedFloat32Array, alive: PackedInt32Array, high: int) -> void:
	head.fill(-1)
	registered = 0
	var gw := GRID_W
	for i in range(high):
		if alive[i] == 0:
			continue
		var cx := int(pos_x[i] * 0.25)
		var cy := int(pos_y[i] * 0.25)
		if cx < 0:
			cx = 0
		elif cx >= gw:
			cx = gw - 1
		if cy < 0:
			cy = 0
		elif cy >= gw:
			cy = gw - 1
		var c := cy * gw + cx
		next[i] = head[c]
		head[c] = i
		registered += 1

## 반경 안에서 가장 가까운 살아 있는 적 인덱스. 없으면 -1.
func nearest(x: float, y: float, radius: float,
		pos_x: PackedFloat32Array, pos_y: PackedFloat32Array, alive: PackedInt32Array) -> int:
	var r := int(ceil(radius / CELL_SIZE))
	var cx := clampi(int(x / CELL_SIZE), 0, GRID_W - 1)
	var cy := clampi(int(y / CELL_SIZE), 0, GRID_W - 1)
	var best := -1
	var best_d := radius * radius
	var gw := GRID_W
	for gy in range(maxi(cy - r, 0), mini(cy + r, gw - 1) + 1):
		for gx in range(maxi(cx - r, 0), mini(cx + r, gw - 1) + 1):
			var i := head[gy * gw + gx]
			while i >= 0:
				if alive[i] != 0:
					var dx := pos_x[i] - x
					var dy := pos_y[i] - y
					var d := dx * dx + dy * dy
					if d < best_d:
						best_d = d
						best = i
				i = next[i]
	return best

## 반경 안의 살아 있는 적 인덱스를 out에 채우고 개수를 반환한다. out 크기를 넘으면 잘린다.
func query_circle(x: float, y: float, radius: float,
		pos_x: PackedFloat32Array, pos_y: PackedFloat32Array, alive: PackedInt32Array,
		out: PackedInt32Array) -> int:
	var r := int(ceil(radius / CELL_SIZE))
	var cx := clampi(int(x / CELL_SIZE), 0, GRID_W - 1)
	var cy := clampi(int(y / CELL_SIZE), 0, GRID_W - 1)
	var r2 := radius * radius
	var count := 0
	var cap := out.size()
	var gw := GRID_W
	for gy in range(maxi(cy - r, 0), mini(cy + r, gw - 1) + 1):
		for gx in range(maxi(cx - r, 0), mini(cx + r, gw - 1) + 1):
			var i := head[gy * gw + gx]
			while i >= 0:
				if alive[i] != 0:
					var dx := pos_x[i] - x
					var dy := pos_y[i] - y
					if dx * dx + dy * dy <= r2:
						if count < cap:
							out[count] = i
						count += 1
				i = next[i]
	return mini(count, cap)
