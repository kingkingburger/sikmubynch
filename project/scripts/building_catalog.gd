extends RefCounted

## 첫 프로토타입 건물 카탈로그: HQ, 방어물 2종, 타워 6종.
## 인덱스는 BuildingData.BuildingType과 같다.
## 비용은 "계속 짓는 손맛"이 나도록 낮게 잡고, 부족함은 지켜야 할 방향 수에서 나오게 한다.

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
	barricade.cost = 8
	barricade.max_hp = 120.0
	barricade.color = Color(0.55, 0.55, 0.58)
	barricade.height = 0.35
	list.append(barricade)

	var wall := BuildingData.new()
	wall.building_name = "Wall"
	wall.building_type = BuildingData.BuildingType.WALL
	wall.cost = 25
	wall.max_hp = 500.0
	wall.color = Color(0.36, 0.34, 0.38)
	wall.height = 0.6
	list.append(wall)

	var gun := BuildingData.new()
	gun.building_name = "Gun Tower"
	gun.building_type = BuildingData.BuildingType.GUN_TOWER
	gun.cost = 30
	gun.max_hp = 100.0
	gun.color = Color(0.85, 0.7, 0.25)
	gun.height = 1.0
	gun.damage = 7.0
	gun.attack_rate = 4.0
	gun.attack_range = 7.0
	gun.attack_mode = BuildingData.AttackMode.PROJECTILE
	gun.projectile_kind = BuildingData.ProjectileKind.BULLET
	gun.projectile_speed = 30.0
	list.append(gun)

	var cannon := BuildingData.new()
	cannon.building_name = "Cannon"
	cannon.building_type = BuildingData.BuildingType.CANNON_TOWER
	cannon.cost = 90
	cannon.max_hp = 130.0
	cannon.color = Color(0.9, 0.42, 0.18)
	cannon.height = 1.1
	cannon.damage = 45.0
	cannon.attack_rate = 0.6
	cannon.attack_range = 9.5
	cannon.splash_radius = 2.2
	cannon.attack_mode = BuildingData.AttackMode.PROJECTILE
	cannon.projectile_kind = BuildingData.ProjectileKind.SHELL
	cannon.projectile_speed = 13.0
	list.append(cannon)

	var frost := BuildingData.new()
	frost.building_name = "Frost Tower"
	frost.building_type = BuildingData.BuildingType.FROST_TOWER
	frost.cost = 60
	frost.max_hp = 100.0
	frost.color = Color(0.35, 0.75, 0.95)
	frost.height = 0.95
	frost.damage = 3.0
	frost.attack_rate = 1.2
	frost.attack_range = 6.0
	frost.slow_amount = 0.55
	frost.slow_duration = 2.0
	frost.slow_radius = 1.8
	frost.attack_mode = BuildingData.AttackMode.PROJECTILE
	frost.projectile_kind = BuildingData.ProjectileKind.FROST
	frost.projectile_speed = 18.0
	list.append(frost)

	var flame := BuildingData.new()
	flame.building_name = "Flame Tower"
	flame.building_type = BuildingData.BuildingType.FLAME_TOWER
	flame.cost = 70
	flame.max_hp = 110.0
	flame.color = Color(0.95, 0.35, 0.1)
	flame.height = 0.9
	flame.damage = 4.0            # 반경 안 전부, 초당 5회 → 20 dps 광역
	flame.attack_rate = 5.0
	flame.attack_range = 3.6
	flame.attack_mode = BuildingData.AttackMode.AREA
	list.append(flame)

	var tesla := BuildingData.new()
	tesla.building_name = "Tesla Tower"
	tesla.building_type = BuildingData.BuildingType.TESLA_TOWER
	tesla.cost = 100
	tesla.max_hp = 100.0
	tesla.color = Color(0.55, 0.45, 1.0)
	tesla.height = 1.2
	tesla.damage = 18.0
	tesla.attack_rate = 1.5
	tesla.attack_range = 6.5
	tesla.attack_mode = BuildingData.AttackMode.CHAIN
	tesla.chain_count = 7
	tesla.chain_radius = 2.6
	list.append(tesla)

	var sniper := BuildingData.new()
	sniper.building_name = "Sniper Tower"
	sniper.building_type = BuildingData.BuildingType.SNIPER_TOWER
	sniper.cost = 110
	sniper.max_hp = 90.0
	sniper.color = Color(0.4, 0.85, 0.55)
	sniper.height = 1.5
	sniper.damage = 140.0
	sniper.attack_rate = 0.5
	sniper.attack_range = 14.0
	sniper.attack_mode = BuildingData.AttackMode.BEAM
	sniper.beam_width = 0.45
	sniper.prefer_high_hp = true
	list.append(sniper)

	return list

## 플레이어가 고를 수 있는 건물 (HQ 제외). 핫키 1~8 순서.
static func buildable_types() -> Array:
	return [
		BuildingData.BuildingType.BARRICADE,
		BuildingData.BuildingType.WALL,
		BuildingData.BuildingType.GUN_TOWER,
		BuildingData.BuildingType.CANNON_TOWER,
		BuildingData.BuildingType.FROST_TOWER,
		BuildingData.BuildingType.FLAME_TOWER,
		BuildingData.BuildingType.TESLA_TOWER,
		BuildingData.BuildingType.SNIPER_TOWER,
	]
