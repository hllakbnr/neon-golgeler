extends Node3D
class_name World
## Gerçekçi şehir dilimi: yollar, kaldırımlar, binalar, palmiyeler, lambalar, trafik ışıkları,
## gökyüzü/gün-gece döngüsü ve ortam ayarları. Varlıklar Poly Haven'dan (CC0) gelirse
## onları kullanır, gelmezse prosedürel yedekler devreye girer.

const CELL := 80.0
const ROAD_W := 12.0
const WALK := 5.0
const GRID := 2            # -GRID..GRID yol çizgileri → 4x4 blok
const BLOCK := CELL - ROAD_W - WALK * 2.0

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var street_lights: Array[OmniLight3D] = []
var signal_lights: Array = []   # [mesh_red, mesh_green, axis]
var rng := RandomNumberGenerator.new()
var _sky_t := 0.0
var night := 0.0
var blocks: Array[Rect2] = []   # yayalar ve mini harita için

var b_shader: Shader = preload("res://shaders/building.gdshader")
var r_shader: Shader = preload("res://shaders/road.gdshader")
var s_shader: Shader = preload("res://shaders/sky.gdshader")
var f_shader: Shader = preload("res://shaders/frond.gdshader")


func build() -> void:
	rng.seed = 20261127
	_environment()
	_ground()
	for i in range(-GRID, GRID):
		for j in range(-GRID, GRID):
			_block(Vector2((i + 0.5) * CELL, (j + 0.5) * CELL))
	_street_furniture()
	_skyline()
	update_time(Game.time_of_day, true)


# ---------------------------------------------------------------- ortam
func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = s_shader
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	apply_quality()
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.8
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.12
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 120.0
	add_child(moon)
	Game.settings_changed.connect(apply_quality)


func apply_quality() -> void:
	if env == null:
		return
	var q: int = Game.settings.quality
	env.sdfgi_enabled = Game.settings.sdfgi and q >= 1
	env.sdfgi_cascades = 4 if q >= 2 else 3
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.9
	env.ssr_enabled = Game.settings.ssr and q >= 1
	env.ssr_max_steps = 48
	env.ssil_enabled = q >= 2
	env.ssao_enabled = q >= 1
	env.volumetric_fog_enabled = q >= 2
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_length = 120.0
	env.volumetric_fog_ambient_inject = 0.2
	if sun:
		sun.directional_shadow_max_distance = [90.0, 160.0, 220.0][q]


func update_time(h: float, force := false) -> void:
	# güneş açısı: 6:00 doğuş, 18:00 batış
	var ang := (h - 6.0) / 12.0 * PI
	var elev := sin(ang)
	var day: float = clamp(elev * 3.0 + 0.15, 0.0, 1.0)
	night = 1.0 - clamp(elev * 4.0 + 0.35, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("night", night)
	Game.night = night
	var sun_dir := Vector3(cos(ang), max(elev, -0.3), 0.35).normalized()
	sun.look_at_from_position(sun_dir * 100.0, Vector3.ZERO, Vector3.UP)
	var golden: float = clamp(1.0 - abs(elev) * 3.0, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.55, 0.3), golden)
	sun.light_energy = lerp(0.0, 1.6, day)
	sun.visible = elev > -0.08
	var moon_ang := ang + PI
	moon.look_at_from_position(Vector3(cos(moon_ang) * 0.6, max(sin(moon_ang), 0.25), -0.5).normalized() * 100.0, Vector3.ZERO, Vector3.UP)
	moon.visible = not sun.visible
	# gökyüzü renkleri
	var top := Color(0.16, 0.36, 0.78).lerp(Color(0.25, 0.28, 0.6), golden)
	var hor := Color(0.78, 0.86, 0.95).lerp(Color(1.0, 0.55, 0.45), golden)
	top = top.lerp(Color(0.02, 0.03, 0.09), night)
	hor = hor.lerp(Color(0.12, 0.08, 0.22), night)
	_sky_t += 0.016
	if force or Engine.get_process_frames() % 20 == 0:
		sky_mat.set_shader_parameter("top_col", Vector3(top.r, top.g, top.b))
		sky_mat.set_shader_parameter("hor_col", Vector3(hor.r, hor.g, hor.b))
		sky_mat.set_shader_parameter("ground_col", Vector3(0.2, 0.19, 0.2) * (1.0 - night * 0.8))
		sky_mat.set_shader_parameter("night_f", night)
		sky_mat.set_shader_parameter("cloud_t", Time.get_ticks_msec() / 1000.0)
	env.ambient_light_energy = lerp(0.25, 1.0, day)
	env.background_energy_multiplier = lerp(0.6, 1.0, day)
	env.tonemap_exposure = lerp(1.35, 1.0, day)
	env.fog_light_color = hor.lerp(Color(0.05, 0.04, 0.1), night * 0.5)
	env.volumetric_fog_albedo = Color(0.9, 0.9, 0.95).lerp(Color(0.5, 0.4, 0.7), night)
	# sokak lambaları ve trafik ışıkları
	var lamps_on := night > 0.35
	for l in street_lights:
		l.visible = lamps_on
	var phase := int(Time.get_ticks_msec() / 8000) % 2
	for s in signal_lights:
		var green: bool = (phase == 0) == (s[2] == 0)
		s[0].visible = not green
		s[1].visible = green


