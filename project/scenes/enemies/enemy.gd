extends CharacterBody3D

signal died()
signal drop_mineral(pos: Vector3, amount: int)

var data: EnemyData
var current_hp: float
var target_position: Vector3
var flow_field: Dictionary = {}

var _dead: bool = false
var _attack_target: BaseBuilding = null
var _attack_timer: float = 0.0

# Status effects
var _burn_dps: float = 0.0
var _burn_timer: float = 0.0
var _slow_mult: float = 1.0
var _slow_timer: float = 0.0
var _poison_dps: float = 0.0
var _poison_timer: float = 0.0
var _stun_timer: float = 0.0
var _mesh_instance: MeshInstance3D
var _body_mat: StandardMaterial3D
var _hp_bar_fill: MeshInstance3D
var _attack_flash: float = 0.0

var _last_grid_pos: Vector3

func _ready() -> void:
	add_to_group("enemies")
	if data:
		current_hp = data.max_hp
	_build_mesh()
	_last_grid_pos = global_position
	SpatialGrid.register(self, "enemies")

func _build_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	var sf: float = data.scale_factor if data else 1.0
	var shadow_size := 0.6 * sf

	# GLB model names per enemy type
	var _type_names := {
		EnemyData.EnemyType.RUSHER: "rusher",
		EnemyData.EnemyType.TANK: "tank",
		EnemyData.EnemyType.SPLITTER: "splitter",
		EnemyData.EnemyType.EXPLODER: "exploder",
		EnemyData.EnemyType.ELITE_RUSHER: "elite_rusher",
		EnemyData.EnemyType.DESTROYER: "destroyer",
	}
	var etype: int = data.enemy_type if data else EnemyData.EnemyType.RUSHER
	var glb_name: String = _type_names.get(etype, "rusher")
	var glb: Mesh = BaseBuilding._load_glb("enemies", glb_name)

	if glb:
		_mesh_instance.mesh = glb
		_mesh_instance.scale = Vector3(sf, sf, sf)
		# Position defaults per type
		match etype:
			EnemyData.EnemyType.RUSHER: _mesh_instance.position = Vector3(0.0, 0.15 * sf, 0.0); shadow_size = 0.5 * sf
			EnemyData.EnemyType.TANK: _mesh_instance.position = Vector3(0.0, 0.28 * sf, 0.0); shadow_size = 0.8 * sf
			EnemyData.EnemyType.SPLITTER: _mesh_instance.position = Vector3(0.0, 0.22 * sf, 0.0); shadow_size = 0.5 * sf
			EnemyData.EnemyType.EXPLODER: _mesh_instance.position = Vector3(0.0, 0.35 * sf, 0.0); shadow_size = 0.6 * sf
			EnemyData.EnemyType.DESTROYER: _mesh_instance.position = Vector3(0.0, 0.45 * sf, 0.0); shadow_size = 1.1 * sf
			_: _mesh_instance.position = Vector3(0.0, 0.3 * sf, 0.0); shadow_size = 0.55 * sf
	else:
		# Fallback: primitive meshes
		match etype:
			EnemyData.EnemyType.RUSHER:
				var prism := PrismMesh.new()
				prism.size = Vector3(0.35, 0.3, 0.5) * sf
				_mesh_instance.mesh = prism
				_mesh_instance.position = Vector3(0.0, 0.15 * sf, 0.0)
				shadow_size = 0.5 * sf
			EnemyData.EnemyType.TANK:
				var box := BoxMesh.new()
				box.size = Vector3(0.6, 0.55, 0.6) * sf
				_mesh_instance.mesh = box
				_mesh_instance.position = Vector3(0.0, 0.28 * sf, 0.0)
				shadow_size = 0.8 * sf
			EnemyData.EnemyType.SPLITTER:
				var prism := PrismMesh.new()
				prism.size = Vector3(0.4, 0.45, 0.4) * sf
				_mesh_instance.mesh = prism
				_mesh_instance.position = Vector3(0.0, 0.22 * sf, 0.0)
				shadow_size = 0.5 * sf
			EnemyData.EnemyType.EXPLODER:
				var sphere := SphereMesh.new()
				sphere.radius = 0.35 * sf
				sphere.height = 0.7 * sf
				sphere.radial_segments = 6
				sphere.rings = 3
				_mesh_instance.mesh = sphere
				_mesh_instance.position = Vector3(0.0, 0.35 * sf, 0.0)
				shadow_size = 0.6 * sf
			EnemyData.EnemyType.DESTROYER:
				var box := BoxMesh.new()
				box.size = Vector3(0.8, 0.9, 0.8) * sf
				_mesh_instance.mesh = box
				_mesh_instance.position = Vector3(0.0, 0.45 * sf, 0.0)
				shadow_size = 1.1 * sf
			_:
				var sphere := SphereMesh.new()
				sphere.radius = 0.3 * sf
				sphere.height = 0.6 * sf
				_mesh_instance.mesh = sphere
				_mesh_instance.position = Vector3(0.0, 0.3 * sf, 0.0)
				shadow_size = 0.55 * sf

	_body_mat = StandardMaterial3D.new()
	var c: Color = data.color if data else Color.RED
	_body_mat.albedo_color = c
	_body_mat.roughness = 0.5
	_body_mat.emission_enabled = true
	_body_mat.emission = c * 0.5
	_body_mat.emission_energy_multiplier = 1.8
	_mesh_instance.material_override = _body_mat
	add_child(_mesh_instance)

	# Ground shadow
	var shadow := MeshInstance3D.new()
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(shadow_size, shadow_size)
	shadow.mesh = shadow_quad
	shadow.rotation_degrees.x = -90.0
	shadow.position = Vector3(0.0, 0.02, 0.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.4)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_mat
	add_child(shadow)

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3 * sf
	col.shape = shape
	col.position = Vector3(0.0, 0.3 * sf, 0.0)
	add_child(col)

	# HP bar background
	var hp_bg := MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.5, 0.04, 0.08)
	hp_bg.mesh = bg_box
	hp_bg.position = Vector3(0.0, 0.55 * sf + 0.15, 0.0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_bg.material_override = bg_mat
	add_child(hp_bg)

	# HP bar fill
	_hp_bar_fill = MeshInstance3D.new()
	var fill_box := BoxMesh.new()
	fill_box.size = Vector3(0.5, 0.05, 0.08)
	_hp_bar_fill.mesh = fill_box
	_hp_bar_fill.position = Vector3(0.0, 0.55 * sf + 0.16, 0.0)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.15, 0.85, 0.2)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_fill.material_override = fill_mat
	add_child(_hp_bar_fill)

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over or _dead:
		return

	if _attack_flash > 0.0:
		_attack_flash -= delta * 5.0
		if _attack_flash < 0.0:
			_attack_flash = 0.0
		_update_flash()

	# Status effect ticks
	if _burn_timer > 0.0:
		_burn_timer -= delta
		take_damage(_burn_dps * delta)
		if _burn_timer <= 0.0:
			_burn_dps = 0.0
	if _poison_timer > 0.0:
		_poison_timer -= delta
		take_damage(_poison_dps * delta)
		if _poison_timer <= 0.0:
			_poison_dps = 0.0
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_mult = 1.0
	if _stun_timer > 0.0:
		_stun_timer -= delta
		return  # Stunned - skip all movement/attack

	# Exploder: check proximity to buildings for self-destruct (every 5 frames)
	if data and data.enemy_type == EnemyData.EnemyType.EXPLODER:
		if Engine.get_physics_frames() % 5 == hash(get_instance_id()) % 5:
			if _check_explode_proximity():
				return

	if _attack_target:
		if not is_instance_valid(_attack_target):
			_attack_target = null
		else:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				var dmg := data.dps * EventManager.get_enemy_dps_mult()
				# Destroyer does 2x damage to buildings
				if data.enemy_type == EnemyData.EnemyType.DESTROYER:
					dmg *= 2.0
				_attack_target.take_damage(dmg, self)
				_attack_timer = 1.0
				_attack_flash = 1.0
				_update_flash()
			return

	# Movement - use flow field if available, otherwise direct path
	var dir := _get_move_direction()
	velocity = dir * data.speed * EventManager.get_enemy_speed_mult() * _slow_mult
	var old_pos := global_position
	var collision := move_and_collide(velocity * delta)
	SpatialGrid.update_position(self, old_pos, "enemies")

	if collision:
		var collider := collision.get_collider()
		if collider is BaseBuilding:
			_attack_target = collider as BaseBuilding
			_attack_timer = 0.0
			velocity = Vector3.ZERO

