extends Node3D

const RewardCard := preload("res://scripts/data/reward_card.gd")
const TraitData := preload("res://scripts/data/trait_data.gd")

const MAP_SIZE := 256
const WAVE_INTERVAL := 10.0

# Scenes
var barricade_scene: PackedScene
var tower_scene: PackedScene
var barracks_scene: PackedScene
var miner_scene: PackedScene
var buff_tower_scene: PackedScene
var enemy_scene: PackedScene
var mineral_orb_scene: PackedScene

# Building data templates
var _building_datas: Array = []
var _selected_slot: int = 0

# State
var building_grid: Dictionary = {}
var enemies_alive: int = 0
var _units_alive: int = 0
var _buildings_count: int = 0
var _wave_active: bool = false
var _between_waves: bool = false
var _wave_countdown: float = 0.0

# Nodes
var _camera: Camera3D
var _hq: BaseBuilding

# UI
var _canvas: CanvasLayer
var _mineral_label: Label
var _wave_info_label: Label
var _hp_label: Label
var _game_over_panel: PanelContainer
var _result_label: Label
var _slot_buttons: Array = []

# Reward card UI
var _card_panel: PanelContainer
var _card_buttons: Array = []
var _card_skip_btn: Button
var _pending_cards: Array = []

# Synergy bar UI
var _synergy_label: Label

# Event UI
var _event_label: Label
var _event_timer: float = 0.0
var _choice_panel: PanelContainer
var _choice_buttons: Array = []
var _choice_label: Label

# Pause during card/choice selection
var _awaiting_card: bool = false
var _awaiting_choice: bool = false

# Camera control
var _cam_center := Vector2(128.0, 128.0)
var _cam_zoom: float = 22.0
const CAM_SPEED := 35.0
var _right_dragging: bool = false
var _flow_dirty: bool = false
var _flow_timer: float = 0.0
const CAM_ZOOM_MIN := 18.0
const CAM_ZOOM_MAX := 120.0
const CAM_DIST := 50.0

# Drag build
var _dragging: bool = false
var _drag_last_grid: Vector2i = Vector2i(-999, -999)

# Speed label
var _speed_label: Label

# ESC menu
var _esc_panel: PanelContainer
var _esc_visible: bool = false

# Debug overlay
var _debug_label: Label
var _debug_visible: bool = false

# Ghost
var _mouse_grid_pos: Vector2i = Vector2i(-1, -1)
var _ghost_mesh: MeshInstance3D
var _ghost_mat: StandardMaterial3D

func _ready() -> void:
	barricade_scene = load("res://scenes/buildings/barricade.tscn")
	tower_scene = load("res://scenes/buildings/tower.tscn")
	barracks_scene = load("res://scenes/buildings/barracks.tscn")
	miner_scene = load("res://scenes/buildings/miner.tscn")
	buff_tower_scene = load("res://scenes/buildings/buff_tower.tscn")
	enemy_scene = load("res://scenes/enemies/enemy.tscn")
	mineral_orb_scene = load("res://scenes/effects/mineral_orb.tscn")

	_init_building_data()
	_setup_camera()
	_setup_lighting()
	_setup_ground()
	_setup_hq()
	_setup_ghost()
	_setup_ui()
	_buildings_count = 1  # HQ

	GameManager.minerals_changed.connect(_on_minerals_changed)
	GameManager.game_over_triggered.connect(_on_game_over)
	EventManager.combat_event_triggered.connect(_on_combat_event)
	EventManager.choice_event_triggered.connect(_on_choice_event)
	SynergyManager.synergy_changed.connect(_update_synergy_bar)
	GameFeel.setup(_camera, _canvas)
	_recalculate_flow_field()
	# Battle BGM
	AudioManager.play_bgm_by_name("battle")
	_spawn_wave()

func _init_building_data() -> void:
	var barr := BuildingData.new()
	barr.building_name = "Barricade"
	barr.cost = 10
	barr.max_hp = 80.0
	barr.size = Vector2i(1, 1)
	barr.color = Color(0.55, 0.55, 0.58)
	_building_datas.append(barr)

	var twr := BuildingData.new()
	twr.building_name = "Tower"
	twr.cost = 50
	twr.max_hp = 100.0
	twr.size = Vector2i(1, 1)
	twr.color = Color(0.35, 0.55, 0.75)
	twr.dps = 15.0
	twr.attack_range = 7.0
	twr.attack_speed = 1.0
	_building_datas.append(twr)

	var brk := BuildingData.new()
	brk.building_name = "Barracks"
	brk.cost = 100
	brk.max_hp = 200.0
	brk.size = Vector2i(1, 1)
	brk.color = Color(0.25, 0.4, 0.7)
	_building_datas.append(brk)

	var mnr := BuildingData.new()
	mnr.building_name = "Miner"
	mnr.cost = 80
	mnr.max_hp = 60.0
	mnr.size = Vector2i(1, 1)
	mnr.color = Color(0.2, 0.7, 0.8)
	mnr.mineral_per_sec = 2.0
	_building_datas.append(mnr)

	var buf := BuildingData.new()
	buf.building_name = "Buff Tower"
	buf.cost = 120
	buf.max_hp = 100.0
	buf.size = Vector2i(1, 1)
	buf.color = Color(0.9, 0.8, 0.2)
	buf.buff_range = 3.5
	buf.buff_dps_mult = 0.2
	_building_datas.append(buf)

func _process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	# Camera WASD
	var cam_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): cam_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): cam_dir.y += 1.0
	if Input.is_key_pressed(KEY_A): cam_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): cam_dir.x += 1.0
	if cam_dir != Vector2.ZERO:
		var rotated := cam_dir.rotated(deg_to_rad(-45.0))
		_cam_center += rotated.normalized() * CAM_SPEED * delta
		var pad := _cam_zoom * 0.3
		_cam_center.x = clampf(_cam_center.x, pad, float(MAP_SIZE) - pad)
		_cam_center.y = clampf(_cam_center.y, pad, float(MAP_SIZE) - pad)
		_update_camera_position()
	# Debug overlay — uses cached counters, no tree scan
	if _debug_visible and _debug_label:
		_debug_label.text = "FPS: %d\nEnemies: %d\nUnits: %d\nBuildings: %d\nSpeed: %.1fx" % [
			Engine.get_frames_per_second(), enemies_alive, _units_alive, _buildings_count, GameFeel.game_speed
		]
	# Fade event notification
	if _event_timer > 0.0:
		_event_timer -= delta
		if _event_timer <= 0.0 and _event_label:
			_event_label.visible = false
	# Deferred FlowField recalculation (avoid lag on build)
	if _flow_dirty:
		_flow_timer += delta
		if _flow_timer >= 0.3:
			_flow_dirty = false
			_flow_timer = 0.0
			_recalculate_flow_field()
	# Gradual enemy spawning
	_process_spawn_queue()
	# Pause wave countdown during card/choice selection
	if _between_waves and not _awaiting_choice:
		_wave_countdown -= delta
		_update_hud()
		if _wave_countdown <= 0.0:
			_between_waves = false
			_spawn_wave()
	elif _wave_active:
		# Check wave completion using cached counter (no tree scan)
		if enemies_alive <= 0 and _spawn_queue.is_empty():
			_wave_active = false
			enemies_alive = 0
			_on_wave_cleared()
		_update_hud()

