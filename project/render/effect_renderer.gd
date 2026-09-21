extends Node2D

## 이펙트 렌더러. 파티클과 잔해(얼룩)는 MultiMesh로, 폭발 링·번개 볼트·저격 빔·총구 섬광은 _draw로 그린다.
## 시뮬레이션 이벤트(사망·명중·폭발·발사·건물 파괴)를 받아 규모에 비례해 생성하되 상한을 둔다.

const Iso := preload("res://render/iso.gd")
const SpriteFactory := preload("res://render/sprite_factory.gd")
const SimConfig := preload("res://sim/sim_config.gd")

const MAX_PARTICLES := 4096
const STRIDE := 12
const MAX_SPAWN_PER_TICK := 700
const MAX_RINGS := 48
const MAX_BOLTS := 96
const MAX_BEAMS := 32
const MAX_FLASHES := 96
const GRAVITY := 38.0   # 타일/초² (높이 z 기준)
# 잔해: 죽은 자리에 남는 얼룩. 링 버퍼로 오래된 것부터 덮어쓴다.
const MAX_DECALS := 2048
const DECAL_LIFE := 7.0
const MAX_DECALS_PER_TICK := 160
const BOLT_LIFE := 0.14
const BEAM_LIFE := 0.18
const FLASH_LIFE := 0.08

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

# 잔해
var _decal_mmi: MultiMeshInstance2D
var _decal_buf: PackedFloat32Array
var _decal_age: PackedFloat32Array
var _decal_head: int = 0
var _decal_count: int = 0
var _decals_this_tick: int = 0

var _rings: Array = []    # [Vector2 world, radius_tiles, age, max_age, Color]
var _bolts: Array = []    # [PackedVector2Array screen points, age]
var _beams: Array = []    # [Vector2 screen a, Vector2 screen b, age, big]
var _flashes: Array = []  # [Vector2 screen, age, Color, radius]
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
	_mmi.z_index = 2
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

	# 잔해 레이어 (지면, 개체 아래)
	var dq := SpriteFactory.make_quad_mesh(22.0, 11.0)
	var dmm := MultiMesh.new()
	dmm.transform_format = MultiMesh.TRANSFORM_2D
	dmm.use_colors = true
	dmm.mesh = dq
	dmm.instance_count = MAX_DECALS
	dmm.visible_instance_count = 0
	dmm.custom_aabb = SpriteFactory.map_aabb(SimConfig.MAP_SIZE)
	_decal_mmi = MultiMeshInstance2D.new()
	_decal_mmi.multimesh = dmm
	_decal_mmi.texture = SpriteFactory.make_dot_texture(16, true)
	_decal_mmi.z_index = -1
	add_child(_decal_mmi)
	_decal_buf = PackedFloat32Array()
	_decal_buf.resize(MAX_DECALS * STRIDE)
	_decal_age = PackedFloat32Array()
	_decal_age.resize(MAX_DECALS)
	_decal_age.fill(DECAL_LIFE + 1.0)

func clear_all() -> void:
	_alive.fill(0)
	_free = PackedInt32Array()
	_high = 0
	_alive_count = 0
	_rings.clear()
	_bolts.clear()
	_beams.clear()
	_flashes.clear()
	_decal_age.fill(DECAL_LIFE + 1.0)
	_decal_count = 0
	_decal_head = 0

func begin_tick() -> void:
	_spawned_this_tick = 0
	_decals_this_tick = 0

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

func _add_decal(x: float, y: float, scale: float, color: Color) -> void:
	if _decals_this_tick >= MAX_DECALS_PER_TICK:
		return
	_decals_this_tick += 1
	var i := _decal_head
	_decal_head = (_decal_head + 1) % MAX_DECALS
	if _decal_count < MAX_DECALS:
		_decal_count += 1
	_decal_age[i] = 0.0
	var s := Iso.to_screen(x, y)
	var o := i * STRIDE
	var rot := _rng.randf() * TAU
	var c := cos(rot)
	var sn := sin(rot)
	_decal_buf[o] = c * scale
	_decal_buf[o + 1] = -sn * scale * 0.5
	_decal_buf[o + 2] = 0.0
	_decal_buf[o + 3] = s.x
	_decal_buf[o + 4] = sn * scale
	_decal_buf[o + 5] = c * scale * 0.5
	_decal_buf[o + 6] = 0.0
	_decal_buf[o + 7] = s.y
	_decal_buf[o + 8] = color.r
	_decal_buf[o + 9] = color.g
	_decal_buf[o + 10] = color.b
	_decal_buf[o + 11] = 0.55

# ---------------------------------------------------------------------------
# 이벤트 → 파티클
# ---------------------------------------------------------------------------

