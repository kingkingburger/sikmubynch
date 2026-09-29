extends RefCounted

## 위협 레이더. 시뮬레이션 배열을 읽어 적·건물·HQ를 점으로 그린다.
## 맵을 마름모(쿼터뷰)로 보여주며, 적이 몰린 변을 붉게 표시한다.

const PIXELS := 120
const UPDATE_INTERVAL := 0.2
const MAX_ENEMY_DOTS := 600

var _texture_rect: TextureRect
var _timer: float = 0.0
var _img: Image
var _tex: ImageTexture

## parent를 가득 채우는 레이더 이미지를 만든다 (테두리·제목은 HUD가 그린다)
func _init(parent: Control) -> void:
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_texture_rect)
	_img = Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	_texture_rect.texture = _tex

## spawn_sides: 지금 압박이 두꺼운 변(붉게). 스트림은 항상 사방이라 나머지는 따로 표시하지 않는다
func tick(delta: float, sim, spawn_sides: int) -> void:
	if not _texture_rect:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	_render(sim, spawn_sides)

func _render(sim, spawn_sides: int) -> void:
	var map_size: int = sim.buildings.SIZE
	_img.fill(Color(0.02, 0.025, 0.035, 1.0))
	# 마름모 배경
	var c := PIXELS * 0.5
	for y in range(PIXELS):
		for x in range(PIXELS):
			if absf(x - c) + absf(y - c) * 2.0 <= c:
				_img.set_pixel(x, y, Color(0.06, 0.08, 0.1, 1.0))
	# 두꺼운 변 경고 (붉게)
	var warn := Color(0.95, 0.2, 0.15, 1.0)
	for side in range(4):
		if spawn_sides & (1 << side):
			_edge(side, warn, map_size)
	# 건물
	var b = sim.buildings
	for i in range(b.high):
		if b.alive[i] == 0:
			continue
		var col := Color(0.96, 0.72, 0.24)
		var r := 1
		if i == b.hq_index:
			col = Color(0.37, 0.89, 1.0)
			r = 2
		_dot(b.center_x(i), b.center_y(i), map_size, col, r)
	# 적
	var e = sim.enemies
	var drawn := 0
	var step := 1
	if e.alive_count > MAX_ENEMY_DOTS:
		step = int(ceil(float(e.alive_count) / float(MAX_ENEMY_DOTS)))
	var k := 0
	for i in range(e.high):
		if e.alive[i] == 0:
			continue
		k += 1
		if k % step != 0:
			continue
		var col := Color(1.0, 0.2, 0.12)
		if e.type_id[i] == EnemyData.EnemyType.TANK:
			col = Color(0.8, 0.4, 1.0)
		_dot(e.pos_x[i], e.pos_y[i], map_size, col, 0)
		drawn += 1
		if drawn >= MAX_ENEMY_DOTS:
			break
	_tex.update(_img)

func _to_px(x: float, y: float, map_size: int) -> Vector2i:
	var u := x / float(map_size)
	var v := y / float(map_size)
	var c := PIXELS * 0.5
	var px := c + (u - v) * c
	var py := c + (u + v - 1.0) * c * 0.5
	return Vector2i(clampi(int(px), 0, PIXELS - 1), clampi(int(py), 0, PIXELS - 1))

func _dot(x: float, y: float, map_size: int, color: Color, radius: int) -> void:
	var p := _to_px(x, y, map_size)
	if radius <= 0:
		_img.set_pixel(p.x, p.y, color)
		return
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var xx := p.x + dx
			var yy := p.y + dy
			if xx >= 0 and xx < PIXELS and yy >= 0 and yy < PIXELS:
				_img.set_pixel(xx, yy, color)

func _edge(side: int, color: Color, map_size: int) -> void:
	var m := float(map_size)
	for i in range(0, 40):
		var t := float(i) / 39.0 * m
		match side:
			0: _dot(t, 0.5, map_size, color, 0)
			1: _dot(m - 0.5, t, map_size, color, 0)
			2: _dot(t, m - 0.5, map_size, color, 0)
			_: _dot(0.5, t, map_size, color, 0)
