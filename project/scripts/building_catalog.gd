extends RefCounted

static func create() -> Array:
	var buildings: Array = []

	var barricade := BuildingData.new()
	barricade.building_name = "Barricade"
	barricade.cost = 10
	barricade.max_hp = 80.0
	barricade.size = Vector2i(1, 1)
	barricade.color = Color(0.55, 0.55, 0.58)
	buildings.append(barricade)

	var tower := BuildingData.new()
	tower.building_name = "Tower"
	tower.cost = 50
	tower.max_hp = 100.0
	tower.size = Vector2i(1, 1)
	tower.color = Color(0.35, 0.55, 0.75)
	tower.dps = 15.0
	tower.attack_range = 7.0
	tower.attack_speed = 1.0
	buildings.append(tower)

	var barracks := BuildingData.new()
	barracks.building_name = "Barracks"
	barracks.cost = 100
	barracks.max_hp = 200.0
	barracks.size = Vector2i(1, 1)
	barracks.color = Color(0.25, 0.4, 0.7)
	buildings.append(barracks)

	var miner := BuildingData.new()
	miner.building_name = "Miner"
	miner.cost = 80
	miner.max_hp = 60.0
	miner.size = Vector2i(1, 1)
	miner.color = Color(0.2, 0.7, 0.8)
	miner.mineral_per_sec = 2.0
	buildings.append(miner)

	var buff_tower := BuildingData.new()
	buff_tower.building_name = "Buff Tower"
	buff_tower.cost = 120
	buff_tower.max_hp = 100.0
	buff_tower.size = Vector2i(1, 1)
	buff_tower.color = Color(0.9, 0.8, 0.2)
	buff_tower.buff_range = 3.5
	buff_tower.buff_dps_mult = 0.2
	buildings.append(buff_tower)

	return buildings
