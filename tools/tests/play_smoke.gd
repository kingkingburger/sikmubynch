extends SceneTree

## 게임 씬 스모크 테스트. 씬을 띄우고 프레임을 돌리며 렌더러·HUD·입력 경로가 오류 없이 도는지 본다.
## headless에서도 동작한다(그리기는 생략되지만 스크립트 경로는 실행된다).

var failures: Array[String] = []
var checks := 0
var game
var feel
var gm

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: ", label)

func _run() -> void:
	OS.set_environment("SIKMUBYNCH_SEED", "20260921")
	feel = root.get_node("GameFeel")
	gm = root.get_node("GameManager")
	# 실제 개인 기록을 건드리지 않는다
	gm.records_path = "user://test_records.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.records_path))
	change_scene_to_file("res://scenes/main/game.tscn")
	await process_frame
	await process_frame
	game = current_scene
	check(game != null and game.sim != null, "game scene created a simulation")
	check(game.run_seed == 20260921, "seed from environment")

	# MultiMesh buffer 레이아웃 검증: 첫 인스턴스에 알려진 값을 쓰고 읽는다
	var mmi: MultiMeshInstance2D = game._enemy_renderer._mmis[0]
	var mm := mmi.multimesh
	var buf: PackedFloat32Array = game._enemy_renderer._buffers[0]
	buf[0] = 2.0
	buf[1] = 0.0
	buf[2] = 0.0
	buf[3] = 123.0
	buf[4] = 0.0
	buf[5] = 2.0
	buf[6] = 0.0
	buf[7] = 456.0
	buf[8] = 0.5
	buf[9] = 0.25
	buf[10] = 1.0
	buf[11] = 1.0
	mm.buffer = buf
	check(game._enemy_renderer.STRIDE == 12 and mmi.material is ShaderMaterial, "buffer stride 12, frame shader material attached")
	check(game._enemy_renderer.frames_for_type(0) >= 1, "enemy type 0 reports its frame count (%d)" % game._enemy_renderer.frames_for_type(0))
	if DisplayServer.get_name() != "headless":
		# headless 더미 렌더러는 인스턴스 값을 돌려주지 않는다. 창 모드에서만 레이아웃을 검증한다.
		var xf := mm.get_instance_transform_2d(0)
		var col := mm.get_instance_color(0)
		check(is_equal_approx(xf.origin.x, 123.0) and is_equal_approx(xf.origin.y, 456.0), "buffer layout: origin")
		check(is_equal_approx(xf.x.x, 2.0) and is_equal_approx(xf.y.y, 2.0), "buffer layout: scale")
		check(is_equal_approx(col.r, 0.5) and is_equal_approx(col.g, 0.25), "buffer layout: color")

	# 시뮬레이션 2초 진행 (프레임 수가 아니라 틱 기준)
	var frames := 0
	while game.sim.tick_index < 60 and frames < 2000:
		await process_frame
		frames += 1
	check(game.sim.tick_index >= 60, "simulation ticks advance (%d)" % game.sim.tick_index)
	check(game.sim.enemies_alive() > 0, "enemies exist after 2 seconds")
	check(game._enemy_renderer.visible_total() == game.sim.enemies_alive(), "renderer shows every alive enemy")

	# 건설: 마우스 위치를 타일로 바꿔 배치
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	var minerals: int = game.sim.minerals
	game._select_slot(2)   # Gun Tower
	var tile := Vector2i(60, 63)
	var views_before: int = game._building_views.size()
	var gun_cost: int = game.sim.buildings.t_cost[BuildingData.BuildingType.GUN_TOWER]
	check(views_before == game.sim.buildings.alive_count, "one view per starting building")
	check(game._try_place(BuildingData.BuildingType.GUN_TOWER, tile), "place gun tower via scene")
	check(game.sim.minerals == minerals - gun_cost, "minerals spent")
	check(game._building_views.size() == views_before + 1, "building view created")
	check(not game._try_place(BuildingData.BuildingType.GUN_TOWER, tile), "occupied tile rejected")
	check(game._try_demolish(tile), "demolish via scene")
	check(game._building_views.size() == views_before, "building view removed")
	check(not game._try_demolish(Vector2i(63, 63)), "HQ cannot be demolished via scene")

	# 화면 좌표 → 타일 왕복
	var center_tile: Vector2i = game._screen_to_tile(vp * 0.5)
	check(center_tile == Vector2i(63, 63), "screen center maps to HQ tile (%s)" % str(center_tile))

	# 일시정지: 틱이 멈춘다
	var t0: int = game.sim.tick_index
	feel.toggle_pause()
	for i in 30:
		await process_frame
	check(game.sim.tick_index == t0, "Q-SYS-9 paused: no ticks")
	feel.toggle_pause()
	for i in 30:
		await process_frame
	check(game.sim.tick_index > t0, "Q-SYS-9 resumed: ticks continue")

	# ESC 메뉴는 정지 사유를 유지한다
	game._toggle_esc_menu()
	check(feel.paused and game._esc_visible, "ESC pauses")
	check(not game._try_place(BuildingData.BuildingType.BARRICADE, Vector2i(50, 50)), "ESC blocks placement")
	game._on_esc_resume()
	check(not feel.paused, "ESC resume unpauses")

	# 배속
	var s1: float = feel.cycle_speed()
	check(s1 == 2.0, "speed cycles to 2x")
	feel.set_game_speed(1.0)

	# 게임오버 경로: HQ를 강제로 부순다
	game.sim.buildings.hp[game.sim.buildings.hq_index] = 1.0
	var e: int = game.sim.enemies.spawn(EnemyData.EnemyType.TANK, 63.5, 61.5, 1.0, 1.0, 1.0)
	game.sim.enemies.attack_target[e] = game.sim.buildings.hq_index
	game.sim.enemies.attack_timer[e] = 0.0
	for i in 20:
		await process_frame
	check(game.sim.game_over, "HQ destroyed ends the run")
	check(gm.is_game_over, "GameManager mirrors game over")
	check(game._hud._game_over_panel.visible, "game over panel shown")
	var result: String = game._hud._result_label.text
	check(result.contains(root.get_node("Locale").t("result_lines").split(" ")[0]), "result shows building stats")
	check(gm.load_records()["runs"] == 1, "run recorded to personal records")
	check(feel.paused, "game over pauses simulation")

	# 재시작
	game._on_restart()
	await process_frame
	await process_frame
	game = current_scene
	check(not game.sim.game_over and game.sim.minerals == 150, "restart resets run")
	check(game.sim.buildings.alive_count == 5, "restart leaves HQ + starting defense")

	# 스트레스: 500마리 추가 후 프레임 진행
	game.sim.debug_spawn(500)
	var worst_render := 0
	for i in 60:
		await process_frame
		worst_render = maxi(worst_render, game._last_render_usec)
	print("SMOKE: 500+ enemies render worst %.2f ms, tick %.2f ms" % [float(worst_render) / 1000.0, float(game.sim.last_tick_usec) / 1000.0])
	check(game._enemy_renderer.visible_total() == game.sim.enemies_alive(), "renderer matches sim at 500+")
	var cap_total := 0
	for t in range(game.sim.enemy_datas.size()):
		cap_total += game._enemy_renderer.capacity_for_type(t)
	check(cap_total < game._enemy_renderer.max_per_type, "enemy buffers grow with the crowd instead of the cap (%d)" % cap_total)
	# F3 디버그 오버레이 문자열: 포맷 인자 수가 어긋나면 여기서 오류가 난다
	var debug_text: String = game._debug_text()
	check(debug_text.contains("Flow 재계산") and debug_text.contains("이동"), "F3 debug text formats with phase timings")

	# 최고 기록: 두 번째 런이 더 길면 갱신, 짧으면 이전 최고를 보여준다
	var rec_short: Dictionary = gm.submit_run({"time": 1.0, "kills": 0, "peak": 0})
	check(not rec_short["new_time"] and rec_short["best_time"] > 1.0, "shorter run keeps previous best")
	var rec_long: Dictionary = gm.submit_run({"time": 99999.0, "kills": 1, "peak": 1})
	check(rec_long["new_time"] and rec_long["best_time"] == 99999.0, "longer run sets a new best")
	var summary := {"time": 125.0, "kills": 10, "peak": 20, "built": 7, "lost": 3, "spent": 300,
		"minerals_left": 400, "breach_side": 0, "breach_share": 0.62}
	var text: String = game.result_text(summary, rec_long)
	check(text.contains("2:05") and text.contains("62%") and text.contains(root.get_node("Locale").t("side_0")), "result text shows time, breach side and share")
	check(text.contains("400"), "result text hints unspent minerals")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.records_path))

	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	# 씬을 먼저 내리고 오디오를 멈춰야 종료 시 누수 경고가 없다
	root.get_node("AudioManager").stop_all()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
