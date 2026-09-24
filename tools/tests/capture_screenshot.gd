extends SceneTree

## 창 모드에서 게임 씬을 띄우고 스크린샷을 저장한다. 비주얼 검수용.
## 실행: godot --path project --script ../tools/tests/capture_screenshot.gd
## 출력: build/shot-<name>.png

var game
var out_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("SIKMUBYNCH_SEED", "20260921")
	out_dir = ProjectSettings.globalize_path("res://").path_join("../build")
	DirAccess.make_dir_recursive_absolute(out_dir)
	change_scene_to_file("res://scenes/main/game.tscn")
	await process_frame
	await process_frame
	game = current_scene

	# 장면 1: 시작 직후 (10초 안에 적이 보이는가)
	for i in 90:
		await process_frame
	await _shot("01-start")

	# 장면 2: 방어선 구축 + 중반 물량
	game.sim.minerals = 5000
	for x in range(56, 72):
		game._try_place(BuildingData.BuildingType.BARRICADE, Vector2i(x, 57))
	for x in range(57, 71, 3):
		game._try_place(BuildingData.BuildingType.GUN_TOWER, Vector2i(x, 59))
	game._try_place(BuildingData.BuildingType.CANNON_TOWER, Vector2i(60, 61))
	game._try_place(BuildingData.BuildingType.CANNON_TOWER, Vector2i(66, 61))
	game._try_place(BuildingData.BuildingType.FROST_TOWER, Vector2i(63, 60))
	game._try_place(BuildingData.BuildingType.WALL, Vector2i(55, 60))
	game._try_place(BuildingData.BuildingType.WALL, Vector2i(72, 60))
	game._try_place(BuildingData.BuildingType.FLAME_TOWER, Vector2i(61, 58))
	game._try_place(BuildingData.BuildingType.FLAME_TOWER, Vector2i(65, 58))
	game._try_place(BuildingData.BuildingType.TESLA_TOWER, Vector2i(58, 61))
	game._try_place(BuildingData.BuildingType.TESLA_TOWER, Vector2i(68, 61))
	game._try_place(BuildingData.BuildingType.SNIPER_TOWER, Vector2i(63, 66))
	game._try_place(BuildingData.BuildingType.SNIPER_TOWER, Vector2i(59, 66))
	game._try_place(BuildingData.BuildingType.SNIPER_TOWER, Vector2i(67, 66))
	game.sim.debug_spawn(300, EnemyData.EnemyType.RUSHER, 24.0)
	game.sim.debug_spawn(20, EnemyData.EnemyType.TANK, 20.0)
	for i in 240:
		await process_frame
	game._debug_visible = true
	game._hud.set_debug_visible(true)
	await process_frame
	await _shot("02-defense-300")

	# 장면 3: 줌 아웃 + 500 추가 (물량 가독성)
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	game._camera.zoom_by(0.55, vp * 0.5, vp)
	game.sim.debug_spawn(500, EnemyData.EnemyType.RUSHER, 30.0)
	game.sim.debug_spawn(60, EnemyData.EnemyType.TANK, 34.0)
	game.sim.debug_spawn(80, EnemyData.EnemyType.SPLITTER, 28.0)
	for i in 150:
		await process_frame
	await _shot("03-zoomout-800")

	# 장면 4: 줌 인 (스프라이트 방향·그림자·총구 섬광·볼트·빔 확인)
	game._camera.zoom_by(3.2, vp * 0.5, vp)
	game._camera.pan_tiles(Vector2(0.0, -6.0))
	game.sim.debug_spawn(120, EnemyData.EnemyType.RUSHER, 9.0)
	game.sim.debug_spawn(10, EnemyData.EnemyType.TANK, 10.0)
	for i in 30:
		await process_frame
	await _shot("04-zoomin")

	# 장면 5: 결과 화면 (기록·뚫린 방향·손실). 실제 개인 기록은 건드리지 않는다
	game.get_node("/root/GameManager").records_path = "user://shot_records.cfg"
	game._debug_visible = false
	game._hud.set_debug_visible(false)
	var hq: int = game.sim.buildings.hq_index
	game.sim.buildings.hp[hq] = 1.0
	var e: int = game.sim.enemies.spawn(EnemyData.EnemyType.TANK, 63.5, 61.5, 1.0, 1.0, 1.0)
	game.sim.enemies.attack_target[e] = hq
	game.sim.enemies.attack_timer[e] = 0.0
	for i in 30:
		await process_frame
	await _shot("05-result")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_records.cfg"))
	quit(0)

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join("shot-%s.png" % name)
	var err := img.save_png(path)
	print("SHOT %s -> %s (%s)" % [name, path, "ok" if err == OK else str(err)])
