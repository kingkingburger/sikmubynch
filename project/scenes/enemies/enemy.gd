extends CharacterBody3D

signal died()

var data: EnemyData
var current_hp: float
var target_position: Vector3

var _attack_target: BaseBuilding = null
var _attack_timer: float = 0.0
var _mesh_instance: MeshInstance3D
var _body_mat: StandardMaterial3D
var _hp_bar_fill: MeshInstance3D
var _attack_flash: float = 0.0

func _ready() -> void:
	if data:
		current_hp = data.max_hp
	_build_mesh()

func _build_mesh() -> void:
	# Sphere body
	_mesh_instance = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	_mesh_instance.mesh = sphere
	_mesh_instance.position = Vector3(0.0, 0.25, 0.0)

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = data.color if data else Color.RED
	_body_mat.roughness = 0.6
	_mesh_instance.material_override = _body_mat
	add_child(_mesh_instance)

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	col.position = Vector3(0.0, 0.25, 0.0)
	add_child(col)

	# HP bar background
	var hp_bg := MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.5, 0.04, 0.08)
	hp_bg.mesh = bg_box
	hp_bg.position = Vector3(0.0, 0.65, 0.0)
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
	_hp_bar_fill.position = Vector3(0.0, 0.66, 0.0)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.15, 0.85, 0.2)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_fill.material_override = fill_mat
	add_child(_hp_bar_fill)

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return

	if _attack_flash > 0.0:
		_attack_flash -= delta * 5.0
		if _attack_flash < 0.0:
			_attack_flash = 0.0
		_update_flash()

	if _attack_target:
		if not is_instance_valid(_attack_target):
			_attack_target = null
		else:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_target.take_damage(data.dps)
				_attack_timer = 1.0
				_attack_flash = 1.0
				_update_flash()
			return

	# Move toward target on XZ plane
	var my_pos := Vector3(global_position.x, 0.0, global_position.z)
	var tgt := Vector3(target_position.x, 0.0, target_position.z)
	var dir := (tgt - my_pos).normalized()
	velocity = dir * data.speed
	var collision := move_and_collide(velocity * delta)

	if collision:
		var collider := collision.get_collider()
		if collider is BaseBuilding:
			_attack_target = collider as BaseBuilding
			_attack_timer = 0.0
			velocity = Vector3.ZERO

	_update_hp_bar()

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
		fill_mesh.size = Vector3(max(fill_width, 0.01), 0.05, 0.08)
	_hp_bar_fill.position.x = (fill_width - full_width) / 2.0
	var fill_mat := _hp_bar_fill.material_override as StandardMaterial3D
	if fill_mat:
		fill_mat.albedo_color = Color(0.15, 0.85, 0.2) if hp_ratio > 0.5 else Color(0.9, 0.3, 0.1)

func take_damage(amount: float) -> void:
	current_hp -= amount
	_update_hp_bar()
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	GameManager.add_minerals(data.mineral_reward)
	GameManager.add_kill()
	died.emit()
	queue_free()
