extends Node3D

const MAP_SIZE := 64

var barricade_scene: PackedScene
var enemy_scene: PackedScene
var barricade_data: BuildingData

var building_grid: Dictionary = {}
var enemies_alive: int = 0

var _camera: Camera3D
var _hq: BaseBuilding

# UI nodes
var _top_bar_label: Label
var _hotbar_label: Label
var _game_over_panel: PanelContainer
var _result_label: Label

# Mouse state
var _mouse_grid_pos: Vector2i = Vector2i(-1, -1)
var _can_place: bool = false

# Ghost preview mesh
var _ghost_mesh: MeshInstance3D
var _ghost_mat: StandardMaterial3D

func _ready() -> void:
	barricade_scene = load("res://scenes/buildings/barricade.tscn")
	enemy_scene = load("res://scenes/enemies/enemy.tscn")

	barricade_data = BuildingData.new()
	barricade_data.building_name = "Barricade"
	barricade_data.cost = 15
	barricade_data.max_hp = 50.0
	barricade_data.size = Vector2i(1, 1)
	barricade_data.color = Color(0.55, 0.55, 0.58)

	_setup_camera()
	_setup_lighting()
	_setup_ground()
	_setup_hq()
	_setup_ghost()
	_setup_ui()

	GameManager.minerals_changed.connect(_on_minerals_changed)
	GameManager.game_over_triggered.connect(_on_game_over)
	_spawn_wave()

# ---------------------------------------------------------------------------
# Scene setup
# ---------------------------------------------------------------------------

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 35.0
	# Isometric angle: pull camera up and back from map center
	# Map center is (32, 0, 32). Position camera above-behind at ~35° elevation, 45° yaw.
	var dist := 50.0
	var elev_rad := deg_to_rad(35.0)
	var yaw_rad  := deg_to_rad(45.0)
	_camera.position = Vector3(
		32.0 + dist * cos(elev_rad) * sin(yaw_rad),
		dist * sin(elev_rad),
		32.0 + dist * cos(elev_rad) * cos(yaw_rad)
	)
	_camera.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	add_child(_camera)

func _setup_lighting() -> void:
	# Directional sun light
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.88)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	# World environment for ambient
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.42)
	env.ambient_light_energy = 0.6

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _setup_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_SIZE, MAP_SIZE)
	# Shader-based grid pattern
	var shader_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;

uniform vec3 ground_color : source_color = vec3(0.12, 0.18, 0.10);
uniform vec3 grid_color : source_color = vec3(0.18, 0.24, 0.16);
uniform vec3 chunk_color : source_color = vec3(0.22, 0.30, 0.20);
uniform float map_size = 64.0;

