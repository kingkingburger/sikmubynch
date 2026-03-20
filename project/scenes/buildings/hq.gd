extends BaseBuilding

var _pulse_time: float = 0.0
var _emission_mat: StandardMaterial3D

func _ready() -> void:
	data = BuildingData.new()
	data.building_name = "HQ"
	data.max_hp = 1000.0
	data.size = Vector2i(3, 3)
	data.color = Color(0.2, 0.4, 0.8)
	current_hp = data.max_hp
	add_to_group("hq")
	_build_mesh()
	_setup_emission()

func _setup_emission() -> void:
	# Replace material with emissive version for HQ glow
	if _mesh_instance:
		_emission_mat = StandardMaterial3D.new()
		_emission_mat.albedo_color = Color(0.2, 0.4, 0.8)
		_emission_mat.emission_enabled = true
		_emission_mat.emission = Color(0.1, 0.3, 0.7)
		_emission_mat.emission_energy_multiplier = 0.6
		_emission_mat.roughness = 0.5
		_mesh_instance.material_override = _emission_mat
		_damage_mat = _emission_mat

func _process(delta: float) -> void:
	if not GameManager.is_game_over:
		current_hp = min(current_hp + delta, data.max_hp)

	super._process(delta)

	_pulse_time += delta * 2.0
	if _pulse_time > TAU:
		_pulse_time -= TAU

	# Pulse emission
	if _emission_mat:
		var pulse := (sin(_pulse_time) + 1.0) * 0.5
		var energy := 0.4 + pulse * 0.5
		_emission_mat.emission_energy_multiplier = energy

func take_damage(amount: float) -> void:
	super.take_damage(amount)

func die() -> void:
	GameManager.trigger_game_over()