func _get_move_direction() -> Vector3:
	if not flow_field.is_empty():
		var gx := int(floor(global_position.x))
		var gz := int(floor(global_position.z))
		var cell := Vector2i(gx, gz)
		if flow_field.has(cell):
			var flow_dir: Vector2 = flow_field[cell]
			return Vector3(flow_dir.x, 0.0, flow_dir.y).normalized()
	# Fallback: direct path to target
	var my_pos := Vector3(global_position.x, 0.0, global_position.z)
	var tgt := Vector3(target_position.x, 0.0, target_position.z)
	return (tgt - my_pos).normalized()

func _check_explode_proximity() -> bool:
	if SpatialGrid.has_any_in_range(global_position, "buildings", 1.5):
		_explode()
		return true
	return false

func _explode() -> void:
	var radius := data.explode_radius
	var dmg := data.explode_damage

	for building in SpatialGrid.find_in_range(global_position, "buildings", radius):
		if building.has_method("take_damage"):
			building.take_damage(dmg)

	for unit in SpatialGrid.find_in_range(global_position, "units", radius):
		if unit.has_method("take_damage"):
			unit.take_damage(dmg)

	_die()

func _update_flash() -> void:
	if _body_mat and data:
		if _attack_flash > 0.0:
			_body_mat.albedo_color = data.color.lerp(Color(1.0, 0.8, 0.0), _attack_flash * 0.6)
		else:
			_body_mat.albedo_color = data.color