void fragment() {
	vec2 uv = UV * map_size;
	vec2 grid_uv = fract(uv);
	float line_w = 0.04;
	float is_line = 0.0;
	if (grid_uv.x < line_w || grid_uv.x > 1.0 - line_w ||
		grid_uv.y < line_w || grid_uv.y > 1.0 - line_w) {
		is_line = 0.55;
	}
	// Chunk lines every 4 tiles
	vec2 chunk_uv = fract(uv / 4.0);
	float chunk_w = 0.025;
	float is_chunk = 0.0;
	if (chunk_uv.x < chunk_w || chunk_uv.x > 1.0 - chunk_w ||
		chunk_uv.y < chunk_w || chunk_uv.y > 1.0 - chunk_w) {
		is_chunk = 0.7;
	}
	vec3 col = ground_color;
	col = mix(col, grid_color, is_line);
	col = mix(col, chunk_color, is_chunk);
	ALBEDO = col;
}
"""
	shader_mat.shader = shader
	ground.mesh = plane
	ground.material_override = shader_mat
	# PlaneMesh is centered at origin; shift so it covers 0..64 in X and Z
	ground.position = Vector3(MAP_SIZE / 2.0, 0.0, MAP_SIZE / 2.0)
	add_child(ground)

	# Map border frame (4 thin boxes)
	_add_border()

func _add_border() -> void:
	var border_color := Color(0.3, 0.55, 0.3, 1.0)
	var thickness := 0.15
	var height := 0.05
	var s := float(MAP_SIZE)
	# North, South, West, East
	var borders := [
		[Vector3(s / 2.0, height, 0.0),        Vector3(s, height, thickness)],
		[Vector3(s / 2.0, height, s),           Vector3(s, height, thickness)],
		[Vector3(0.0,     height, s / 2.0),     Vector3(thickness, height, s)],
		[Vector3(s,       height, s / 2.0),     Vector3(thickness, height, s)],
	]
	for b in borders:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = b[1]
		mi.mesh = bx
		mi.position = b[0]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = border_color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		add_child(mi)

func _setup_hq() -> void:
	var hq_scene := load("res://scenes/buildings/hq.tscn") as PackedScene
	_hq = hq_scene.instantiate() as BaseBuilding
	# HQ is 3x3, center at (32.5, 0, 32.5) — grid cells 31-33
	_hq.position = Vector3(32.5, 0.0, 32.5)
	_hq.destroyed.connect(_on_hq_destroyed)
	add_child(_hq)

	# Register HQ grid cells
	for dx in 3:
		for dz in 3:
			building_grid[Vector2i(31 + dx, 31 + dz)] = _hq

func _setup_ghost() -> void:
	_ghost_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.4, 1.0)
	_ghost_mesh.mesh = box
	_ghost_mesh.position = Vector3(0.5, 0.2, 0.5)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.4, 0.8, 0.4, 0.4)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mesh.material_override = _ghost_mat
	_ghost_mesh.visible = false
	add_child(_ghost_mesh)

# ---------------------------------------------------------------------------
# UI setup (Diablo-style dark)
# ---------------------------------------------------------------------------

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# --- Top bar ---
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.custom_minimum_size = Vector2(0, 44)
	var top_style := _create_panel_style(
		Color(0.05, 0.05, 0.08, 0.88),
		Color(0.6, 0.5, 0.2),
		2
	)
	top_panel.add_theme_stylebox_override("panel", top_style)
	canvas.add_child(top_panel)

	_top_bar_label = Label.new()
	_top_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_bar_label.add_theme_font_size_override("font_size", 18)
	_top_bar_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	top_panel.add_child(_top_bar_label)

	# --- Bottom hotbar ---
	var bottom_panel := PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.custom_minimum_size = Vector2(0, 80)
	bottom_panel.offset_top = -80.0
	var bot_style := _create_panel_style(
		Color(0.04, 0.04, 0.07, 0.90),
		Color(0.6, 0.5, 0.2),
		2
	)
	bottom_panel.add_theme_stylebox_override("panel", bot_style)
	canvas.add_child(bottom_panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	bottom_panel.add_child(hbox)

	# Building slot button
	var slot_btn := Button.new()
	slot_btn.custom_minimum_size = Vector2(180, 56)
	var btn_style := _create_panel_style(
		Color(0.08, 0.06, 0.04, 0.95),
		Color(0.6, 0.5, 0.2),
		2
	)
	var btn_hover := _create_panel_style(
		Color(0.14, 0.11, 0.06, 0.95),
		Color(0.85, 0.72, 0.3),
		2
	)
	slot_btn.add_theme_stylebox_override("normal", btn_style)
	slot_btn.add_theme_stylebox_override("hover", btn_hover)
	slot_btn.add_theme_stylebox_override("pressed", btn_style)
	slot_btn.add_theme_stylebox_override("focus", btn_style)
	slot_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	slot_btn.add_theme_font_size_override("font_size", 14)
	slot_btn.text = "[1] BARRICADE\nCost: 15"
	hbox.add_child(slot_btn)

	_hotbar_label = Label.new()
	_hotbar_label.add_theme_font_size_override("font_size", 13)
	_hotbar_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_hotbar_label.text = "Left-click to place"
	hbox.add_child(_hotbar_label)

	# --- Game Over panel ---
	_game_over_panel = PanelContainer.new()
	_game_over_panel.visible = false
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(420, 260)
	_game_over_panel.offset_left = -210.0
	_game_over_panel.offset_top = -130.0
	_game_over_panel.offset_right = 210.0
	_game_over_panel.offset_bottom = 130.0
	var go_style := _create_panel_style(
		Color(0.04, 0.03, 0.06, 0.96),
		Color(0.6, 0.5, 0.2),
		3
	)
	_game_over_panel.add_theme_stylebox_override("panel", go_style)
	canvas.add_child(_game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	_game_over_panel.add_child(vbox)

	var go_title := Label.new()
	go_title.text = "GAME OVER"
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_title.add_theme_font_size_override("font_size", 40)
	go_title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	vbox.add_child(go_title)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 17)
	_result_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	vbox.add_child(_result_label)

	var restart_btn := Button.new()
	restart_btn.text = "RESTART"
	restart_btn.custom_minimum_size = Vector2(150, 46)
	var rb_style := _create_panel_style(
		Color(0.08, 0.06, 0.04, 0.95),
		Color(0.7, 0.55, 0.2),
		2
	)
	restart_btn.add_theme_stylebox_override("normal", rb_style)
	restart_btn.add_theme_stylebox_override("hover", _create_panel_style(
		Color(0.16, 0.12, 0.05, 0.95), Color(0.9, 0.75, 0.3), 2))
	restart_btn.add_theme_stylebox_override("pressed", rb_style)
	restart_btn.add_theme_stylebox_override("focus", rb_style)
	restart_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	restart_btn.add_theme_font_size_override("font_size", 17)
	restart_btn.pressed.connect(_on_restart)
	var rb_center := CenterContainer.new()
	rb_center.add_child(restart_btn)
	vbox.add_child(rb_center)

	_update_hud()

func _create_panel_style(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	if border_color != Color.TRANSPARENT:
		style.border_color = border_color
		style.border_width_bottom = border_width
		style.border_width_top = border_width
		style.border_width_left = border_width
		style.border_width_right = border_width
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

# ---------------------------------------------------------------------------
# Wave spawning
# ---------------------------------------------------------------------------

func _spawn_wave() -> void:
	var enemy_data := EnemyData.new()
	enemy_data.enemy_name = "Rusher"
	enemy_data.max_hp = 20.0
	enemy_data.dps = 8.0
	enemy_data.speed = 3.5
	enemy_data.mineral_reward = 3
	enemy_data.color = Color(0.85, 0.2, 0.15)
	enemy_data.radius = 0.25

	var hq_pos := Vector3(32.5, 0.0, 32.5)
	for i in 45:
		var enemy: Node3D = enemy_scene.instantiate()
		enemy.set("data", enemy_data)
		enemy.set("target_position", hq_pos)
		var edge := _random_edge_position()
		enemy.position = Vector3(edge.x, 0.0, edge.y)
		enemy.connect("died", _on_enemy_died)
		add_child(enemy)
		enemies_alive += 1

func _random_edge_position() -> Vector2:
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(1.0, MAP_SIZE - 1.0), -1.0)
		1: return Vector2(float(MAP_SIZE) + 1.0, randf_range(1.0, MAP_SIZE - 1.0))
		2: return Vector2(randf_range(1.0, MAP_SIZE - 1.0), float(MAP_SIZE) + 1.0)
		3: return Vector2(-1.0, randf_range(1.0, MAP_SIZE - 1.0))
	return Vector2.ZERO

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_ghost(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_barricade(event.position)

func _update_ghost(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_ground(screen_pos)
	if world_pos.x < 0.0:
		_ghost_mesh.visible = false
		return
	var gx := int(floor(world_pos.x))
	var gz := int(floor(world_pos.z))
	_mouse_grid_pos = Vector2i(gx, gz)
	var in_bounds := gx >= 0 and gx < MAP_SIZE and gz >= 0 and gz < MAP_SIZE
	_can_place = in_bounds and not building_grid.has(_mouse_grid_pos)

	if in_bounds:
		_ghost_mesh.visible = true
		_ghost_mesh.position = Vector3(float(gx) + 0.5, 0.0, float(gz) + 0.5)
		if _can_place and GameManager.minerals >= barricade_data.cost:
			_ghost_mat.albedo_color = Color(0.4, 0.85, 0.4, 0.38)
		else:
			_ghost_mat.albedo_color = Color(0.9, 0.2, 0.2, 0.38)
	else:
		_ghost_mesh.visible = false

func _try_place_barricade(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_ground(screen_pos)
	if world_pos.x < 0.0:
		return
	var gx := int(floor(world_pos.x))
	var gz := int(floor(world_pos.z))
	var grid_pos := Vector2i(gx, gz)

	if gx < 0 or gx >= MAP_SIZE or gz < 0 or gz >= MAP_SIZE:
		return
	if building_grid.has(grid_pos):
		return
	if not GameManager.spend_minerals(barricade_data.cost):
		return

	var barricade: BaseBuilding = barricade_scene.instantiate()
	barricade.data = barricade_data
	barricade.grid_position = grid_pos
	barricade.position = Vector3(float(gx) + 0.5, 0.0, float(gz) + 0.5)
	barricade.destroyed.connect(_on_building_destroyed.bind(grid_pos))
	add_child(barricade)
	building_grid[grid_pos] = barricade

# ---------------------------------------------------------------------------
# Mouse-to-ground ray
# ---------------------------------------------------------------------------

func _screen_to_ground(screen_pos: Vector2) -> Vector3:
	var from := _camera.project_ray_origin(screen_pos)
	var dir  := _camera.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return Vector3(-1.0, 0.0, -1.0)
	var t := -from.y / dir.y
	return from + dir * t

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_building_destroyed(grid_pos: Vector2i) -> void:
	building_grid.erase(grid_pos)

func _on_hq_destroyed() -> void:
	pass  # game over is triggered inside hq.gd -> die()

func _on_enemy_died() -> void:
	enemies_alive -= 1
	_update_hud()

func _on_minerals_changed(_amount: int) -> void:
	_update_hud()

func _update_hud() -> void:
	if _top_bar_label:
		_top_bar_label.text = "MINERALS: %d  |  KILLS: %d  |  ENEMIES: %d" % [
			GameManager.minerals, GameManager.kill_count, enemies_alive
		]

func _on_game_over() -> void:
	_game_over_panel.visible = true
	_ghost_mesh.visible = false
	var secs := int(GameManager.game_time)
	_result_label.text = "Wave: %d  |  Kills: %d  |  Time: %d:%02d" % [
		GameManager.wave_number, GameManager.kill_count, secs / 60, secs % 60
	]

func _on_restart() -> void:
	GameManager.reset()
	get_tree().reload_current_scene()
