extends Node2D

## 메인 게임 씬(코디네이터). 시뮬레이션을 고정 틱으로 돌리고, 렌더러·HUD·입력을 잇는다.
## 시뮬레이션은 Node를 모르고, 여기서만 sim의 명령 함수를 호출한다.

const SimConfig := preload("res://sim/sim_config.gd")
const GameSimulation := preload("res://sim/game_simulation.gd")
const Iso := preload("res://render/iso.gd")
const GroundRenderer := preload("res://render/ground_renderer.gd")
const EnemyRenderer := preload("res://render/enemy_renderer.gd")
const ProjectileRenderer := preload("res://render/projectile_renderer.gd")
const EffectRenderer := preload("res://render/effect_renderer.gd")
const BuildingView := preload("res://render/building_view.gd")
const PlacementView := preload("res://render/placement_view.gd")
const WorldCamera := preload("res://render/world_camera.gd")
const Hud := preload("res://scenes/ui/hud.gd")
const ResultText := preload("res://scenes/ui/result_text.gd")
const BuildingCatalog := preload("res://scripts/building_catalog.gd")

const MAX_TICKS_PER_FRAME := 6
const RIGHT_CLICK_DRAG_THRESHOLD := 6.0

var sim: GameSimulation
var run_seed: int = 0
## 타이틀 배경용: HUD·입력·소리·흔들림 없이 방어선과 무리만 돌린다. 본진은 죽지 않는다
var demo_mode: bool = false

var _accum: float = 0.0
var _alpha: float = 0.0
var _ground: GroundRenderer
var _buildings_root: Node2D
var _enemy_renderer: EnemyRenderer
var _projectile_renderer: ProjectileRenderer
var _effect_renderer: EffectRenderer
var _placement: PlacementView
var _camera: WorldCamera
var _hud
var _building_views: Dictionary = {}     # sim index → BuildingView
var _enemy_colors: Array = []

var _slot_types: Array = []
var _selected_slot: int = 0
var _dragging: bool = false
var _drag_last_tile: Vector2i = Vector2i(-999, -999)
var _right_pressed: bool = false
var _right_press_pos: Vector2 = Vector2.ZERO
var _right_dragged: bool = false
var _esc_visible: bool = false
var _debug_visible: bool = false
var _last_render_usec: int = 0
var _mouse_tile: Vector2i = Vector2i(-1, -1)
var _demo_time: float = 0.0

func _ready() -> void:
	if not demo_mode:
		GameManager.reset()
		GameFeel.reset()
	run_seed = _pick_seed()
	sim = GameSimulation.new()
	sim.start(run_seed)
	_slot_types = BuildingCatalog.buildable_types()
	for ed in sim.enemy_datas:
		_enemy_colors.append((ed as EnemyData).color)

	_ground = GroundRenderer.new()
	_ground.z_index = -5   # 잔해 얼룩(z -1)이 바닥 위에 오도록
	add_child(_ground)
	_ground.setup(SimConfig.MAP_SIZE, SimConfig.HQ_CENTER, run_seed)

	_buildings_root = Node2D.new()
	_buildings_root.y_sort_enabled = true
	add_child(_buildings_root)

	_enemy_renderer = EnemyRenderer.new()
	add_child(_enemy_renderer)
	_enemy_renderer.setup(sim.enemy_datas)

	_projectile_renderer = ProjectileRenderer.new()
	add_child(_projectile_renderer)
	_projectile_renderer.setup()

	_effect_renderer = EffectRenderer.new()
	add_child(_effect_renderer)
	_effect_renderer.setup()

	_placement = PlacementView.new()
	_placement.visible = false
	add_child(_placement)

	_camera = WorldCamera.new()
	add_child(_camera)
	_camera.setup(SimConfig.MAP_SIZE, SimConfig.HQ_CENTER)
	_camera.make_current()

	for idx in range(sim.buildings.high):
		if sim.buildings.alive[idx] != 0:
			_add_building_view(idx)

	if demo_mode:
		_setup_demo()
		return

	_hud = Hud.new()
	_hud.slot_pressed.connect(_on_slot_pressed)
	_hud.resume_requested.connect(_on_esc_resume)
	_hud.restart_requested.connect(_on_restart)
	_hud.title_requested.connect(_on_esc_title)
	_hud.pause_pressed.connect(func() -> void:
		if not _is_world_input_blocked():
			GameFeel.toggle_pause())
	_hud.speed_pressed.connect(func(spd: float) -> void: GameFeel.set_game_speed(spd))
	_hud.menu_pressed.connect(func() -> void:
		if not sim.game_over:
			_toggle_esc_menu())
	_hud.setup(self, sim.building_datas)
	_hud.update_slot_highlight(_selected_slot, sim.building_datas)
	_hud.update_hud(sim, GameFeel.paused)

	GameManager.game_over_triggered.connect(_on_game_over)
	AudioManager.play_bgm_by_name("battle")

