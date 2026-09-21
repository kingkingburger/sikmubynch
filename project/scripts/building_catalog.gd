extends RefCounted

## 첫 프로토타입 건물 카탈로그: HQ, 방어물 2종, 타워 3종.
## 인덱스는 BuildingData.BuildingType과 같다.

static func create() -> Array:
	var list: Array = []

	var hq := BuildingData.new()
	hq.building_name = "HQ"
	hq.building_type = BuildingData.BuildingType.HQ
	hq.cost = 0
	hq.max_hp = 2500.0
	hq.size = 3
	hq.color = Color(0.25, 0.45, 0.85)
	hq.height = 1.6
	list.append(hq)

	var barricade := BuildingData.new()
	barricade.building_name = "Barricade"
	barricade.building_type = BuildingData.BuildingType.BARRICADE
	barricade.cost = 10
	barricade.max_hp = 120.0
	barricade.color = Color(0.55, 0.55, 0.58)
	barricade.height = 0.35
	list.append(barricade)

	var wall := BuildingData.new()
	wall.building_name = "Wall"
	wall.building_type = BuildingData.BuildingType.WALL
	wall.cost = 35
	wall.max_hp = 500.0
	wall.color = Color(0.36, 0.34, 0.38)
	wall.height = 0.6
	list.append(wall)

	var gun := BuildingData.new()
	gun.building_name = "Gun Tower"
	gun.building_type = BuildingData.BuildingType.GUN_TOWER
	gun.cost = 50
	gun.max_hp = 100.0
	gun.color = Color(0.85, 0.7, 0.25)
	gun.height = 1.0
	gun.damage = 7.0
	gun.attack_rate = 4.0
	gun.attack_range = 7.0
	gun.projectile_kind = BuildingData.ProjectileKind.BULLET
	gun.projectile_speed = 26.0
	list.append(gun)

	var cannon := BuildingData.new()
	cannon.building_name = "Cannon"
	cannon.building_type = BuildingData.BuildingType.CANNON_TOWER
	cannon.cost = 120
	cannon.max_hp = 130.0
	cannon.color = Color(0.9, 0.42, 0.18)
	cannon.height = 1.1
	cannon.damage = 45.0
	cannon.attack_rate = 0.6
	cannon.attack_range = 9.5
	cannon.splash_radius = 2.2
	cannon.projectile_kind = BuildingData.ProjectileKind.SHELL
	cannon.projectile_speed = 13.0
	list.append(cannon)

	var frost := BuildingData.new()
	frost.building_name = "Frost Tower"
	frost.building_type = BuildingData.BuildingType.FROST_TOWER
	frost.cost = 80
	frost.max_hp = 100.0
	frost.color = Color(0.35, 0.75, 0.95)
	frost.height = 0.95
	frost.damage = 3.0
	frost.attack_rate = 1.2
	frost.attack_range = 6.0
	frost.slow_amount = 0.55
	frost.slow_duration = 2.0
	frost.slow_radius = 1.8
	frost.projectile_kind = BuildingData.ProjectileKind.FROST
	frost.projectile_speed = 18.0
	list.append(frost)

	return list

## 플레이어가 고를 수 있는 건물 (HQ 제외). 핫키 1~5 순서.
static func buildable_types() -> Array:
	return [
		BuildingData.BuildingType.BARRICADE,
		BuildingData.BuildingType.GUN_TOWER,
		BuildingData.BuildingType.CANNON_TOWER,
		BuildingData.BuildingType.FROST_TOWER,
		BuildingData.BuildingType.WALL,
	]
