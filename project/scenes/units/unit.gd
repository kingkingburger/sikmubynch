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

# Visual
var _body_pivot: Node3D
var _mesh_instance: MeshInstance3D
var _weapon_mesh: MeshInstance3D
var _body_mat: StandardMaterial3D
var _hp_bar_fill: MeshInstance3D
var _hp_bar_bg: MeshInstance3D
var _shadow: MeshInstance3D
var _flash: float = 0.0

# Animation
var _anim_time: float = 0.0
var _base_mesh_y: float = 0.0
var _attack_anim: float = -1.0
var _weapon_base_pos: Vector3
var _weapon_base_rot: Vector3

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
	var unit_type: int = data.unit_type if data else UnitData.UnitType.SOLDIER

	# Body pivot — rotates to face direction, holds body + weapon
	_body_pivot = Node3D.new()
	add_child(_body_pivot)

	_mesh_instance = MeshInstance3D.new()

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
		match unit_type:
			UnitData.UnitType.SOLDIER:
				var capsule := CapsuleMesh.new()
				capsule.radius = 0.18
				capsule.height = 0.65
				_mesh_instance.mesh = capsule
				_mesh_instance.position = Vector3(0.0, 0.33, 0.0)
			UnitData.UnitType.ARCHER:
				var capsule := CapsuleMesh.new()
				capsule.radius = 0.14
				capsule.height = 0.7
				_mesh_instance.mesh = capsule
				_mesh_instance.position = Vector3(0.0, 0.35, 0.0)
			UnitData.UnitType.TANKER:
				var box := BoxMesh.new()
				box.size = Vector3(0.5, 0.6, 0.45)
				_mesh_instance.mesh = box
				_mesh_instance.position = Vector3(0.0, 0.3, 0.0)
			UnitData.UnitType.BOMBER:
				var sphere := SphereMesh.new()
				sphere.radius = 0.25
				sphere.height = 0.5
				sphere.radial_segments = 12
				_mesh_instance.mesh = sphere
				_mesh_instance.position = Vector3(0.0, 0.25, 0.0)
			_:
				var capsule := CapsuleMesh.new()
				capsule.radius = 0.2
				capsule.height = 0.55
				_mesh_instance.mesh = capsule
				_mesh_instance.position = Vector3(0.0, 0.28, 0.0)

	_base_mesh_y = _mesh_instance.position.y

	_body_mat = StandardMaterial3D.new()
	var c: Color = data.color if data else Color.BLUE
	_body_mat.albedo_color = c
	_body_mat.roughness = 0.4
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.2, 0.4, 1.0) * 0.8
	_body_mat.emission_energy_multiplier = 3.0
	_body_mat.rim_enabled = true
	_body_mat.rim = 0.45
	_body_mat.rim_tint = 0.25
	_mesh_instance.material_override = _body_mat
	_body_pivot.add_child(_mesh_instance)

	# Head
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	var unit_type_h: int = data.unit_type if data else UnitData.UnitType.SOLDIER
	match unit_type_h:
		UnitData.UnitType.SOLDIER:
			head_mesh.radius = 0.11
			head_mesh.height = 0.22
			head.position = Vector3(0.0, _base_mesh_y + 0.28, 0.0)
		UnitData.UnitType.ARCHER:
			head_mesh.radius = 0.09
			head_mesh.height = 0.18
			head.position = Vector3(0.0, _base_mesh_y + 0.32, 0.0)
		UnitData.UnitType.TANKER:
			head_mesh.radius = 0.13
			head_mesh.height = 0.26
			head.position = Vector3(0.0, _base_mesh_y + 0.25, 0.0)
		_:
			head_mesh.radius = 0.1
			head_mesh.height = 0.2
			head.position = Vector3(0.0, _base_mesh_y + 0.2, 0.0)
	head.mesh = head_mesh
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = c.lightened(0.15)
	head_mat.roughness = 0.3
	head_mat.emission_enabled = true
	head_mat.emission = c * 0.3
	head_mat.emission_energy_multiplier = 1.2
	head_mat.rim_enabled = true
	head_mat.rim = 0.5
	head_mat.rim_tint = 0.2
	head.material_override = head_mat
	_body_pivot.add_child(head)

	# Weapon
	_build_weapon(unit_type)

	# Ground shadow
	_shadow = MeshInstance3D.new()
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(0.5, 0.5)
	_shadow.mesh = shadow_quad
	_shadow.rotation_degrees.x = -90.0
	_shadow.position = Vector3(0.0, 0.02, 0.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = shadow_mat
	add_child(_shadow)

	# Collision
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 0.55
	col.shape = shape
	col.position = Vector3(0.0, 0.28, 0.0)
	add_child(col)

	# HP bar bg
	_hp_bar_bg = MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.45, 0.04, 0.07)
	_hp_bar_bg.mesh = bg_box
	_hp_bar_bg.position = Vector3(0.0, 0.6, 0.0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_bg.material_override = bg_mat
	add_child(_hp_bar_bg)

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

func _build_weapon(unit_type: int) -> void:
	var wm := MeshInstance3D.new()
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	match unit_type:
		UnitData.UnitType.SOLDIER:
			# Sword blade
			var blade := BoxMesh.new()
			blade.size = Vector3(0.04, 0.45, 0.02)
			wm.mesh = blade
			wmat.albedo_color = Color(0.85, 0.85, 0.9)
			wmat.emission_enabled = true
			wmat.emission = Color(0.6, 0.65, 0.8)
			wmat.emission_energy_multiplier = 0.8
			wm.position = Vector3(0.25, 0.35, 0.0)
			wm.rotation_degrees.z = -15.0
			# Guard
			var guard := MeshInstance3D.new()
			var gmesh := BoxMesh.new()
			gmesh.size = Vector3(0.12, 0.03, 0.04)
			guard.mesh = gmesh
			guard.position = Vector3(0.0, -0.15, 0.0)
			var gmat := StandardMaterial3D.new()
			gmat.albedo_color = Color(0.6, 0.5, 0.2)
			gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			guard.material_override = gmat
			wm.add_child(guard)

		UnitData.UnitType.ARCHER:
			# Bow
			var bow := CylinderMesh.new()
			bow.top_radius = 0.02
			bow.bottom_radius = 0.02
			bow.height = 0.5
			wm.mesh = bow
			wmat.albedo_color = Color(0.55, 0.35, 0.15)
			wmat.emission_enabled = true
			wmat.emission = Color(0.3, 0.2, 0.1)
			wmat.emission_energy_multiplier = 0.5
			wm.position = Vector3(-0.2, 0.35, 0.0)
			wm.rotation_degrees.z = 10.0
			# Bowstring
			var str_node := MeshInstance3D.new()
			var str_cyl := CylinderMesh.new()
			str_cyl.top_radius = 0.005
			str_cyl.bottom_radius = 0.005
			str_cyl.height = 0.48
			str_node.mesh = str_cyl
			str_node.position = Vector3(0.06, 0.0, 0.0)
			var str_mat := StandardMaterial3D.new()
			str_mat.albedo_color = Color(0.8, 0.8, 0.7)
			str_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			str_node.material_override = str_mat
			wm.add_child(str_node)

		UnitData.UnitType.TANKER:
			# Shield
			var shield := BoxMesh.new()
			shield.size = Vector3(0.35, 0.4, 0.04)
			wm.mesh = shield
			wmat.albedo_color = Color(0.5, 0.5, 0.55)
			wmat.emission_enabled = true
			wmat.emission = Color(0.3, 0.3, 0.35)
			wmat.emission_energy_multiplier = 0.4
			wm.position = Vector3(0.0, 0.3, 0.28)
			# Emblem
			var emb := MeshInstance3D.new()
			var emesh := BoxMesh.new()
			emesh.size = Vector3(0.12, 0.12, 0.005)
			emb.mesh = emesh
			emb.position = Vector3(0.0, 0.02, 0.025)
			var emat := StandardMaterial3D.new()
			emat.albedo_color = Color(0.8, 0.7, 0.2)
			emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			emat.emission_enabled = true
			emat.emission = Color(0.6, 0.5, 0.1)
			emat.emission_energy_multiplier = 1.0
			emb.material_override = emat
			wm.add_child(emb)

		UnitData.UnitType.BOMBER:
			# Explosive pack
			var pack := BoxMesh.new()
			pack.size = Vector3(0.2, 0.15, 0.12)
			wm.mesh = pack
			wmat.albedo_color = Color(0.4, 0.25, 0.1)
			wmat.emission_enabled = true
			wmat.emission = Color(0.9, 0.4, 0.1)
			wmat.emission_energy_multiplier = 2.0
			wm.position = Vector3(0.0, 0.25, -0.18)
			# Fuse glow
			var fuse := MeshInstance3D.new()
			var fmesh := SphereMesh.new()
			fmesh.radius = 0.04
			fmesh.height = 0.08
			fuse.mesh = fmesh
			fuse.position = Vector3(0.0, 0.1, -0.02)
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = Color(1.0, 0.6, 0.1)
			fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fmat.emission_enabled = true
			fmat.emission = Color(1.0, 0.5, 0.0)
			fmat.emission_energy_multiplier = 4.0
			fuse.material_override = fmat
			wm.add_child(fuse)
		_:
			wm.free()
			return

	wm.material_override = wmat
	_weapon_mesh = wm
	_weapon_base_pos = wm.position
	_weapon_base_rot = wm.rotation_degrees
	_body_pivot.add_child(wm)

# ---------------------------------------------------------------------------
# Processing
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over or _state == State.DEAD:
		return

	if _flash > 0.0:
		_flash -= delta * 5.0
		if _flash <= 0.0:
			_flash = 0.0
			if _body_mat and data:
				_body_mat.albedo_color = data.color
		elif Engine.get_physics_frames() % 3 == 0:
			_update_flash()

	match _state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	_animate(delta)

# -- State: PATROL --
func _process_patrol(delta: float) -> void:
	if Engine.get_physics_frames() % 5 == hash(get_instance_id()) % 5:
		var enemy := _find_nearest_enemy()
		if enemy:
			_chase_target = enemy
			_state = State.CHASE
			return

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

	if data.unit_type == UnitData.UnitType.BOMBER:
		if dist <= BOMBER_EXPLODE_RANGE:
			_bomber_explode()
			return

	if dist <= data.attack_range:
		_state = State.ATTACK
		_attack_timer = 0.0
		return

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
	_attack_anim = 0.0

	var dmg := data.dps * (1.0 + EventManager.get_unit_dps_perm_bonus())
	if data.unit_type == UnitData.UnitType.ARCHER:
		_fire_projectile(dmg)
	else:
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

# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func _animate(delta: float) -> void:
	_anim_time += delta

	# Face movement direction
	if velocity.length_squared() > 0.1:
		var target_angle := atan2(velocity.x, velocity.z)
		_body_pivot.rotation.y = lerp_angle(_body_pivot.rotation.y, target_angle, delta * 8.0)
	elif _state == State.ATTACK and is_instance_valid(_chase_target):
		var dir := _chase_target.global_position - global_position
		if dir.length_squared() > 0.01:
			var target_angle := atan2(dir.x, dir.z)
			_body_pivot.rotation.y = lerp_angle(_body_pivot.rotation.y, target_angle, delta * 10.0)

	match _state:
		State.PATROL:
			_animate_idle()
		State.CHASE:
			_animate_walk()
		State.ATTACK:
			_animate_combat(delta)

	# Bomber fuse pulse
	if data and data.unit_type == UnitData.UnitType.BOMBER and _weapon_mesh:
		if _weapon_mesh.get_child_count() > 0:
			var fuse := _weapon_mesh.get_child(0) as MeshInstance3D
			if fuse:
				var fmat := fuse.material_override as StandardMaterial3D
				if fmat:
					var pulse := (sin(_anim_time * 8.0) + 1.0) * 0.5
					fmat.emission_energy_multiplier = 2.0 + pulse * 4.0

func _animate_idle() -> void:
	_mesh_instance.position.y = _base_mesh_y + sin(_anim_time * 2.0) * 0.025
	_body_pivot.rotation.x = sin(_anim_time * 1.5) * 0.03
	_body_pivot.rotation.z = cos(_anim_time * 1.2) * 0.02
	_mesh_instance.scale = Vector3.ONE
	if _weapon_mesh:
		_weapon_mesh.position = _weapon_base_pos
		_weapon_mesh.rotation_degrees = _weapon_base_rot

func _animate_walk() -> void:
	var walk_phase := _anim_time * 10.0
	_mesh_instance.position.y = _base_mesh_y + abs(sin(walk_phase)) * 0.06
	_body_pivot.rotation.x = -0.15
	_body_pivot.rotation.z = sin(walk_phase * 0.5) * 0.08
	_mesh_instance.scale = Vector3.ONE
	if _weapon_mesh:
		_weapon_mesh.position = _weapon_base_pos
		_weapon_mesh.rotation_degrees = _weapon_base_rot
		_weapon_mesh.rotation.x += sin(walk_phase) * 0.1

func _animate_combat(delta: float) -> void:
	if _attack_anim >= 0.0:
		_attack_anim = minf(_attack_anim + delta * 4.0, 1.0)
		var t := _attack_anim
		var squash := sin(t * PI)
		_mesh_instance.scale = Vector3(
			1.0 + squash * 0.12,
			1.0 - squash * 0.08,
			1.0 + squash * 0.12
		)
		_mesh_instance.position.y = _base_mesh_y + squash * 0.04
		_body_pivot.rotation.x = -squash * 0.2
		_body_pivot.rotation.z = 0.0
		if _weapon_mesh:
			_animate_weapon_attack(t)
		if _attack_anim >= 1.0:
			_attack_anim = -1.0
			_mesh_instance.scale = Vector3.ONE
			_mesh_instance.position.y = _base_mesh_y
			_body_pivot.rotation.x = 0.0
			if _weapon_mesh:
				_weapon_mesh.position = _weapon_base_pos
				_weapon_mesh.rotation_degrees = _weapon_base_rot
	else:
		_mesh_instance.position.y = _base_mesh_y + sin(_anim_time * 3.0) * 0.02
		_body_pivot.rotation.x = -0.05
		_body_pivot.rotation.z = 0.0
		_mesh_instance.scale = Vector3.ONE

func _animate_weapon_attack(t: float) -> void:
	if not data:
		return
	var swing := sin(t * PI)
	match data.unit_type:
		UnitData.UnitType.SOLDIER:
			_weapon_mesh.rotation_degrees = _weapon_base_rot
			_weapon_mesh.rotation_degrees.z += swing * 90.0
			_weapon_mesh.rotation_degrees.x += swing * 30.0
		UnitData.UnitType.ARCHER:
			_weapon_mesh.rotation_degrees = _weapon_base_rot
			if t < 0.5:
				_weapon_mesh.rotation_degrees.z -= t * 20.0
			else:
				_weapon_mesh.rotation_degrees.z += (t - 0.5) * 40.0
		UnitData.UnitType.TANKER:
			_weapon_mesh.position = _weapon_base_pos + Vector3(0.0, 0.0, swing * 0.2)
			_weapon_mesh.rotation_degrees = _weapon_base_rot
			_weapon_mesh.rotation_degrees.x += swing * 20.0

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _find_nearest_enemy() -> Node3D:
	return SpatialGrid.find_nearest(global_position, "enemies", DETECTION_RANGE)

func _random_patrol_point() -> Vector3:
	var offset := Vector3(
		randf_range(-PATROL_RADIUS, PATROL_RADIUS),
		0.0,
		randf_range(-PATROL_RADIUS, PATROL_RADIUS)
	)
	var point := spawn_origin + offset
	point.x = clampf(point.x, 1.0, 255.0)
	point.z = clampf(point.z, 1.0, 255.0)
	point.y = 0.0
	return point

# ---------------------------------------------------------------------------
# Damage & Death
# ---------------------------------------------------------------------------

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
	_update_hp_bar()
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	SpatialGrid.unregister(self, "units")
	died.emit()
	_spawn_death_particles()
	if data and data.unit_type == UnitData.UnitType.BOMBER:
		AudioManager.play_sfx_by_name("explosion", -3.0)
		EffectsManager.spawn_explosion_effect(global_position, 2.5)
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	if _hp_bar_fill:
		_hp_bar_fill.visible = false
	if _hp_bar_bg:
		_hp_bar_bg.visible = false
	# Death animation
	var tween := create_tween()
	tween.set_parallel(true)
	if data and data.unit_type == UnitData.UnitType.BOMBER:
		# Explosion: scale up then vanish
		if _body_mat:
			_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_body_mat.albedo_color = Color(1.0, 0.7, 0.2)
		tween.tween_property(_body_pivot, "scale", Vector3(2.0, 2.0, 2.0), 0.15)
		if _body_mat:
			tween.tween_property(_body_mat, "albedo_color", Color(1.0, 0.5, 0.0, 0.0), 0.2)
	else:
		# Fall + shrink
		tween.tween_property(_body_pivot, "rotation_degrees:x", 90.0, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(_body_pivot, "position:y", -0.15, 0.3)
		tween.tween_property(_body_pivot, "scale", Vector3(0.5, 0.1, 0.5), 0.3)
	if _shadow:
		tween.tween_property(_shadow, "scale", Vector3.ZERO, 0.15)
	tween.chain().tween_callback(queue_free)

func _spawn_death_particles() -> void:
	var color: Color = data.color if data else Color.BLUE
	EffectsManager.spawn_unit_death(global_position, color)
