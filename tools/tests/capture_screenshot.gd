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
	game.sim.debug_spawn(300, EnemyData.EnemyType.RUSHER, 24.0)
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

	# 장면 4: 줌 인 (스프라이트 방향·그림자 확인)
	game._camera.zoom_by(3.2, vp * 0.5, vp)
	game._camera.pan_tiles(Vector2(0.0, -6.0))
	for i in 20:
		await process_frame
	await _shot("04-zoomin")
	quit(0)

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join("shot-%s.png" % name)
	var err := img.save_png(path)
	print("SHOT %s -> %s (%s)" % [name, path, "ok" if err == OK else str(err)])