# ---------------------------------------------------------------------------
# Scene setup
# ---------------------------------------------------------------------------

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _cam_zoom
	_camera.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	add_child(_camera)
	_update_camera_position()

func _update_camera_position() -> void:
	if not _camera:
		return
	var elev_rad := deg_to_rad(35.0)
	var yaw_rad := deg_to_rad(45.0)
	var pos := Vector3(
		_cam_center.x + CAM_DIST * cos(elev_rad) * sin(yaw_rad),
		CAM_DIST * sin(elev_rad),
		_cam_center.y + CAM_DIST * cos(elev_rad) * cos(yaw_rad)
	)
	_camera.position = pos
	_camera.size = _cam_zoom
	GameFeel.update_camera_base(pos)

func _setup_lighting() -> void:
	# Dim directional — barely visible, just for shadows
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.light_color = Color(0.95, 0.9, 0.8)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	# Dark environment —発光体 only
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.24, 0.3)
	env.ambient_light_energy = 0.5
	# Glow/Bloom — makes emission pop
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.8

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _setup_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_SIZE + 128, MAP_SIZE + 128)
	var shader_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

uniform vec3 ground_dark : source_color = vec3(0.04, 0.045, 0.03);
uniform vec3 ground_mid : source_color = vec3(0.08, 0.09, 0.06);
uniform vec3 ground_light : source_color = vec3(0.12, 0.11, 0.07);
uniform vec3 grid_color : source_color = vec3(0.10, 0.12, 0.07);
uniform vec3 chunk_color : source_color = vec3(0.14, 0.11, 0.06);
uniform vec3 crack_color : source_color = vec3(0.02, 0.02, 0.015);
uniform vec3 moss_color : source_color = vec3(0.04, 0.08, 0.03);
uniform vec3 hq_glow_color : source_color = vec3(0.15, 0.25, 0.5);
uniform float map_size = 256.0;
uniform float time_scale = 1.0;
uniform vec2 hq_pos = vec2(128.5, 128.5);

// Procedural noise functions
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < octaves; i++) {
		val += amp * value_noise(p * freq);
		amp *= 0.5;
		freq *= 2.0;
	}
	return val;
}

// Voronoi for cracks/stone pattern
float voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_dist = 1.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = vec2(hash(i + neighbor), hash2(i + neighbor));
			float d = length(neighbor + point - f);
			min_dist = min(min_dist, d);
		}
	}
	return min_dist;
}

void fragment() {
	vec2 uv = UV * map_size;
	vec2 world_uv = uv;
	vec2 cell = floor(uv);

	// Multi-layer noise for organic terrain
	float n1 = fbm(uv * 0.15, 4);
	float n2 = fbm(uv * 0.4 + 50.0, 3);
	float n3 = value_noise(uv * 0.08);

	// Base color: blend between dark/mid/light using noise
	vec3 base = mix(ground_dark, ground_mid, n1 * 0.8 + 0.1);
	base = mix(base, ground_light, smoothstep(0.55, 0.7, n2) * 0.4);

	// Stone patches (voronoi-based)
	float stone = voronoi(uv * 0.3);
	float stone_edge = smoothstep(0.02, 0.06, stone);
	base = mix(crack_color, base, stone_edge);

	// Cracks (thin dark lines from voronoi)
	float cracks = voronoi(uv * 0.12 + 100.0);
	float crack_line = 1.0 - smoothstep(0.0, 0.03, cracks);
	base = mix(base, crack_color, crack_line * 0.7);

	// Moss patches (in low areas)
	float moss = smoothstep(0.3, 0.5, n3) * smoothstep(0.4, 0.6, n1);
	base = mix(base, moss_color, moss * 0.5);

	// Per-tile hash variation (subtle)
	float h = hash(cell);
	base *= 0.9 + h * 0.2;

	// Grid lines (subtle)
	vec2 grid_uv = fract(uv);
	float line_w = 0.025;
	float is_line = 0.0;
	if (grid_uv.x < line_w || grid_uv.x > 1.0 - line_w ||
		grid_uv.y < line_w || grid_uv.y > 1.0 - line_w) {
		is_line = 0.3;
	}

	// 4x4 chunk borders
	vec2 chunk_uv = fract(uv / 4.0);
	float chunk_w = 0.015;
	float is_chunk = 0.0;
	if (chunk_uv.x < chunk_w || chunk_uv.x > 1.0 - chunk_w ||
		chunk_uv.y < chunk_w || chunk_uv.y > 1.0 - chunk_w) {
		is_chunk = 0.5;
	}

	// HQ proximity glow
	float hq_dist = length(world_uv - hq_pos);
	float hq_glow = exp(-hq_dist * 0.08) * 0.3;
	float hq_pulse = 1.0 + sin(TIME * time_scale * 1.5) * 0.15;

	// Vignette — stronger edge darkening
	vec2 center_uv = UV - 0.5;
	float vignette = 1.0 - dot(center_uv, center_uv) * 1.2;
	vignette = clamp(vignette, 0.2, 1.0);

	// Compose
	vec3 col = base;
	col = mix(col, grid_color, is_line);
	col = mix(col, chunk_color, is_chunk);
	col += hq_glow_color * hq_glow * hq_pulse;
	col *= vignette;

	ALBEDO = col;
	ROUGHNESS = 0.92 - stone_edge * 0.15;
	SPECULAR = 0.1 + stone_edge * 0.1;
}
"""
	shader_mat.shader = shader
	ground.mesh = plane
	ground.material_override = shader_mat
	ground.position = Vector3(MAP_SIZE / 2.0, 0.0, MAP_SIZE / 2.0)
	add_child(ground)
	_add_border()

func _add_border() -> void:
	var border_color := Color(0.15, 0.12, 0.08, 1.0)
	var thickness := 0.15
	var height := 0.05
	var s := float(MAP_SIZE)
	var borders := [
		[Vector3(s / 2.0, height, 0.0), Vector3(s, height, thickness)],
		[Vector3(s / 2.0, height, s), Vector3(s, height, thickness)],
		[Vector3(0.0, height, s / 2.0), Vector3(thickness, height, s)],
		[Vector3(s, height, s / 2.0), Vector3(thickness, height, s)],
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
	_hq.position = Vector3(128.5, 0.0, 128.5)
	_hq.add_to_group("buildings")
	add_child(_hq)

	for dx in 3:
		for dz in 3:
			var cell := Vector2i(127 + dx, 127 + dz)
			building_grid[cell] = _hq

var _range_ring: MeshInstance3D
var _range_shader_mat: ShaderMaterial

func _setup_ghost() -> void:
	_ghost_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.4, 1.0)
	_ghost_mesh.mesh = box
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.4, 0.8, 0.4, 0.4)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mesh.material_override = _ghost_mat
	_ghost_mesh.visible = false
	add_child(_ghost_mesh)
	# Range indicator ring
	_range_ring = MeshInstance3D.new()
	var ring_plane := PlaneMesh.new()
	ring_plane.size = Vector2(2.0, 2.0)
	_range_ring.mesh = ring_plane
	_range_shader_mat = ShaderMaterial.new()
	var ring_shader := Shader.new()
	ring_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 ring_color : source_color = vec4(0.3, 0.7, 1.0, 0.5);
uniform float ring_width = 0.04;
uniform float pulse_speed = 2.5;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	// Outer edge ring
	float ring = smoothstep(1.0, 1.0 - ring_width, dist)
			   - smoothstep(1.0 - ring_width, 1.0 - ring_width * 2.5, dist);
	// Inner fill (very faint)
	float fill = smoothstep(1.0, 0.0, dist) * 0.08;
	// Pulse animation
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	// Radial scan line
	float angle = atan(uv.y, uv.x);
	float scan = smoothstep(0.0, 0.15, fract(angle / 6.283 + TIME * 0.3)) * 0.3;
	float a = (ring * pulse + fill + scan * smoothstep(1.0, 0.3, dist)) * ring_color.a;
	ALBEDO = ring_color.rgb;
	ALPHA = a * step(dist, 1.0);
}
"""
	_range_shader_mat.shader = ring_shader
	_range_ring.material_override = _range_shader_mat
	_range_ring.visible = false
	add_child(_range_ring)