func _process(_d: float) -> void:
	update_time(Game.time_of_day)


# ---------------------------------------------------------------- zemin & yollar
func _ground() -> void:
	var size := CELL * GRID * 2.0 + 120.0
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	road.mesh = pm
	var rm := ShaderMaterial.new()
	rm.shader = r_shader
	var t := Game.tex("asphalt", "diff")
	if t:
		rm.set_shader_parameter("asph", t)
		rm.set_shader_parameter("has_tex", true)
	var tn := Game.tex("asphalt", "nor")
	if tn:
		rm.set_shader_parameter("asph_n", tn)
		rm.set_shader_parameter("has_nor", true)
	var tr := Game.tex("asphalt", "rough")
	if tr:
		rm.set_shader_parameter("asph_r", tr)
		rm.set_shader_parameter("has_rough", true)
	rm.set_shader_parameter("cell", CELL)
	rm.set_shader_parameter("road_w", ROAD_W)
	road.material_override = rm
	add_child(road)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)
	# şehir dışı: çimen + kum
	var outer := MeshInstance3D.new()
	var om := PlaneMesh.new()
	om.size = Vector2(3000, 3000)
	outer.mesh = om
	outer.position.y = -0.05
	outer.material_override = Game.pbr("grass", Color(0.55, 0.7, 0.45), 0.15)
	add_child(outer)


