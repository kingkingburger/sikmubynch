extends BaseBuilding

var _pulse_timer: float = 0.0
var _aura_mesh: MeshInstance3D

func _ready() -> void:
	super._ready()
	_setup_aura()

func _get_height() -> float:
	return 0.9

func _setup_aura() -> void:
	# Visual aura ring
	_aura_mesh = MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 3.5
	torus.bottom_radius = 3.5
	torus.height = 0.02
	_aura_mesh.mesh = torus
	_aura_mesh.position = Vector3(0.0, 0.05, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.3, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_mesh.material_override = mat
	add_child(_aura_mesh)

	# Top crystal
	var crystal := MeshInstance3D.new()
	var glb := BaseBuilding._load_glb("buildings", "buff_crystal")
	if glb:
		crystal.mesh = glb
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.2, 0.3, 0.2)
		crystal.mesh = box
	crystal.position = Vector3(0.0, 1.05, 0.0)
	crystal.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.9, 0.3)
	cmat.emission_enabled = true
	cmat.emission = Color(1.0, 0.85, 0.2)
	cmat.emission_energy_multiplier = 1.5
	crystal.material_override = cmat
	add_child(crystal)

func _process(delta: float) -> void:
	super._process(delta)
	if GameManager.is_game_over or not data:
		return

	# Pulse animation
	_pulse_timer += delta
	if _aura_mesh:
		var pulse := 0.9 + sin(_pulse_timer * 2.0) * 0.1
		_aura_mesh.scale = Vector3(pulse, 1.0, pulse)

func get_buff_range() -> float:
	if not data:
		return 0.0
	return data.buff_range * (1.0 + BaseBuilding.LEVEL_BONUS * (level - 1))

func get_buff_multiplier() -> float:
	if not data:
		return 0.0
	return data.buff_dps_mult * (1.0 + BaseBuilding.LEVEL_BONUS * (level - 1))
