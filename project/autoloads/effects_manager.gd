extends Node

## 파티클/비주얼 이펙트 팩토리. 재사용 가능한 이펙트 생성 함수 모음.

var _tree_root: Node

func _ready() -> void:
	_tree_root = get_tree().root

func _get_scene_root() -> Node:
	var current := get_tree().current_scene
	return current if current else _tree_root

# ── Helpers ──────────────────────────────────────────────────────

func _make_emissive_mat(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _make_sphere_mesh(radius: float = 0.05) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 6
	m.rings = 3
	return m

func _make_box_mesh(size: float = 0.08) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(size, size, size)
	return m

func _auto_free(node: Node, delay: float) -> void:
	var tw := node.create_tween()
	tw.tween_callback(node.queue_free).set_delay(delay)

# ── Building Effects ─────────────────────────────────────────────

func spawn_build_effect(pos: Vector3, color: Color = Color(0.7, 0.6, 0.3)) -> void:
	var root := _get_scene_root()

	# Dust puff
	var dust := CPUParticles3D.new()
	dust.emitting = true
	dust.one_shot = true
	dust.amount = 15
	dust.lifetime = 0.5
	dust.explosiveness = 0.85
	dust.direction = Vector3.UP
	dust.spread = 120.0
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 3.5
	dust.gravity = Vector3(0, -4, 0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.2
	dust.color = Color(0.5, 0.45, 0.3, 0.6)
	dust.mesh = _make_sphere_mesh(0.06)
	dust.position = pos + Vector3(0, 0.2, 0)
	root.add_child(dust)

	# Sparkle confirmation
	var sparkle := CPUParticles3D.new()
	sparkle.emitting = true
	sparkle.one_shot = true
	sparkle.amount = 8
	sparkle.lifetime = 0.6
	sparkle.explosiveness = 0.7
	sparkle.direction = Vector3.UP
	sparkle.spread = 40.0
	sparkle.initial_velocity_min = 2.0
	sparkle.initial_velocity_max = 5.0
	sparkle.gravity = Vector3(0, -2, 0)
	sparkle.scale_amount_min = 0.2
	sparkle.scale_amount_max = 0.5
	sparkle.color = color
	sparkle.mesh = _make_sphere_mesh(0.03)
	sparkle.material_override = _make_emissive_mat(color, 2.5)
	sparkle.position = pos + Vector3(0, 0.3, 0)
	root.add_child(sparkle)

	_auto_free(dust, 1.2)
	_auto_free(sparkle, 1.2)

func spawn_destroy_effect(pos: Vector3, color: Color = Color(1.0, 0.4, 0.1)) -> void:
	var root := _get_scene_root()

	# Debris chunks
	var debris := CPUParticles3D.new()
	debris.emitting = true
	debris.one_shot = true
	debris.amount = 20
	debris.lifetime = 0.7
	debris.explosiveness = 0.9
	debris.direction = Vector3.UP
	debris.spread = 160.0
	debris.initial_velocity_min = 3.0
	debris.initial_velocity_max = 7.0
	debris.gravity = Vector3(0, -12, 0)
	debris.scale_amount_min = 0.4
	debris.scale_amount_max = 1.0
	debris.color = Color(0.4, 0.35, 0.25)
	debris.mesh = _make_box_mesh(0.08)
	debris.position = pos + Vector3(0, 0.5, 0)
	root.add_child(debris)

	# Fire burst
	var fire := CPUParticles3D.new()
	fire.emitting = true
	fire.one_shot = true
	fire.amount = 12
	fire.lifetime = 0.5
	fire.explosiveness = 0.8
	fire.direction = Vector3.UP
	fire.spread = 60.0
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 3.0
	fire.gravity = Vector3(0, 2, 0)
	fire.scale_amount_min = 0.5
	fire.scale_amount_max = 1.5
	fire.color = color
	fire.mesh = _make_sphere_mesh(0.06)
	fire.material_override = _make_emissive_mat(color, 4.0)
	fire.position = pos + Vector3(0, 0.3, 0)
	root.add_child(fire)

	# Smoke
	var smoke := CPUParticles3D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 8
	smoke.lifetime = 1.2
	smoke.explosiveness = 0.5
	smoke.direction = Vector3.UP
	smoke.spread = 30.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.5
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.5
	smoke.color = Color(0.2, 0.2, 0.2, 0.4)
	smoke.mesh = _make_sphere_mesh(0.1)
	smoke.position = pos + Vector3(0, 0.5, 0)
	root.add_child(smoke)

	_auto_free(debris, 1.5)
	_auto_free(fire, 1.5)
	_auto_free(smoke, 2.5)

# ── Combat Effects ───────────────────────────────────────────────

func spawn_explosion_effect(pos: Vector3, radius: float = 3.0) -> void:
	var root := _get_scene_root()

	# Core flash (expanding ring)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.6
	torus.rings = 12
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = _make_emissive_mat(Color(1.0, 0.6, 0.1), 6.0)
	ring.position = pos + Vector3(0, 0.3, 0)
	ring.rotation.x = PI / 2.0
	root.add_child(ring)

	var ring_tw := ring.create_tween()
	ring_tw.set_parallel(true)
	var target_scale := radius * 0.5
	ring_tw.tween_property(ring, "scale", Vector3(target_scale, target_scale, target_scale), 0.3).set_ease(Tween.EASE_OUT)
	ring_tw.tween_property(ring.material_override, "albedo_color", Color(1.0, 0.3, 0.0, 0.0), 0.3)
	ring_tw.chain().tween_callback(ring.queue_free)

	# Fire particles
	var fire := CPUParticles3D.new()
	fire.emitting = true
	fire.one_shot = true
	fire.amount = 35
	fire.lifetime = 0.6
	fire.explosiveness = 0.95
	fire.direction = Vector3.UP
	fire.spread = 180.0
	fire.initial_velocity_min = 4.0
	fire.initial_velocity_max = 10.0
	fire.gravity = Vector3(0, -6, 0)
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.8
	fire.color = Color(1.0, 0.5, 0.1)
	fire.mesh = _make_sphere_mesh(0.07)
	fire.material_override = _make_emissive_mat(Color(1.0, 0.5, 0.1), 5.0)
	fire.position = pos + Vector3(0, 0.3, 0)
	root.add_child(fire)

	# Ember sparks
	var embers := CPUParticles3D.new()
	embers.emitting = true
	embers.one_shot = true
	embers.amount = 20
	embers.lifetime = 1.0
	embers.explosiveness = 0.8
	embers.direction = Vector3.UP
	embers.spread = 180.0
	embers.initial_velocity_min = 2.0
	embers.initial_velocity_max = 6.0
	embers.gravity = Vector3(0, -3, 0)
	embers.scale_amount_min = 0.1
	embers.scale_amount_max = 0.3
	embers.color = Color(1.0, 0.8, 0.2)
	embers.mesh = _make_sphere_mesh(0.02)
	embers.material_override = _make_emissive_mat(Color(1.0, 0.8, 0.2), 4.0)
	embers.position = pos + Vector3(0, 0.5, 0)
	root.add_child(embers)

	_auto_free(fire, 1.5)
	_auto_free(embers, 2.0)

func spawn_crit_effect(pos: Vector3) -> void:
	var root := _get_scene_root()

	# Quick radial burst
	var burst := CPUParticles3D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 16
	burst.lifetime = 0.3
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 6.0
	burst.gravity = Vector3.ZERO
	burst.scale_amount_min = 0.2
	burst.scale_amount_max = 0.5
	burst.color = Color(1.0, 1.0, 0.3)
	burst.mesh = _make_sphere_mesh(0.03)
	burst.material_override = _make_emissive_mat(Color(1.0, 1.0, 0.3), 5.0)
	burst.position = pos + Vector3(0, 0.4, 0)
	root.add_child(burst)

	# Expanding ring
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.2
	torus.rings = 8
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _make_emissive_mat(Color(1.0, 0.9, 0.3), 4.0)
	ring.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.position = pos + Vector3(0, 0.3, 0)
	ring.rotation.x = PI / 2.0
	root.add_child(ring)

	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.0, 3.0, 3.0), 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring.material_override, "albedo_color", Color(1.0, 0.9, 0.3, 0.0), 0.25)
	tw.chain().tween_callback(ring.queue_free)

	_auto_free(burst, 1.0)

