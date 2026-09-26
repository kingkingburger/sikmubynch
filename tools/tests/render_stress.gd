extends SceneTree

## 창 모드 렌더 스트레스: 게임 씬에서 살아 있는 적 수를 N으로 유지하며 FPS·프레임 시간·렌더 CPU 시간·시뮬레이션 틱을 잰다.
## 수직 동기화를 끄고 재므로 FPS는 한계 성능이다. 실패 판정은 하지 않는다.
## 실행: godot --path project --script ../tools/tests/render_stress.gd
## RENDER_COUNTS=1000,2000,5000 / RENDER_SECONDS=N (기본 6) 으로 바꾼다.

const SimConfig := preload("res://sim/sim_config.gd")
const StressCommon := preload("stress_common.gd")

var game

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("SIKMUBYNCH_SEED", "4242")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file("res://scenes/main/game.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game.sim.waves.enabled = false
	game.sim.minerals = 1000000
	StressCommon.build_ring(func(type: int, tile: Vector2i) -> bool: return game._try_place(type, tile))
	var seconds := StressCommon.env_int("RENDER_SECONDS", 6)
	for n in StressCommon.env_counts("RENDER_COUNTS", [1000, 2000, 5000]):
		await _measure(int(n), seconds)
	quit(0)

func _measure(target: int, seconds: int) -> void:
	var frames := 0
	var frame_total := 0.0
	var frame_worst := 0.0
	var render_total := 0
	var render_worst := 0
	var tick_total := 0
	var tick_n := 0
	var last_tick: int = game.sim.tick_index
	var warm := 60
	var start := Time.get_ticks_msec()
	var measure_start := 0
	while true:
		var missing: int = target - game.sim.enemies_alive()
		if missing > 0:
			game.sim.debug_spawn(missing, EnemyData.EnemyType.RUSHER, 30.0)
		var t0 := Time.get_ticks_usec()
		await process_frame
		var ft := float(Time.get_ticks_usec() - t0) / 1000.0
		if game.sim.game_over:
			break
		if warm > 0:
			warm -= 1
			if warm == 0:
				measure_start = Time.get_ticks_msec()
			continue
		frames += 1
		frame_total += ft
		frame_worst = maxf(frame_worst, ft)
		render_total += game._last_render_usec
		render_worst = maxi(render_worst, game._last_render_usec)
		if game.sim.tick_index != last_tick:
			last_tick = game.sim.tick_index
			tick_total += game.sim.last_tick_usec
			tick_n += 1
		if Time.get_ticks_msec() - measure_start >= seconds * 1000:
			break
	if frames == 0:
		print("RENDER %5d: no frames measured (game over)" % target)
		return
	var elapsed := float(Time.get_ticks_msec() - measure_start) / 1000.0
	print("RENDER %5d: alive %5d, fps %.1f, frame avg %.2f ms worst %.2f ms, render cpu avg %.2f ms worst %.2f ms, sim tick avg %.2f ms, particles %d%s" % [
		target, game.sim.enemies_alive(), float(frames) / elapsed, frame_total / frames, frame_worst,
		float(render_total) / frames / 1000.0, float(render_worst) / 1000.0,
		float(tick_total) / maxi(tick_n, 1) / 1000.0, game._effect_renderer.particle_count(),
		" (HQ destroyed)" if game.sim.game_over else ""])