func _pick_seed() -> int:
	var env := OS.get_environment("SIKMUBYNCH_SEED")
	if env != "" and env.is_valid_int():
		return int(env)
	randomize()
	return randi() & 0x7FFFFFFF

# ---------------------------------------------------------------------------
# 프레임
# ---------------------------------------------------------------------------

## 데모: 본진 주변에 방어선을 깔고, 카메라를 멀리 빼서 천천히 흘린다
func _setup_demo() -> void:
	sim.minerals = 100000
	for r in [7, 10]:
		for a in range(0, 360, 24 if r == 7 else 18):
			var tx := int(round(SimConfig.HQ_CENTER.x + cos(deg_to_rad(a)) * r))
			var ty := int(round(SimConfig.HQ_CENTER.y + sin(deg_to_rad(a)) * r))
			var types := [BuildingData.BuildingType.GUN_TOWER, BuildingData.BuildingType.CANNON_TOWER,
				BuildingData.BuildingType.TESLA_TOWER, BuildingData.BuildingType.FLAME_TOWER,
				BuildingData.BuildingType.FROST_TOWER, BuildingData.BuildingType.SNIPER_TOWER]
			var type: int = types[(a / 18 + r) % types.size()]
			var idx := sim.place_building(type, tx, ty)
			if idx >= 0:
				_add_building_view(idx)
	# 압박 스트림은 끄고 일정한 무리를 유지한다 (타이틀에 오래 머물러도 물량이 무한히 늘지 않게)
	sim.waves.enabled = false
	sim.debug_spawn(300, EnemyData.EnemyType.RUSHER, 16.0)
	sim.debug_spawn(120, EnemyData.EnemyType.RUSHER, 26.0)
	sim.debug_spawn(12, EnemyData.EnemyType.TANK, 20.0)
	var vp := get_viewport().get_visible_rect().size
	_camera.zoom_by(0.62 / WorldCamera.DEFAULT_ZOOM, vp * 0.5, vp)

