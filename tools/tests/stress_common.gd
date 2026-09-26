extends RefCounted

## 물량 스트레스 도구(stress_scale.gd, render_stress.gd)가 같이 쓰는 배치와 설정 읽기.

const SimConfig := preload("res://sim/sim_config.gd")

const RING_TOWERS := [
	BuildingData.BuildingType.GUN_TOWER, BuildingData.BuildingType.CANNON_TOWER,
	BuildingData.BuildingType.FROST_TOWER, BuildingData.BuildingType.FLAME_TOWER,
	BuildingData.BuildingType.TESLA_TOWER, BuildingData.BuildingType.SNIPER_TOWER,
]

## 본진 주변 반지름 8·11·14 링의 타워 후보 [type, Vector2i]. 적이 방어선에 닿아 전투가 계속 일어나는 배치.
## place(type, tile) -> bool 로 실제 배치하고, 성공할 때만 다음 타입으로 넘어간다. 배치한 수를 반환한다.
static func build_ring(place: Callable) -> int:
	var k := 0
	for r in [8, 11, 14]:
		for a in range(0, 360, 12):
			var tile := Vector2i(
				int(round(SimConfig.HQ_CENTER.x + cos(deg_to_rad(a)) * r)),
				int(round(SimConfig.HQ_CENTER.y + sin(deg_to_rad(a)) * r)))
			if place.call(RING_TOWERS[k % RING_TOWERS.size()], tile):
				k += 1
	return k

## "1000,2000,5000" 형식 환경 변수. 없으면 기본값
static func env_counts(name: String, fallback: Array) -> Array:
	var v := OS.get_environment(name)
	if v == "":
		return fallback
	return Array(v.split(",")).map(func(s): return int(s))

static func env_int(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback
