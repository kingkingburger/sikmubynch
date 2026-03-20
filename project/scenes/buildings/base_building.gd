class_name BaseBuilding
extends StaticBody3D

signal destroyed()

const MAX_LEVEL := 3
const LEVEL_BONUS := 0.3

var data: BuildingData
var current_hp: float
var grid_position: Vector2i
var level: int = 1

var _mesh_instance: MeshInstance3D
var _hp_bar_bg: MeshInstance3D
var _hp_bar_fill: MeshInstance3D
var _damage_flash: float = 0.0
var _damage_mat: StandardMaterial3D

func _ready() -> void:
	if data:
		current_hp = data.max_hp
	_build_mesh()

func get_effective_max_hp() -> float:
	if not data:
		return 100.0
	return data.max_hp * (1.0 + LEVEL_BONUS * (level - 1))

func get_effective_dps() -> float:
	if not data:
		return 0.0
	return data.dps * (1.0 + LEVEL_BONUS * (level - 1))

func _build_mesh() -> void:
	if not data:
		return

	var building_height := _get_height()
	var size_x := float(data.size.x)
	var size_z := float(data.size.y)

	# Main body mesh
	_mesh_instance = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size_x, building_height, size_z)
	_mesh_instance.mesh = box
	_mesh_instance.position = Vector3(0.0, building_height / 2.0, 0.0)

	_damage_mat = StandardMaterial3D.new()
	_damage_mat.albedo_color = data.color
	_damage_mat.roughness = 0.7
	_mesh_instance.material_override = _damage_mat
	add_child(_mesh_instance)

	# Collision
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_x, building_height, size_z)
	col.shape = shape
	col.position = Vector3(0.0, building_height / 2.0, 0.0)
	add_child(col)

	# HP bar background
	_hp_bar_bg = MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(size_x * 0.9, 0.05, 0.12)
	_hp_bar_bg.mesh = bg_box
	_hp_bar_bg.position = Vector3(0.0, building_height + 0.2, 0.0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_bg.material_override = bg_mat
	add_child(_hp_bar_bg)

	# HP bar fill
	_hp_bar_fill = MeshInstance3D.new()
	var fill_box := BoxMesh.new()
	fill_box.size = Vector3(size_x * 0.9, 0.06, 0.12)
	_hp_bar_fill.mesh = fill_box
	_hp_bar_fill.position = Vector3(0.0, building_height + 0.21, 0.0)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.15, 0.85, 0.25)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_fill.material_override = fill_mat
	add_child(_hp_bar_fill)

func _get_height() -> float:
	if data and data.building_name == "HQ":
		return 1.5
	return 0.4

func _process(delta: float) -> void:
	if _damage_flash > 0.0:
		_damage_flash -= delta * 4.0
		if _damage_flash < 0.0:
			_damage_flash = 0.0
		_update_material()
	_update_hp_bar()

func _get_base_color() -> Color:
	if not data:
		return Color.WHITE
	var b := 1.0 + (level - 1) * 0.2
	return Color(
		minf(data.color.r * b, 1.0),
		minf(data.color.g * b, 1.0),
		minf(data.color.b * b, 1.0)
	)

func _update_material() -> void:
	if not _damage_mat or not data:
		return
	var base := _get_base_color()
	if _damage_flash > 0.0:
		_damage_mat.albedo_color = base.lerp(Color(1.0, 0.2, 0.2), _damage_flash)
	else:
		_damage_mat.albedo_color = base

func _update_hp_bar() -> void:
	if not data or not _hp_bar_fill:
		return
	var max_hp := get_effective_max_hp()
	var hp_ratio: float = clampf(current_hp / max_hp, 0.0, 1.0)
	var size_x: float = float(data.size.x)
	var full_width: float = size_x * 0.9
	var fill_width: float = full_width * hp_ratio

	var fill_mesh := _hp_bar_fill.mesh as BoxMesh
	if fill_mesh:
		fill_mesh.size = Vector3(max(fill_width, 0.01), 0.06, 0.12)
	_hp_bar_fill.position.x = (fill_width - full_width) / 2.0

	var fill_mat := _hp_bar_fill.material_override as StandardMaterial3D
	if fill_mat:
		if hp_ratio > 0.6:
			fill_mat.albedo_color = Color(0.15, 0.85, 0.25)
		elif hp_ratio > 0.3:
			fill_mat.albedo_color = Color(0.9, 0.75, 0.1)
		else:
			fill_mat.albedo_color = Color(0.9, 0.2, 0.15)

func take_damage(amount: float) -> void:
	current_hp -= amount
	_damage_flash = 1.0
	_update_material()
	if current_hp <= 0.0:
		die()

func die() -> void:
	destroyed.emit()
	queue_free()

func level_up() -> bool:
	if level >= MAX_LEVEL:
		return false
	if not GameManager.spend_minerals(data.cost):
		return false
	level += 1
	current_hp = get_effective_max_hp()
	_update_level_visual()
	return true

func demolish() -> void:
	var total_cost := data.cost * level
	var refund := int(total_cost * 0.5)
	GameManager.add_minerals(refund)
	die()

func _update_level_visual() -> void:
	_update_material()
	if _mesh_instance:
		var s := 1.0 + (level - 1) * 0.06
		_mesh_instance.scale = Vector3(s, s, s)
