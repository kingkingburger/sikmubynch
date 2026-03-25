extends BaseBuilding

var _attack_timer: float = 0.0
var _turret_mesh: MeshInstance3D
var _muzzle_flash: MeshInstance3D
var _muzzle_timer: float = 0.0
var projectile_scene: PackedScene
var _cached_buff_mult: float = 1.0
var _buff_cache_timer: float = 0.0
const BUFF_CACHE_INTERVAL := 2.0  # Recalculate buffs every 2 seconds

func _ready() -> void:
	super._ready()
	projectile_scene = load("res://scenes/projectiles/projectile.tscn")
	_setup_turret()

func _get_height() -> float:
	return 1.0

func _setup_turret() -> void:
	_turret_mesh = MeshInstance3D.new()
	var glb := BaseBuilding._load_glb("buildings", "tower_turret")
	if glb:
		_turret_mesh.mesh = glb
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.15
		cylinder.bottom_radius = 0.22
		cylinder.height = 0.35
		_turret_mesh.mesh = cylinder
	_turret_mesh.position = Vector3(0.0, 1.175, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.78, 0.25)
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.78, 0.25) * 0.3
	mat.emission_energy_multiplier = 1.0
	_turret_mesh.material_override = mat
	add_child(_turret_mesh)

	# Muzzle flash sphere (hidden by default)
	_muzzle_flash = MeshInstance3D.new()
	var flash_sphere := SphereMesh.new()
	flash_sphere.radius = 0.2
	flash_sphere.height = 0.4
	_muzzle_flash.mesh = flash_sphere
	_muzzle_flash.position = Vector3(0.0, 1.45, 0.0)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.3)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.85, 0.2)
	flash_mat.emission_energy_multiplier = 6.0
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_muzzle_flash.material_override = flash_mat
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)

func _process(delta: float) -> void:
	super._process(delta)
	if GameManager.is_game_over:
		return

	# Muzzle flash fade
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta * 8.0
		if _muzzle_timer <= 0.0:
			_muzzle_flash.visible = false
			_muzzle_timer = 0.0

	# Refresh buff cache periodically
	_buff_cache_timer -= delta
	if _buff_cache_timer <= 0.0:
		_buff_cache_timer = BUFF_CACHE_INTERVAL
		_cached_buff_mult = _calculate_buff_mult()

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		var target := _find_nearest_enemy()
		if target:
			_fire_at(target)
			_attack_timer = 1.0 / data.attack_speed
		else:
			_attack_timer = 0.1

func _find_nearest_enemy() -> Node3D:
	return SpatialGrid.find_nearest(global_position, "enemies", data.attack_range)

func _fire_at(target: Node3D) -> void:
	# Muzzle flash
	if _muzzle_flash:
		_muzzle_flash.visible = true
		_muzzle_timer = 1.0

	var projectile := projectile_scene.instantiate()
	projectile.position = Vector3(global_position.x, 1.35, global_position.z)
	projectile.target = target
	projectile.damage = GameFeel.roll_critical(_get_buffed_dps())
	# Pass synergy effects to projectile
	if data and data.trait_type >= 0:
		projectile.set("trait_effects", SynergyManager.get_special_effects(data.trait_type))
	get_parent().add_child(projectile)

func _get_buffed_dps() -> float:
	var base_dps := get_effective_dps()
	# Synergy bonus
	if data and data.trait_type >= 0:
		base_dps *= SynergyManager.get_dps_multiplier(data.trait_type)
	# Buff tower bonus — use cached value
	base_dps *= _cached_buff_mult
	return base_dps

func _calculate_buff_mult() -> float:
	var mult := 1.0
	var nearby_buildings := SpatialGrid.find_in_range(global_position, "buildings", 7.0)
	for b in nearby_buildings:
		if not b.has_method("get_buff_range"):
			continue
		var br: float = b.get_buff_range()
		if global_position.distance_squared_to(b.global_position) <= br * br:
			mult *= (1.0 + b.get_buff_multiplier())
	return mult
