extends BaseBuilding

var _mine_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_setup_drill()

func _get_height() -> float:
	return 0.6

func _setup_drill() -> void:
	var drill := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.12
	cyl.height = 0.4
	drill.mesh = cyl
	drill.position = Vector3(0.0, 0.8, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.85, 0.9)
	mat.roughness = 0.4
	drill.material_override = mat
	add_child(drill)

func _process(delta: float) -> void:
	super._process(delta)
	if GameManager.is_game_over:
		return
	if not data:
		return

	var rate := data.mineral_per_sec * (1.0 + BaseBuilding.LEVEL_BONUS * (level - 1))
	_mine_timer += delta * rate
	while _mine_timer >= 1.0:
		_mine_timer -= 1.0
		GameManager.add_minerals(1)
