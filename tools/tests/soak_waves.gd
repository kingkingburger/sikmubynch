extends SceneTree

## 헤드리스 소크: 스크립트로 방어선을 짓고 N웨이브까지 돌리며 웨이브별 규모·틱 시간·HQ 상태를 기록한다.
## 밸런스 감각과 성능 추세를 보는 용도. 실패 판정은 하지 않는다.

const GameSimulation := preload("res://sim/game_simulation.gd")
const SimConfig := preload("res://sim/sim_config.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim := GameSimulation.new()
	sim.start(20260921)
	var target_wave := int(OS.get_environment("SOAK_WAVES")) if OS.get_environment("SOAK_WAVES") != "" else 12
	var last_wave := 0
	var worst := 0
	var total := 0
	var n := 0
	var peak := 0
	var ticks := 0
	var max_ticks := 30 * 60 * 20
	while sim.waves.wave_number <= target_wave and not sim.game_over and ticks < max_ticks:
		if sim.waves.wave_number != last_wave:
			last_wave = sim.waves.wave_number
			_build_defense(sim, last_wave)
			print("W%2d start: type=%d planned=%d hp_scale=%.2f minerals=%d buildings=%d" % [
				last_wave, sim.waves.wave_type, sim.waves.total_planned, sim.waves.hp_scale(last_wave), sim.minerals, sim.buildings.alive_count])
		sim.tick()
		ticks += 1
		n += 1
		total += sim.last_tick_usec
		worst = maxi(worst, sim.last_tick_usec)
		peak = maxi(peak, sim.enemies_alive())
		if ticks % (30 * 10) == 0:
			print("  t=%4ds wave=%d alive=%4d peak=%4d hq=%4d kills=%5d minerals=%5d tick=%.2fms" % [
				ticks / 30, sim.waves.wave_number, sim.enemies_alive(), peak, int(sim.hq_hp()), sim.kills, sim.minerals, float(sim.last_tick_usec) / 1000.0])
	print("SOAK: reached wave %d, game_over=%s, kills=%d, peak_alive=%d, avg tick %.2f ms, worst %.2f ms, time %ds" % [
		sim.waves.wave_number, str(sim.game_over), sim.kills, sim.peak_alive(), float(total) / float(n) / 1000.0, float(worst) / 1000.0, ticks / 30])
	quit(0)

## 매 웨이브 시작마다 자원이 허락하는 만큼 타워를 본진 주변 나선으로 늘리고, 바깥에 바리케이드 링(틈 있음)을 둔다.
## 플레이어의 "적당한" 배치를 흉내 내는 용도이지 최적 배치가 아니다.
var _slots: Array = []       # 타워 후보 타일 (본진에서 가까운 순)
var _slot_head: int = 0
var _tower_count: int = 0

func _prepare_slots() -> void:
	var c := SimConfig.HQ_CENTER
	var cands: Array = []
	for ty in range(48, 80):
		for tx in range(48, 80):
			var dx := float(tx) + 0.5 - c.x
			var dy := float(ty) + 0.5 - c.y
			var d := sqrt(dx * dx + dy * dy)
			if d < 3.5 or d > 12.0:
				continue
			# 체스판 간격: 타워 사이에 통로를 남긴다
			if (tx + ty) % 2 != 0:
				continue
			cands.append([d, tx, ty])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	_slots = cands

func _build_defense(sim, wave: int) -> void:
	if _slots.is_empty():
		_prepare_slots()
	var gun := BuildingData.BuildingType.GUN_TOWER
	var cannon := BuildingData.BuildingType.CANNON_TOWER
	var frost := BuildingData.BuildingType.FROST_TOWER
	var barricade := BuildingData.BuildingType.BARRICADE
	# 바리케이드 예산: 웨이브당 최대 4개, 반지름 10~13 링에 3칸마다 틈
	var ring := 10 + (wave % 4)
	var placed_b := 0
	for i in range(32):
		if placed_b >= 4 or sim.minerals < 60:
			break
		if i % 3 == 2:
			continue
		var a := float(i) / 32.0 * TAU
		var tx := int(SimConfig.HQ_CENTER.x + cos(a) * float(ring))
		var ty := int(SimConfig.HQ_CENTER.y + sin(a) * float(ring))
		if sim.place_building(barricade, tx, ty) >= 0:
			placed_b += 1
	# 타워: 자원이 50 이상이면 계속. 4개마다 캐논, 6개마다 냉기
	while sim.minerals >= 50 and _slot_head < _slots.size():
		var slot: Array = _slots[_slot_head]
		var type := gun
		if _tower_count % 4 == 3 and sim.minerals >= 120:
			type = cannon
		elif _tower_count % 6 == 5 and sim.minerals >= 80:
			type = frost
		elif _tower_count % 4 == 3 or _tower_count % 6 == 5:
			break  # 다음 웨이브 수입까지 기다린다
		if sim.place_building(type, int(slot[1]), int(slot[2])) >= 0:
			_tower_count += 1
		_slot_head += 1
