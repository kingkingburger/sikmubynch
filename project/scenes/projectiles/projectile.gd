extends Node3D

var target: Node3D
var damage: float = 0.0
var speed: float = 25.0
var trait_effects: Dictionary = {}

var _trail_mesh: MeshInstance3D

func _ready() -> void:
	# Main projectile
	var mesh := MeshInstance3D.new()
	var glb: Mesh = BaseBuilding._load_glb("effects", "projectile")
	if glb:
		mesh.mesh = glb
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)

	# Trail mesh
	_trail_mesh = MeshInstance3D.new()
	var trail := CylinderMesh.new()
	trail.top_radius = 0.04
	trail.bottom_radius = 0.15
	trail.height = 0.6
	_trail_mesh.mesh = trail
	var trail_mat := StandardMaterial3D.new()
	trail_mat.albedo_color = Color(1.0, 0.7, 0.1, 0.6)
	trail_mat.emission_enabled = true
	trail_mat.emission = Color(1.0, 0.6, 0.1)
	trail_mat.emission_energy_multiplier = 2.0
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mesh.material_override = trail_mat
	add_child(_trail_mesh)

	# Particle trail
	var trail_particles := CPUParticles3D.new()
	trail_particles.emitting = true
	trail_particles.amount = 12
	trail_particles.lifetime = 0.15
	trail_particles.explosiveness = 0.0
	trail_particles.direction = Vector3.ZERO
	trail_particles.spread = 15.0
	trail_particles.initial_velocity_min = 0.0
	trail_particles.initial_velocity_max = 0.3
	trail_particles.gravity = Vector3.ZERO
	trail_particles.scale_amount_min = 0.3
	trail_particles.scale_amount_max = 0.6
	trail_particles.color = Color(1.0, 0.6, 0.1, 0.6)
	var tmesh := SphereMesh.new()
	tmesh.radius = 0.03
	tmesh.height = 0.06
	trail_particles.mesh = tmesh
	add_child(trail_particles)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var target_pos := target.global_position + Vector3(0.0, 0.25, 0.0)
	var to_target := target_pos - global_position
	var dist := to_target.length()
	var move_dist := speed * delta

	if move_dist >= dist:
		_on_hit()
		queue_free()
		return

	var direction := to_target.normalized()
	global_position += direction * move_dist

	# Orient trail opposite to movement direction
	if _trail_mesh and direction.length() > 0.01:
		_trail_mesh.look_at(global_position - direction, Vector3.UP)
		_trail_mesh.rotation.x += PI / 2.0

func _on_hit() -> void:
	if not is_instance_valid(target):
		return

	# Impact particles
	_spawn_impact()

	# Apply damage
	if target.has_method("take_damage"):
		target.take_damage(damage)

	# Apply synergy status effects
	if trait_effects.is_empty():
		return

	if trait_effects.has("burn_dps") and target.has_method("apply_burn"):
		target.apply_burn(trait_effects["burn_dps"])
	if trait_effects.has("slow_percent") and target.has_method("apply_slow"):
		target.apply_slow(trait_effects["slow_percent"])
	if trait_effects.has("freeze_chance") and target.has_method("apply_stun"):
		if randf() < trait_effects["freeze_chance"]:
			target.apply_stun(1.0)
	if trait_effects.has("poison_dps") and target.has_method("apply_poison"):
		target.apply_poison(trait_effects["poison_dps"])
	if trait_effects.has("chain_count"):
		var chain_count: int = trait_effects["chain_count"]
		_chain_lightning(chain_count, damage * 0.5)
	if trait_effects.has("stun_chance") and target.has_method("apply_stun"):
		if randf() < trait_effects["stun_chance"]:
			target.apply_stun(0.3)

func _spawn_impact() -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.25
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 50.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0, -12, 0)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.7
	particles.color = Color(1.0, 0.8, 0.2)
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.04
	pmesh.height = 0.08
	particles.mesh = pmesh
	particles.position = global_position
	get_parent().add_child(particles)
	var tw := particles.create_tween()
	tw.tween_callback(particles.queue_free).set_delay(0.8)

func _chain_lightning(count: int, chain_dmg: float) -> void:
	var hit_targets: Array = [target]
	var current := target

	for i in count:
		var nearby := SpatialGrid.find_in_range(current.global_position, "enemies", 4.0)
		var nearest: Node3D = null
		var nearest_dist_sq := 16.0
		for enemy in nearby:
			if enemy in hit_targets:
				continue
			var dist_sq := current.global_position.distance_squared_to(enemy.global_position)
			if dist_sq < nearest_dist_sq:
				nearest = enemy
				nearest_dist_sq = dist_sq
		if nearest:
			if nearest.has_method("take_damage"):
				nearest.take_damage(chain_dmg)
			hit_targets.append(nearest)
			current = nearest
		else:
			break