func spawn_hit_impact(pos: Vector3, color: Color = Color(1.0, 0.8, 0.2)) -> void:
	var root := _get_scene_root()

	var sparks := CPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 10
	sparks.lifetime = 0.2
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 5.0
	sparks.gravity = Vector3(0, -15, 0)
	sparks.scale_amount_min = 0.15
	sparks.scale_amount_max = 0.4
	sparks.color = color
	sparks.mesh = _make_sphere_mesh(0.03)
	sparks.material_override = _make_emissive_mat(color, 3.5)
	sparks.position = pos
	root.add_child(sparks)

	_auto_free(sparks, 0.8)

# ── Meta Effects ─────────────────────────────────────────────────

func spawn_synergy_effect(pos: Vector3, color: Color) -> void:
	var root := _get_scene_root()

	# Ascending spiral particles
	var spiral := CPUParticles3D.new()
	spiral.emitting = true
	spiral.one_shot = true
	spiral.amount = 24
	spiral.lifetime = 0.8
	spiral.explosiveness = 0.6
	spiral.direction = Vector3.UP
	spiral.spread = 30.0
	spiral.initial_velocity_min = 3.0
	spiral.initial_velocity_max = 6.0
	spiral.gravity = Vector3(0, 1, 0)
	spiral.scale_amount_min = 0.3
	spiral.scale_amount_max = 0.7
	spiral.color = color
	spiral.mesh = _make_sphere_mesh(0.04)
	spiral.material_override = _make_emissive_mat(color, 4.0)
	spiral.position = pos + Vector3(0, 0.2, 0)
	root.add_child(spiral)

	# Ground ring
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.4
	torus.rings = 10
	torus.ring_segments = 10
	ring.mesh = torus
	ring.material_override = _make_emissive_mat(color, 3.0)
	ring.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.position = pos + Vector3(0, 0.1, 0)
	ring.rotation.x = PI / 2.0
	root.add_child(ring)

	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(4.0, 4.0, 4.0), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring.material_override, "albedo_color", Color(color.r, color.g, color.b, 0.0), 0.6)
	tw.chain().tween_callback(ring.queue_free)

	_auto_free(spiral, 1.5)