## 사망 이벤트. 한 틱에 많이 죽을수록 개체당 파티클 수를 줄여 총량을 유지한다.
func on_deaths(count: int, xs: PackedFloat32Array, ys: PackedFloat32Array, types: PackedInt32Array,
		type_colors: Array) -> void:
	if count <= 0:
		return
	var per := 7
	if count > 200:
		per = 1
	elif count > 60:
		per = 2
	elif count > 20:
		per = 4
	var n := mini(count, xs.size())
	for i in range(n):
		var t := types[i]
		var c: Color = type_colors[t] if t < type_colors.size() else Color.RED
		for k in range(per):
			var a := _rng.randf() * TAU
			var sp := _rng.randf_range(1.5, 6.0)
			_spawn(xs[i], ys[i], 0.3, cos(a) * sp, sin(a) * sp, _rng.randf_range(3.0, 10.0),
				_rng.randf_range(0.35, 0.75), _rng.randf_range(0.8, 1.6), c.lightened(0.25))
		_add_decal(xs[i], ys[i], _rng.randf_range(0.8, 1.4), c.darkened(0.55))

func on_hits(count: int, xs: PackedFloat32Array, ys: PackedFloat32Array, kinds: PackedInt32Array) -> void:
	var n := mini(count, xs.size())
	n = mini(n, 64)
	for i in range(n):
		var c := Color(1.0, 0.9, 0.5)
		if kinds[i] == 3:
			c = Color(0.6, 0.9, 1.0)
		for k in range(2):
			_spawn(xs[i], ys[i], 0.6, _rng.randf_range(-2.0, 2.0), _rng.randf_range(-2.0, 2.0),
				_rng.randf_range(1.5, 4.0), 0.2, _rng.randf_range(0.5, 0.8), c)

func on_explosions(count: int, xs: PackedFloat32Array, ys: PackedFloat32Array,
		radii: PackedFloat32Array, kills: PackedInt32Array) -> void:
	var n := mini(count, xs.size())
	for i in range(n):
		var x := xs[i]
		var y := ys[i]
		var r := radii[i]
		var big := kills[i] >= 6
		var parts := 30 if big else 16
		for k in range(parts):
			var a := _rng.randf() * TAU
			var sp := _rng.randf_range(2.0, 7.0) * (r * 0.5)
			_spawn(x, y, 0.2, cos(a) * sp, sin(a) * sp, _rng.randf_range(4.0, 12.0),
				_rng.randf_range(0.3, 0.6), _rng.randf_range(1.0, 2.4),
				Color(1.0, _rng.randf_range(0.4, 0.75), 0.15))
		_add_ring(Vector2(x, y), r, 0.35 if big else 0.25, Color(1.0, 0.6, 0.2, 0.9))
		if big:
			_add_ring(Vector2(x, y), r * 1.6, 0.5, Color(1.0, 0.85, 0.5, 0.5))
		_add_decal(x, y, r * 1.1, Color(0.12, 0.08, 0.05))
		_add_flash(Iso.to_screen(x, y), Color(1.0, 0.8, 0.4, 0.9), 26.0 if big else 16.0)

## 연쇄 번개 선분. 지면 위로 조금 띄워 그린다.
func on_bolts(count: int, x0: PackedFloat32Array, y0: PackedFloat32Array,
		x1: PackedFloat32Array, y1: PackedFloat32Array) -> void:
	var n := mini(count, x0.size())
	for i in range(n):
		if _bolts.size() >= MAX_BOLTS:
			_bolts.pop_front()
		var a := Iso.to_screen(x0[i], y0[i]) - Vector2(0.0, 18.0)
		var b := Iso.to_screen(x1[i], y1[i]) - Vector2(0.0, 12.0)
		var pts := PackedVector2Array()
		var segs := 4
		pts.append(a)
		for k in range(1, segs):
			var t := float(k) / float(segs)
			var p := a.lerp(b, t)
			var perp := (b - a).orthogonal().normalized() * _rng.randf_range(-6.0, 6.0)
			pts.append(p + perp)
		pts.append(b)
		_bolts.append([pts, 0.0])
		_spawn(x1[i], y1[i], 0.5, _rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5),
			_rng.randf_range(2.0, 4.0), 0.2, 0.7, Color(0.8, 0.75, 1.0))

## 저격 빔. 시작점에 큰 섬광, 빔은 굵은 선 + 넓은 반투명 선.
func on_beams(count: int, x0: PackedFloat32Array, y0: PackedFloat32Array,
		x1: PackedFloat32Array, y1: PackedFloat32Array, kills: PackedInt32Array) -> void:
	var n := mini(count, x0.size())
	for i in range(n):
		if _beams.size() >= MAX_BEAMS:
			_beams.pop_front()
		var a := Iso.to_screen(x0[i], y0[i]) - Vector2(0.0, 34.0)
		var b := Iso.to_screen(x1[i], y1[i]) - Vector2(0.0, 12.0)
		_beams.append([a, b, 0.0, kills[i] >= 3])
		_add_flash(a, Color(0.7, 1.0, 0.8, 1.0), 14.0)

