extends SceneTree

## 게임 씬 스모크. 씬을 띄우고 프레임을 돌리며 렌더러·HUD·입력 경로가 오류 없이 한 판을 도는지 본다.
## 핵심 흐름만 본다: 시작 → 적 표시 → 건설·철거 → 정지 → 게임오버 → 재시작.

const SimConfig := preload("res://sim/sim_config.gd")

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

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	OS.set_environment("SIKMUBYNCH_SEED", "20260921")
	feel = root.get_node("GameFeel")
	gm = root.get_node("GameManager")
	gm.records_path = "user://test_records.cfg"   # 실제 개인 기록을 건드리지 않는다
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.records_path))
	change_scene_to_file("res://scenes/main/game.tscn")
	await _frames(2)
	game = current_scene
	check(game != null and game.sim != null, "game scene starts a simulation")

	var frames := 0
	while game.sim.tick_index < 60 and frames < 2000:
		await process_frame
		frames += 1
	check(game.sim.tick_index >= 60, "simulation advances")
	check(game._enemy_renderer.visible_total() == game.sim.enemies_alive() and game.sim.enemies_alive() > 0, "renderer shows every alive enemy")

	# 건설·철거
	var tile := Vector2i(60, 63)
	var views: int = game._building_views.size()
	check(game._try_place(BuildingData.BuildingType.GUN_TOWER, tile) and game._building_views.size() == views + 1, "build through the scene")
	check(game._try_demolish(tile) and game._building_views.size() == views, "demolish through the scene")
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	check(game._screen_to_tile(vp * 0.5) == Vector2i(63, 63), "screen center maps to the HQ tile")

	# 정지
	var t0: int = game.sim.tick_index
	feel.toggle_pause()
	await _frames(20)
	check(game.sim.tick_index == t0, "pause stops the simulation")
	feel.toggle_pause()
	await _frames(20)
	check(game.sim.tick_index > t0, "resume continues")

	# 자동 플레이: HUD 버튼 → 정상 비용 건설·뷰 생성 → 정지 → 단축키로 끄기.
	check(not game.auto_play_enabled, "auto play starts disabled")
	game._hud._btn_auto.pressed.emit()
	views = game._building_views.size()
	var built_before: int = game.sim.buildings_built
	await _frames(70)
	check(game.auto_play_enabled and game.sim.buildings_built > built_before and game._building_views.size() > views, "HUD enables auto play and renders its buildings")
	feel.toggle_pause()
	built_before = game.sim.buildings_built
	await _frames(40)
	check(game.sim.buildings_built == built_before, "pause also stops auto construction")
	feel.toggle_pause()
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	game._input(key)
	check(not game.auto_play_enabled and not game._hud._btn_auto.active, "B disables auto play and updates its indicator")
	built_before = game.sim.buildings_built
	await _frames(40)
	check(game.sim.buildings_built == built_before, "disabled bot issues no more construction")

	# 게임오버
	game.sim.buildings.hp[game.sim.buildings.hq_index] = 1.0
	var e: int = game.sim.enemies.spawn(EnemyData.EnemyType.TANK, 63.5, 61.5, 1.0, 1.0, 1.0)
	game.sim.enemies.attack_target[e] = game.sim.buildings.hq_index
	game.sim.enemies.attack_gen[e] = game.sim.buildings.generation[game.sim.buildings.hq_index]
	game.sim.enemies.attack_timer[e] = 0.0
	await _frames(30)
	check(game.sim.game_over and game._hud.is_game_over_visible(), "HQ destroyed shows the result screen")
	game._toggle_auto_play()
	check(not game.auto_play_enabled, "cannot enable auto play after game over")

	# 재시작
	game._on_restart()
	await _frames(2)
	game = current_scene
	check(not game.sim.game_over and game.sim.minerals == SimConfig.START_MINERALS, "restart resets the run")
	check(not game.auto_play_enabled, "restart resets auto play to disabled")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.records_path))

	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await _frames(2)
	quit(0 if failures.is_empty() else 1)