func _process(delta: float) -> void:
	if demo_mode:
		# 방어선은 무너지지 않고(타이틀에 오래 머물러도 같은 그림), 카메라는 느리게 원을 그리며 흐른다
		var b := sim.buildings
		for i in range(b.high):
			if b.alive[i] != 0:
				b.hp[i] = b.max_hp[i]
		if sim.enemies_alive() < 380:
			sim.debug_spawn(40, EnemyData.EnemyType.RUSHER, 26.0)
			sim.debug_spawn(3, EnemyData.EnemyType.TANK, 28.0)
		_demo_time += delta
		# 본진이 화면 오른쪽 가운데에 오도록 (왼쪽은 타이틀 글자 자리)
		_camera.center_tile = SimConfig.HQ_CENTER + Vector2(cos(_demo_time * 0.05), sin(_demo_time * 0.05)) * 3.0 + Vector2(-6.0, 6.0)
		_camera.pan_tiles(Vector2.ZERO)
	_camera.frame_tick(delta, not _is_world_input_blocked() and not demo_mode)
	if _camera.is_zooming() and get_viewport().gui_get_hovered_control() == null:
		_update_ghost_at_tile(_screen_to_tile(get_viewport().get_mouse_position()))

	var sim_time := GameFeel.consume_sim_time(delta)
	if sim.game_over:
		sim_time = 0.0
	_accum += sim_time
	var ticks := 0
	while _accum >= SimConfig.TICK_DT and ticks < MAX_TICKS_PER_FRAME:
		sim.tick()
		_consume_tick_events()
		_accum -= SimConfig.TICK_DT
		ticks += 1
		# 끝난 틱은 이벤트를 비우지 않으므로 더 돌면 마지막 폭발·사망·수입이 겹쳐 재생된다
		if sim.game_over:
			break
	if ticks >= MAX_TICKS_PER_FRAME and _accum > SimConfig.TICK_DT:
		_accum = 0.0   # 따라잡지 못하면 버린다 (죽음의 나선 방지)
	_alpha = clampf(_accum / SimConfig.TICK_DT, 0.0, 1.0)

	var t0 := Time.get_ticks_usec()
	_enemy_renderer.update_from_sim(sim.enemies, _alpha, sim.tick_index, sim.buildings)
	_projectile_renderer.update_from_sim(sim.combat, _alpha)
	# 게임오버 정지 중에도 본진 붕괴 파편은 끝까지 흩어진다 (흔들림도 실제 시간으로 잦아든다)
	_effect_renderer.update_frame(delta if not GameFeel.paused or sim.game_over else 0.0)
	for view in _building_views.values():
		view.update_from_sim(sim.buildings, delta, sim.tick_index, _alpha)
	_last_render_usec = Time.get_ticks_usec() - t0

	if demo_mode:
		return
	GameManager.sync(sim)
	if _hud:
		_hud.update_hud(sim, GameFeel.paused)
		_hud.tick(delta, sim, _debug_visible, _debug_text() if _debug_visible else "")

func _phase_ms(phase: int) -> float:
	return float(sim.phase_usec[phase]) / 1000.0

func _debug_text() -> String:
	return "FPS %d\n적 %d (최대 %d)\n발사체 %d  파티클 %d\n건물 %d\n틱 %.2f ms  렌더 %.2f ms\n  이동 %.2f  전투 %.2f  그리드 %.2f  Flow %.2f\n그리드 등록 %d  Flow 재계산 %d (%.2f ms%s)\n유입 %.1f/s (바닥 %.1f × %.2f + 디렉터 %.1f, 목표 무리 %d)  변 %s\n시간 %.0f  속도 %.1fx  seed %d" % [
		Engine.get_frames_per_second(), sim.enemies_alive(), sim.peak_alive(),
		sim.combat.p_alive_count, _effect_renderer.particle_count(),
		sim.buildings.alive_count,
		float(sim.last_tick_usec) / 1000.0, float(_last_render_usec) / 1000.0,
		_phase_ms(GameSimulation.Phase.ENEMIES), _phase_ms(GameSimulation.Phase.COMBAT), _phase_ms(GameSimulation.Phase.GRID), _phase_ms(GameSimulation.Phase.FLOW),
		sim.grid.registered, sim.flow.recalc_count, float(sim.flow.last_step_usec) / 1000.0, " 계산 중" if sim.flow.is_busy() else "",
		sim.waves.spawn_rate(), sim.waves.base_rate(sim.waves.time), sim.waves.pressure, sim.waves.director_rate, int(sim.waves.target_alive(sim.waves.time)),
		"%.1f/%.1f/%.1f/%.1f" % [sim.waves.side_weight[0], sim.waves.side_weight[1], sim.waves.side_weight[2], sim.waves.side_weight[3]],
		sim.waves.time, GameFeel.game_speed, run_seed
	]

