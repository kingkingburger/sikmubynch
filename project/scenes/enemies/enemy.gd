extends CharacterBody3D

signal died()
signal drop_mineral(pos: Vector3, amount: int)

const _enemy_scene_preload: PackedScene = preload("res://scenes/enemies/enemy.tscn")

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

# Visual
var _body_pivot: Node3D
var _mesh_instance: MeshInstance3D
var _detail_mesh: MeshInstance3D
var _body_mat: StandardMaterial3D
var _hp_bar_fill: MeshInstance3D
var _hp_bar_bg: MeshInstance3D
var _shadow: MeshInstance3D
var _attack_flash: float = 0.0

# Animation
var _anim_time: float = 0.0
var _base_mesh_y: float = 0.0
var _attack_anim: float = -1.0
var _last_dmg_num_time: float = 0.0

var _last_grid_pos: Vector3

func _ready() -> void:
	add_to_group("enemies")
	if data:
		current_hp = data.max_hp
	_build_mesh()
	_last_grid_pos = global_position
	SpatialGrid.register(self, "enemies")

func _build_mesh() -> void:
	var sf: float = data.scale_factor if data else 1.0
	var shadow_size := 0.6 * sf

	# Body pivot
	_body_pivot = Node3D.new()
	add_child(_body_pivot)

	_mesh_instance = MeshInstance3D.new()

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
		match etype:
			EnemyData.EnemyType.RUSHER: _mesh_instance.position = Vector3(0.0, 0.15 * sf, 0.0); shadow_size = 0.5 * sf
			EnemyData.EnemyType.TANK: _mesh_instance.position = Vector3(0.0, 0.28 * sf, 0.0); shadow_size = 0.8 * sf
			EnemyData.EnemyType.SPLITTER: _mesh_instance.position = Vector3(0.0, 0.22 * sf, 0.0); shadow_size = 0.5 * sf
			EnemyData.EnemyType.EXPLODER: _mesh_instance.position = Vector3(0.0, 0.35 * sf, 0.0); shadow_size = 0.6 * sf
			EnemyData.EnemyType.DESTROYER: _mesh_instance.position = Vector3(0.0, 0.45 * sf, 0.0); shadow_size = 1.1 * sf
			_: _mesh_instance.position = Vector3(0.0, 0.3 * sf, 0.0); shadow_size = 0.55 * sf
	else:
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

	_base_mesh_y = _mesh_instance.position.y

	_body_mat = StandardMaterial3D.new()
	var c: Color = data.color if data else Color.RED
	_body_mat.albedo_color = c
	_body_mat.roughness = 0.5
	_body_mat.emission_enabled = true
	_body_mat.emission = c * 0.5
	_body_mat.emission_energy_multiplier = 1.8
	_mesh_instance.material_override = _body_mat
	_body_pivot.add_child(_mesh_instance)

	# Type-specific detail
	_build_detail(etype, sf)

	# Ground shadow
	_shadow = MeshInstance3D.new()
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(shadow_size, shadow_size)
	_shadow.mesh = shadow_quad
	_shadow.rotation_degrees.x = -90.0
	_shadow.position = Vector3(0.0, 0.02, 0.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.4)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = shadow_mat
	add_child(_shadow)

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3 * sf
	col.shape = shape
	col.position = Vector3(0.0, 0.3 * sf, 0.0)
	add_child(col)

	# HP bar
	_hp_bar_bg = MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.5, 0.04, 0.08)
	_hp_bar_bg.mesh = bg_box
	_hp_bar_bg.position = Vector3(0.0, 0.55 * sf + 0.15, 0.0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_bg.material_override = bg_mat
	add_child(_hp_bar_bg)

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

func _build_detail(etype: int, sf: float) -> void:
	var dm := MeshInstance3D.new()
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	match etype:
		EnemyData.EnemyType.RUSHER:
			# Front horn
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.06 * sf
			spike.height = 0.25 * sf
			dm.mesh = spike
			dmat.albedo_color = Color(1.0, 0.3, 0.2)
			dmat.emission_enabled = true
			dmat.emission = Color(0.8, 0.15, 0.1)
			dmat.emission_energy_multiplier = 1.5
			dm.position = Vector3(0.0, 0.2 * sf, 0.25 * sf)
			dm.rotation_degrees.x = 90.0

		EnemyData.EnemyType.TANK:
			# Shoulder armor
			var pad := BoxMesh.new()
			pad.size = Vector3(0.15, 0.1, 0.15) * sf
			dm.mesh = pad
			dmat.albedo_color = Color(0.35, 0.25, 0.45)
			dmat.emission_enabled = true
			dmat.emission = Color(0.25, 0.15, 0.35)
			dmat.emission_energy_multiplier = 1.0
			dm.position = Vector3(0.35 * sf, 0.45 * sf, 0.0)
			var pad2 := MeshInstance3D.new()
			pad2.mesh = pad
			pad2.position = Vector3(-0.7 * sf, 0.0, 0.0)
			var p2mat := dmat.duplicate()
			pad2.material_override = p2mat
			dm.add_child(pad2)

		EnemyData.EnemyType.SPLITTER:
			# Glowing seam
			var seam := BoxMesh.new()
			seam.size = Vector3(0.02, 0.4, 0.35) * sf
			dm.mesh = seam
			dmat.albedo_color = Color(0.7, 1.0, 0.3)
			dmat.emission_enabled = true
			dmat.emission = Color(0.5, 0.9, 0.2)
			dmat.emission_energy_multiplier = 3.0
			dm.position = Vector3(0.0, 0.22 * sf, 0.0)

		EnemyData.EnemyType.EXPLODER:
			# Glow ring
			var ring := TorusMesh.new()
			ring.inner_radius = 0.3 * sf
			ring.outer_radius = 0.38 * sf
			ring.rings = 8
			ring.ring_segments = 12
			dm.mesh = ring
			dmat.albedo_color = Color(1.0, 0.5, 0.1, 0.7)
			dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dmat.emission_enabled = true
			dmat.emission = Color(1.0, 0.4, 0.0)
			dmat.emission_energy_multiplier = 4.0
			dm.position = Vector3(0.0, 0.35 * sf, 0.0)
			dm.rotation_degrees.x = 90.0

		EnemyData.EnemyType.ELITE_RUSHER:
			# Crown horns
			var crown := CylinderMesh.new()
			crown.top_radius = 0.0
			crown.bottom_radius = 0.08 * sf
			crown.height = 0.2 * sf
			dm.mesh = crown
			dmat.albedo_color = Color(1.0, 0.2, 0.3)
			dmat.emission_enabled = true
			dmat.emission = Color(0.95, 0.1, 0.2)
			dmat.emission_energy_multiplier = 2.5
			dm.position = Vector3(0.0, 0.45 * sf, 0.0)
			var horn2 := MeshInstance3D.new()
			horn2.mesh = crown
			horn2.position = Vector3(0.12 * sf, -0.05, 0.0)
			horn2.rotation_degrees.z = 20.0
			var h2mat := dmat.duplicate()
			horn2.material_override = h2mat
			dm.add_child(horn2)
			var horn3 := MeshInstance3D.new()
			horn3.mesh = crown
			horn3.position = Vector3(-0.12 * sf, -0.05, 0.0)
			horn3.rotation_degrees.z = -20.0
			var h3mat := dmat.duplicate()
			horn3.material_override = h3mat
			dm.add_child(horn3)

		EnemyData.EnemyType.DESTROYER:
			# Helm crest
			var crest := BoxMesh.new()
			crest.size = Vector3(0.12, 0.3, 0.04) * sf
			dm.mesh = crest
			dmat.albedo_color = Color(0.5, 0.15, 0.6)
			dmat.emission_enabled = true
			dmat.emission = Color(0.4, 0.1, 0.5)
			dmat.emission_energy_multiplier = 2.0
			dm.position = Vector3(0.0, 0.8 * sf, 0.0)
			# Eye glow
			var eye := MeshInstance3D.new()
			var esphere := SphereMesh.new()
			esphere.radius = 0.06 * sf
			esphere.height = 0.12 * sf
			eye.mesh = esphere
			eye.position = Vector3(0.0, -0.2, 0.42 * sf)
			var emat := StandardMaterial3D.new()
			emat.albedo_color = Color(1.0, 0.2, 0.0)
			emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			emat.emission_enabled = true
			emat.emission = Color(1.0, 0.15, 0.0)
			emat.emission_energy_multiplier = 5.0
			eye.material_override = emat
			dm.add_child(eye)
		_:
			dm.free()
			return

	dm.material_override = dmat
	_detail_mesh = dm
	_body_pivot.add_child(dm)

# ---------------------------------------------------------------------------
# Processing
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over or _dead:
		return

	if _attack_flash > 0.0:
		_attack_flash -= delta * 5.0
		if _attack_flash <= 0.0:
			_attack_flash = 0.0
			if _body_mat and data:
				_body_mat.albedo_color = data.color
		elif Engine.get_physics_frames() % 3 == 0:
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
		_animate_stun(delta)
		return

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
				if data.enemy_type == EnemyData.EnemyType.DESTROYER:
					dmg *= 2.0
				_attack_target.take_damage(dmg, self)
				_attack_timer = 1.0
				_attack_flash = 1.0
				_attack_anim = 0.0
				_update_flash()
			_animate(delta)
			return

	# Movement
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

	_animate(delta)

func _get_move_direction() -> Vector3:
	if not flow_field.is_empty():
		var gx := int(floor(global_position.x))
		var gz := int(floor(global_position.z))
		var cell := Vector2i(gx, gz)
		if flow_field.has(cell):
			var flow_dir: Vector2 = flow_field[cell]
			return Vector3(flow_dir.x, 0.0, flow_dir.y).normalized()
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

# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func _animate(delta: float) -> void:
	_anim_time += delta
	_mesh_instance.position.x = 0.0

	# Face movement direction
	if velocity.length_squared() > 0.1:
		var target_angle := atan2(velocity.x, velocity.z)
		_body_pivot.rotation.y = lerp_angle(_body_pivot.rotation.y, target_angle, delta * 8.0)
	elif _attack_target and is_instance_valid(_attack_target):
		var to_target := _attack_target.global_position - global_position
		if to_target.length_squared() > 0.01:
			var target_angle := atan2(to_target.x, to_target.z)
			_body_pivot.rotation.y = lerp_angle(_body_pivot.rotation.y, target_angle, delta * 10.0)

	if _attack_target and is_instance_valid(_attack_target):
		_animate_attack(delta)
	else:
		_animate_march()

	_animate_type_special()

func _animate_stun(delta: float) -> void:
	_anim_time += delta
	_mesh_instance.position.x = sin(_anim_time * 40.0) * 0.04
	_mesh_instance.position.y = _base_mesh_y
	_body_pivot.rotation.z = sin(_anim_time * 30.0) * 0.08

func _animate_march() -> void:
	var sf: float = data.scale_factor if data else 1.0
	var walk_phase := _anim_time * 8.0
	_mesh_instance.position.y = _base_mesh_y + abs(sin(walk_phase)) * 0.05 * sf
	_body_pivot.rotation.x = -0.12
	_body_pivot.rotation.z = sin(walk_phase * 0.5) * 0.06
	_mesh_instance.scale = Vector3.ONE

func _animate_attack(delta: float) -> void:
	if _attack_anim >= 0.0:
		_attack_anim = minf(_attack_anim + delta * 4.0, 1.0)
		var t := _attack_anim
		var slam := sin(t * PI)
		_body_pivot.rotation.x = -slam * 0.3
		_body_pivot.rotation.z = 0.0
		_mesh_instance.scale = Vector3(
			1.0 + slam * 0.15,
			1.0 - slam * 0.1,
			1.0 + slam * 0.15
		)
		_mesh_instance.position.y = _base_mesh_y + slam * 0.03
		if _attack_anim >= 1.0:
			_attack_anim = -1.0
			_mesh_instance.scale = Vector3.ONE
			_mesh_instance.position.y = _base_mesh_y
			_body_pivot.rotation.x = 0.0
	else:
		_mesh_instance.position.y = _base_mesh_y + sin(_anim_time * 3.0) * 0.02
		_body_pivot.rotation.x = -0.08
		_body_pivot.rotation.z = 0.0
		_mesh_instance.scale = Vector3.ONE

func _animate_type_special() -> void:
	if not data or not _detail_mesh:
		return
	match data.enemy_type:
		EnemyData.EnemyType.EXPLODER:
			var pulse := (sin(_anim_time * 6.0) + 1.0) * 0.5
			_detail_mesh.scale = Vector3.ONE * (0.9 + pulse * 0.2)
			var dmat := _detail_mesh.material_override as StandardMaterial3D
			if dmat:
				dmat.emission_energy_multiplier = 2.0 + pulse * 4.0
		EnemyData.EnemyType.DESTROYER:
			if _detail_mesh.get_child_count() > 0:
				var eye := _detail_mesh.get_child(0) as MeshInstance3D
				if eye:
					var emat := eye.material_override as StandardMaterial3D
					if emat:
						var pulse := (sin(_anim_time * 4.0) + 1.0) * 0.5
						emat.emission_energy_multiplier = 3.0 + pulse * 4.0
		EnemyData.EnemyType.SPLITTER:
			var dmat := _detail_mesh.material_override as StandardMaterial3D
			if dmat:
				var pulse := (sin(_anim_time * 3.0) + 1.0) * 0.5
				dmat.emission_energy_multiplier = 1.5 + pulse * 3.0

# ---------------------------------------------------------------------------
# Damage & Flash
# ---------------------------------------------------------------------------

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
	if amount > 1.0:
		var now := Time.get_ticks_msec() * 0.001
		if now - _last_dmg_num_time > 0.25:
			_last_dmg_num_time = now
			_spawn_damage_number(amount)
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	SpatialGrid.unregister(self, "enemies")

	if _poison_dps > 0.0 and _poison_timer > 0.0:
		var nearby := SpatialGrid.find_in_range(global_position, "enemies", 3.0)
		for enemy in nearby:
			if enemy == self:
				continue
			if enemy.has_method("apply_poison"):
				enemy.apply_poison(_poison_dps * 0.6, 3.0)

	if data and data.enemy_type == EnemyData.EnemyType.SPLITTER:
		_spawn_splits()

	var reward := data.mineral_reward if data else 3
	if drop_mineral.get_connections().is_empty():
		GameManager.add_minerals(reward)
	else:
		drop_mineral.emit(global_position, reward)
	GameManager.add_kill()
	died.emit()
	_spawn_death_particles()

	# Death animation
	collision_layer = 0
	collision_mask = 0
	if _hp_bar_fill:
		_hp_bar_fill.visible = false
	if _hp_bar_bg:
		_hp_bar_bg.visible = false

	var tween := create_tween()
	if data and data.enemy_type == EnemyData.EnemyType.EXPLODER:
		# Explosion: scale up, flash, vanish
		if _body_mat:
			_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_body_mat.albedo_color = Color(1.0, 0.7, 0.2)
		tween.set_parallel(true)
		tween.tween_property(_body_pivot, "scale", Vector3(2.5, 0.5, 2.5), 0.2)
		if _body_mat:
			tween.tween_property(_body_mat, "albedo_color", Color(1.0, 0.5, 0.0, 0.0), 0.25)
		if _shadow:
			tween.tween_property(_shadow, "scale", Vector3.ZERO, 0.1)
	else:
		# Fall + shrink
		tween.set_parallel(true)
		tween.tween_property(_body_pivot, "rotation_degrees:z", randf_range(-90.0, 90.0), 0.25).set_ease(Tween.EASE_IN)
		tween.tween_property(_body_pivot, "position:y", -0.2, 0.25)
		tween.tween_property(_body_pivot, "scale", Vector3(0.3, 0.05, 0.3), 0.25)
		if _shadow:
			tween.tween_property(_shadow, "scale", Vector3.ZERO, 0.15)
	tween.chain().tween_callback(queue_free)

func _spawn_death_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.direction = Vector3.UP
	particles.gravity = Vector3(0, -8, 0)
	var is_exploder := data and data.enemy_type == EnemyData.EnemyType.EXPLODER
	if is_exploder:
		particles.amount = 30
		particles.lifetime = 0.6
		particles.spread = 180.0
		particles.initial_velocity_min = 4.0
		particles.initial_velocity_max = 8.0
		particles.scale_amount_min = 1.0
		particles.scale_amount_max = 2.0
		particles.color = Color(1.0, 0.5, 0.1)
	else:
		particles.amount = 12
		particles.lifetime = 0.4
		particles.spread = 80.0
		particles.initial_velocity_min = 2.0
		particles.initial_velocity_max = 5.0
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 1.0
		particles.color = data.color if data else Color.RED
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.05
	pmesh.height = 0.1
	particles.mesh = pmesh
	particles.position = global_position + Vector3(0, 0.3, 0)
	get_parent().add_child(particles)
	var tw := particles.create_tween()
	tw.tween_callback(particles.queue_free).set_delay(1.5)

func _spawn_damage_number(amount: float) -> void:
	var label := Label3D.new()
	label.text = str(int(amount))
	label.font_size = 18
	label.outline_size = 4
	label.modulate = Color(1.0, 0.9, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = global_position + Vector3(randf_range(-0.2, 0.2), 0.6, randf_range(-0.2, 0.2))
	get_parent().add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.2, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)

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

	var parent := get_parent()
	for i in data.split_count:
		var mini: CharacterBody3D = _enemy_scene_preload.instantiate()
		mini.set("data", split_data)
		mini.set("target_position", target_position)
		mini.set("flow_field", flow_field)
		var offset := Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
		mini.position = global_position + offset
		if parent.has_method("_on_enemy_died"):
			mini.connect("died", parent._on_enemy_died)
		if parent.has_method("_on_enemy_drop_mineral") and mini.has_signal("drop_mineral"):
			mini.connect("drop_mineral", parent._on_enemy_drop_mineral)
		parent.call_deferred("add_child", mini)