# ---------------------------------------------------------------------------
# UI (Diablo-style dark)
# ---------------------------------------------------------------------------

func _setup_ui() -> void:
	_canvas = CanvasLayer.new()
	add_child(_canvas)

	# --- Top center: Mineral (big, prominent) ---
	_mineral_label = Label.new()
	_mineral_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_mineral_label.offset_top = 6.0
	_mineral_label.offset_left = -80.0
	_mineral_label.offset_right = 80.0
	_mineral_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mineral_label.add_theme_font_size_override("font_size", 26)
	_mineral_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.95))
	_canvas.add_child(_mineral_label)

	# --- Top right: Wave / Kills / Time ---
	var tr_panel := PanelContainer.new()
	tr_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_panel.offset_left = -220.0
	tr_panel.offset_top = 6.0
	tr_panel.offset_right = -8.0
	tr_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.06, 0.06, 0.08, 0.85), Color(0.3, 0.25, 0.15, 0.4), 1))
	_canvas.add_child(tr_panel)
	_wave_info_label = Label.new()
	_wave_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_info_label.add_theme_font_size_override("font_size", 13)
	_wave_info_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	tr_panel.add_child(_wave_info_label)

	# --- Bottom panel (StarCraft style: portrait | build | minimap) ---
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.custom_minimum_size = Vector2(0, 150)
	bottom.offset_top = -150.0
	bottom.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.08, 0.07, 0.06, 0.97), Color(0.35, 0.28, 0.15, 0.6), 2))
	_canvas.add_child(bottom)

	var grid := HBoxContainer.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("separation", 0)
	bottom.add_child(grid)

	# --- Left: Portrait area ---
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(160, 0)
	portrait.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.05, 0.04, 0.03, 0.9), Color(0.3, 0.25, 0.15, 0.4), 1))
	grid.add_child(portrait)
	var port_vbox := VBoxContainer.new()
	port_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait.add_child(port_vbox)
	var port_title := Label.new()
	port_title.text = "SELECTED"
	port_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_title.add_theme_font_size_override("font_size", 9)
	port_title.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
	port_vbox.add_child(port_title)
	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	port_vbox.add_child(_hp_label)
	var hp_sub := Label.new()
	hp_sub.text = "HQ HP"
	hp_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_sub.add_theme_font_size_override("font_size", 10)
	hp_sub.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
	port_vbox.add_child(hp_sub)

	# --- Center: Build slots ---
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 4)
	grid.add_child(center)

	# Wave info bar
	var wave_bar := HBoxContainer.new()
	wave_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(wave_bar)

	# Build buttons
	var build_hbox := HBoxContainer.new()
	build_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	build_hbox.add_theme_constant_override("separation", 3)
	center.add_child(build_hbox)

	for i in _building_datas.size():
		var bd := _building_datas[i] as BuildingData
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(60, 68)
		var localized_name := Locale.t(bd.building_name)
		btn.text = "%d\n%s\n$%d" % [i + 1, localized_name.substr(0, 4).to_upper(), bd.cost]
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color", Color(0.88, 0.78, 0.4))
		var ns := _create_panel_style(
			Color(0.1, 0.09, 0.07, 0.85), Color(0.3, 0.25, 0.15, 0.5), 2)
		ns.corner_radius_top_left = 4
		ns.corner_radius_top_right = 4
		ns.corner_radius_bottom_left = 4
		ns.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", ns)
		var hs := _create_panel_style(
			Color(0.18, 0.15, 0.08, 0.9), Color(0.9, 0.75, 0.25), 2)
		hs.corner_radius_top_left = 4
		hs.corner_radius_top_right = 4
		hs.corner_radius_bottom_left = 4
		hs.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("hover", hs)
		btn.add_theme_stylebox_override("pressed", hs)
		btn.add_theme_stylebox_override("focus", ns)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		build_hbox.add_child(btn)
		_slot_buttons.append(btn)

	# --- Right: Minimap placeholder ---
	var minimap_panel := PanelContainer.new()
	minimap_panel.custom_minimum_size = Vector2(170, 0)
	minimap_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.05, 0.03, 0.9), Color(0.3, 0.25, 0.15, 0.4), 1))
	grid.add_child(minimap_panel)
	var mm_label := Label.new()
	mm_label.text = "MINIMAP\n256x256"
	mm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mm_label.add_theme_font_size_override("font_size", 11)
	mm_label.add_theme_color_override("font_color", Color(0.4, 0.45, 0.35))
	minimap_panel.add_child(mm_label)

	_update_slot_highlight()

	# --- Game Over panel ---
	_game_over_panel = PanelContainer.new()
	_game_over_panel.visible = false
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(460, 280)
	_game_over_panel.offset_left = -230.0
	_game_over_panel.offset_top = -140.0
	_game_over_panel.offset_right = 230.0
	_game_over_panel.offset_bottom = 140.0
	_game_over_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.03, 0.06, 0.96), Color(0.6, 0.5, 0.2), 3))
	_canvas.add_child(_game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	_game_over_panel.add_child(vbox)

	var go_title := Label.new()
	go_title.text = Locale.t("game_over")
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
	restart_btn.text = Locale.t("restart")
	restart_btn.custom_minimum_size = Vector2(150, 46)
	var rb_style := _create_panel_style(
		Color(0.08, 0.06, 0.04, 0.95), Color(0.7, 0.55, 0.2), 2)
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
	_setup_card_ui()
	_setup_synergy_bar()
	_setup_event_ui()
	_setup_choice_ui()
	_setup_speed_label()
	_setup_esc_menu()
	_setup_debug_overlay()

func _setup_card_ui() -> void:
	_card_panel = PanelContainer.new()
	_card_panel.visible = false
	_card_panel.set_anchors_preset(Control.PRESET_CENTER)
	_card_panel.custom_minimum_size = Vector2(700, 320)
	_card_panel.offset_left = -350.0
	_card_panel.offset_top = -160.0
	_card_panel.offset_right = 350.0
	_card_panel.offset_bottom = 160.0
	_card_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.03, 0.03, 0.06, 0.96), Color(0.7, 0.55, 0.15), 3))
	_canvas.add_child(_card_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_card_panel.add_child(vbox)

	var title := Label.new()
	title.text = Locale.t("choose_reward")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	for i in 3:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 150)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		var card_normal := _create_panel_style(
			Color(0.07, 0.05, 0.03, 0.95), Color(0.5, 0.4, 0.2), 2)
		card_normal.corner_radius_top_left = 8
		card_normal.corner_radius_top_right = 8
		card_normal.corner_radius_bottom_left = 8
		card_normal.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", card_normal)
		var card_hover := _create_panel_style(
			Color(0.14, 0.11, 0.06, 0.95), Color(0.95, 0.8, 0.3), 3)
		card_hover.corner_radius_top_left = 8
		card_hover.corner_radius_top_right = 8
		card_hover.corner_radius_bottom_left = 8
		card_hover.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("hover", card_hover)
		btn.add_theme_stylebox_override("pressed", card_hover)
		btn.pressed.connect(_on_card_selected.bind(i))
		hbox.add_child(btn)
		_card_buttons.append(btn)

	_card_skip_btn = Button.new()
	_card_skip_btn.text = Locale.t("skip")
	_card_skip_btn.custom_minimum_size = Vector2(100, 36)
	_card_skip_btn.add_theme_font_size_override("font_size", 14)
	_card_skip_btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_card_skip_btn.add_theme_stylebox_override("normal", _create_panel_style(
		Color(0.06, 0.05, 0.04, 0.9), Color(0.4, 0.35, 0.2), 1))
	_card_skip_btn.pressed.connect(_on_card_skip)
	var skip_center := CenterContainer.new()
	skip_center.add_child(_card_skip_btn)
	vbox.add_child(skip_center)