## 틱 결과를 표현 계층으로 넘긴다. 규모에 비례하되 개별 재생하지 않는다.
## 데모(타이틀 배경)에서는 이펙트만 그리고 소리·흔들림·HUD는 건너뛴다.
func _consume_tick_events() -> void:
	var loud := not demo_mode
	var e := sim.enemies
	var c := sim.combat
	_effect_renderer.begin_tick()
	if e.death_count > 0:
		_effect_renderer.on_deaths(e.death_count, e.death_x, e.death_y, e.death_type, _enemy_colors)
	if c.hit_count > 0:
		_effect_renderer.on_hits(c.hit_count, c.hit_x, c.hit_y, c.hit_kind)
		if loud:
			AudioManager.play_sfx_by_name("hit", -14.0, 1.0 + randf_range(-0.08, 0.08))
	var max_explosion_kills := 0
	if c.explosion_count > 0:
		_effect_renderer.on_explosions(c.explosion_count, c.explosion_x, c.explosion_y, c.explosion_radius, c.explosion_kills)
		for i in range(mini(c.explosion_count, SimConfig.MAX_EXPLOSION_EVENTS)):
			max_explosion_kills = maxi(max_explosion_kills, c.explosion_kills[i])
	if c.bolt_count > 0:
		_effect_renderer.on_bolts(c.bolt_count, c.bolt_x0, c.bolt_y0, c.bolt_x1, c.bolt_y1)
		if loud:
			AudioManager.play_sfx_by_name("tesla", -8.0, 1.0 + randf_range(-0.1, 0.1))
	if c.beam_count > 0:
		_effect_renderer.on_beams(c.beam_count, c.beam_x0, c.beam_y0, c.beam_x1, c.beam_y1, c.beam_kills)
		if loud:
			AudioManager.play_sfx_by_name("sniper", -4.0, 1.0 + randf_range(-0.05, 0.05))
			GameFeel.shake(1.2)
	if c.flame_count > 0:
		_effect_renderer.on_flames(c.flame_count, c.flame_x, c.flame_y, c.flame_tx, c.flame_ty, c.flame_radius)
		if loud:
			AudioManager.play_sfx_by_name("flame", -12.0)
	# 폭발 흔들림은 여러 마리를 잡았을 때만 (본진 주포가 쉬지 않고 쏴도 화면이 계속 떨리지 않게)
	if max_explosion_kills >= 2 and loud:
		GameFeel.shake(1.0 + 0.4 * float(mini(max_explosion_kills, 10)))
	# 총구 섬광: 이번 틱 발사한 타워 (상한 안에서)
	var flashed := 0
	for idx in range(sim.buildings.high):
		if flashed >= 48:
			break
		if sim.buildings.alive[idx] == 0 or sim.buildings.last_fire_tick[idx] != sim.tick_index - 1:
			continue
		var view: BuildingView = _building_views.get(idx)
		if view == null:
			continue
		var bd: BuildingData = view.data
		var radius := 6.0
		match bd.building_type:
			BuildingData.BuildingType.CANNON_TOWER: radius = 12.0
			BuildingData.BuildingType.SNIPER_TOWER: radius = 9.0
			BuildingData.BuildingType.TESLA_TOWER: radius = 8.0
			BuildingData.BuildingType.FLAME_TOWER: radius = 0.0
			BuildingData.BuildingType.HQ: radius = 16.0
		if radius > 0.0:
			var flash_col := Color(1.0, 0.85, 0.5) if bd.building_type == BuildingData.BuildingType.HQ else bd.color.lightened(0.5)
			_effect_renderer.on_muzzle(view.position - Vector2(0.0, Iso.height_px(bd.height) + 10.0), flash_col, radius)
			flashed += 1
	if loud:
		GameFeel.report_kills(c.tick_kills, max_explosion_kills)
		AudioManager.play_kill_layer(c.tick_kills, max_explosion_kills)
		if sim.minerals_gained_this_tick > 0:
			_hud.report_gain(sim.minerals_gained_this_tick)

	for idx in sim.buildings_destroyed:
		var view: BuildingView = _building_views.get(idx)
		if view:
			var bd := view.data
			var cx := float(view.tile_x) + float(view.size) * 0.5
			var cy := float(view.tile_y) + float(view.size) * 0.5
			_effect_renderer.on_building_destroyed(cx, cy, float(view.size), bd.color)
			if loud:
				GameFeel.report_building_destroyed(bd.building_type == BuildingData.BuildingType.HQ)
			view.queue_free()
			_building_views.erase(idx)
		if loud:
			AudioManager.play_sfx_by_name("destroy", -2.0)
	if sim.hq_hit_this_tick and loud:
		_hud.show_hq_warning()
		GameFeel.shake(2.0)


