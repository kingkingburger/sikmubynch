extends Node3D

var target: Node3D
var damage: float = 0.0
var speed: float = 25.0

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.15)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var target_pos := target.global_position + Vector3(0.0, 0.25, 0.0)
	var to_target := target_pos - global_position
	var dist := to_target.length()
	var move_dist := speed * delta

	if move_dist >= dist:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
		return

	global_position += to_target.normalized() * move_dist
