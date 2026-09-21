extends Node2D

## 이펙트 렌더러. 파티클은 MultiMesh 1개로 그리고, 폭발 링은 _draw로 몇 개만 그린다.
## 시뮬레이션 이벤트(사망·명중·폭발·건물 파괴)를 받아 규모에 비례해 생성하되 상한을 둔다.

const Iso := preload("res://render/iso.gd")
const SpriteFactory := preload("res://render/sprite_factory.gd")
const SimConfig := preload("res://sim/sim_config.gd")

const MAX_PARTICLES := 4096
const STRIDE := 12
const MAX_SPAWN_PER_TICK := 700
const MAX_RINGS := 48
const GRAVITY := 38.0   # 타일/초² (높이 z 기준)

var _mmi: MultiMeshInstance2D
var _buf: PackedFloat32Array

var _alive: PackedInt32Array
var _px: PackedFloat32Array
var _py: PackedFloat32Array
var _pz: PackedFloat32Array
var _vx: PackedFloat32Array
var _vy: PackedFloat32Array
var _vz: PackedFloat32Array
var _life: PackedFloat32Array
var _max_life: PackedFloat32Array
var _size: PackedFloat32Array
var _r: PackedFloat32Array
var _g: PackedFloat32Array
var _b: PackedFloat32Array
var _free: PackedInt32Array
var _high: int = 0
var _alive_count: int = 0
var _spawned_this_tick: int = 0

var _rings: Array = []   # [Vector2 world, radius_tiles, age, max_age, Color]
var _rng := RandomNumberGenerator.new()

func setup() -> void:
	_rng.seed = 12345
	var quad := SpriteFactory.make_quad_mesh(8.0, 8.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = MAX_PARTICLES
	mm.visible_instance_count = 0
	mm.custom_aabb = SpriteFactory.map_aabb(SimConfig.MAP_SIZE)
	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = mm
	_mmi.texture = SpriteFactory.make_dot_texture(8, true)
	add_child(_mmi)
	_buf = PackedFloat32Array()
	_buf.resize(MAX_PARTICLES * STRIDE)
	_alive = PackedInt32Array()
	_alive.resize(MAX_PARTICLES)
	_px = PackedFloat32Array()
	_px.resize(MAX_PARTICLES)
	_py = PackedFloat32Array()
	_py.resize(MAX_PARTICLES)
	_pz = PackedFloat32Array()
	_pz.resize(MAX_PARTICLES)
	_vx = PackedFloat32Array()
	_vx.resize(MAX_PARTICLES)
	_vy = PackedFloat32Array()
	_vy.resize(MAX_PARTICLES)
	_vz = PackedFloat32Array()
	_vz.resize(MAX_PARTICLES)
	_life = PackedFloat32Array()
	_life.resize(MAX_PARTICLES)
	_max_life = PackedFloat32Array()
	_max_life.resize(MAX_PARTICLES)
	_size = PackedFloat32Array()
	_size.resize(MAX_PARTICLES)
	_r = PackedFloat32Array()
	_r.resize(MAX_PARTICLES)
	_g = PackedFloat32Array()
	_g.resize(MAX_PARTICLES)
	_b = PackedFloat32Array()
	_b.resize(MAX_PARTICLES)
	_free = PackedInt32Array()

func clear_all() -> void:
	_alive.fill(0)
	_free = PackedInt32Array()
	_high = 0
	_alive_count = 0
	_rings.clear()

func begin_tick() -> void:
	_spawned_this_tick = 0

func _spawn(x: float, y: float, z: float, vx: float, vy: float, vz: float,
		life: float, size: float, color: Color) -> void:
	if _spawned_this_tick >= MAX_SPAWN_PER_TICK:
		return
	var idx := -1
	if _free.size() > 0:
		idx = _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
	else:
		if _high >= MAX_PARTICLES:
			return
		idx = _high
		_high += 1
	_alive[idx] = 1
	_alive_count += 1
	_spawned_this_tick += 1
	_px[idx] = x
	_py[idx] = y
	_pz[idx] = z
	_vx[idx] = vx
	_vy[idx] = vy
	_vz[idx] = vz
	_life[idx] = life
	_max_life[idx] = life
	_size[idx] = size
	_r[idx] = color.r
	_g[idx] = color.g
	_b[idx] = color.b

# ---------------------------------------------------------------------------
# 이벤트 → 파티클
# ---------------------------------------------------------------------------

## 사망 이벤트. 한 틱에 많이 죽을수록 개체당 파티클 수를 줄여 총량을 유지한다.
func on_deaths(count: int, xs: PackedFloat32Array, ys: PackedFloat32Array, types: PackedInt32Array,
		type_colors: Array) -> void:
	if count <= 0:
		return
	var per := 6
	if count > 200:
		per = 1
	elif count > 60:
		per = 2
	elif count > 20:
		per = 3
	var n := mini(count, xs.size())
	for i in range(n):
		var t := types[i]
		var c: Color = type_colors[t] if t < type_colors.size() else Color.RED
		for k in range(per):
			var a := _rng.randf() * TAU
			var sp := _rng.randf_range(1.5, 5.0)
			_spawn(xs[i], ys[i], 0.3, cos(a) * sp, sin(a) * sp, _rng.randf_range(3.0, 9.0),
				_rng.randf_range(0.35, 0.7), _rng.randf_range(0.7, 1.4), c.lightened(0.2))

func on_hits(count: int, xs: PackedFloat32Array, ys: PackedFloat32Array, kinds: PackedInt32Array) -> void:
	var n := mini(count, xs.size())
	n = mini(n, 48)
	for i in range(n):
		var c := Color(1.0, 0.9, 0.5)
		if kinds[i] == 3:
			c = Color(0.6, 0.9, 1.0)
		_spawn(xs[i], ys[i], 0.6, _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0),
			_rng.randf_range(1.0, 3.0), 0.18, 0.6, c)

