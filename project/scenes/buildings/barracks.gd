extends BaseBuilding

const SPAWN_INTERVAL := 8.0

var _spawn_timer: float = SPAWN_INTERVAL
var _unit_scene: PackedScene

var _unit_templates: Array = []

func _ready() -> void:
	super._ready()
	_unit_scene = load("res://scenes/units/unit.tscn")
	_init_unit_templates()
	_setup_banner()

func _get_height() -> float:
	return 0.8

func _init_unit_templates() -> void:
	var soldier := UnitData.new()
	soldier.unit_name = "Soldier"
	soldier.unit_type = UnitData.UnitType.SOLDIER
	soldier.max_hp = 80.0
	soldier.dps = 10.0
	soldier.speed = 4.0
	soldier.attack_range = 1.2
	soldier.color = Color(0.3, 0.5, 0.9)
	_unit_templates.append(soldier)

	var archer := UnitData.new()
	archer.unit_name = "Archer"
	archer.unit_type = UnitData.UnitType.ARCHER
	archer.max_hp = 40.0
	archer.dps = 12.0
	archer.speed = 3.5
	archer.attack_range = 5.0
	archer.color = Color(0.2, 0.8, 0.4)
	_unit_templates.append(archer)

	var tanker := UnitData.new()
	tanker.unit_name = "Tanker"
	tanker.unit_type = UnitData.UnitType.TANKER
	tanker.max_hp = 200.0
	tanker.dps = 5.0
	tanker.speed = 2.5
	tanker.attack_range = 1.5
	tanker.color = Color(0.7, 0.7, 0.75)
	_unit_templates.append(tanker)

	var bomber := UnitData.new()
	bomber.unit_name = "Bomber"
	bomber.unit_type = UnitData.UnitType.BOMBER
	bomber.max_hp = 30.0
	bomber.dps = 25.0
	bomber.speed = 5.0
	bomber.attack_range = 1.5
	bomber.color = Color(0.95, 0.5, 0.15)
	_unit_templates.append(bomber)

func _setup_banner() -> void:
	var glb := BaseBuilding._load_glb("buildings", "barracks_banner")
	if glb:
		var banner_mesh := MeshInstance3D.new()
		banner_mesh.mesh = glb
		banner_mesh.position = Vector3(0.3, 1.05, 0.3)
		add_child(banner_mesh)
		return
	# Fallback: primitive banner
	var banner := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.5, 0.08)
	banner.mesh = box
	banner.position = Vector3(0.3, 1.05, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 0.9)
	mat.roughness = 0.5
	banner.material_override = mat
	add_child(banner)

	var flag := MeshInstance3D.new()
	var flag_box := BoxMesh.new()
	flag_box.size = Vector3(0.25, 0.15, 0.04)
	flag.mesh = flag_box
	flag.position = Vector3(0.17, 1.22, 0.3)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.3, 0.5, 0.9)
	flag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flag.material_override = flag_mat
	add_child(flag)

func _process(delta: float) -> void:
	super._process(delta)
	if GameManager.is_game_over:
		return

	var effective_interval := SPAWN_INTERVAL / (1.0 + BaseBuilding.LEVEL_BONUS * (level - 1))
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_unit()
		_spawn_timer = effective_interval

func _spawn_unit() -> void:
	var template: UnitData = _unit_templates[randi() % _unit_templates.size()]
	var unit: CharacterBody3D = _unit_scene.instantiate()
	unit.set("data", template)

	# Spawn near the barracks
	var offset := Vector3(
		randf_range(-1.5, 1.5),
		0.0,
		randf_range(-1.5, 1.5)
	)
	var spawn_pos := global_position + offset
	spawn_pos.x = clampf(spawn_pos.x, 1.0, 63.0)
	spawn_pos.z = clampf(spawn_pos.z, 1.0, 63.0)
	spawn_pos.y = 0.0
	unit.position = spawn_pos

	get_parent().add_child(unit)