func _update_hp_bar() -> void:
	if not data or not _hp_bar_fill:
		return
	var hp_ratio: float = clampf(current_hp / data.max_hp, 0.0, 1.0)
	var full_width: float = 0.5
	var fill_width: float = full_width * hp_ratio
	var fill_mesh := _hp_bar_fill.mesh as BoxMesh
	if fill_mesh:
		fill_mesh.size = Vector3(maxf(fill_width, 0.01), 0.05, 0.08)
	_hp_bar_fill.position.x = (fill_width - full_width) / 2.0
	var fill_mat := _hp_bar_fill.material_override as StandardMaterial3D
	if fill_mat:
		fill_mat.albedo_color = Color(0.15, 0.85, 0.2) if hp_ratio > 0.5 else Color(0.9, 0.3, 0.1)

func apply_burn(dps: float, duration: float = 3.0) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_timer = maxf(_burn_timer, duration)

func apply_slow(mult: float, duration: float = 2.0) -> void:
	_slow_mult = minf(_slow_mult, 1.0 - mult)
	_slow_timer = maxf(_slow_timer, duration)

func apply_poison(dps: float, duration: float = 4.0) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_timer = maxf(_poison_timer, duration)

func apply_stun(duration: float = 0.5) -> void:
	_stun_timer = maxf(_stun_timer, duration)

func take_damage(amount: float) -> void:
	if _dead:
		return
	current_hp -= amount
	_update_hp_bar()
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	SpatialGrid.unregister(self, "enemies")

	# Poison spread on death
	if _poison_dps > 0.0 and _poison_timer > 0.0:
		var nearby := SpatialGrid.find_in_range(global_position, "enemies", 3.0)
		for enemy in nearby:
			if enemy == self:
				continue
			if enemy.has_method("apply_poison"):
				enemy.apply_poison(_poison_dps * 0.6, 3.0)

	# Splitter: spawn smaller enemies
	if data and data.enemy_type == EnemyData.EnemyType.SPLITTER:
		_spawn_splits()

	# Mineral orb handled by game.gd via drop_mineral signal
	if drop_mineral.get_connections().size() > 0:
		drop_mineral.emit(global_position, data.mineral_reward if data else 3)
	else:
		# Fallback for split spawns not connected to game.gd
		GameManager.add_minerals(data.mineral_reward if data else 3)
	GameManager.add_kill()
	died.emit()
	queue_free()

func _spawn_splits() -> void:
	var split_data := EnemyData.new()
	split_data.enemy_name = "Mini Splitter"
	split_data.enemy_type = EnemyData.EnemyType.RUSHER
	split_data.max_hp = data.max_hp * 0.3
	split_data.dps = data.dps * 0.5
	split_data.speed = data.speed * 1.2
	split_data.mineral_reward = 1
	split_data.color = data.color.lightened(0.3)
	split_data.scale_factor = 0.6

	var enemy_scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var parent := get_parent()
	for i in data.split_count:
		var mini: CharacterBody3D = enemy_scene.instantiate()
		mini.set("data", split_data)
		mini.set("target_position", target_position)
		mini.set("flow_field", flow_field)
		var offset := Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
		mini.position = global_position + offset
		# Connect signals to game.gd (parent) so splits are tracked
		if parent.has_method("_on_enemy_died"):
			mini.connect("died", parent._on_enemy_died)
		if parent.has_method("_on_enemy_drop_mineral") and mini.has_signal("drop_mineral"):
			mini.connect("drop_mineral", parent._on_enemy_drop_mineral)
		parent.call_deferred("add_child", mini)