# ---------------------------------------------------------------------------
# 건물 표현
# ---------------------------------------------------------------------------

func _add_building_view(idx: int) -> void:
	if idx < 0:
		return
	var type: int = sim.buildings.type_id[idx]
	var view := BuildingView.new()
	_buildings_root.add_child(view)
	view.setup(idx, sim.building_datas[type], sim.buildings.tile_x[idx], sim.buildings.tile_y[idx])
	_building_views[idx] = view

func _try_place(type: int, tile: Vector2i) -> bool:
	if _is_world_input_blocked():
		return false
	if not SimConfig.in_bounds(tile.x, tile.y):
		return false
	if not sim.can_place(type, tile.x, tile.y):
		return false
	if not sim.can_afford(type):
		return false
	var idx := sim.place_building(type, tile.x, tile.y)
	if idx < 0:
		return false
	_add_building_view(idx)
	var bd := sim.building_datas[type] as BuildingData
	AudioManager.play_sfx_by_name("build", -3.0)
	_effect_renderer.on_building_placed(float(tile.x) + float(bd.size) * 0.5, float(tile.y) + float(bd.size) * 0.5, bd.color)
	_update_ghost_at_tile(tile)
	return true

func _try_demolish(tile: Vector2i) -> bool:
	if _is_world_input_blocked():
		return false
	var idx := sim.buildings.building_at(tile.x, tile.y)
	if idx < 0 or idx == sim.buildings.hq_index:
		return false
	var view: BuildingView = _building_views.get(idx)
	var refund := sim.demolish_at(tile.x, tile.y)
	if refund < 0:
		return false
	if view:
		view.queue_free()
		_building_views.erase(idx)
	AudioManager.play_sfx_by_name("ui_click", -4.0)
	_update_ghost_at_tile(tile)
	return true

