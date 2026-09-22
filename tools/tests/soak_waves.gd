extends SceneTree

## 헤드리스 소크: 스크립트로 방어선을 짓고 N분까지 돌리며 유입률·동시 적 수·틱 시간·HQ 상태를 기록한다.
## 밸런스 감각과 성능 추세를 보는 용도. 실패 판정은 하지 않는다.
## SOAK_MINUTES=N 으로 목표 시간을 바꾼다 (기본 6). 본진이 죽으면 그 전에 끝난다.

const GameSimulation := preload("res://sim/game_simulation.gd")
const SimConfig := preload("res://sim/sim_config.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim := GameSimulation.new()
	sim.start(20260921)
	var target_minutes := int(OS.get_environment("SOAK_MINUTES")) if OS.get_environment("SOAK_MINUTES") != "" else 6
	var min_alive_after_start := 999999
	var min_alive_at := 0
	var worst := 0
	var total := 0
	var n := 0
	var peak := 0
	var ticks := 0
	var max_ticks := 30 * 60 * target_minutes
	var build_timer := 0.0
	while not sim.game_over and ticks < max_ticks:
		# 1초마다 자원이 허락하는 만큼 짓는다 (플레이어가 계속 손을 움직이는 것을 흉내)
		build_timer -= SimConfig.TICK_DT
		if build_timer <= 0.0:
			build_timer = 1.0
			_build_defense(sim)
		sim.tick()
		ticks += 1
		n += 1
		total += sim.last_tick_usec
		worst = maxi(worst, sim.last_tick_usec)
		peak = maxi(peak, sim.enemies_alive())
		# 30초 이후 동시 적 수의 바닥: 잦아드는 구간이 있는지 본다
		if ticks > 30 * 30 and sim.enemies_alive() < min_alive_after_start:
			min_alive_after_start = sim.enemies_alive()
			min_alive_at = ticks / 30
		if ticks % (30 * 10) == 0:
			var near := 0
			for i in range(sim.enemies.high):
				if sim.enemies.alive[i] != 0 and Vector2(sim.enemies.pos_x[i], sim.enemies.pos_y[i]).distance_to(SimConfig.HQ_CENTER) <= 22.0:
					near += 1
			print("  t=%4ds inflow=%5.1f/s (floor %4.1f + dir %5.1f) target=%4d alive=%4d near22=%4d peak=%4d hq=%4d kills=%5d minerals=%5d towers=%3d tick=%.2fms" % [
				ticks / 30, sim.waves.spawn_rate(), sim.waves.floor_rate(), sim.waves.director_rate, int(sim.waves.target_alive(sim.waves.time)),
				sim.enemies_alive(), near, peak, int(sim.hq_hp()), sim.kills, sim.minerals,
				sim.buildings.alive_count, float(sim.last_tick_usec) / 1000.0])
	print("SOAK: time %ds, game_over=%s, kills=%d, peak_alive=%d, min_alive_after_30s=%d (at %ds), avg tick %.2f ms, worst %.2f ms" % [
		ticks / 30, str(sim.game_over), sim.kills, sim.peak_alive(), min_alive_after_start, min_alive_at, float(total) / float(n) / 1000.0, float(worst) / 1000.0])
	quit(0)

## 자원이 허락하는 만큼 타워를 본진 주변 나선으로 늘리고, 바깥에 바리케이드 링(틈 있음)을 둔다.
## 플레이어의 "적당한" 배치를 흉내 내는 용도이지 최적 배치가 아니다.
var _slots: Array = []       # 타워 후보 타일 (본진에서 가까운 순)
var _slot_head: int = 0
var _tower_count: int = 0
var _barricades: int = 0

func _prepare_slots() -> void:
	var c := SimConfig.HQ_CENTER
	var cands: Array = []
	for ty in range(44, 84):
		for tx in range(44, 84):
			var dx := float(tx) + 0.5 - c.x
			var dy := float(ty) + 0.5 - c.y
			var d := sqrt(dx * dx + dy * dy)
			if d < 3.5 or d > 16.0:
				continue
			# 체스판 간격: 타워 사이에 통로를 남긴다
			if (tx + ty) % 2 != 0:
				continue
			cands.append([d, tx, ty])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	_slots = cands

## 타워 종류 순환: 처음 GUN_ONLY_COUNT개는 싼 속사만(사람이 초반에 하는 것), 그 뒤 속사 3 → 화염 → 속사 2 → 전격 → 포격 → 감속 → 저격
const GUN_ONLY_COUNT := 20
const ROTATION := [
	BuildingData.BuildingType.GUN_TOWER, BuildingData.BuildingType.GUN_TOWER, BuildingData.BuildingType.GUN_TOWER,
	BuildingData.BuildingType.FLAME_TOWER, BuildingData.BuildingType.GUN_TOWER, BuildingData.BuildingType.GUN_TOWER,
	BuildingData.BuildingType.TESLA_TOWER, BuildingData.BuildingType.CANNON_TOWER,
	BuildingData.BuildingType.FROST_TOWER, BuildingData.BuildingType.SNIPER_TOWER,
]

func _build_defense(sim) -> void:
	if _slots.is_empty():
		_prepare_slots()
	var barricade := BuildingData.BuildingType.BARRICADE
	# 바리케이드: 타워 6개마다 8개씩 반지름 10~13 링에 3칸마다 틈
	var wanted_b := (_tower_count / 6) * 8
	if _barricades < wanted_b:
		var ring := 10 + (_barricades / 8) % 4
		for i in range(32):
			if _barricades >= wanted_b or sim.minerals < 40:
				break
			if i % 3 == 2:
				continue
			var a := float(i) / 32.0 * TAU
			var tx := int(SimConfig.HQ_CENTER.x + cos(a) * float(ring))
			var ty := int(SimConfig.HQ_CENTER.y + sin(a) * float(ring))
			if sim.place_building(barricade, tx, ty) >= 0:
				_barricades += 1
	# 타워: 순환표의 다음 타워를 살 수 있으면 짓는다. 못 사면 다음 수입까지 기다린다.
	var built := 0
	while _slot_head < _slots.size() and built < 3:
		var type: int = BuildingData.BuildingType.GUN_TOWER if _tower_count < GUN_ONLY_COUNT else ROTATION[_tower_count % ROTATION.size()]
		if not sim.can_afford(type):
			break
		var slot: Array = _slots[_slot_head]
		if sim.place_building(type, int(slot[1]), int(slot[2])) >= 0:
			_tower_count += 1
			built += 1
		_slot_head += 1
