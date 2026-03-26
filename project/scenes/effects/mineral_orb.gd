extends Node3D

var target_position := Vector3(32.5, 0.5, 32.5)
var amount: int = 3
var _elapsed: float = 0.0
var _duration: float = 1.5
var _start_pos: Vector3
var _collected: bool = false
var _mesh: MeshInstance3D

func _ready() -> void:
	_start_pos = global_position
	_build_mesh()
	_build_trail()

func _build_trail() -> void:
	var trail := CPUParticles3D.new()
	trail.emitting = true
	trail.amount = 6
	trail.lifetime = 0.3
	trail.explosiveness = 0.0
	trail.direction = Vector3.ZERO
	trail.spread = 180.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.2
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.1
	trail.scale_amount_max = 0.25
	trail.color = Color(0.3, 0.9, 1.0, 0.7)
	var tmesh := SphereMesh.new()
	tmesh.radius = 0.02
	tmesh.height = 0.04
	trail.mesh = tmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail.material_override = mat
	add_child(trail)

func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var glb: Mesh = BaseBuilding._load_glb("effects", "mineral_orb")
	if glb:
		_mesh.mesh = glb
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	_mesh.material_override = mat
	add_child(_mesh)

func _process(delta: float) -> void:
	if _collected:
		return

	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)

	# Ease-in curve for acceleration effect
	var ease_t := t * t

	# Arc upward then down
	var arc_height := 2.0 * sin(t * PI)
	var lerped := _start_pos.lerp(target_position, ease_t)
	global_position = Vector3(lerped.x, lerped.y + arc_height, lerped.z)

	# Shrink near end
	var s := 1.0 - t * 0.5
	_mesh.scale = Vector3(s, s, s)

	if t >= 1.0:
		_collected = true
		AudioManager.play_sfx_by_name("mineral", -10.0)
		GameManager.add_minerals(amount)
		queue_free()
