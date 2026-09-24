extends Node2D

## 적 렌더러. 타입별 MultiMeshInstance2D 1개, 프레임마다 buffer만 갱신한다.
## 시뮬레이션 배열을 읽기만 하며, 두 틱 사이를 보간한다.
## 스프라이트가 가로 스트립(정사각 셀 N개)이면 프레임 애니메이션: 0 걷기A, 1 걷기B, 2 물기 준비, 3 물기.
## 프레임·밝기·플래시는 인스턴스 색에 담아 셰이더에 넘긴다 (R 밝기, G 프레임, B 흰색 플래시).
## GL Compatibility에서 MultiMesh 커스텀 셰이더는 fragment의 COLOR와 INSTANCE_CUSTOM이 깨지므로
## vertex에서 COLOR를 varying으로 넘겨 쓴다. 정지 이미지(셀 1개)도 같은 경로로 그린다.
## 공격 중인 적은 프레임과 별개로 건물 쪽으로 뒤로 뺐다가 확 달려드는 런지를 한다 (정지 이미지도 움직인다).
## 피격 플래시·펀치는 시뮬레이션의 last_hit_tick으로 계산한다.

const Iso := preload("res://render/iso.gd")
const SpriteFactory := preload("res://render/sprite_factory.gd")
const SimConfig := preload("res://sim/sim_config.gd")

const STRIDE := 12   # 2D transform 8 + color 4
const FRAME_CODE := 8.0   # 색 G 채널에 담는 프레임 코드 분모 (최대 8프레임)
const FLASH_TICKS := 3.0
const PUNCH_SCALE := 0.3      # 피격 순간 확대 비율
const LUNGE_BACK := 0.12      # 물기 전 뒤로 빼는 거리 (칸)
const LUNGE_FORWARD := 0.32   # 무는 순간 앞으로 뻗는 거리 (칸)
const WALK_TICKS_PER_FRAME := 4   # 걷기 프레임 전환 주기 (틱). 30Hz에서 7.5fps
const BOB_PX := 1.2           # 걷는 동안 위아래 흔들림 (px)
const START_CAPACITY := 512   # 타입별 버퍼 시작 크기. 넘치면 두 배로 늘린다 (매 프레임 올리는 양을 실제 물량에 맞춘다)

const FRAME_SHADER := """
shader_type canvas_item;
uniform float frames = 1.0;
varying vec4 v_col;
void vertex() {
	v_col = COLOR;
}
void fragment() {
	float frame = floor(v_col.g * 8.0);
	vec4 tex = texture(TEXTURE, vec2((UV.x + frame) / frames, UV.y));
	COLOR = vec4(mix(tex.rgb * v_col.r, vec3(1.0), v_col.b), tex.a * v_col.a);
}
"""

var _mmis: Array = []          # MultiMeshInstance2D per type
var _buffers: Array = []       # PackedFloat32Array per type
var _counts: PackedInt32Array
var _caps: PackedInt32Array    # 타입별 현재 버퍼 용량 (인스턴스 수)
var _type_px: PackedInt32Array
var _type_frames: PackedInt32Array
var max_per_type: int = SimConfig.MAX_ENEMIES
var _shader: Shader

## enemy_datas: EnemyData 배열 (타입 순서)
func setup(enemy_datas: Array) -> void:
	for c in get_children():
		c.queue_free()
	_mmis.clear()
	_buffers.clear()
	_counts = PackedInt32Array()
	_counts.resize(enemy_datas.size())
	_caps = PackedInt32Array()
	_type_px = PackedInt32Array()
	_type_frames = PackedInt32Array()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FRAME_SHADER
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
		# 스프라이트 파일이 있으면 그것을, 없으면 코드 생성 폴백. 셀 크기(=세로)와 프레임 수(가로/세로)는 파일이 정한다
		var tex: Texture2D = SpriteFactory.load_sprite("enemies", SpriteFactory.enemy_sprite_key(ed.enemy_type))
		var from_file := tex != null
		var frames := 1
		if from_file:
			px = tex.get_height()
			frames = maxi(1, int(round(float(tex.get_width()) / float(px))))
		else:
			tex = SpriteFactory.make_enemy_texture(shape, px, ed.color)
		var quad := SpriteFactory.make_quad_mesh(float(px), float(px))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = quad
		var cap := mini(START_CAPACITY, max_per_type)
		mm.instance_count = cap
		mm.visible_instance_count = 0
		mm.custom_aabb = SpriteFactory.map_aabb(SimConfig.MAP_SIZE)
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		mmi.texture = tex
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("frames", float(frames))
		mmi.material = mat
		if from_file:
			mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(mmi)
		_mmis.append(mmi)
		var buf := PackedFloat32Array()
		buf.resize(cap * STRIDE)
		_buffers.append(buf)
		_caps.append(cap)
		_type_px.append(px)
		_type_frames.append(frames)

