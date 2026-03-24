extends CharacterBody3D

signal died()

enum State { PATROL, CHASE, ATTACK, DEAD }

var data: UnitData
var current_hp: float
var spawn_origin: Vector3

var _state: int = State.PATROL
var _attack_timer: float = 0.0
var _patrol_target: Vector3
var _chase_target: Node3D = null

var _mesh_instance: MeshInstance3D
var _body_mat: StandardMaterial3D
var _hp_bar_fill: MeshInstance3D
var _flash: float = 0.0

var projectile_scene: PackedScene

const DETECTION_RANGE := 10.0
const PATROL_RADIUS := 5.0
const BOMBER_EXPLODE_RANGE := 1.5
const BOMBER_AOE_RADIUS := 3.0

func _ready() -> void:
	add_to_group("units")
	if data:
		current_hp = data.max_hp
	spawn_origin = global_position
	_patrol_target = _random_patrol_point()
	_build_mesh()
	if data and data.unit_type == UnitData.UnitType.ARCHER:
		projectile_scene = load("res://scenes/projectiles/projectile.tscn")
	SpatialGrid.register(self, "units")

func _build_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	var unit_type: int = data.unit_type if data else UnitData.UnitType.SOLDIER

	var _utype_names := {
		UnitData.UnitType.SOLDIER: "soldier",
		UnitData.UnitType.ARCHER: "archer",
		UnitData.UnitType.TANKER: "tanker",
		UnitData.UnitType.BOMBER: "bomber",
	}
	var uname: String = _utype_names.get(unit_type, "soldier")
	var glb: Mesh = BaseBuilding._load_glb("units", uname)

	if glb:
		_mesh_instance.mesh = glb
		match unit_type:
			UnitData.UnitType.SOLDIER: _mesh_instance.position = Vector3(0.0, 0.3, 0.0)
			UnitData.UnitType.ARCHER: _mesh_instance.position = Vector3(0.0, 0.33, 0.0)
			UnitData.UnitType.TANKER: _mesh_instance.position = Vector3(0.0, 0.28, 0.0)
			UnitData.UnitType.BOMBER: _mesh_instance.position = Vector3(0.0, 0.25, 0.0)
			_: _mesh_instance.position = Vector3(0.0, 0.28, 0.0)
	else:
		# Fallback: primitive meshes
		match unit_type:
			UnitData.UnitType.SOLDIER:
				var capsule := CapsuleMesh.new()
				capsule.radius = 0.2
				capsule.height = 0.6
				_mesh_instance.mesh = capsule
				_mesh_instance.position = Vector3(0.0, 0.3, 0.0)
			UnitData.UnitType.ARCHER:
				var capsule := CapsuleMesh.new()
				capsule.radius = 0.15
				capsule.height = 0.65
				_mesh_instance.mesh = capsule
				_mesh_instance.position = Vector3(0.0, 0.33, 0.0)
			UnitData.UnitType.TANKER:
				var box := BoxMesh.new()
				box.size = Vector3(0.5, 0.55, 0.4)
				_mesh_instance.mesh = box
				_mesh_instance.position = Vector3(0.0, 0.28, 0.0)
			UnitData.UnitType.BOMBER:
				var sphere := SphereMesh.new()
				sphere.radius = 0.25
				sphere.height = 0.5
				sphere.radial_segments = 8
				_mesh_instance.mesh = sphere
				_mesh_instance.position = Vector3(0.0, 0.25, 0.0)
			_:
				var capsule := CapsuleMesh.new()
				capsule.radius = 0.2
				capsule.height = 0.55
				_mesh_instance.mesh = capsule
				_mesh_instance.position = Vector3(0.0, 0.28, 0.0)

	_body_mat = StandardMaterial3D.new()
	var c: Color = data.color if data else Color.BLUE
	_body_mat.albedo_color = c
	_body_mat.roughness = 0.5
	_body_mat.emission_enabled = true
	_body_mat.emission = c * 0.3
	_body_mat.emission_energy_multiplier = 1.2
	_mesh_instance.material_override = _body_mat
	add_child(_mesh_instance)

	# Ground shadow
	var shadow := MeshInstance3D.new()
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(0.5, 0.5)
	shadow.mesh = shadow_quad
	shadow.rotation_degrees.x = -90.0
	shadow.position = Vector3(0.0, 0.02, 0.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_mat
	add_child(shadow)

	# Collision
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 0.55
	col.shape = shape
	col.position = Vector3(0.0, 0.28, 0.0)
	add_child(col)

	# HP bar bg
	var hp_bg := MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.45, 0.04, 0.07)
	hp_bg.mesh = bg_box
	hp_bg.position = Vector3(0.0, 0.6, 0.0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_bg.material_override = bg_mat
	add_child(hp_bg)

	# HP bar fill
	_hp_bar_fill = MeshInstance3D.new()
	var fill_box := BoxMesh.new()
	fill_box.size = Vector3(0.45, 0.05, 0.07)
	_hp_bar_fill.mesh = fill_box
	_hp_bar_fill.position = Vector3(0.0, 0.61, 0.0)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2, 0.6, 0.95)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_fill.material_override = fill_mat
	add_child(_hp_bar_fill)

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over or _state == State.DEAD:
		return

	if _flash > 0.0:
		_flash -= delta * 5.0
		if _flash < 0.0:
			_flash = 0.0
		_update_flash()

	match _state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	_update_hp_bar()