func _setup_synergy_bar() -> void:
	var syn_panel := PanelContainer.new()
	syn_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	syn_panel.offset_left = 6.0
	syn_panel.offset_top = 40.0
	syn_panel.custom_minimum_size = Vector2(140, 0)
	syn_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.04, 0.05, 0.7), Color(0.25, 0.22, 0.15, 0.3), 1))
	_canvas.add_child(syn_panel)
	_synergy_label = Label.new()
	_synergy_label.add_theme_font_size_override("font_size", 11)
	_synergy_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	syn_panel.add_child(_synergy_label)
	_update_synergy_bar()

func _setup_event_ui() -> void:
	_event_label = Label.new()
	_event_label.visible = false
	_event_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_event_label.offset_top = 50.0
	_event_label.offset_left = -200.0
	_event_label.offset_right = 200.0
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.add_theme_font_size_override("font_size", 20)
	_event_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_canvas.add_child(_event_label)

func _setup_choice_ui() -> void:
	_choice_panel = PanelContainer.new()
	_choice_panel.visible = false
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.custom_minimum_size = Vector2(440, 200)
	_choice_panel.offset_left = -220.0
	_choice_panel.offset_top = -100.0
	_choice_panel.offset_right = 220.0
	_choice_panel.offset_bottom = 100.0
	_choice_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.03, 0.06, 0.96), Color(0.5, 0.7, 0.3), 3))
	_canvas.add_child(_choice_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_choice_panel.add_child(vbox)

	_choice_label = Label.new()
	_choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_label.add_theme_font_size_override("font_size", 17)
	_choice_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_choice_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	for i in 2:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(190, 44)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		btn.add_theme_stylebox_override("normal", _create_panel_style(
			Color(0.08, 0.06, 0.04, 0.95), Color(0.5, 0.6, 0.3), 2))
		btn.add_theme_stylebox_override("hover", _create_panel_style(
			Color(0.14, 0.12, 0.06, 0.95), Color(0.7, 0.8, 0.3), 2))
		btn.pressed.connect(_on_choice_selected.bind(i))
		hbox.add_child(btn)
		_choice_buttons.append(btn)

func _setup_speed_label() -> void:
	_speed_label = Label.new()
	_speed_label.visible = false
	_speed_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_speed_label.offset_left = -60.0
	_speed_label.offset_top = 50.0
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed_label.add_theme_font_size_override("font_size", 22)
	_speed_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	_canvas.add_child(_speed_label)

func _setup_esc_menu() -> void:
	_esc_panel = PanelContainer.new()
	_esc_panel.visible = false
	_esc_panel.set_anchors_preset(Control.PRESET_CENTER)
	_esc_panel.custom_minimum_size = Vector2(320, 380)
	_esc_panel.offset_left = -160.0
	_esc_panel.offset_top = -190.0
	_esc_panel.offset_right = 160.0
	_esc_panel.offset_bottom = 190.0
	_esc_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.03, 0.06, 0.96), Color(0.6, 0.5, 0.2), 3))
	_canvas.add_child(_esc_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_esc_panel.add_child(vbox)

	var title := Label.new()
	title.text = Locale.t("paused")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	vbox.add_child(title)

	var btn_style := _create_panel_style(
		Color(0.08, 0.06, 0.04, 0.95), Color(0.6, 0.5, 0.2), 2)
	var btn_hover := _create_panel_style(
		Color(0.14, 0.11, 0.06, 0.95), Color(0.85, 0.72, 0.3), 2)

	var resume_btn := Button.new()
	resume_btn.text = Locale.t("resume")
	resume_btn.custom_minimum_size = Vector2(200, 40)
	resume_btn.add_theme_font_size_override("font_size", 16)
	resume_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	resume_btn.add_theme_stylebox_override("normal", btn_style)
	resume_btn.add_theme_stylebox_override("hover", btn_hover)
	resume_btn.pressed.connect(_on_esc_resume)
	var c1 := CenterContainer.new()
	c1.add_child(resume_btn)
	vbox.add_child(c1)

	var restart_btn := Button.new()
	restart_btn.text = Locale.t("restart")
	restart_btn.custom_minimum_size = Vector2(200, 40)
	restart_btn.add_theme_font_size_override("font_size", 16)
	restart_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	restart_btn.add_theme_stylebox_override("normal", btn_style)
	restart_btn.add_theme_stylebox_override("hover", btn_hover)
	restart_btn.pressed.connect(_on_restart)
	var c2 := CenterContainer.new()
	c2.add_child(restart_btn)
	vbox.add_child(c2)

	var title_btn := Button.new()
	title_btn.text = Locale.t("title_screen")
	title_btn.custom_minimum_size = Vector2(200, 40)
	title_btn.add_theme_font_size_override("font_size", 16)
	title_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	title_btn.add_theme_stylebox_override("normal", btn_style)
	title_btn.add_theme_stylebox_override("hover", btn_hover)
	title_btn.pressed.connect(_on_esc_title)
	var c3 := CenterContainer.new()
	c3.add_child(title_btn)
	vbox.add_child(c3)

	# --- Volume sliders ---
	var vol_label_color := Color(0.75, 0.68, 0.4)
	var slider_names := ["Master", "Music", "SFX"]
	var slider_defaults := [AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume]
	for i in 3:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(260, 28)
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = slider_names[i]
		lbl.custom_minimum_size = Vector2(55, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", vol_label_color)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = slider_defaults[i]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		slider.value_changed.connect(func(val: float) -> void:
			match idx:
				0: AudioManager.master_volume = val
				1: AudioManager.music_volume = val
				2: AudioManager.sfx_volume = val
		)
		row.add_child(slider)
		var cc := CenterContainer.new()
		cc.add_child(row)
		vbox.add_child(cc)

func _setup_debug_overlay() -> void:
	_debug_label = Label.new()
	_debug_label.visible = false
	_debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_label.offset_left = 8.0
	_debug_label.offset_top = 180.0
	_debug_label.add_theme_font_size_override("font_size", 12)
	_debug_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_canvas.add_child(_debug_label)

func _update_slot_highlight() -> void:
	for i in _slot_buttons.size():
		var btn: Button = _slot_buttons[i]
		var style: StyleBoxFlat
		if i == _selected_slot:
			style = _create_panel_style(
				Color(0.18, 0.14, 0.06, 0.95), Color(1.0, 0.85, 0.25), 3)
		else:
			style = _create_panel_style(
				Color(0.12, 0.1, 0.07, 0.75), Color(0.4, 0.3, 0.18, 0.5), 2)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style)

