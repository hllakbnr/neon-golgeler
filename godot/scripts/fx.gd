extends RefCounted
class_name Fx
## Küçük görsel efektler: kıvılcım, su fıskiyesi, çöp parçaları, elektrik arkı, toz, para parıltısı.

static func _root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree else null


static func _particles(pos: Vector3, amount: int, life: float, mat: Material, mesh_size: float, one_shot := true) -> CPUParticles3D:
	var r := _root()
	if r == null:
		return null
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	var qm := QuadMesh.new()
	qm.size = Vector2(mesh_size, mesh_size)
	qm.material = mat
	p.mesh = qm
	r.add_child(p)
	p.global_position = pos
	p.emitting = true
	if one_shot:
		r.get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	return m


static func sparks(pos: Vector3, c: Color) -> void:
	var p := _particles(pos, 40, 0.7, _glow_mat(c), 0.06)
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2


static func debris(pos: Vector3, c: Color, n := 10) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var p := _particles(pos, n, 1.6, m, 0.18)
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9, 0)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0


static func dust(pos: Vector3, scale := 1.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.7, 0.62, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var p := _particles(pos, 24, 1.2, m, 0.6 * scale)
	if p == null:
		return
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.6 * scale
	p.emission_ring_inner_radius = 0.2
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0 * scale
	p.gravity = Vector3(0, -1, 0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.6))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g


static func fountain(pos: Vector3, secs: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.88, 1.0, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.roughness = 0.1
	var p := _particles(pos, 160, 1.3, m, 0.16, false)
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_max = 1.6
	p.get_tree().create_timer(secs).timeout.connect(func():
		if is_instance_valid(p):
			p.emitting = false
			p.get_tree().create_timer(1.5).timeout.connect(p.queue_free))


static func bolt(a: Vector3, b: Vector3, c: Color, life := 0.18) -> void:
	var r := _root()
	if r == null:
		return
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 6.0
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, m)
	var n := 10
	for k in n + 1:
		var t := float(k) / n
		var off := Vector3.ZERO
		if k > 0 and k < n:
			off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.25
		im.surface_add_vertex(a.lerp(b, t) + off)
	im.surface_end()
	r.add_child(mi)
	r.get_tree().create_timer(life).timeout.connect(mi.queue_free)


static func ring(pos: Vector3, c: Color, radius: float, life := 0.5) -> void:
	## yere yayılan şok halkası
	var r := _root()
	if r == null:
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 32
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 4.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	r.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.2, 0.3, 0.2)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), life).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)