## alpha: 마지막 두 틱 사이 보간 (0..1). buildings: 공격 런지 방향용 (null이면 런지 없음)
func update_from_sim(enemies, alpha: float, tick_index: int, buildings = null) -> void:
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
	var attack_target: PackedInt32Array = enemies.attack_target
	var attack_timer: PackedFloat32Array = enemies.attack_timer
	var high: int = enemies.high
	var half_w := Iso.HALF_W
	var half_h := Iso.HALF_H
	var ftick := float(tick_index)
	var dt: float = SimConfig.TICK_DT
	var walk_step := tick_index / WALK_TICKS_PER_FRAME
	var b_tx: PackedInt32Array
	var b_ty: PackedInt32Array
	var b_size: PackedInt32Array
	if buildings != null:
		b_tx = buildings.tile_x
		b_ty = buildings.tile_y
		b_size = buildings.size
	for i in range(high):
		if alive[i] == 0:
			continue
		var t := type_id[i]
		var n := _counts[t]
		if n >= _caps[t]:
			if n >= max_per_type:
				continue
			_grow(t, n + 1)
		_counts[t] = n + 1
		var x := ppx[i] + (px[i] - ppx[i]) * alpha
		var y := ppy[i] + (py[i] - ppy[i]) * alpha
		var frames := _type_frames[t]
		var frame := 0
		var scale_x := 1.0
		var scale_y := 1.0
		var bob := 0.0
		var target := attack_target[i]
		if target >= 0:
			# 공격 중: 마지막 물기 이후 경과 u (0..1). 0.6~0.9 뒤로 빼고, 0.9~1.0 확 달려들고, 0~0.15 되돌아온다
			var u := clampf(1.0 - attack_timer[i] + alpha * dt, 0.0, 1.0)
			var lunge := 0.0
			if u < 0.15:
				lunge = LUNGE_FORWARD * (1.0 - u / 0.15)
			elif u >= 0.9:
				lunge = -LUNGE_BACK + (LUNGE_BACK + LUNGE_FORWARD) * ((u - 0.9) / 0.1)
			elif u >= 0.6:
				lunge = -LUNGE_BACK * ((u - 0.6) / 0.3)
			if frames >= 4:
				frame = 3 if (u >= 0.95 or u < 0.15) else (2 if u >= 0.6 else 0)
			elif frames >= 2:
				frame = 1 if (u >= 0.95 or u < 0.15) else 0
			if lunge != 0.0 and buildings != null:
				# 건물 발자국에서 가장 가까운 점 방향으로
				var bs := float(b_size[target])
				var bx0 := float(b_tx[target])
				var by0 := float(b_ty[target])
				var dx := clampf(x, bx0, bx0 + bs) - x
				var dy := clampf(y, by0, by0 + bs) - y
				var l := sqrt(dx * dx + dy * dy)
				if l > 0.001:
					x += dx / l * lunge
					y += dy / l * lunge
				if lunge > 0.0:
					var f := lunge / LUNGE_FORWARD
					scale_x = 1.0 + 0.18 * f
					scale_y = 1.0 - 0.12 * f
		else:
			# 걷기: 프레임 교대 + 살짝 흔들림. i로 위상을 어긋나게 해 무리가 한 몸처럼 안 보이게
			var phase := walk_step + i
			if frames >= 2:
				frame = phase % 2
			bob = BOB_PX * absf(sin(float(phase) * 1.7 + alpha * 0.8))
		var sx := (x - y) * half_w
		# 스프라이트 바닥이 발 위치: 세로 중심을 위로 올린다
		var sy := (x + y) * half_h - float(_type_px[t]) * 0.36 - bob
		var buf: PackedFloat32Array = _buffers[t]
		var o := n * STRIDE
		# 피격 플래시(흰색) + 순간 확대(펀치). 저체력은 어둡게.
		var flash := 1.0 - (ftick - float(last_hit[i])) / FLASH_TICKS
		var punch := 1.0
		if flash > 0.0:
			punch = 1.0 + PUNCH_SCALE * flash
		buf[o] = punch * scale_x
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = sx
		buf[o + 4] = 0.0
		buf[o + 5] = punch * scale_y
		buf[o + 6] = 0.0
		buf[o + 7] = sy - float(_type_px[t]) * 0.36 * (punch * scale_y - 1.0)
		# 색 채널 = 셰이더 입력: R 밝기(저체력은 어둡게), G 프레임 코드, B 흰색 플래시 세기
		buf[o + 8] = 0.7 + 0.3 * hp[i] / max_hp[i]
		buf[o + 9] = (float(frame) + 0.5) / FRAME_CODE
		buf[o + 10] = flash * 0.85 if flash > 0.0 else 0.0
		buf[o + 11] = 1.0
	for t in range(types):
		var mmi: MultiMeshInstance2D = _mmis[t]
		var mm := mmi.multimesh
		if mm.instance_count != _caps[t]:
			mm.instance_count = _caps[t]
		mm.buffer = _buffers[t]
		mm.visible_instance_count = _counts[t]

## 타입 t의 버퍼를 need 이상으로 늘린다 (두 배씩, 상한 max_per_type). 기존 내용은 유지된다.
func _grow(t: int, need: int) -> void:
	var cap := _caps[t]
	while cap < need:
		cap *= 2
	cap = mini(cap, max_per_type)
	_caps[t] = cap
	var buf: PackedFloat32Array = _buffers[t]
	buf.resize(cap * STRIDE)
	_buffers[t] = buf

func capacity_for_type(t: int) -> int:
	if t < 0 or t >= _caps.size():
		return 0
	return _caps[t]

func visible_total() -> int:
	var s := 0
	for c in _counts:
		s += c
	return s

func frames_for_type(t: int) -> int:
	if t < 0 or t >= _type_frames.size():
		return 0
	return _type_frames[t]