func on_explosions(count: int, xs: PackedFloat32Array, ys: PackedFloat32Array,
		radii: PackedFloat32Array, kills: PackedInt32Array) -> void:
	var n := mini(count, xs.size())
	for i in range(n):
		var x := xs[i]
		var y := ys[i]
		var r := radii[i]
		var big := kills[i] >= 6
		var parts := 26 if big else 14
		for k in range(parts):
			var a := _rng.randf() * TAU
			var sp := _rng.randf_range(2.0, 7.0) * (r * 0.5)
			_spawn(x, y, 0.2, cos(a) * sp, sin(a) * sp, _rng.randf_range(4.0, 12.0),
				_rng.randf_range(0.3, 0.6), _rng.randf_range(1.0, 2.2),
				Color(1.0, _rng.randf_range(0.4, 0.75), 0.15))
		_add_ring(Vector2(x, y), r, 0.35 if big else 0.25, Color(1.0, 0.6, 0.2, 0.9))
		if big:
			_add_ring(Vector2(x, y), r * 1.6, 0.5, Color(1.0, 0.85, 0.5, 0.5))

func on_building_destroyed(x: float, y: float, size: float, color: Color) -> void:
	for k in range(30):
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(1.0, 4.0) * size
		_spawn(x, y, 0.5, cos(a) * sp, sin(a) * sp, _rng.randf_range(3.0, 10.0),
			_rng.randf_range(0.5, 1.0), _rng.randf_range(1.2, 2.4), color)
	_add_ring(Vector2(x, y), size * 1.5, 0.4, Color(1.0, 0.4, 0.2, 0.8))

func on_building_placed(x: float, y: float, color: Color) -> void:
	for k in range(10):
		var a := _rng.randf() * TAU
		_spawn(x, y, 0.1, cos(a) * 1.2, sin(a) * 1.2, _rng.randf_range(2.0, 4.0),
			0.4, 0.9, color.lightened(0.3))

func _add_ring(world: Vector2, radius: float, duration: float, color: Color) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.pop_front()
	_rings.append([world, radius, 0.0, duration, color])

# ---------------------------------------------------------------------------
# 프레임 갱신
# ---------------------------------------------------------------------------

func update_frame(delta: float) -> void:
	var half_w := Iso.HALF_W
	var half_h := Iso.HALF_H
	var n := 0
	for i in range(_high):
		if _alive[i] == 0:
			continue
		_life[i] -= delta
		if _life[i] <= 0.0:
			_alive[i] = 0
			_alive_count -= 1
			_free.append(i)
			continue
		_vz[i] -= GRAVITY * delta
		_px[i] += _vx[i] * delta
		_py[i] += _vy[i] * delta
		_pz[i] += _vz[i] * delta
		if _pz[i] < 0.0:
			_pz[i] = 0.0
			_vz[i] = -_vz[i] * 0.35
			_vx[i] *= 0.6
			_vy[i] *= 0.6
		var t := _life[i] / _max_life[i]
		var s := _size[i] * (0.4 + 0.6 * t)
		var o := n * STRIDE
		_buf[o] = s
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = (_px[i] - _py[i]) * half_w
		_buf[o + 4] = 0.0
		_buf[o + 5] = s
		_buf[o + 6] = 0.0
		_buf[o + 7] = (_px[i] + _py[i]) * half_h - _pz[i] * Iso.TILE_H
		_buf[o + 8] = _r[i]
		_buf[o + 9] = _g[i]
		_buf[o + 10] = _b[i]
		_buf[o + 11] = t
		n += 1
	var mm := _mmi.multimesh
	mm.buffer = _buf
	mm.visible_instance_count = n

	var changed := false
	var keep: Array = []
	for ring in _rings:
		ring[2] += delta
		if ring[2] < ring[3]:
			keep.append(ring)
		changed = true
	_rings = keep
	if changed or not _rings.is_empty():
		queue_redraw()

func _draw() -> void:
	for ring in _rings:
		var world: Vector2 = ring[0]
		var t: float = ring[2] / ring[3]
		var radius: float = ring[1] * (0.3 + 0.7 * t)
		var color: Color = ring[4]
		color.a *= 1.0 - t
		var center := Iso.to_screen_v(world)
		draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, radius * Iso.HALF_W * 1.4142, 0.0, TAU, 40, color, 3.0 * (1.0 - t) + 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func particle_count() -> int:
	return _alive_count