## 화염: 타워에서 목표 방향으로 불꽃 파티클을 뿜는다.
func on_flames(count: int, xs: PackedFloat32Array, ys: PackedFloat32Array,
		txs: PackedFloat32Array, tys: PackedFloat32Array, radii: PackedFloat32Array) -> void:
	var n := mini(count, xs.size())
	for i in range(n):
		var dx := txs[i] - xs[i]
		var dy := tys[i] - ys[i]
		var len := sqrt(dx * dx + dy * dy)
		if len < 0.01:
			dx = 1.0
			dy = 0.0
			len = 1.0
		var ux := dx / len
		var uy := dy / len
		for k in range(5):
			var spread := _rng.randf_range(-0.5, 0.5)
			var vx := (ux + uy * spread) * _rng.randf_range(4.0, 8.0)
			var vy := (uy - ux * spread) * _rng.randf_range(4.0, 8.0)
			_spawn(xs[i] + ux * 0.4, ys[i] + uy * 0.4, 0.8, vx, vy, _rng.randf_range(0.5, 2.5),
				_rng.randf_range(0.25, 0.45), _rng.randf_range(1.0, 1.8),
				Color(1.0, _rng.randf_range(0.3, 0.7), 0.1))

## 총구 섬광 (발사한 타워 위치, 화면 좌표)
func on_muzzle(screen_pos: Vector2, color: Color, radius: float) -> void:
	_add_flash(screen_pos, color, radius)

func on_building_destroyed(x: float, y: float, size: float, color: Color) -> void:
	for k in range(34):
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(1.0, 4.5) * size
		_spawn(x, y, 0.5, cos(a) * sp, sin(a) * sp, _rng.randf_range(3.0, 10.0),
			_rng.randf_range(0.5, 1.0), _rng.randf_range(1.2, 2.6), color)
	_add_ring(Vector2(x, y), size * 1.5, 0.4, Color(1.0, 0.4, 0.2, 0.8))
	_add_decal(x, y, size * 1.6, Color(0.1, 0.08, 0.07))

func on_building_placed(x: float, y: float, color: Color) -> void:
	for k in range(10):
		var a := _rng.randf() * TAU
		_spawn(x, y, 0.1, cos(a) * 1.2, sin(a) * 1.2, _rng.randf_range(2.0, 4.0),
			0.4, 0.9, color.lightened(0.3))

func _add_ring(world: Vector2, radius: float, duration: float, color: Color) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.pop_front()
	_rings.append([world, radius, 0.0, duration, color])

func _add_flash(screen: Vector2, color: Color, radius: float) -> void:
	if _flashes.size() >= MAX_FLASHES:
		_flashes.pop_front()
	_flashes.append([screen, 0.0, color, radius])

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

	# 잔해: 나이만 올리고 알파를 줄인다. 링 버퍼라 visible은 항상 채워진 수.
	if _decal_count > 0 and delta > 0.0:
		for i in range(_decal_count):
			var age := _decal_age[i] + delta
			_decal_age[i] = age
			var a := 0.0
			if age < DECAL_LIFE:
				a = 0.55 * (1.0 - age / DECAL_LIFE)
			_decal_buf[i * STRIDE + 11] = a
		var dmm := _decal_mmi.multimesh
		dmm.buffer = _decal_buf
		dmm.visible_instance_count = _decal_count

	var keep: Array = []
	for ring in _rings:
		ring[2] += delta
		if ring[2] < ring[3]:
			keep.append(ring)
	_rings = keep
	keep = []
	for bolt in _bolts:
		bolt[1] += delta
		if bolt[1] < BOLT_LIFE:
			keep.append(bolt)
	_bolts = keep
	keep = []
	for beam in _beams:
		beam[2] += delta
		if beam[2] < BEAM_LIFE:
			keep.append(beam)
	_beams = keep
	keep = []
	for fl in _flashes:
		fl[1] += delta
		if fl[1] < FLASH_LIFE:
			keep.append(fl)
	_flashes = keep
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
	for bolt in _bolts:
		var t: float = bolt[1] / BOLT_LIFE
		var pts: PackedVector2Array = bolt[0]
		draw_polyline(pts, Color(0.6, 0.5, 1.0, 0.5 * (1.0 - t)), 6.0, true)
		draw_polyline(pts, Color(0.95, 0.92, 1.0, 1.0 - t), 2.0, true)
	for beam in _beams:
		var t: float = beam[2] / BEAM_LIFE
		var a: Vector2 = beam[0]
		var b: Vector2 = beam[1]
		var big: bool = beam[3]
		draw_line(a, b, Color(0.4, 1.0, 0.6, 0.35 * (1.0 - t)), 9.0 if big else 6.0, true)
		draw_line(a, b, Color(0.9, 1.0, 0.95, 1.0 - t), 2.0, true)
	for fl in _flashes:
		var t: float = fl[1] / FLASH_LIFE
		var c: Color = fl[2]
		c.a *= 1.0 - t
		var r: float = fl[3] * (1.0 + 0.6 * t)
		draw_circle(fl[0], r, Color(c.r, c.g, c.b, c.a * 0.35))
		draw_circle(fl[0], r * 0.45, c)

func particle_count() -> int:
	return _alive_count