# ---------------------------------------------------------------------------
# 입력
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if demo_mode:
		return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _right_pressed and not _right_dragged and not _is_world_input_blocked():
				_try_demolish(_screen_to_tile(event.position))
			_right_pressed = false
			_right_dragged = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_debug_visible = not _debug_visible
			_hud.set_debug_visible(_debug_visible)
			return
		if event.keycode == KEY_ESCAPE:
			if sim.game_over:
				_on_esc_title()
			else:
				_toggle_esc_menu()
			return
		if event.keycode == KEY_R and sim.game_over:
			_on_restart()
			return
		if event.keycode == KEY_SPACE:
			if not _is_world_input_blocked():
				GameFeel.toggle_pause()
			return
		if event.keycode == KEY_F4 and OS.is_debug_build():
			# 스트레스: HQ 주변 링에 500마리
			if not _is_world_input_blocked():
				sim.debug_spawn(500, EnemyData.EnemyType.RUSHER, 26.0)
			return
	if _is_world_input_blocked():
		_cancel_world_drag()
		return
	if event is InputEventMouseMotion:
		if get_viewport().gui_get_hovered_control() != null:
			_placement.hide_ghost()
			_dragging = false
			return
		if _right_pressed:
			if _right_dragged or event.position.distance_to(_right_press_pos) > RIGHT_CLICK_DRAG_THRESHOLD:
				_right_dragged = true
				_camera.pan_screen(-event.relative)
		var tile := _screen_to_tile(event.position)
		_mouse_tile = tile
		_update_ghost_at_tile(tile)
		if _dragging and _is_drag_buildable(_slot_types[_selected_slot]):
			if tile != _drag_last_tile:
				_drag_last_tile = tile
				_try_place(_slot_types[_selected_slot], tile)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom_smooth(WorldCamera.ZOOM_STEP, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom_smooth(1.0 / WorldCamera.ZOOM_STEP, event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select_slot(0)
			KEY_2: _select_slot(1)
			KEY_3: _select_slot(2)
			KEY_4: _select_slot(3)
			KEY_5: _select_slot(4)
			KEY_6: _select_slot(5)
			KEY_7: _select_slot(6)
			KEY_8: _select_slot(7)
			KEY_F:
				var spd := GameFeel.cycle_speed()
				_hud.set_speed_label(spd)

func _unhandled_input(event: InputEvent) -> void:
	if demo_mode or _is_world_input_blocked():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = true
			var tile := _screen_to_tile(event.position)
			_drag_last_tile = tile
			_try_place(_slot_types[_selected_slot], tile)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_right_pressed = true
			_right_dragged = false
			_right_press_pos = event.position

func _is_drag_buildable(type: int) -> bool:
	return type == BuildingData.BuildingType.BARRICADE or type == BuildingData.BuildingType.WALL

func _select_slot(slot: int) -> void:
	if slot < 0 or slot >= _slot_types.size():
		return
	_selected_slot = slot
	_hud.update_slot_highlight(_selected_slot, sim.building_datas)
	_update_ghost_at_tile(_mouse_tile)

func _on_slot_pressed(slot_index: int) -> void:
	if _is_world_input_blocked():
		return
	AudioManager.play_sfx_by_name("ui_click", -3.0)
	_select_slot(slot_index)

func _is_world_input_blocked() -> bool:
	return sim.game_over or _esc_visible

func _cancel_world_drag() -> void:
	_dragging = false
	_right_pressed = false
	_right_dragged = false
	_placement.hide_ghost()

func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var world := _camera.screen_to_world(screen_pos, get_viewport().get_visible_rect().size)
	return Vector2i(int(floor(world.x)), int(floor(world.y)))

func _update_ghost_at_tile(tile: Vector2i) -> void:
	if _is_world_input_blocked() or not SimConfig.in_bounds(tile.x, tile.y):
		_placement.hide_ghost()
		return
	var type: int = _slot_types[_selected_slot]
	_placement.show_at(sim.building_datas[type], tile.x, tile.y,
		sim.can_place(type, tile.x, tile.y), sim.can_afford(type))

# ---------------------------------------------------------------------------
# 메뉴·게임오버
# ---------------------------------------------------------------------------

func _toggle_esc_menu() -> void:
	_esc_visible = not _esc_visible
	_hud.set_esc_visible(_esc_visible)
	GameFeel.set_pause_reason("esc", _esc_visible)
	_cancel_world_drag()

func _on_esc_resume() -> void:
	_esc_visible = false
	_hud.set_esc_visible(false)
	GameFeel.set_pause_reason("esc", false)

func _on_game_over() -> void:
	GameFeel.set_pause_reason("game_over", true)
	_cancel_world_drag()
	_esc_visible = false
	AudioManager.stop_bgm()
	AudioManager.play_sfx_by_name("destroy", 3.0)
	var summary := sim.run_summary()
	var records := GameManager.submit_run(summary)
	_hud.set_esc_visible(false)
	_hud.show_game_over(ResultText.build(summary, records))

func _reset_managers() -> void:
	GameManager.reset()
	GameFeel.reset()

func _on_esc_title() -> void:
	_reset_managers()
	get_tree().change_scene_to_file("res://scenes/main/title.tscn")

func _on_restart() -> void:
	_reset_managers()
	get_tree().reload_current_scene()