func _box(pos: Vector3, size: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		sb.position = pos
		add_child(sb)
	return mi


# ---------------------------------------------------------------- bloklar & binalar
const FACADES := [
	["plaster", Color(0.98, 0.93, 0.86)], ["plaster", Color(0.95, 0.82, 0.78)], ["plaster", Color(0.86, 0.93, 0.95)],
	["brick", Color(1.0, 0.95, 0.92)], ["concrete", Color(0.92, 0.92, 0.9)], ["plaster", Color(1.0, 0.97, 0.8)],
	["plaster", Color(0.85, 0.95, 0.9)], ["concrete", Color(0.8, 0.82, 0.85)]
]
const SIGNS := ["NEON BAR", "ERİŞTE", "SMOOTHIE", "OTEL", "KAFE", "GARAJ", "DOJO", "BUTİK", "ECZANE", "KULÜP 24"]


func _block(c: Vector2) -> void:
	var outer := BLOCK + WALK * 2.0
	blocks.append(Rect2(c - Vector2(outer, outer) * 0.5, Vector2(outer, outer)))
	# kaldırım (görsel 0.18 m; çarpışma 0.08 m → karakter kolayca çıkar)
	var walk_mat := Game.pbr("sidewalk", Color(0.9, 0.88, 0.85), 0.35, 0.85)
	_box(Vector3(c.x, 0.09, c.y), Vector3(outer, 0.18, outer), walk_mat, false)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(outer, 0.08, outer)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(c.x, 0.04, c.y)
	add_child(sb)
	# kaldırım taşı (bordür) çizgisi
	var curb := Game.pbr("concrete", Color(0.75, 0.75, 0.74), 0.5)
	for s in [-1, 1]:
		_box(Vector3(c.x, 0.1, c.y + s * (outer * 0.5 - 0.15)), Vector3(outer, 0.2, 0.3), curb, false)
		_box(Vector3(c.x + s * (outer * 0.5 - 0.15), 0.1, c.y), Vector3(0.3, 0.2, outer), curb, false)
	# binalar: blok çevresinde cepheler, ortada avlu
	var layout := rng.randi_range(0, 2)
	var lots := []
	var h := BLOCK * 0.5
	if layout == 0:
		lots = [Rect2(-h, -h, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(2, -h, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(-h, 2, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(2, 2, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2)]
	elif layout == 1:
		lots = [Rect2(-h, -h, BLOCK, BLOCK * 0.42), Rect2(-h, BLOCK * 0.42 - h + 3, BLOCK * 0.45, BLOCK * 0.58 - 3), Rect2(BLOCK * 0.45 - h + 3, BLOCK * 0.42 - h + 3, BLOCK * 0.55 - 3, BLOCK * 0.58 - 3)]
	else:
		lots = [Rect2(-h, -h, BLOCK * 0.62, BLOCK), Rect2(BLOCK * 0.62 - h + 3, -h, BLOCK * 0.38 - 3, BLOCK * 0.5 - 1.5), Rect2(BLOCK * 0.62 - h + 3, 1.5, BLOCK * 0.38 - 3, BLOCK * 0.5 - 1.5)]
	for r in lots:
		var center: Vector2 = c + r.position + r.size * 0.5
		_building(Vector3(center.x, 0.18, center.y), Vector3(r.size.x, 0, r.size.y))


func _building(base: Vector3, fp: Vector3) -> void:
	var tall := rng.randf() < 0.25
	var floors := rng.randi_range(9, 22) if tall else rng.randi_range(1, 5)
	var height := 4.6 + floors * 3.4
	var f = FACADES[rng.randi_range(0, FACADES.size() - 1)]
	var m := ShaderMaterial.new()
	m.shader = b_shader
	var t := Game.tex(f[0], "diff")
	if t:
		m.set_shader_parameter("wall_tex", t)
		m.set_shader_parameter("has_tex", true)
	var tn := Game.tex(f[0], "nor")
	if tn:
		m.set_shader_parameter("wall_nor", tn)
		m.set_shader_parameter("has_nor", true)
	m.set_shader_parameter("tint", f[1])
	m.set_shader_parameter("tex_scale", 0.25 if f[0] != "brick" else 0.4)
	if tall and rng.randf() < 0.5:
		m.set_shader_parameter("glass_amt", 1.0)
		m.set_shader_parameter("tint", Color(0.55, 0.65, 0.72))
	var mi := _box(base + Vector3(0, height * 0.5, 0), Vector3(fp.x, height, fp.z), m)
	mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
	# çatı kenarı (korkuluk) + çatı ekipmanları
	var trim := Game.paint(Color(0.92, 0.9, 0.86), 0.0, 0.6)
	_box(base + Vector3(0, height + 0.35, 0), Vector3(fp.x + 0.4, 0.7, fp.z + 0.4), trim, false)
	if rng.randf() < 0.7:
		_box(base + Vector3(rng.randf_range(-fp.x, fp.x) * 0.25, height + 1.2, rng.randf_range(-fp.z, fp.z) * 0.25), Vector3(3, 1.6, 2.4), Game.paint(Color(0.7, 0.72, 0.74), 0.6, 0.4), false)
	# zemin kat tente + tabela (sokağa bakan cepheler)
	if floors <= 6 or rng.randf() < 0.5:
		var awn_col: Color = [Color(0.85, 0.15, 0.2), Color(0.1, 0.45, 0.5), Color(0.95, 0.75, 0.2), Color(0.2, 0.2, 0.25), Color(0.95, 0.95, 0.95)][rng.randi_range(0, 4)]
		var side := rng.randi_range(0, 3)
		var off: Vector3 = [Vector3(0, 0, fp.z * 0.5 + 0.9), Vector3(0, 0, -fp.z * 0.5 - 0.9), Vector3(fp.x * 0.5 + 0.9, 0, 0), Vector3(-fp.x * 0.5 - 0.9, 0, 0)][side]
		var along_x := side < 2
		var w: float = (fp.x if along_x else fp.z) * 0.7
		var awn := _box(base + off + Vector3(0, 3.6, 0), Vector3(w if along_x else 1.8, 0.12, 1.8 if along_x else w), Game.paint(awn_col, 0.0, 0.7), false)
		awn.rotation.x = 0.12 if side == 0 else (-0.12 if side == 1 else 0.0)
		awn.rotation.z = -0.12 if side == 2 else (0.12 if side == 3 else 0.0)
		# neon tabela
		var neon_col: Color = [Color(1, 0.2, 0.8), Color(0.2, 0.95, 1.0), Color(1.0, 0.6, 0.15), Color(0.6, 1.0, 0.3)][rng.randi_range(0, 3)]
		var lbl := Label3D.new()
		lbl.text = SIGNS[rng.randi_range(0, SIGNS.size() - 1)]
		lbl.font_size = 96
		lbl.pixel_size = 0.012
		lbl.modulate = neon_col * 3.0
		lbl.outline_size = 0
		lbl.shaded = false
		if Game.font_display:
			lbl.font = Game.font_display
		lbl.position = base + off * 0.95 + Vector3(0, 4.35, 0)
		lbl.rotation.y = [0.0, PI, PI * 0.5, -PI * 0.5][side]
		add_child(lbl)


# ---------------------------------------------------------------- sokak mobilyası
func _merged(parts: Array) -> ArrayMesh:
	## parts: [[Mesh, Transform3D, Material]] → malzeme başına yüzey içeren tek ArrayMesh
	var by_mat := {}
	for p in parts:
		if not by_mat.has(p[2]):
			by_mat[p[2]] = []
		by_mat[p[2]].append(p)
	var am := ArrayMesh.new()
	for mat in by_mat.keys():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in by_mat[mat]:
			st.append_from(p[0], 0, p[1])
		st.generate_tangents()
		st.set_material(mat)
		st.commit(am)
	return am


func _palm_mesh() -> ArrayMesh:
	var parts := []
	var bark := Game.paint(Color(0.45, 0.36, 0.27), 0.0, 0.9)
	var frond_mat := ShaderMaterial.new()
	frond_mat.shader = f_shader
	var h := 0.0
	var x := 0.0
	for i in range(7):
		var seg := CylinderMesh.new()
		seg.top_radius = 0.17 - i * 0.008
		seg.bottom_radius = 0.2 - i * 0.008
		seg.height = 1.3
		seg.radial_segments = 8
		var tr := Transform3D(Basis(Vector3(0, 0, 1), -0.03 * i), Vector3(x, h + 0.65, 0))
		parts.append([seg, tr, bark])
		h += 1.28
		x += 0.05 * i
	var top := Vector3(x, h, 0)
	for k in range(11):
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 3.6)
		q.center_offset = Vector3(0, 1.8, 0)
		var yaw := k * TAU / 11.0
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5 - 0.35 - (k % 3) * 0.15)
		parts.append([q, Transform3D(b, top), frond_mat])
	return _merged(parts)


func _lamp_mesh() -> ArrayMesh:
	var metal := Game.paint(Color(0.18, 0.19, 0.2), 0.7, 0.45)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.11
	pole.height = 7.0
	pole.radial_segments = 8
	var arm := BoxMesh.new()
	arm.size = Vector3(1.8, 0.1, 0.12)
	var head := BoxMesh.new()
	head.size = Vector3(0.7, 0.14, 0.32)
	var glow := BoxMesh.new()
	glow.size = Vector3(0.55, 0.03, 0.24)
	return _merged([[pole, Transform3D(Basis(), Vector3(0, 3.5, 0)), metal], [arm, Transform3D(Basis(), Vector3(0.85, 6.95, 0)), metal], [head, Transform3D(Basis(), Vector3(1.6, 6.9, 0)), metal], [glow, Transform3D(Basis(), Vector3(1.6, 6.82, 0)), Game.emissive(Color(1.0, 0.85, 0.6), 2.0)]])


func _multi(mesh: Mesh, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _street_furniture() -> void:
	var palms := []
	var lamps := []
	var outer := BLOCK + WALK * 2.0
	for r in blocks:
		var c := r.get_center()
		var hw := outer * 0.5 - 1.2
		for s in [-1, 1]:
			var t := -hw + 6.0
			while t < hw - 4.0:
				# kaldırımın yola yakın kenarı boyunca palmiye ve lambalar
				var odd := int((t + hw) / 12.0) % 2 == 0
				var p1 := Vector3(c.x + t, 0.18, c.y + s * hw)
				var p2 := Vector3(c.x + s * hw, 0.18, c.y + t)
				if odd:
					palms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), p1))
					palms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), p2))
				else:
					lamps.append(Transform3D(Basis(Vector3.UP, -PI * 0.5 * s), p1))
					lamps.append(Transform3D(Basis(Vector3.UP, PI if s > 0 else 0.0), p2))
					for p in [p1, p2]:
						var l := OmniLight3D.new()
						l.light_color = Color(1.0, 0.82, 0.58)
						l.light_energy = 2.2
						l.omni_range = 16.0
						l.omni_attenuation = 1.2
						l.position = p + Vector3(0, 6.6, 0) + (Vector3(0, 0, -s * 1.6) if p == p1 else Vector3(-s * 1.6, 0, 0))
						l.visible = false
						add_child(l)
						street_lights.append(l)
				t += 12.0
	var palm_scene := Game.model("palm")
	if palm_scene:
		for tr in palms:
			var n: Node3D = palm_scene.instantiate()
			n.transform = tr
			add_child(n)
	else:
		_multi(_palm_mesh(), palms)
	var lamp_scene := Game.model("lamp")
	if lamp_scene:
		for tr in lamps:
			var n: Node3D = lamp_scene.instantiate()
			n.transform = tr
			add_child(n)
	else:
		_multi(_lamp_mesh(), lamps)
	# banklar, çöp kutuları, yangın muslukları (model varsa)
	for key in ["bench", "bin", "hydrant", "plant"]:
		var sc := Game.model(key)
		if sc == null:
			continue
		for r in blocks:
			if rng.randf() < 0.5:
				continue
			var c := r.get_center()
			var n: Node3D = sc.instantiate()
			var s := 1 if rng.randf() < 0.5 else -1
			n.position = Vector3(c.x + rng.randf_range(-20, 20), 0.18, c.y + s * (outer * 0.5 - 2.2))
			n.rotation.y = 0.0 if s > 0 else PI
			add_child(n)
	# trafik ışıkları (her kavşak köşesinde)
	for i in range(-GRID + 1, GRID):
		for j in range(-GRID + 1, GRID):
			var k := Vector3(i * CELL, 0, j * CELL)
			_traffic_light(k + Vector3(ROAD_W * 0.5 + 1.2, 0.18, ROAD_W * 0.5 + 1.2), 0)
			_traffic_light(k + Vector3(-ROAD_W * 0.5 - 1.2, 0.18, -ROAD_W * 0.5 - 1.2), 1)


