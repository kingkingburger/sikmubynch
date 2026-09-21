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

func _init(parent: Control, title: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(
		Color(0.04, 0.05, 0.03, 0.9), Color(0.3, 0.25, 0.15, 0.4), 1))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.65))
	vbox.add_child(label)

	_texture_rect = TextureRect.new()
	_texture_rect.custom_minimum_size = Vector2(124, 100)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	vbox.add_child(_texture_rect)
	_img = Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	_texture_rect.texture = _tex

## spawn_sides: 진행 중인 급증의 변(붉게). 스트림은 항상 사방이라 따로 표시하지 않는다
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
	_img.fill(Color(0.015, 0.02, 0.015, 1.0))
	# 마름모 배경
	var c := PIXELS * 0.5
	for y in range(PIXELS):
		for x in range(PIXELS):
			if absf(x - c) + absf(y - c) * 2.0 <= c:
				_img.set_pixel(x, y, Color(0.05, 0.07, 0.05, 1.0))
	# 급증 변 경고 (붉게)
	var warn := Color(0.95, 0.2, 0.15, 1.0)
	for side in range(4):
		if spawn_sides & (1 << side):
			_edge(side, warn, map_size)
	# 건물
	var b = sim.buildings
	for i in range(b.high):
		if b.alive[i] == 0:
			continue
		var col := Color(0.3, 0.7, 1.0)
		var r := 1
		if i == b.hq_index:
			col = Color(0.5, 1.0, 1.0)
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

func _panel_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
