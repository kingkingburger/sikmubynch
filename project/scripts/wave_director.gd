extends RefCounted

const EARLY_WAVE_MAX := 3

static func enemy_count(wave_num: int, challenge_multiplier: float) -> int:
	var cycle_pos := (wave_num - 1) % 3
	var base_count := 30 + (wave_num - 1) * 8
	var count_multiplier: float = [0.7, 1.0, 1.4][cycle_pos]
	return int(base_count * count_multiplier * challenge_multiplier)

static func create_enemy_templates(wave_num: int) -> Array:
	var hp_scale := pow(1.30, wave_num - 1)
	var speed_scale := 1.0 + (wave_num - 1) * 0.03
	var dps_scale := 1.0 + (wave_num - 1) * 0.10
	var templates: Array = []

	var rusher := EnemyData.new()
	rusher.enemy_name = "Rusher"
	rusher.enemy_type = EnemyData.EnemyType.RUSHER
	rusher.max_hp = 25.0 * hp_scale
	rusher.dps = 8.0 * dps_scale
	rusher.speed = 3.5 * speed_scale
	rusher.mineral_reward = 3
	rusher.color = Color(0.85, 0.2, 0.15)
	templates.append(rusher)

	if wave_num >= 2:
		var splitter := EnemyData.new()
		splitter.enemy_name = "Splitter"
		splitter.enemy_type = EnemyData.EnemyType.SPLITTER
		splitter.max_hp = 40.0 * hp_scale
		splitter.dps = 6.0 * dps_scale
		splitter.speed = 3.0 * speed_scale
		splitter.mineral_reward = 5
		splitter.color = Color(0.6, 0.85, 0.2)
		splitter.split_count = 2
		templates.append(splitter)

	if wave_num >= 3:
		var tank := EnemyData.new()
		tank.enemy_name = "Tank"
		tank.enemy_type = EnemyData.EnemyType.TANK
		tank.max_hp = 120.0 * hp_scale
		tank.dps = 14.0 * dps_scale
		tank.speed = 1.8 * speed_scale
		tank.mineral_reward = 8
		tank.color = Color(0.5, 0.35, 0.6)
		tank.scale_factor = 1.4
		templates.append(tank)

	if wave_num >= 4:
		var exploder := EnemyData.new()
		exploder.enemy_name = "Exploder"
		exploder.enemy_type = EnemyData.EnemyType.EXPLODER
		exploder.max_hp = 20.0 * hp_scale
		exploder.dps = 4.0 * dps_scale
		exploder.speed = 4.5 * speed_scale
		exploder.mineral_reward = 4
		exploder.color = Color(1.0, 0.6, 0.1)
		exploder.explode_radius = 2.5
		exploder.explode_damage = 35.0 + wave_num * 8.0
		templates.append(exploder)

	if wave_num >= 5:
		var elite := EnemyData.new()
		elite.enemy_name = "Elite Rusher"
		elite.enemy_type = EnemyData.EnemyType.ELITE_RUSHER
		elite.max_hp = 60.0 * hp_scale
		elite.dps = 18.0 * dps_scale
		elite.speed = 4.5 * speed_scale
		elite.mineral_reward = 6
		elite.color = Color(0.95, 0.15, 0.3)
		elite.scale_factor = 1.15
		templates.append(elite)

	if wave_num >= 6:
		var destroyer := EnemyData.new()
		destroyer.enemy_name = "Destroyer"
		destroyer.enemy_type = EnemyData.EnemyType.DESTROYER
		destroyer.max_hp = 180.0 * hp_scale
		destroyer.dps = 25.0 * dps_scale
		destroyer.speed = 1.5 * speed_scale
		destroyer.mineral_reward = 12
		destroyer.color = Color(0.3, 0.1, 0.4)
		destroyer.scale_factor = 1.6
		templates.append(destroyer)

	return templates

static func spawn_position(wave_num: int, map_size: int, hq_center: Vector2) -> Vector2:
	if wave_num <= EARLY_WAVE_MAX:
		var radius := 20.0 + float(wave_num - 1) * 10.0 + randf_range(-4.0, 5.0)
		var angle := randf() * TAU
		var pos := hq_center + Vector2(cos(angle), sin(angle)) * radius
		return Vector2(
			clampf(pos.x, 4.0, float(map_size) - 4.0),
			clampf(pos.y, 4.0, float(map_size) - 4.0)
		)
	return _random_edge_position(map_size)

static func _random_edge_position(map_size: int) -> Vector2:
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(1.0, map_size - 1.0), -1.0)
		1: return Vector2(float(map_size) + 1.0, randf_range(1.0, map_size - 1.0))
		2: return Vector2(randf_range(1.0, map_size - 1.0), float(map_size) + 1.0)
		3: return Vector2(-1.0, randf_range(1.0, map_size - 1.0))
	return Vector2.ZERO