func _traffic_light(p: Vector3, axis: int) -> void:
	var metal := Game.paint(Color(0.12, 0.12, 0.13), 0.6, 0.5)
	_box(p + Vector3(0, 2.6, 0), Vector3(0.18, 5.2, 0.18), metal)
	var head := _box(p + Vector3(0, 5.0, 0), Vector3(0.45, 1.2, 0.35), metal, false)
	var red := _box(p + Vector3(0, 5.35, 0.19 if axis == 0 else -0.19), Vector3(0.26, 0.26, 0.05), Game.emissive(Color(1, 0.12, 0.08), 6.0), false)
	var green := _box(p + Vector3(0, 4.7, 0.19 if axis == 0 else -0.19), Vector3(0.26, 0.26, 0.05), Game.emissive(Color(0.15, 1, 0.45), 6.0), false)
	signal_lights.append([red, green, axis])


func _skyline() -> void:
	# uzak siluet: şehir dışında yüksek binalar (çarpışmasız)
	var far := CELL * GRID + 140.0
	for i in range(60):
		var a := i * TAU / 60.0 + rng.randf() * 0.05
		var d := far + rng.randf_range(0, 220)
		var h := rng.randf_range(25, 140)
		var m := ShaderMaterial.new()
		m.shader = b_shader
		m.set_shader_parameter("tint", Color(0.75, 0.8, 0.85).lerp(Color(0.95, 0.9, 0.85), rng.randf()))
		m.set_shader_parameter("glass_amt", 1.0 if rng.randf() < 0.5 else 0.0)
		var mi := _box(Vector3(cos(a) * d, h * 0.5, sin(a) * d), Vector3(rng.randf_range(18, 40), h, rng.randf_range(18, 40)), m, false)
		mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)


# ---------------------------------------------------------------- yardımcılar
func lane_points() -> Array:
	## trafik için kavşak noktaları (yol ağı)
	var pts := []
	for i in range(-GRID, GRID + 1):
		for j in range(-GRID, GRID + 1):
			pts.append(Vector3(i * CELL, 0, j * CELL))
	return pts


func sidewalk_loop(r: Rect2) -> Array:
	var c := r.get_center()
	var hw := r.size.x * 0.5 - 2.6
	return [Vector3(c.x - hw, 0.18, c.y - hw), Vector3(c.x + hw, 0.18, c.y - hw), Vector3(c.x + hw, 0.18, c.y + hw), Vector3(c.x - hw, 0.18, c.y + hw)]