func _create_panel_style(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	if border_color != Color.TRANSPARENT:
		style.border_color = border_color
		style.border_width_bottom = border_width
		style.border_width_top = border_width
		style.border_width_left = border_width
		style.border_width_right = border_width
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

# ---------------------------------------------------------------------------
# Wave system
# ---------------------------------------------------------------------------

func _create_enemy_templates(wave_num: int) -> Array:
	# Exponential HP scaling: 1.30^(wave-1) — wave 3=1.69x, wave 5=2.86x, wave 7=4.83x
	var hp_scale := pow(1.30, wave_num - 1)
	var speed_scale := 1.0 + (wave_num - 1) * 0.03
	var dps_scale := 1.0 + (wave_num - 1) * 0.10
	var templates: Array = []

	# Rusher — always present
	var rusher := EnemyData.new()
	rusher.enemy_name = "Rusher"
	rusher.enemy_type = EnemyData.EnemyType.RUSHER
	rusher.max_hp = 25.0 * hp_scale
	rusher.dps = 8.0 * dps_scale
	rusher.speed = 3.5 * speed_scale
	rusher.mineral_reward = 3
	rusher.color = Color(0.85, 0.2, 0.15)
	templates.append(rusher)

	# Wave 2+: Splitter
	if wave_num >= 2:
		var splitter := EnemyData.new()
		splitter.enemy_name = "Splitter"
		splitter.enemy_type = EnemyData.EnemyType.SPLITTER
		splitter.max_hp = 40.0 * hp_scale
		splitter.dps = 6.0 * dps_scale
		splitter.speed = 3.0 * speed_scale
		splitter.mineral_reward = 5
		splitter.color = Color(0.6, 0.85, 0.2)
		splitter.split_count = 2
		templates.append(splitter)

	# Wave 3+: Tank
	if wave_num >= 3:
		var tank := EnemyData.new()
		tank.enemy_name = "Tank"
		tank.enemy_type = EnemyData.EnemyType.TANK
		tank.max_hp = 120.0 * hp_scale
		tank.dps = 14.0 * dps_scale
		tank.speed = 1.8 * speed_scale
		tank.mineral_reward = 8
		tank.color = Color(0.5, 0.35, 0.6)
		tank.scale_factor = 1.4
		templates.append(tank)

	# Wave 4+: Exploder
	if wave_num >= 4:
		var exploder := EnemyData.new()
		exploder.enemy_name = "Exploder"
		exploder.enemy_type = EnemyData.EnemyType.EXPLODER
		exploder.max_hp = 20.0 * hp_scale
		exploder.dps = 4.0 * dps_scale
		exploder.speed = 4.5 * speed_scale
		exploder.mineral_reward = 4
		exploder.color = Color(1.0, 0.6, 0.1)
		exploder.explode_radius = 2.5
		exploder.explode_damage = 35.0 + wave_num * 8.0
		templates.append(exploder)

	# Wave 5+: Elite Rusher
	if wave_num >= 5:
		var elite := EnemyData.new()
		elite.enemy_name = "Elite Rusher"
		elite.enemy_type = EnemyData.EnemyType.ELITE_RUSHER
		elite.max_hp = 60.0 * hp_scale
		elite.dps = 18.0 * dps_scale
		elite.speed = 4.5 * speed_scale
		elite.mineral_reward = 6
		elite.color = Color(0.95, 0.15, 0.3)
		elite.scale_factor = 1.15
		templates.append(elite)

	# Wave 6+: Destroyer
	if wave_num >= 6:
		var destroyer := EnemyData.new()
		destroyer.enemy_name = "Destroyer"
		destroyer.enemy_type = EnemyData.EnemyType.DESTROYER
		destroyer.max_hp = 180.0 * hp_scale
		destroyer.dps = 25.0 * dps_scale
		destroyer.speed = 1.5 * speed_scale
		destroyer.mineral_reward = 12
		destroyer.color = Color(0.3, 0.1, 0.4)
		destroyer.scale_factor = 1.6
		templates.append(destroyer)

	return templates

var _spawn_queue: Array = []
const SPAWN_PER_FRAME := 3  # max enemies to spawn per frame

func _spawn_wave() -> void:
	var wave_num := GameManager.wave_number
	# Tidal pattern: calm → storm cycle every 3 waves
	var cycle_pos := (wave_num - 1) % 3  # 0=calm, 1=rising, 2=storm
	var base_count := 30 + (wave_num - 1) * 8
	var count_multiplier: float = [0.7, 1.0, 1.4][cycle_pos]
	var enemy_count := int(base_count * count_multiplier * EventManager.get_challenge_enemy_mult())

	var templates := _create_enemy_templates(wave_num)
	var hq_pos := Vector3(128.5, 0.0, 128.5)

	# Queue enemies for gradual spawning instead of all at once
	for i in enemy_count:
		var template: EnemyData = templates[randi() % templates.size()]
		_spawn_queue.append({
			"template": template,
			"hq_pos": hq_pos,
			"edge": _random_edge_position(),
		})

	_wave_active = true
	_update_hud()

func _process_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		return
	var count := mini(SPAWN_PER_FRAME, _spawn_queue.size())
	for i in count:
		var info: Dictionary = _spawn_queue.pop_front()
		var enemy: Node3D = enemy_scene.instantiate()
		enemy.set("data", info["template"])
		enemy.set("target_position", info["hq_pos"])
		enemy.position = Vector3(info["edge"].x, 0.0, info["edge"].y)
		enemy.connect("died", _on_enemy_died)
		if enemy.has_signal("drop_mineral"):
			enemy.connect("drop_mineral", _on_enemy_drop_mineral)
		add_child(enemy)
		enemies_alive += 1

func _on_wave_cleared() -> void:
	AudioManager.play_sfx_by_name("wave_start")
	EffectsManager.spawn_reward_sparkle(Vector3(128.5, 1.0, 128.5))
	var bonus := 25 + GameManager.wave_number * 10
	var reward_mult := EventManager.get_challenge_reward_mult()
	GameManager.add_minerals(int(bonus * reward_mult))
	EventManager.clear_combat_effects()
	EventManager.clear_challenge()
	GameManager.wave_number += 1
	_between_waves = true
	_wave_countdown = WAVE_INTERVAL

	# Trigger reward cards
	_show_reward_cards()

	# 30% chance of combat event on next wave
	if randf() < 0.3:
		EventManager.trigger_random_combat_event()

	# 25% chance of choice event between waves (wave 3+)
	if GameManager.wave_number >= 3 and randf() < 0.25:
		EventManager.trigger_random_choice_event()

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
		# Right-click drag camera (StarCraft style)
		if _right_dragging:
			var spd := _cam_zoom * 0.004
			var cam_delta := Vector2(-event.relative.x, -event.relative.y) * spd
			cam_delta = cam_delta.rotated(deg_to_rad(-45.0))
			_cam_center += cam_delta
			var pad := _cam_zoom * 0.3
			_cam_center.x = clampf(_cam_center.x, pad, float(MAP_SIZE) - pad)
			_cam_center.y = clampf(_cam_center.y, pad, float(MAP_SIZE) - pad)
			_update_camera_position()
		# Drag build for barricades
		if _dragging and _selected_slot == 0:
			_try_drag_build(event.position)

	if event is InputEventMouseButton:
		# Zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_zoom = maxf(_cam_zoom - 3.0, CAM_ZOOM_MIN)
			_update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_zoom = minf(_cam_zoom + 3.0, CAM_ZOOM_MAX)
			_update_camera_position()
		# Right-click drag
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_right_dragging = event.pressed
		# Drag start/stop
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_last_grid = Vector2i(-999, -999)
			else:
				_dragging = false

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_selected_slot = 0
				_update_slot_highlight()
			KEY_2:
				_selected_slot = 1
				_update_slot_highlight()
			KEY_3:
				_selected_slot = 2
				_update_slot_highlight()
			KEY_4:
				_selected_slot = 3
				_update_slot_highlight()
			KEY_5:
				_selected_slot = 4
				_update_slot_highlight()
			KEY_SPACE:
				GameFeel.toggle_pause()
				_update_hud()
			KEY_F:
				var spd := GameFeel.cycle_speed()
				if _speed_label:
					_speed_label.text = "%dx" % [int(spd)]
					_speed_label.visible = spd > 1.0
			KEY_ESCAPE:
				_toggle_esc_menu()
			KEY_F3:
				_debug_visible = not _debug_visible
				if _debug_label:
					_debug_label.visible = _debug_visible

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(event.position)

func _handle_left_click(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_ground(screen_pos)
	if world_pos.x < 0.0:
		return
	var gx := int(floor(world_pos.x))
	var gz := int(floor(world_pos.z))
	var grid_pos := Vector2i(gx, gz)

	if gx < 0 or gx >= MAP_SIZE or gz < 0 or gz >= MAP_SIZE:
		return

	# Existing building -> level up
	if building_grid.has(grid_pos):
		var existing := building_grid[grid_pos] as BaseBuilding
		if existing and is_instance_valid(existing) and existing != _hq:
			existing.level_up()
			_update_hud()
		return

	# Place new building
	var bd := _building_datas[_selected_slot] as BuildingData
	if not GameManager.spend_minerals(bd.cost):
		return

	var building: BaseBuilding
	match _selected_slot:
		0:
			building = barricade_scene.instantiate() as BaseBuilding
		1:
			building = tower_scene.instantiate() as BaseBuilding
		2:
			building = barracks_scene.instantiate() as BaseBuilding
		3:
			building = miner_scene.instantiate() as BaseBuilding
		4:
			building = buff_tower_scene.instantiate() as BaseBuilding
		_:
			building = barricade_scene.instantiate() as BaseBuilding

	building.data = bd
	building.grid_position = grid_pos
	building.position = Vector3(float(gx) + 0.5, 0.0, float(gz) + 0.5)
	building.add_to_group("buildings")
	building.destroyed.connect(_on_building_destroyed.bind(grid_pos))
	add_child(building)
	_buildings_count += 1
	building_grid[grid_pos] = building
	FlowField.set_obstacle(grid_pos, true)
	_flow_dirty = true
	AudioManager.play_sfx_by_name("build")
	EffectsManager.spawn_build_effect(building.position + Vector3(0, 0.2, 0), bd.color)
	if bd.trait_type >= 0:
		SynergyManager.add_trait(bd.trait_type)

func _handle_right_click(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_ground(screen_pos)
	if world_pos.x < 0.0:
		return
	var gx := int(floor(world_pos.x))
	var gz := int(floor(world_pos.z))
	var grid_pos := Vector2i(gx, gz)

	if not building_grid.has(grid_pos):
		return
	var building := building_grid[grid_pos] as BaseBuilding
	if building and is_instance_valid(building) and building != _hq:
		building.demolish()
		_update_hud()

func _update_ghost(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_ground(screen_pos)
	if world_pos.x < 0.0:
		_ghost_mesh.visible = false
		_range_ring.visible = false
		return
	var gx := int(floor(world_pos.x))
	var gz := int(floor(world_pos.z))
	_mouse_grid_pos = Vector2i(gx, gz)
	var in_bounds := gx >= 0 and gx < MAP_SIZE and gz >= 0 and gz < MAP_SIZE

	if not in_bounds:
		_ghost_mesh.visible = false
		_range_ring.visible = false
		return

	# Hide ghost over existing buildings
	if building_grid.has(_mouse_grid_pos):
		_ghost_mesh.visible = false
		_range_ring.visible = false
		return

	_ghost_mesh.visible = true
	var bd := _building_datas[_selected_slot] as BuildingData
	var h := 0.4
	match bd.building_name:
		"Tower": h = 1.0
		"Barracks": h = 0.8
		"Miner": h = 0.6
		"Buff Tower": h = 0.9
	var ghost_box := _ghost_mesh.mesh as BoxMesh
	if ghost_box:
		ghost_box.size = Vector3(1.0, h, 1.0)
	var center := Vector3(float(gx) + 0.5, h / 2.0, float(gz) + 0.5)
	_ghost_mesh.position = center

	if GameManager.minerals >= bd.cost:
		_ghost_mat.albedo_color = Color(0.4, 0.85, 0.4, 0.38)
	else:
		_ghost_mat.albedo_color = Color(0.9, 0.2, 0.2, 0.38)

	# Range indicator
	var range_val := 0.0
	var ring_col := Color(0.3, 0.7, 1.0, 0.5)
	if bd.attack_range > 0.0:
		range_val = bd.attack_range
		ring_col = Color(1.0, 0.4, 0.2, 0.45)
	elif bd.buff_range > 0.0:
		range_val = bd.buff_range
		ring_col = Color(0.9, 0.8, 0.2, 0.45)
	if range_val > 0.0:
		_range_ring.visible = true
		_range_ring.position = Vector3(center.x, 0.05, center.z)
		_range_ring.scale = Vector3(range_val, 1.0, range_val)
		_range_shader_mat.set_shader_parameter("ring_color", ring_col)
	else:
		_range_ring.visible = false

# ---------------------------------------------------------------------------
# Mouse-to-ground ray
# ---------------------------------------------------------------------------

func _screen_to_ground(screen_pos: Vector2) -> Vector3:
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return Vector3(-1.0, 0.0, -1.0)
	var t := -from.y / dir.y
	return from + dir * t

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _try_drag_build(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_ground(screen_pos)
	if world_pos.x < 0.0:
		return
	var gx := int(floor(world_pos.x))
	var gz := int(floor(world_pos.z))
	var grid_pos := Vector2i(gx, gz)

	if grid_pos == _drag_last_grid:
		return
	_drag_last_grid = grid_pos

	if gx < 0 or gx >= MAP_SIZE or gz < 0 or gz >= MAP_SIZE:
		return
	if building_grid.has(grid_pos):
		return

	var bd := _building_datas[0] as BuildingData
	if not GameManager.spend_minerals(bd.cost):
		return

	var building: BaseBuilding = barricade_scene.instantiate() as BaseBuilding
	building.data = bd
	building.grid_position = grid_pos
	building.position = Vector3(float(gx) + 0.5, 0.0, float(gz) + 0.5)
	building.add_to_group("buildings")
	building.destroyed.connect(_on_building_destroyed.bind(grid_pos))
	add_child(building)
	_buildings_count += 1
	building_grid[grid_pos] = building
	FlowField.set_obstacle(grid_pos, true)
	_flow_dirty = true

func _on_unit_spawned() -> void:
	_units_alive += 1

func _on_unit_died() -> void:
	_units_alive -= 1

func _on_building_destroyed(grid_pos: Vector2i) -> void:
	AudioManager.play_sfx_by_name("destroy")
	var destroy_pos := Vector3(float(grid_pos.x) + 0.5, 0.0, float(grid_pos.y) + 0.5)
	EffectsManager.spawn_destroy_effect(destroy_pos)
	_buildings_count -= 1
	if building_grid.has(grid_pos):
		var b = building_grid[grid_pos]
		if is_instance_valid(b) and b.data and b.data.trait_type >= 0:
			SynergyManager.remove_trait(b.data.trait_type)
	building_grid.erase(grid_pos)
	FlowField.set_obstacle(grid_pos, false)
	_flow_dirty = true

func _on_enemy_died() -> void:
	enemies_alive -= 1
	GameFeel.shake(0.12)
	AudioManager.play_sfx_by_name("death", -6.0)
	# Check for split spawns — recount from group after a frame
	_check_wave_completion.call_deferred()
	_update_hud()

func _check_wave_completion() -> void:
	if not _wave_active:
		return
	if enemies_alive <= 0 and _spawn_queue.is_empty():
		_wave_active = false
		enemies_alive = 0
		_on_wave_cleared()
		_update_hud()

func _on_enemy_drop_mineral(pos: Vector3, amount: int) -> void:
	var orb: Node3D = mineral_orb_scene.instantiate()
	orb.position = pos + Vector3(0.0, 0.3, 0.0)
	orb.set("amount", amount)
	orb.set("target_position", Vector3(128.5, 0.5, 128.5))
	add_child(orb)

func _on_minerals_changed(_amount: int) -> void:
	_update_hud()

func _recalculate_flow_field() -> void:
	# HQ occupies 3x3 at (127,127)-(129,129), use center cells as targets
	var targets: Array = []
	for dx in 3:
		for dz in 3:
			targets.append(Vector2i(127 + dx, 127 + dz))
	FlowField.recalculate(targets)

func _on_slot_pressed(slot_index: int) -> void:
	AudioManager.play_sfx_by_name("ui_click", -3.0)
	_selected_slot = slot_index
	_update_slot_highlight()

func _update_hud() -> void:
	if _mineral_label:
		_mineral_label.text = "$%d" % GameManager.minerals
	if _wave_info_label:
		var next := ""
		if _between_waves:
			next = "  |  Next: %ds" % int(ceil(_wave_countdown))
		var pause := "  ||" if GameFeel.paused else ""
		_wave_info_label.text = "W%d  K:%d  E:%d%s%s" % [
			GameManager.wave_number, GameManager.kill_count, enemies_alive, next, pause]
	if _hp_label and _hq:
		var hp := int(_hq.current_hp) if is_instance_valid(_hq) else 0
		_hp_label.text = "%d" % hp

func _on_game_over() -> void:
	AudioManager.stop_bgm()
	AudioManager.play_sfx_by_name("destroy", 3.0)
	_game_over_panel.visible = true
	_ghost_mesh.visible = false
	var secs := int(GameManager.game_time)
	_result_label.text = Locale.t_fmt("result_format", [
		GameManager.wave_number, GameManager.kill_count, secs / 60, secs % 60
	])

# ---------------------------------------------------------------------------
# Reward cards
# ---------------------------------------------------------------------------

func _show_reward_cards() -> void:
	_pending_cards = RewardCard.pick_cards(GameManager.wave_number)
	if _pending_cards.is_empty():
		return
	for i in 3:
		if i < _pending_cards.size():
			var card: RewardCard = _pending_cards[i]
			_card_buttons[i].text = "[%s]\n%s\n%s" % [card.get_rarity_name(), card.card_name, card.description]
			_card_buttons[i].visible = true
			var rcolor: Color = card.get_rarity_color()
			_card_buttons[i].add_theme_stylebox_override("normal", _create_panel_style(
				Color(0.08, 0.06, 0.04, 0.95), rcolor * 0.6, 2))
			_card_buttons[i].add_theme_stylebox_override("hover", _create_panel_style(
				Color(0.14, 0.11, 0.06, 0.95), rcolor, 3))
		else:
			_card_buttons[i].visible = false
	_card_panel.visible = true
	_awaiting_card = true

func _on_card_selected(index: int) -> void:
	if index >= _pending_cards.size():
		return
	AudioManager.play_sfx_by_name("reward")
	EffectsManager.spawn_reward_sparkle(Vector3(128.5, 1.0, 128.5))
	var card: RewardCard = _pending_cards[index]
	_apply_card(card)
	_card_panel.visible = false
	_awaiting_card = false

func _on_card_skip() -> void:
	_card_panel.visible = false
	_awaiting_card = false

func _apply_card(card: RewardCard) -> void:
	match card.effect_type:
		RewardCard.EffectType.MINERAL_BONUS:
			GameManager.add_minerals(int(card.effect_value))
		RewardCard.EffectType.TRAIT_GRANT:
			if card.trait_type >= 0:
				SynergyManager.add_trait(card.trait_type)
		RewardCard.EffectType.BUILDING_HEAL:
			var buildings := get_tree().get_nodes_in_group("buildings")
			for b in buildings:
				if is_instance_valid(b) and b is BaseBuilding:
					var max_hp: float = b.get_effective_max_hp()
					b.current_hp = minf(b.current_hp + max_hp * card.effect_value, max_hp)
		RewardCard.EffectType.UNIT_BUFF:
			# Store as permanent bonus in EventManager
			EventManager.add_unit_dps_perm_bonus(card.effect_value)

# ---------------------------------------------------------------------------
# Synergy bar
# ---------------------------------------------------------------------------

func _update_synergy_bar() -> void:
	if not _synergy_label:
		return
	var _trait_icons := {
		TraitData.TraitType.FIRE: "F",
		TraitData.TraitType.ICE: "I",
		TraitData.TraitType.POISON: "P",
		TraitData.TraitType.ELECTRIC: "E",
		TraitData.TraitType.FORTIFY: "D",
	}
	var text := ""
	for t in [TraitData.TraitType.FIRE, TraitData.TraitType.ICE, TraitData.TraitType.POISON,
			TraitData.TraitType.ELECTRIC, TraitData.TraitType.FORTIFY]:
		var count := SynergyManager.get_trait_count(t)
		if count > 0:
			var tier := SynergyManager.get_synergy_tier(t)
			var tier_mark := ""
			if tier >= 2:
				tier_mark = " **"
			elif tier >= 1:
				tier_mark = " *"
			var icon: String = _trait_icons.get(t, "?")
			text += "[%s] %s x%d%s\n" % [icon, TraitData.get_trait_name(t), count, tier_mark]
	var cross := SynergyManager.get_cross_synergies()
	for c in cross:
		text += ">> %s\n" % c.to_upper()
	_synergy_label.text = text

# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_combat_event(event_name: String, description: String) -> void:
	if _event_label:
		_event_label.text = "%s: %s" % [Locale.t(event_name), Locale.t(description)]
		_event_label.visible = true
		_event_timer = 4.0

var _pending_choices: Array = []

func _on_choice_event(event_name: String, description: String, choices: Array) -> void:
	_pending_choices = choices
	if _choice_label:
		_choice_label.text = "%s\n%s" % [Locale.t(event_name), Locale.t(description)]
	for i in _choice_buttons.size():
		if i < choices.size():
			_choice_buttons[i].text = Locale.t(choices[i]["label"])
			_choice_buttons[i].visible = true
		else:
			_choice_buttons[i].visible = false
	_choice_panel.visible = true
	_awaiting_choice = true

func _on_choice_selected(index: int) -> void:
	if index >= _pending_choices.size():
		return
	AudioManager.play_sfx_by_name("ui_click")
	var choice_id: String = _pending_choices[index]["id"]
	var result := EventManager.resolve_choice(choice_id)
	_choice_panel.visible = false
	_awaiting_choice = false
	# Show result as event notification
	if _event_label and result != "":
		_event_label.text = result
		_event_label.visible = true
		_event_timer = 3.0

func _toggle_esc_menu() -> void:
	_esc_visible = not _esc_visible
	_esc_panel.visible = _esc_visible
	if _esc_visible:
		GameFeel.toggle_pause()
		if not GameFeel.paused:
			GameFeel.toggle_pause()
	else:
		if GameFeel.paused:
			GameFeel.toggle_pause()
	_update_hud()

func _on_esc_resume() -> void:
	_esc_visible = false
	_esc_panel.visible = false
	if GameFeel.paused:
		GameFeel.toggle_pause()
	_update_hud()

func _reset_all_managers() -> void:
	GameManager.reset()
	SynergyManager.reset()
	EventManager.reset()
	GameFeel.reset()
	SpatialGrid.reset()

func _on_esc_title() -> void:
	_reset_all_managers()
	get_tree().change_scene_to_file("res://scenes/main/title.tscn")

func _on_restart() -> void:
	_reset_all_managers()
	get_tree().reload_current_scene()