# -- State: PATROL --
func _process_patrol(delta: float) -> void:
	# Check for enemies
	var enemy := _find_nearest_enemy()
	if enemy:
		_chase_target = enemy
		_state = State.CHASE
		return

	# Move to patrol point
	var to_target := _patrol_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.5:
		_patrol_target = _random_patrol_point()
		return

	velocity = to_target.normalized() * data.speed * 0.6
	move_and_slide()

# -- State: CHASE --
func _process_chase(delta: float) -> void:
	if not is_instance_valid(_chase_target) or _chase_target.get("_dead"):
		_chase_target = null
		_state = State.PATROL
		return

	var dist := global_position.distance_to(_chase_target.global_position)

	# Bomber: explode when close
	if data.unit_type == UnitData.UnitType.BOMBER:
		if dist <= BOMBER_EXPLODE_RANGE:
			_bomber_explode()
			return

	# In attack range
	if dist <= data.attack_range:
		_state = State.ATTACK
		_attack_timer = 0.0
		return

	# Move toward enemy
	var dir := (_chase_target.global_position - global_position).normalized()
	dir.y = 0.0
	velocity = dir * data.speed
	move_and_slide()

# -- State: ATTACK --
func _process_attack(delta: float) -> void:
	if not is_instance_valid(_chase_target) or _chase_target.get("_dead"):
		_chase_target = null
		_state = State.PATROL
		return

	var dist := global_position.distance_to(_chase_target.global_position)
	if dist > data.attack_range * 1.3:
		_state = State.CHASE
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_perform_attack()
		_attack_timer = 1.0

func _perform_attack() -> void:
	if not is_instance_valid(_chase_target):
		return
	_flash = 1.0
	_update_flash()

	var dmg := data.dps * (1.0 + EventManager.get_unit_dps_perm_bonus())
	if data.unit_type == UnitData.UnitType.ARCHER:
		_fire_projectile(dmg)
	else:
		# Melee attack
		if _chase_target.has_method("take_damage"):
			_chase_target.take_damage(dmg)

func _fire_projectile(dmg: float) -> void:
	if not projectile_scene or not is_instance_valid(_chase_target):
		return
	var proj := projectile_scene.instantiate()
	proj.position = Vector3(global_position.x, 0.5, global_position.z)
	proj.target = _chase_target
	proj.damage = dmg
	get_parent().add_child(proj)

func _bomber_explode() -> void:
	var nearby := SpatialGrid.find_in_range(global_position, "enemies", BOMBER_AOE_RADIUS)
	for enemy in nearby:
		if enemy.has_method("take_damage"):
			enemy.take_damage(data.dps)
	_die()

# -- Utility --
func _find_nearest_enemy() -> Node3D:
	return SpatialGrid.find_nearest(global_position, "enemies", DETECTION_RANGE)

func _random_patrol_point() -> Vector3:
	var offset := Vector3(
		randf_range(-PATROL_RADIUS, PATROL_RADIUS),
		0.0,
		randf_range(-PATROL_RADIUS, PATROL_RADIUS)
	)
	var point := spawn_origin + offset
	point.x = clampf(point.x, 1.0, 63.0)
	point.z = clampf(point.z, 1.0, 63.0)
	point.y = 0.0
	return point

# -- Damage & Death --
func _update_flash() -> void:
	if _body_mat and data:
		if _flash > 0.0:
			_body_mat.albedo_color = data.color.lerp(Color(1.0, 1.0, 1.0), _flash * 0.5)
		else:
			_body_mat.albedo_color = data.color

func _update_hp_bar() -> void:
	if not data or not _hp_bar_fill:
		return
	var hp_ratio: float = clampf(current_hp / data.max_hp, 0.0, 1.0)
	var full_width: float = 0.45
	var fill_width: float = full_width * hp_ratio
	var fill_mesh := _hp_bar_fill.mesh as BoxMesh
	if fill_mesh:
		fill_mesh.size = Vector3(maxf(fill_width, 0.01), 0.05, 0.07)
	_hp_bar_fill.position.x = (fill_width - full_width) / 2.0
	var fill_mat := _hp_bar_fill.material_override as StandardMaterial3D
	if fill_mat:
		fill_mat.albedo_color = Color(0.2, 0.6, 0.95) if hp_ratio > 0.5 else Color(0.9, 0.4, 0.15)

func take_damage(amount: float) -> void:
	if _state == State.DEAD:
		return
	current_hp -= amount
	_flash = 1.0
	_update_flash()
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	SpatialGrid.unregister(self, "units")
	died.emit()
	queue_free()
