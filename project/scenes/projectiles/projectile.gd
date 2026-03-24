extends Node3D

var target: Node3D
var damage: float = 0.0
var speed: float = 25.0
var trait_effects: Dictionary = {}

var _trail_mesh: MeshInstance3D

func _ready() -> void:
	# Main projectile — larger and brighter
	var mesh := MeshInstance3D.new()
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

	# Trail — stretched cylinder behind projectile
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

	# Apply damage
	if target.has_method("take_damage"):
		target.take_damage(damage)

	# Apply synergy status effects
	if trait_effects.is_empty():
		return

	# Burn (Fire)
	if trait_effects.has("burn_dps") and target.has_method("apply_burn"):
		target.apply_burn(trait_effects["burn_dps"])

	# Slow (Ice)
	if trait_effects.has("slow_percent") and target.has_method("apply_slow"):
		target.apply_slow(trait_effects["slow_percent"])

	# Freeze chance (Ice T2)
	if trait_effects.has("freeze_chance") and target.has_method("apply_stun"):
		if randf() < trait_effects["freeze_chance"]:
			target.apply_stun(1.0)

	# Poison (Poison)
	if trait_effects.has("poison_dps") and target.has_method("apply_poison"):
		target.apply_poison(trait_effects["poison_dps"])

	# Chain lightning (Electric)
	if trait_effects.has("chain_count"):
		var chain_count: int = trait_effects["chain_count"]
		_chain_lightning(chain_count, damage * 0.5)

	# Stun chance (Electric T2)
	if trait_effects.has("stun_chance") and target.has_method("apply_stun"):
		if randf() < trait_effects["stun_chance"]:
			target.apply_stun(0.3)

func _chain_lightning(count: int, chain_dmg: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var hit_targets: Array = [target]
	var current := target

	for i in count:
		var nearest: Node3D = null
		var nearest_dist := INF
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy in hit_targets:
				continue
			if enemy.get("_dead"):
				continue
			var dist := current.global_position.distance_to(enemy.global_position)
			if dist <= 4.0 and dist < nearest_dist:
				nearest = enemy
				nearest_dist = dist
		if nearest:
			if nearest.has_method("take_damage"):
				nearest.take_damage(chain_dmg)
			hit_targets.append(nearest)
			current = nearest
		else:
			break
