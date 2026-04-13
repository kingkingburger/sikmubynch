extends Node

## 파티클/비주얼 이펙트 팩토리.

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
	node.create_tween().tween_callback(node.queue_free).set_delay(delay)

func _spawn_burst(pos: Vector3, color: Color, amount: int = 10,
		lifetime: float = 0.5, speed_min: float = 1.0, speed_max: float = 3.0,
		spread: float = 60.0, gravity: Vector3 = Vector3(0, -3, 0),
		scale_min: float = 0.2, scale_max: float = 0.5,
		mesh_radius: float = 0.04, energy: float = 3.0,
		emissive: bool = true, explosiveness: float = 0.8,
		use_box: bool = false, free_after: float = -1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = explosiveness
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	p.mesh = _make_box_mesh(mesh_radius) if use_box else _make_sphere_mesh(mesh_radius)
	if emissive:
		p.material_override = _make_emissive_mat(color, energy)
	p.position = pos
	get_tree().current_scene.add_child(p)
	_auto_free(p, free_after if free_after > 0 else lifetime + 0.5)
	return p

func _spawn_ring(pos: Vector3, color: Color, target_scale: float = 3.0,
		duration: float = 0.3, energy: float = 4.0,
		inner: float = 0.2, outer: float = 0.4) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 10
	torus.ring_segments = 10
	ring.mesh = torus
	ring.material_override = _make_emissive_mat(color, energy)
	ring.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.position = pos
	ring.rotation.x = PI / 2.0
	get_tree().current_scene.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	var sv := Vector3(target_scale, target_scale, target_scale)
	tw.tween_property(ring, "scale", sv, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring.material_override, "albedo_color",
		Color(color.r, color.g, color.b, 0.0), duration)
	tw.chain().tween_callback(ring.queue_free)

# ── Building Effects ─────────────────────────────────────────────

func spawn_build_effect(pos: Vector3, color: Color = Color(0.7, 0.6, 0.3)) -> void:
	_spawn_burst(pos + Vector3(0, 0.2, 0), Color(0.5, 0.45, 0.3, 0.6),
		15, 0.5, 1.5, 3.5, 120.0, Vector3(0, -4, 0), 0.6, 1.2, 0.06, 2.5, false, 0.85)
	_spawn_burst(pos + Vector3(0, 0.3, 0), color,
		8, 0.6, 2.0, 5.0, 40.0, Vector3(0, -2, 0), 0.2, 0.5, 0.03, 2.5, true, 0.7)

func spawn_destroy_effect(pos: Vector3, color: Color = Color(1.0, 0.4, 0.1)) -> void:
	# Debris
	_spawn_burst(pos + Vector3(0, 0.5, 0), Color(0.4, 0.35, 0.25),
		20, 0.7, 3.0, 7.0, 160.0, Vector3(0, -12, 0), 0.4, 1.0, 0.08, 3.0, false, 0.9,
		true, 1.5)
	# Fire
	_spawn_burst(pos + Vector3(0, 0.3, 0), color,
		12, 0.5, 1.0, 3.0, 60.0, Vector3(0, 2, 0), 0.5, 1.5, 0.06, 4.0, true, 0.8)
	# Smoke
	_spawn_burst(pos + Vector3(0, 0.5, 0), Color(0.2, 0.2, 0.2, 0.4),
		8, 1.2, 0.5, 1.5, 30.0, Vector3(0, 0.5, 0), 1.0, 2.5, 0.1, 2.0, false, 0.5,
		false, 2.5)

# ── Combat Effects ───────────────────────────────────────────────

func spawn_explosion_effect(pos: Vector3, radius: float = 3.0) -> void:
	_spawn_ring(pos + Vector3(0, 0.3, 0), Color(1.0, 0.6, 0.1),
		radius * 0.5, 0.3, 6.0, 0.3, 0.6)
	# Fire
	_spawn_burst(pos + Vector3(0, 0.3, 0), Color(1.0, 0.5, 0.1),
		35, 0.6, 4.0, 10.0, 180.0, Vector3(0, -6, 0), 0.6, 1.8, 0.07, 5.0, true, 0.95)
	# Embers
	_spawn_burst(pos + Vector3(0, 0.5, 0), Color(1.0, 0.8, 0.2),
		20, 1.0, 2.0, 6.0, 180.0, Vector3(0, -3, 0), 0.1, 0.3, 0.02, 4.0, true, 0.8)

func spawn_crit_effect(pos: Vector3) -> void:
	_spawn_burst(pos + Vector3(0, 0.4, 0), Color(1.0, 1.0, 0.3),
		16, 0.3, 3.0, 6.0, 180.0, Vector3.ZERO, 0.2, 0.5, 0.03, 5.0, true, 1.0)
	_spawn_ring(pos + Vector3(0, 0.3, 0), Color(1.0, 0.9, 0.3), 3.0, 0.25, 4.0, 0.1, 0.2)

func spawn_hit_impact(pos: Vector3, color: Color = Color(1.0, 0.8, 0.2)) -> void:
	_spawn_burst(pos, color,
		10, 0.2, 2.5, 5.0, 70.0, Vector3(0, -15, 0), 0.15, 0.4, 0.03, 3.5, true, 1.0)

# ── Meta Effects ─────────────────────────────────────────────────

func spawn_synergy_effect(pos: Vector3, color: Color) -> void:
	_spawn_burst(pos + Vector3(0, 0.2, 0), color,
		24, 0.8, 3.0, 6.0, 30.0, Vector3(0, 1, 0), 0.3, 0.7, 0.04, 4.0, true, 0.6)
	_spawn_ring(pos + Vector3(0, 0.1, 0), color, 4.0, 0.5, 3.0)

func spawn_reward_sparkle(pos: Vector3) -> void:
	_spawn_burst(pos, Color(1.0, 0.85, 0.2),
		20, 0.7, 2.0, 5.0, 60.0, Vector3(0, -3, 0), 0.1, 0.4, 0.025, 4.0, true, 0.7)

# ── Status Effects ───────────────────────────────────────────────

func _spawn_status_tick(pos: Vector3, color: Color, amount: int,
		lifetime: float, spread: float, speed_min: float, speed_max: float,
		gravity: Vector3, use_box: bool = false) -> void:
	_spawn_burst(pos, color, amount, lifetime, speed_min, speed_max, spread,
		gravity, 0.15, 0.4, 0.025, 3.0, true, 0.8, use_box)

func spawn_burn_tick(pos: Vector3) -> void:
	_spawn_status_tick(pos + Vector3(0, 0.4, 0), Color(1.0, 0.4, 0.1),
		4, 0.3, 20.0, 1.0, 2.0, Vector3(0, 1, 0))

func spawn_poison_tick(pos: Vector3) -> void:
	_spawn_status_tick(pos + Vector3(0, 0.5, 0), Color(0.3, 0.9, 0.1),
		3, 0.4, 25.0, 0.5, 1.5, Vector3(0, 0.3, 0))

func spawn_freeze_effect(pos: Vector3) -> void:
	_spawn_status_tick(pos + Vector3(0, 0.3, 0), Color(0.4, 0.8, 1.0),
		8, 0.5, 40.0, 1.0, 2.5, Vector3(0, -2, 0), true)

# ── Death Effects ────────────────────────────────────────────────

func spawn_enemy_death(pos: Vector3, color: Color, is_exploder: bool = false) -> void:
	if is_exploder:
		_spawn_burst(pos + Vector3(0, 0.3, 0), Color(1.0, 0.5, 0.1),
			30, 0.6, 4.0, 8.0, 180.0, Vector3(0, -8, 0), 1.0, 2.0, 0.05, 3.0,
			false, 0.9, false, 1.5)
	else:
		_spawn_burst(pos + Vector3(0, 0.3, 0), color,
			12, 0.4, 2.0, 5.0, 80.0, Vector3(0, -8, 0), 0.5, 1.0, 0.05, 3.0,
			false, 0.9, false, 1.5)

func spawn_unit_death(pos: Vector3, color: Color) -> void:
	_spawn_burst(pos + Vector3(0, 0.3, 0), color,
		10, 0.4, 2.0, 4.0, 70.0, Vector3(0, -8, 0), 0.4, 0.8, 0.04, 3.0,
		false, 0.9, false, 1.0)
