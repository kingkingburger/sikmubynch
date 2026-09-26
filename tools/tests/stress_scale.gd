extends SceneTree

## 물량 단계별 스트레스 측정: 방어선을 깔고 살아 있는 적 수를 N으로 유지하며 틱 단계별 시간을 잰다.
## 병목 위치를 찾는 용도라 실패 판정은 하지 않는다. 결과는 docs/technical-design.md "측정 기록"에 옮긴다.
## STRESS_COUNTS=1000,2000,5000 으로 단계를 바꾼다. STRESS_SECONDS=N 으로 단계당 측정 시간을 바꾼다 (기본 10).

const GameSimulation := preload("res://sim/game_simulation.gd")
const SimConfig := preload("res://sim/sim_config.gd")
const StressCommon := preload("stress_common.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var seconds := StressCommon.env_int("STRESS_SECONDS", 10)
	for n in StressCommon.env_counts("STRESS_COUNTS", [1000, 2000, 5000]):
		_measure(int(n), seconds)
	quit(0)

func _measure(target: int, seconds: int) -> void:
	var sim := GameSimulation.new()
	sim.start(4242)
	sim.waves.enabled = false
	sim.minerals = 1000000
	var towers := StressCommon.build_ring(func(type: int, tile: Vector2i) -> bool: return sim.place_building(type, tile.x, tile.y) >= 0)
	sim.flow.recalculate()
	sim.buildings.rebuild_near()
	print("  ring: %d towers" % towers)
	var phases := sim.phase_usec.size()
	var total := PackedInt64Array()
	total.resize(phases)
	var worst_phase := PackedInt64Array()
	worst_phase.resize(phases)
	var tick_total := 0
	var tick_worst := 0
	var ticks := seconds * SimConfig.TICK_RATE
	var warmup := SimConfig.TICK_RATE * 2
	for t in range(warmup + ticks):
		# 죽은 만큼 가장자리에서 바로 채운다: 이동·전투가 모두 진행 중인 N마리 상태
		var missing := target - sim.enemies_alive()
		if missing > 0:
			sim.debug_spawn(missing, EnemyData.EnemyType.RUSHER, 40.0)
		sim.tick()
		if sim.game_over:
			break
		if t < warmup:
			continue
		tick_total += sim.last_tick_usec
		tick_worst = maxi(tick_worst, sim.last_tick_usec)
		for p in range(phases):
			total[p] += sim.phase_usec[p]
			worst_phase[p] = maxi(worst_phase[p], sim.phase_usec[p])
	var parts: PackedStringArray = []
	for p in range(phases):
		parts.append("%s %.2f/%.2f" % [GameSimulation.PHASE_NAMES[p], float(total[p]) / ticks / 1000.0, float(worst_phase[p]) / 1000.0])
	print("STRESS %5d: alive %5d, tick avg %.2f ms worst %.2f ms | avg/worst ms: %s | projectiles %d, kills %d%s" % [
		target, sim.enemies_alive(), float(tick_total) / ticks / 1000.0, float(tick_worst) / 1000.0,
		", ".join(parts), sim.combat.p_alive_count, sim.kills, " (HQ destroyed)" if sim.game_over else ""])

