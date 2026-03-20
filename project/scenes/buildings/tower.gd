extends BaseBuilding

var _attack_timer: float = 0.0
var _turret_mesh: MeshInstance3D
var projectile_scene: PackedScene

func _ready() -> void:
	super._ready()
	projectile_scene = load("res://scenes/projectiles/projectile.tscn")
	_setup_turret()

func _get_height() -> float:
	return 1.0

func _setup_turret() -> void:
	_turret_mesh = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.15
	cylinder.bottom_radius = 0.22
	cylinder.height = 0.35
	_turret_mesh.mesh = cylinder
	_turret_mesh.position = Vector3(0.0, 1.175, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.78, 0.25)
	mat.roughness = 0.5
	_turret_mesh.material_override = mat
	add_child(_turret_mesh)

func _process(delta: float) -> void:
	super._process(delta)
	if GameManager.is_game_over:
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		var target := _find_nearest_enemy()
		if target:
			_fire_at(target)
			_attack_timer = 1.0 / data.attack_speed
		else:
			_attack_timer = 0.1

func _find_nearest_enemy() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var nearest_dist := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= data.attack_range and dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _fire_at(target: Node3D) -> void:
	var projectile := projectile_scene.instantiate()
	projectile.position = Vector3(global_position.x, 1.35, global_position.z)
	projectile.target = target
	projectile.damage = get_effective_dps()
	get_parent().add_child(projectile)
