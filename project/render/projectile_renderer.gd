extends Node2D

## 발사체 렌더러. MultiMesh 1개, 종류별 색·크기. 발사체는 지면 위로 약간 떠서 날아간다.

const Iso := preload("res://render/iso.gd")
const SpriteFactory := preload("res://render/sprite_factory.gd")
const SimConfig := preload("res://sim/sim_config.gd")

const STRIDE := 12
const LIFT_PX := 22.0

var _mmi: MultiMeshInstance2D
var _buf: PackedFloat32Array
var _count: int = 0

func setup() -> void:
	var quad := SpriteFactory.make_quad_mesh(12.0, 12.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = SimConfig.MAX_PROJECTILES
	mm.visible_instance_count = 0
	mm.custom_aabb = SpriteFactory.map_aabb(SimConfig.MAP_SIZE)
	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = mm
	_mmi.texture = SpriteFactory.make_dot_texture(12, true)
	add_child(_mmi)
	_buf = PackedFloat32Array()
	_buf.resize(SimConfig.MAX_PROJECTILES * STRIDE)

func update_from_sim(combat, alpha: float) -> void:
	var alive: PackedInt32Array = combat.p_alive
	var kind: PackedInt32Array = combat.p_kind
	var px: PackedFloat32Array = combat.p_x
	var py: PackedFloat32Array = combat.p_y
	var ppx: PackedFloat32Array = combat.p_prev_x
	var ppy: PackedFloat32Array = combat.p_prev_y
	var high: int = combat.p_high
	var n := 0
	var cap := SimConfig.MAX_PROJECTILES
	for i in range(high):
		if alive[i] == 0:
			continue
		if n >= cap:
			break
		var x := ppx[i] + (px[i] - ppx[i]) * alpha
		var y := ppy[i] + (py[i] - ppy[i]) * alpha
		var s := Iso.to_screen(x, y)
		var o := n * STRIDE
		var scale := 1.0
		var r := 1.0
		var g := 0.9
		var b := 0.4
		match kind[i]:
			2:  # 셸
				scale = 1.6
				r = 1.0
				g = 0.55
				b = 0.2
			3:  # 냉기
				scale = 1.2
				r = 0.5
				g = 0.85
				b = 1.0
		buf_write(o, scale, s.x, s.y - LIFT_PX, r, g, b)
		n += 1
	_count = n
	var mm := _mmi.multimesh
	mm.buffer = _buf
	mm.visible_instance_count = n

func buf_write(o: int, scale: float, x: float, y: float, r: float, g: float, b: float) -> void:
	_buf[o] = scale
	_buf[o + 1] = 0.0
	_buf[o + 2] = 0.0
	_buf[o + 3] = x
	_buf[o + 4] = 0.0
	_buf[o + 5] = scale
	_buf[o + 6] = 0.0
	_buf[o + 7] = y
	_buf[o + 8] = r
	_buf[o + 9] = g
	_buf[o + 10] = b
	_buf[o + 11] = 1.0