func spawn_wave_warning(center: Vector3, map_size: float = 256.0) -> void:
	var root := _get_scene_root()
	var warn_color := Color(1.0, 0.2, 0.1)

	# Particles at 4 edges
	for i in 4:
		var edge_pos: Vector3
		match i:
			0: edge_pos = Vector3(center.x, 0.5, 0)
			1: edge_pos = Vector3(map_size, 0.5, center.z)
			2: edge_pos = Vector3(center.x, 0.5, map_size)
			3: edge_pos = Vector3(0, 0.5, center.z)

		var warn := CPUParticles3D.new()
		warn.emitting = true
		warn.one_shot = true
		warn.amount = 20
		warn.lifetime = 1.5
		warn.explosiveness = 0.3
		warn.direction = Vector3.UP
		warn.spread = 20.0
		warn.initial_velocity_min = 1.0
		warn.initial_velocity_max = 3.0
		warn.gravity = Vector3(0, -1, 0)
		warn.scale_amount_min = 0.3
		warn.scale_amount_max = 0.8
		warn.color = warn_color
		warn.mesh = _make_sphere_mesh(0.05)
		warn.material_override = _make_emissive_mat(warn_color, 3.0)
		warn.position = edge_pos
		root.add_child(warn)
		_auto_free(warn, 3.0)

func spawn_reward_sparkle(pos: Vector3) -> void:
	var root := _get_scene_root()
	var gold := Color(1.0, 0.85, 0.2)

	var sparkle := CPUParticles3D.new()
	sparkle.emitting = true
	sparkle.one_shot = true
	sparkle.amount = 20
	sparkle.lifetime = 0.7
	sparkle.explosiveness = 0.7
	sparkle.direction = Vector3.UP
	sparkle.spread = 60.0
	sparkle.initial_velocity_min = 2.0
	sparkle.initial_velocity_max = 5.0
	sparkle.gravity = Vector3(0, -3, 0)
	sparkle.scale_amount_min = 0.1
	sparkle.scale_amount_max = 0.4
	sparkle.color = gold
	sparkle.mesh = _make_sphere_mesh(0.025)
	sparkle.material_override = _make_emissive_mat(gold, 4.0)
	sparkle.position = pos
	root.add_child(sparkle)

	_auto_free(sparkle, 1.5)

func spawn_heal_effect(pos: Vector3) -> void:
	var root := _get_scene_root()
	var heal_color := Color(0.2, 1.0, 0.4)

	var particles := CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.8
	particles.explosiveness = 0.5
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0, 0.5, 0)
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.5
	particles.color = heal_color
	particles.mesh = _make_sphere_mesh(0.03)
	particles.material_override = _make_emissive_mat(heal_color, 3.0)
	particles.position = pos + Vector3(0, 0.3, 0)
	root.add_child(particles)

	_auto_free(particles, 1.5)

# ── Status Effect Visuals ────────────────────────────────────────

func spawn_burn_tick(pos: Vector3) -> void:
	var root := _get_scene_root()
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 4
	p.lifetime = 0.3
	p.explosiveness = 0.8
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 1, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	p.color = Color(1.0, 0.4, 0.1)
	p.mesh = _make_sphere_mesh(0.025)
	p.material_override = _make_emissive_mat(Color(1.0, 0.4, 0.1), 3.0)
	p.position = pos + Vector3(0, 0.4, 0)
	root.add_child(p)
	_auto_free(p, 0.8)

func spawn_poison_tick(pos: Vector3) -> void:
	var root := _get_scene_root()
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 3
	p.lifetime = 0.4
	p.explosiveness = 0.7
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.4
	p.color = Color(0.3, 0.9, 0.1)
	p.mesh = _make_sphere_mesh(0.025)
	p.material_override = _make_emissive_mat(Color(0.3, 0.9, 0.1), 2.5)
	p.position = pos + Vector3(0, 0.5, 0)
	root.add_child(p)
	_auto_free(p, 0.8)

func spawn_freeze_effect(pos: Vector3) -> void:
	var root := _get_scene_root()
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 8
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.gravity = Vector3(0, -2, 0)
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.5
	p.color = Color(0.4, 0.8, 1.0)
	p.mesh = _make_box_mesh(0.04)
	p.material_override = _make_emissive_mat(Color(0.4, 0.8, 1.0), 3.0)
	p.position = pos + Vector3(0, 0.3, 0)
	root.add_child(p)
	_auto_free(p, 1.0)
