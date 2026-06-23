extends RefCounted

const PIXELS := 112
const UPDATE_INTERVAL := 0.25
const MAX_ENEMY_DOTS := 180

var _texture_rect: TextureRect
var _timer: float = 0.0

func _init(parent: Control) -> void:
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
	label.text = "THREAT RADAR"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.65))
	vbox.add_child(label)

	_texture_rect = TextureRect.new()
	_texture_rect.custom_minimum_size = Vector2(124, 96)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	vbox.add_child(_texture_rect)

func tick(delta: float, map_size: int, buildings: Array, enemies: Array, hq: Node3D) -> void:
	if not _texture_rect:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	_render(map_size, buildings, enemies, hq)

func _render(map_size: int, buildings: Array, enemies: Array, hq: Node3D) -> void:
	var img := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.015, 0.02, 0.015, 1.0))
	_draw_grid(img)

	for building in buildings:
		if is_instance_valid(building):
			_draw_dot(img, map_size, building.global_position, Color(0.25, 0.65, 1.0), 1)
	if is_instance_valid(hq):
		_draw_dot(img, map_size, hq.global_position, Color(0.45, 1.0, 1.0), 3)

	var drawn_enemies := 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		_draw_dot(img, map_size, enemy.global_position, Color(1.0, 0.18, 0.12), 1)
		drawn_enemies += 1
		if drawn_enemies >= MAX_ENEMY_DOTS:
			break
	_texture_rect.texture = ImageTexture.create_from_image(img)

func _draw_grid(img: Image) -> void:
	var grid_color := Color(0.08, 0.12, 0.08, 1.0)
	for x in range(0, PIXELS, 16):
		for y in range(PIXELS):
			img.set_pixel(x, y, grid_color)
	for y in range(0, PIXELS, 16):
		for x in range(PIXELS):
			img.set_pixel(x, y, grid_color)

func _draw_dot(img: Image, map_size: int, pos: Vector3, color: Color, radius: int) -> void:
	var px := clampi(int(pos.x / float(map_size) * float(PIXELS - 1)), 0, PIXELS - 1)
	var py := clampi(int(pos.z / float(map_size) * float(PIXELS - 1)), 0, PIXELS - 1)
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var x := px + dx
			var y := py + dy
			if x >= 0 and x < PIXELS and y >= 0 and y < PIXELS:
				img.set_pixel(x, y, color)

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
