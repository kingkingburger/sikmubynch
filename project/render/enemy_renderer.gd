extends Node2D

## 적 렌더러. 타입별 MultiMeshInstance2D 1개, 프레임마다 buffer만 갱신한다.
## 시뮬레이션 배열을 읽기만 하며, 두 틱 사이를 보간한다.
## 피격 플래시는 시뮬레이션의 last_hit_tick으로 계산한다.

const Iso := preload("res://render/iso.gd")
const SpriteFactory := preload("res://render/sprite_factory.gd")
const SimConfig := preload("res://sim/sim_config.gd")

const STRIDE := 12   # 2D transform 8 + color 4
const FLASH_TICKS := 3.0
const PUNCH_SCALE := 0.3   # 피격 순간 확대 비율

var _mmis: Array = []          # MultiMeshInstance2D per type
var _buffers: Array = []       # PackedFloat32Array per type
var _counts: PackedInt32Array
var _type_color: Array = []
var _type_scale: PackedFloat32Array
var _type_px: PackedInt32Array
var max_per_type: int = SimConfig.MAX_ENEMIES

## enemy_datas: EnemyData 배열 (타입 순서)
func setup(enemy_datas: Array) -> void:
	for c in get_children():
		c.queue_free()
	_mmis.clear()
	_buffers.clear()
	_type_color.clear()
	_counts = PackedInt32Array()
	_counts.resize(enemy_datas.size())
	_type_scale = PackedFloat32Array()
	_type_px = PackedInt32Array()
	for t in range(enemy_datas.size()):
		var ed := enemy_datas[t] as EnemyData
		var px := 28
		var shape := SpriteFactory.Shape.DIAMOND
		match ed.enemy_type:
			EnemyData.EnemyType.RUSHER:
				px = 26
				shape = SpriteFactory.Shape.DIAMOND
			EnemyData.EnemyType.TANK:
				px = 44
				shape = SpriteFactory.Shape.HEX
			EnemyData.EnemyType.SPLITTER:
				px = 32
				shape = SpriteFactory.Shape.SEAM_DIAMOND
			EnemyData.EnemyType.MINI:
				px = 18
				shape = SpriteFactory.Shape.DIAMOND
		# 스프라이트 파일이 있으면 그것을, 없으면 코드 생성 폴백. 캔버스 크기는 파일이 정한다
		var tex: Texture2D = SpriteFactory.load_sprite("enemies", SpriteFactory.enemy_sprite_key(ed.enemy_type))
		var from_file := tex != null
		if from_file:
			px = tex.get_width()
		else:
			tex = SpriteFactory.make_enemy_texture(shape, px, ed.color)
		var quad := SpriteFactory.make_quad_mesh(float(px), float(px))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = max_per_type
		mm.visible_instance_count = 0
		mm.custom_aabb = SpriteFactory.map_aabb(SimConfig.MAP_SIZE)
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		mmi.texture = tex
		if from_file:
			mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(mmi)
		_mmis.append(mmi)
		var buf := PackedFloat32Array()
		buf.resize(max_per_type * STRIDE)
		_buffers.append(buf)
		_type_color.append(ed.color)
		_type_scale.append(1.0)
		_type_px.append(px)

## alpha: 마지막 두 틱 사이 보간 (0..1)
func update_from_sim(enemies, alpha: float, tick_index: int) -> void:
	var types := _mmis.size()
	if types == 0:
		return
	for t in range(types):
		_counts[t] = 0
	var alive: PackedInt32Array = enemies.alive
	var type_id: PackedInt32Array = enemies.type_id
	var px: PackedFloat32Array = enemies.pos_x
	var py: PackedFloat32Array = enemies.pos_y
	var ppx: PackedFloat32Array = enemies.prev_x
	var ppy: PackedFloat32Array = enemies.prev_y
	var hp: PackedFloat32Array = enemies.hp
	var max_hp: PackedFloat32Array = enemies.max_hp
	var last_hit: PackedInt32Array = enemies.last_hit_tick
	var high: int = enemies.high
	var half_w := Iso.HALF_W
	var half_h := Iso.HALF_H
	var ftick := float(tick_index)
	for i in range(high):
		if alive[i] == 0:
			continue
		var t := type_id[i]
		var n := _counts[t]
		if n >= max_per_type:
			continue
		_counts[t] = n + 1
		var x := ppx[i] + (px[i] - ppx[i]) * alpha
		var y := ppy[i] + (py[i] - ppy[i]) * alpha
		var sx := (x - y) * half_w
		# 스프라이트 바닥이 발 위치: 세로 중심을 위로 올린다
		var sy := (x + y) * half_h - float(_type_px[t]) * 0.36
		var buf: PackedFloat32Array = _buffers[t]
		var o := n * STRIDE
		# 피격 플래시(흰색) + 순간 확대(펀치). 저체력은 어둡게.
		var flash := 1.0 - (ftick - float(last_hit[i])) / FLASH_TICKS
		var punch := 1.0
		if flash > 0.0:
			punch = 1.0 + PUNCH_SCALE * flash
		buf[o] = punch
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = sx
		buf[o + 4] = 0.0
		buf[o + 5] = punch
		buf[o + 6] = 0.0
		buf[o + 7] = sy - float(_type_px[t]) * 0.36 * (punch - 1.0)
		var ratio := hp[i] / max_hp[i]
		var shade := 0.7 + 0.3 * ratio
		if flash > 0.0:
			var f := flash * 0.9
			buf[o + 8] = shade + (2.0 - shade) * f
			buf[o + 9] = shade + (2.0 - shade) * f
			buf[o + 10] = shade + (2.0 - shade) * f
		else:
			buf[o + 8] = shade
			buf[o + 9] = shade
			buf[o + 10] = shade
		buf[o + 11] = 1.0
	for t in range(types):
		var mmi: MultiMeshInstance2D = _mmis[t]
		var mm := mmi.multimesh
		mm.buffer = _buffers[t]
		mm.visible_instance_count = _counts[t]

func visible_total() -> int:
	var s := 0
	for c in _counts:
		s += c
	return s
