extends RefCounted

## 첫 프로토타입 적 카탈로그: 러셔, 탱크, 스플리터 + 분열 자식(MINI).
## 인덱스는 EnemyData.EnemyType과 같다.

static func create() -> Array:
	var list: Array = []

	var rusher := EnemyData.new()
	rusher.enemy_name = "Rusher"
	rusher.enemy_type = EnemyData.EnemyType.RUSHER
	rusher.max_hp = 25.0
	rusher.dps = 5.0
	rusher.speed = 3.5
	rusher.mineral_reward = 3
	rusher.color = Color(0.85, 0.2, 0.15)
	rusher.scale_factor = 1.0
	list.append(rusher)

	var tank := EnemyData.new()
	tank.enemy_name = "Tank"
	tank.enemy_type = EnemyData.EnemyType.TANK
	tank.max_hp = 140.0
	tank.dps = 14.0
	tank.speed = 1.8
	tank.mineral_reward = 8
	tank.color = Color(0.5, 0.35, 0.62)
	tank.scale_factor = 1.5
	list.append(tank)

	var splitter := EnemyData.new()
	splitter.enemy_name = "Splitter"
	splitter.enemy_type = EnemyData.EnemyType.SPLITTER
	splitter.max_hp = 40.0
	splitter.dps = 4.0
	splitter.speed = 3.0
	splitter.mineral_reward = 5
	splitter.color = Color(0.6, 0.85, 0.2)
	splitter.scale_factor = 1.15
	splitter.split_count = 2
	list.append(splitter)

	var mini := EnemyData.new()
	mini.enemy_name = "Mini"
	mini.enemy_type = EnemyData.EnemyType.MINI
	mini.max_hp = 12.0
	mini.dps = 2.0
	mini.speed = 3.8
	mini.mineral_reward = 1
	mini.color = Color(0.75, 0.95, 0.45)
	mini.scale_factor = 0.6
	list.append(mini)

	return list
