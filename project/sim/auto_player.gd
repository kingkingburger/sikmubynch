extends RefCounted

## 정상 건설 명령을 고르는 자동 플레이어. RNG·자원·전투 상태를 직접 변경하지 않는다.
## 반 초마다 주변 적과 남은 방어력을 보고 가장 약한 방향을 보강한다.
const SimConfig := preload("res://sim/sim_config.gd")
const DECISION_TICKS := SimConfig.TICK_RATE / 2
const BUILD_ORDER := [
	BuildingData.BuildingType.GUN_TOWER,
	BuildingData.BuildingType.CANNON_TOWER,
	BuildingData.BuildingType.FROST_TOWER,
	BuildingData.BuildingType.TESLA_TOWER,
	BuildingData.BuildingType.SNIPER_TOWER,
	BuildingData.BuildingType.FLAME_TOWER,
]

var _next_tick: int = 0

## 호출자는 반환된 {type, tile}을 평소와 같은 건설 경로로 실행한다.
func next_command(sim) -> Dictionary:
	if sim.game_over or sim.tick_index < _next_tick:
		return {}
	_next_tick = sim.tick_index + DECISION_TICKS
	var pressure := [0.0, 0.0, 0.0, 0.0]
	var defense := [0.0, 0.0, 0.0, 0.0]
	var counts := [0, 0, 0, 0]
	var enemies = sim.enemies
	for i in range(enemies.high):
		if enemies.alive[i] == 0:
			continue
		var offset := Vector2(enemies.pos_x[i], enemies.pos_y[i]) - SimConfig.HQ_CENTER
		var proximity := maxf(0.0, 1.0 - offset.length() / 40.0)
		pressure[_side(offset)] += proximity * sqrt(maxf(1.0, enemies.hp[i] / 30.0))
	var b = sim.buildings
	for i in range(b.high):
		if b.alive[i] == 0 or i == b.hq_index:
			continue
		var offset := Vector2(b.tile_x[i] + b.size[i] * 0.5, b.tile_y[i] + b.size[i] * 0.5) - SimConfig.HQ_CENTER
		if offset.length() > 20.0:
			continue
		var type: int = b.type_id[i]
		var side := _side(offset)
		var strength: float = b.t_damage[type] * b.t_rate[type]
		# 광역·연쇄·감속 타워도 방어력에 반영한다.
		strength *= 1.0 + b.t_splash[type] + b.t_chain[type] * 0.35
		strength += b.t_slow[type] * 35.0
		defense[side] += (strength + b.max_hp[i] * 0.03) * b.hp[i] / b.max_hp[i]
		if b.t_is_tower[type] != 0:
			counts[side] += 1
	var scores := []
	for side in range(4):
		scores.append((1.0 + pressure[side] / 10.0) / (1.0 + defense[side] / 50.0))
	for attempt in range(4):
		var side := 0
		for candidate in range(1, 4):
			if scores[candidate] > scores[side]:
				side = candidate
		# 두 번째 타워까지는 저렴한 기관총으로 네 방향의 기본 화력을 확보한다.
		var type: int = BUILD_ORDER[0 if counts[side] < 2 else (counts[side] - 1) % BUILD_ORDER.size()]
		var tile := _find_tile(sim, type, side)
		if tile.x >= 0:
			# 선택한 타워를 살 때까지 저축한다.
			return {"type": type, "tile": tile} if sim.can_afford(type) else {}
		scores[side] = -1.0
	return {}

func _side(offset: Vector2) -> int:
	if absf(offset.x) > absf(offset.y):
		return 0 if offset.x > 0.0 else 2
	return 1 if offset.y > 0.0 else 3

func _find_tile(sim, type: int, side: int) -> Vector2i:
	var center := Vector2i(SimConfig.HQ_MIN_TILE + 1, SimConfig.HQ_MIN_TILE + 1)
	# 안쪽부터 채우므로 파괴된 자리도 다음 판단에서 재건 후보가 된다.
	for radius in [5, 8, 11, 14]:
		for lateral in [0, -3, 3, -6, 6]:
			if absi(lateral) >= radius:
				continue
			var offset: Vector2i
			match side:
				0: offset = Vector2i(radius, lateral)
				1: offset = Vector2i(lateral, radius)
				2: offset = Vector2i(-radius, lateral)
				3: offset = Vector2i(lateral, -radius)
			var tile := center + offset
			if sim.can_place(type, tile.x, tile.y):
				return tile
	return Vector2i(-1, -1)
