extends Node3D
class_name World
## Neon Gölgeler adası: ortada ızgara şehir, çevresinde arazi, kumsal ve deniz.
## Bölgeler (eski oyunla aynı): Neon Bulvar (merkez), Eski Çarşı (kuzeybatı), Liman (güneybatı),
## Teknoloji Merkezi (kuzeydoğu), Doğu Konutları (güneydoğu), Sahil (güney),
## Dağ Manastırı (kuzeydeki dağın tepesi), Güvenlikli Ada (doğuda, köprüyle bağlı).

const CELL := 80.0
const ROAD_W := 12.0
const WALK := 5.0
const GRID := 4                         # -GRID..GRID yol çizgileri → 8x8 blok
const BLOCK := CELL - ROAD_W - WALK * 2.0
const CITY := GRID * CELL               # şehir yarı genişliği (320)
const EDGE := CITY + 6.0                # yol kenarı
const SEA := -0.7                       # deniz seviyesi
const RAIL_H := 15.0
const RAIL_R := 80.0
const MON := Vector3(-300, 52, -660)    # Kasırga Manastırı platosu
const ISLE := Vector2(830, 30)          # Güvenlikli Ada
const BRIDGE_X0 := 540.0
const BRIDGE_X1 := 735.0
const T_STEP := 10.0
const T_HALF := 1100.0

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var street_lights: Array[OmniLight3D] = []
var signal_lights: Array = []
var neon_labels: Array[Label3D] = []
var rng := RandomNumberGenerator.new()
var night := 0.0
var blocks: Array[Rect2] = []
var block_district: Array[String] = []
var districts := {}
var pois: Array = []                    # {id, name, kind, pos} — harita/telefon için
var props: StaticBody3D
var train: Array[Node3D] = []
var breakables: Array = []              # devrilebilir sokak eşyaları (G2)
var _train_s := 0.0
var _last_night := -1.0
var _shadow_t := 0.0
var _neon_buckets := {}
var _noise := FastNoiseLite.new()
var _hm := PackedFloat32Array()         # arazi yükseklikleri (harita görseli de bundan çizilir)
var _hn := 0
var _map_tex: ImageTexture
var extra_roads: Array = []             # şehir dışı yollar: [a: Vector2, b: Vector2, genişlik]

var b_shader: Shader = preload("res://shaders/building.gdshader")
var r_shader: Shader = preload("res://shaders/road.gdshader")
var s_shader: Shader = preload("res://shaders/sky.gdshader")
var f_shader: Shader = preload("res://shaders/frond.gdshader")
var neon_mat: ShaderMaterial
var neon_batch_mat: ShaderMaterial
var holo_mat: ShaderMaterial

const NEON := [Color(1.0, 0.15, 0.75), Color(0.1, 0.95, 1.0), Color(1.0, 0.55, 0.1), Color(0.55, 0.3, 1.0), Color(0.3, 1.0, 0.45), Color(1.0, 0.2, 0.25), Color(1.0, 0.85, 0.2)]
const SIGNS := ["ERİŞTE", "DOJO", "NEON", "KAFE", "OTEL", "ÇAY", "SUSHİ", "ARCADE", "BUTİK", "ECZANE", "RAMEN", "KARAOKE", "TEKNO", "MANGA", "BAR", "LOKUM", "DÖNER", "GECE", "SİNEMA", "PİDE"]
const DISTRICT_NAMES := {"merkez": "Neon Bulvar", "cadde": "Neon Bulvar", "eski": "Eski Çarşı", "liman": "Liman", "tekno": "Teknoloji Merkezi",
	"konut": "Doğu Konutları", "sahil": "Sahil", "dag": "Dağ Manastırı", "ada": "Güvenlikli Ada", "kir": "Ada Kırları"}


func build(progress: Callable = Callable()) -> void:
	rng.seed = 20261127
	_noise.seed = 7
	_noise.frequency = 0.004
	neon_mat = ShaderMaterial.new()
	neon_mat.shader = load("res://shaders/neon.gdshader")
	neon_batch_mat = ShaderMaterial.new()
	neon_batch_mat.shader = load("res://shaders/neon_batch.gdshader")
	holo_mat = ShaderMaterial.new()
	holo_mat.shader = load("res://shaders/holo.gdshader")
	props = StaticBody3D.new()
	add_child(props)
	_environment()
	await _step(progress, 0.05, "Ada arazisi oluşturuluyor")
	_ground()
	_terrain()
	await _step(progress, 0.2, "Şehir blokları")
	for i in range(-GRID, GRID):
		for j in range(-GRID, GRID):
			_block(i, j)
		await _step(progress, 0.2 + (i + GRID + 1) * 0.03, "Şehir blokları")
	await _step(progress, 0.45, "Sokak eşyaları")
	_street_furniture()
	_lanterns()
	_monorail()
	await _step(progress, 0.6, "Kıyılar ve köprü")
	_coast()
	await _step(progress, 0.65, "Kasırga Manastırı")
	_monastery()
	_secure_island()
	_landmarks()
	await _step(progress, 0.7, "Ormanlar")
	_trees()
	_horizon()
	_flush_neon()
	await _step(progress, 0.75, "Son dokunuşlar")
	update_time(Game.time_of_day, true)


func _step(cb: Callable, v: float, txt: String) -> void:
	if cb.is_valid():
		cb.call(v, txt)
	await get_tree().process_frame
	await get_tree().process_frame


func district(i: int, j: int) -> String:
	if i <= -3 and j >= 2:
		return "liman"
	if i <= -3 or (j <= -3 and i <= 1):
		return "eski"
	if i >= 2 and j <= -1:
		return "tekno"
	if i >= 2:
		return "konut"
	if j >= 2:
		return "sahil"
	if i >= -1 and i <= 0 and j >= -1 and j <= 0:
		return "merkez"
	return "cadde"


func district_at(p: Vector3) -> String:
	if Vector2(p.x, p.z).distance_to(ISLE) < 140.0:
		return "ada"
	if absf(p.x) > EDGE or absf(p.z) > EDGE:
		if p.z < -EDGE and p.x < 0 and Vector2(p.x, p.z).distance_to(Vector2(MON.x, MON.z)) < 260.0:
			return "dag"
		if p.z > EDGE:
			return "sahil"
		if p.x < -EDGE and p.z > 0:
			return "liman"
		return "kir"
	var i := clampi(int(floor(p.x / CELL)), -GRID, GRID - 1)
	var j := clampi(int(floor(p.z / CELL)), -GRID, GRID - 1)
	return district(i, j)


func district_name(p: Vector3) -> String:
	return DISTRICT_NAMES.get(district_at(p), "")


# ---------------------------------------------------------------- ortam
func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = s_shader
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssao_detail = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(5, 0.5)
	env.fog_enabled = true
	env.fog_density = 0.0009
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.6
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.14
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 120.0
	add_child(moon)
	apply_quality()
	Game.settings_changed.connect(apply_quality)


func apply_quality() -> void:
	if env == null:
		return
	var q: int = Game.settings.quality
	env.sdfgi_enabled = Game.settings.sdfgi and q >= 1
	env.sdfgi_cascades = 4 if q >= 2 else 3
	env.sdfgi_min_cell_size = 0.25 if q >= 2 else 0.4
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.9
	env.sdfgi_read_sky_light = true
	env.ssr_enabled = Game.settings.ssr and q >= 1
	env.ssr_max_steps = 56 if q >= 2 else 32
	env.ssr_fade_in = 0.25
	env.ssr_fade_out = 1.6
	env.ssr_depth_tolerance = 0.25
	env.ssil_enabled = q >= 2
	env.ssao_enabled = q >= 1
	env.volumetric_fog_enabled = q >= 2
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_length = 120.0
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_gi_inject = 0.6
	if sun:
		sun.directional_shadow_max_distance = [100.0, 170.0, 240.0][q]
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])


func update_time(h: float, force := false) -> void:
	var ang := (h - 6.0) / 12.0 * PI
	var elev := sin(ang)
	var day: float = clamp(elev * 3.0 + 0.15, 0.0, 1.0)
	night = 1.0 - clamp(elev * 4.0 + 0.35, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("night", night)
	Game.night = night
	var sun_dir := Vector3(cos(ang), max(elev, -0.3), 0.35).normalized()
	sun.look_at_from_position(sun_dir * 100.0, Vector3.ZERO, Vector3.UP)
	var golden: float = clamp(1.0 - abs(elev) * 3.0, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.5, 0.3), golden)
	sun.light_energy = lerp(0.0, 1.7, day)
	sun.visible = elev > -0.08
	var moon_ang := ang + PI
	moon.look_at_from_position(Vector3(cos(moon_ang) * 0.6, max(sin(moon_ang), 0.25), -0.5).normalized() * 100.0, Vector3.ZERO, Vector3.UP)
	moon.visible = not sun.visible
	var top := Color(0.16, 0.36, 0.78).lerp(Color(0.28, 0.22, 0.58), golden)
	var hor := Color(0.78, 0.86, 0.95).lerp(Color(1.0, 0.5, 0.5), golden)
	top = top.lerp(Color(0.04, 0.02, 0.12), night)
	hor = hor.lerp(Color(0.32, 0.1, 0.36), night)
	if force or Engine.get_process_frames() % 20 == 0:
		sky_mat.set_shader_parameter("top_col", Vector3(top.r, top.g, top.b))
		sky_mat.set_shader_parameter("hor_col", Vector3(hor.r, hor.g, hor.b))
		sky_mat.set_shader_parameter("ground_col", Vector3(0.2, 0.19, 0.2) * (1.0 - night * 0.8))
		sky_mat.set_shader_parameter("night_f", night)
		sky_mat.set_shader_parameter("cloud_t", Time.get_ticks_msec() / 1000.0)
	env.ambient_light_energy = lerp(0.16, 1.0, day)
	env.background_energy_multiplier = lerp(0.55, 1.0, day)
	env.tonemap_exposure = lerp(1.3, 1.0, day)
	env.fog_light_color = hor.lerp(Color(0.12, 0.05, 0.18), night * 0.5)
	env.volumetric_fog_albedo = Color(0.9, 0.9, 0.95).lerp(Color(0.6, 0.4, 0.8), night)
	env.glow_intensity = lerp(0.5, 0.95, night)
	if force or abs(night - _last_night) > 0.02:
		_last_night = night
		var k: float = lerp(0.55, 2.6, smoothstep(0.15, 0.6, night))
		for l in neon_labels:
			var c: Color = l.get_meta("c")
			l.modulate = Color(c.r * k, c.g * k, c.b * k, 1.0)
		var lamps_on := night > 0.35
		for l in street_lights:
			l.visible = lamps_on
	var phase := int(Time.get_ticks_msec() / 8000) % 2
	for s in signal_lights:
		var green: bool = (phase == 0) == (s[2] == 0)
		s[0].visible = not green
		s[1].visible = green


func _process(delta: float) -> void:
	update_time(Game.time_of_day)
	_move_train(delta)
	_shadow_t -= delta
	if _shadow_t <= 0.0 and night > 0.35:
		_shadow_t = 0.6
		var cam := get_viewport().get_camera_3d()
		if cam:
			var cp := cam.global_position
			var best: Array = []
			for l in street_lights:
				var d := l.global_position.distance_squared_to(cp)
				if d < 1600.0:
					best.append([d, l])
				else:
					l.shadow_enabled = false
			best.sort_custom(func(a, b): return a[0] < b[0])
			for i in best.size():
				(best[i][1] as OmniLight3D).shadow_enabled = i < 3


# ---------------------------------------------------------------- yardımcılar
func _box(pos: Vector3, size: Vector3, mat: Material, collide := true, layer := 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		_collider(pos, size, layer)
	return mi


func _collider(pos: Vector3, size: Vector3, layer := 1, rot := Vector3.ZERO) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation = rot
	add_child(sb)


func _cyl_collider(pos: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = pos + Vector3(0, h * 0.5, 0)
	props.add_child(cs)


func _occluder(pos: Vector3, size: Vector3) -> void:
	if size.x < 6 or size.z < 6 or size.y < 6:
		return
	var oi := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = size * 0.94
	oi.occluder = bo
	oi.position = pos
	add_child(oi)


func _neon(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, bucket := "") -> void:
	## neon şeritler kovalarda biriktirilir, sonunda tek mesh'e birleştirilir (az çizim çağrısı)
	var key := bucket if bucket != "" else "%d_%d" % [int(floor(pos.x / 160.0)), int(floor(pos.z / 160.0))]
	if not _neon_buckets.has(key):
		_neon_buckets[key] = []
	_neon_buckets[key].append([Transform3D(Basis.from_euler(rot), pos), size, col, rng.randf()])


func _flush_neon() -> void:
	var cube := BoxMesh.new()
	var arr := cube.get_mesh_arrays()
	var cv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ci: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for key in _neon_buckets.keys():
		var list: Array = _neon_buckets[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var base := 0
		for it in list:
			var xf: Transform3D = it[0]
			var sz: Vector3 = it[1]
			var col: Color = it[2]
			for v in cv:
				st.set_color(col)
				st.set_uv(Vector2(it[3], 0))
				st.add_vertex(xf * (v * sz))
			for idx in ci:
				st.add_index(base + idx)
			base += cv.size()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = neon_batch_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_neon_buckets.clear()


func _label(text: String, pos: Vector3, yaw: float, col: Color, size := 96, px := 0.012) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = size
	lbl.pixel_size = px
	lbl.outline_size = 0
	lbl.shaded = false
	lbl.double_sided = true
	lbl.set_meta("c", col)
	lbl.modulate = col
	if Game.font_display:
		lbl.font = Game.font_display
	lbl.position = pos
	lbl.rotation.y = yaw
	if px < 0.02:
		lbl.visibility_range_end = 150.0
		lbl.visibility_range_end_margin = 15.0
		lbl.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(lbl)
	neon_labels.append(lbl)
	return lbl


func _poi(id: String, name: String, kind: String, pos: Vector3) -> void:
	pois.append({"id": id, "name": name, "kind": kind, "pos": pos})


# ---------------------------------------------------------------- zemin (şehir) ve arazi
func _ground() -> void:
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(EDGE * 2.0, EDGE * 2.0)
	pm.subdivide_width = 16
	pm.subdivide_depth = 16
	road.mesh = pm
	var rm := ShaderMaterial.new()
	rm.shader = r_shader
	for slot in [["asph", "diff", "has_tex"], ["asph_n", "nor", "has_nor"], ["asph_r", "rough", "has_rough"]]:
		var t := Game.tex("asphalt", slot[1])
		if t:
			rm.set_shader_parameter(slot[0], t)
			rm.set_shader_parameter(slot[2], true)
	rm.set_shader_parameter("cell", CELL)
	rm.set_shader_parameter("road_w", ROAD_W)
	road.material_override = rm
	add_child(road)
	_collider(Vector3(0, -0.5, 0), Vector3(EDGE * 2.0, 1.0, EDGE * 2.0))
	var walk_mat := Game.pbr("sidewalk", Color(0.9, 0.88, 0.85), 0.35, 0.85)
	for s in [-1, 1]:
		_box(Vector3(0, 0.09, s * (EDGE + 3.0)), Vector3(EDGE * 2.0 + 12.0, 0.18, 6.0), walk_mat, false)
		_box(Vector3(s * (EDGE + 3.0), 0.09, 0), Vector3(6.0, 0.18, EDGE * 2.0), walk_mat, false)
		_collider(Vector3(0, 0.04, s * (EDGE + 3.0)), Vector3(EDGE * 2.0 + 12.0, 0.08, 6.0))
		_collider(Vector3(s * (EDGE + 3.0), 0.04, 0), Vector3(6.0, 0.08, EDGE * 2.0))


func _margin(th: float) -> float:
	## şehir kenarından kıyıya kadar kara genişliği (yöne göre; +z güney)
	var c := cos(th)
	var s := sin(th)
	return 70.0 + 190.0 * maxf(0.0, c) + 55.0 * maxf(0.0, -c) + 430.0 * maxf(0.0, -s)


func terrain_h(x: float, z: float) -> float:
	var dx := maxf(absf(x) - EDGE, 0.0)
	var dz := maxf(absf(z) - EDGE, 0.0)
	var d := sqrt(dx * dx + dz * dz)
	var h := -0.4
	if d > 0.0:
		var th := atan2(z, x)
		var m := _margin(th) + _noise.get_noise_2d(x, z) * 28.0
		var t := d / maxf(m, 10.0)
		if t >= 1.0:
			h = lerpf(-1.6, -10.0, clampf((t - 1.0) * 3.0, 0.0, 1.0))
		else:
			var amp := 5.0 + 16.0 * maxf(0.0, -sin(th))
			h = sin(clampf(t, 0.0, 1.0) * PI) * amp + _noise.get_noise_2d(x * 3.0, z * 3.0) * 2.5
			h = lerpf(h, -1.4, smoothstep(0.8, 1.0, t))
			h = lerpf(-0.4, h, smoothstep(0.0, 26.0, d))
			var mx := Vector2(x, z)
			var mtn := 118.0 * exp(-mx.distance_squared_to(Vector2(-420, -640)) / (2.0 * 150.0 * 150.0))
			mtn += 85.0 * exp(-mx.distance_squared_to(Vector2(-160, -700)) / (2.0 * 110.0 * 110.0))
			mtn *= 1.0 - smoothstep(0.75, 1.0, t)
			h = maxf(h, mtn)
			var dm := mx.distance_to(Vector2(MON.x, MON.z))
			h = lerpf(MON.y, h, smoothstep(62.0, 95.0, dm))
			if z < -EDGE and z > MON.z + 50.0:
				var road_t := clampf((-EDGE - z) / (absf(MON.z) - 60.0 - EDGE), 0.0, 1.0)
				h = lerpf(road_t * MON.y - 0.15, h, smoothstep(9.0, 26.0, absf(x - MON.x)))
			if x > EDGE and absf(z) < 40.0:
				var by := clampf((x - EDGE) / (BRIDGE_X0 - EDGE), 0.0, 1.0) * 2.0
				h = lerpf(by - 0.15, h, smoothstep(9.0, 30.0, absf(z)))
			if x < -EDGE and z > 0.0:
				h = minf(h, 1.2 - t * 1.5)
	var di := Vector2(x, z).distance_to(ISLE)
	if di < 150.0:
		h = maxf(h, lerpf(3.0, -10.0, smoothstep(105.0, 150.0, di)))
	return h


func _terrain() -> void:
	var n := int(T_HALF * 2.0 / T_STEP) + 1
	var hm := PackedFloat32Array()
	hm.resize(n * n)
	for j in n:
		for i in n:
			hm[j * n + i] = terrain_h(-T_HALF + i * T_STEP, -T_HALF + j * T_STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n - 1:
		for i in n - 1:
			var h00 := hm[j * n + i]
			var h10 := hm[j * n + i + 1]
			var h01 := hm[(j + 1) * n + i]
			var h11 := hm[(j + 1) * n + i + 1]
			if maxf(maxf(h00, h10), maxf(h01, h11)) < -9.5:
				continue
			var x0 := -T_HALF + i * T_STEP
			var z0 := -T_HALF + j * T_STEP
			if absf(x0 + T_STEP * 0.5) < EDGE - 12.0 and absf(z0 + T_STEP * 0.5) < EDGE - 12.0:
				continue
			var q := [Vector3(x0, h00, z0), Vector3(x0 + T_STEP, h10, z0), Vector3(x0, h01, z0 + T_STEP), Vector3(x0 + T_STEP, h11, z0 + T_STEP)]
			for tri in [[0, 1, 2], [1, 3, 2]]:
				for v in tri:
					st.add_vertex(q[v])
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var tm := ShaderMaterial.new()
	tm.shader = load("res://shaders/terrain.gdshader")
	var gt := Game.tex("grass", "diff")
	if gt:
		tm.set_shader_parameter("grass_tex", gt)
		tm.set_shader_parameter("has_grass", true)
	var rt := Game.tex("concrete", "diff")
	if rt:
		tm.set_shader_parameter("rock_tex", rt)
		tm.set_shader_parameter("has_rock", true)
	mi.material_override = tm
	add_child(mi)
	_hm = hm
	_hn = n
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = n
	hs.map_depth = n
	hs.map_data = hm
	cs.shape = hs
	cs.scale = Vector3(T_STEP, 1.0, T_STEP)
	body.add_child(cs)
	add_child(body)
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(6000, 6000)
	wm.subdivide_width = 160
	wm.subdivide_depth = 160
	water.mesh = wm
	water.position = Vector3(0, SEA, 0)
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	water.material_override = wmat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ---------------------------------------------------------------- bloklar & binalar
const FACADES := {
	"cadde": [["plaster", Color(0.98, 0.93, 0.86)], ["brick", Color(1.0, 0.95, 0.92)], ["concrete", Color(0.86, 0.87, 0.9)], ["plaster", Color(0.85, 0.9, 0.95)], ["concrete", Color(0.75, 0.77, 0.82)]],
	"merkez": [["concrete", Color(0.75, 0.78, 0.84)], ["concrete", Color(0.55, 0.6, 0.7)], ["plaster", Color(0.9, 0.92, 0.95)]],
	"eski": [["plaster", Color(0.95, 0.88, 0.75)], ["brick", Color(0.85, 0.6, 0.5)], ["plaster", Color(0.75, 0.3, 0.25)], ["plaster", Color(0.9, 0.82, 0.68)]],
	"sahil": [["plaster", Color(1.0, 0.78, 0.82)], ["plaster", Color(0.7, 0.95, 0.92)], ["plaster", Color(1.0, 0.95, 0.75)], ["plaster", Color(0.85, 0.85, 1.0)], ["plaster", Color(1.0, 1.0, 0.98)]],
	"liman": [["concrete", Color(0.6, 0.62, 0.6)], ["brick", Color(0.8, 0.55, 0.45)], ["concrete", Color(0.7, 0.65, 0.55)]],
	"tekno": [["concrete", Color(0.7, 0.75, 0.82)], ["concrete", Color(0.5, 0.55, 0.65)]],
	"konut": [["plaster", Color(0.98, 0.95, 0.9)], ["plaster", Color(0.9, 0.85, 0.78)], ["brick", Color(0.95, 0.8, 0.75)], ["plaster", Color(0.82, 0.9, 0.85)]],
}


func _block(i: int, j: int) -> void:
	var c := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)
	var d := district(i, j)
	districts[Vector2i(i, j)] = d
	var outer := BLOCK + WALK * 2.0
	blocks.append(Rect2(c - Vector2(outer, outer) * 0.5, Vector2(outer, outer)))
	block_district.append(d)
	var walk_mat := Game.pbr("sidewalk", Color(0.9, 0.88, 0.85) if d != "eski" else Color(0.85, 0.78, 0.7), 0.35, 0.85)
	_box(Vector3(c.x, 0.09, c.y), Vector3(outer, 0.18, outer), walk_mat, false)
	_collider(Vector3(c.x, 0.04, c.y), Vector3(outer, 0.08, outer), 1)
	_collider(Vector3(c.x, 0.12, c.y), Vector3(outer - 0.2, 0.24, outer - 0.2), 2)
	var curb := Game.pbr("concrete", Color(0.75, 0.75, 0.74), 0.5)
	for s in [-1, 1]:
		_box(Vector3(c.x, 0.1, c.y + s * (outer * 0.5 - 0.15)), Vector3(outer, 0.2, 0.3), curb, false)
		_box(Vector3(c.x + s * (outer * 0.5 - 0.15), 0.1, c.y), Vector3(0.3, 0.2, outer), curb, false)
	if d == "konut":
		_houses(c)
		return
	var lots := []
	var h := BLOCK * 0.5
	var layout := rng.randi_range(0, 2)
	if d == "merkez" or d == "tekno":
		layout = rng.randi_range(0, 1) * 3
	if d == "liman":
		layout = 1
	if layout == 0:
		lots = [Rect2(-h, -h, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(2, -h, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(-h, 2, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(2, 2, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2)]
	elif layout == 1:
		lots = [Rect2(-h, -h, BLOCK, BLOCK * 0.42), Rect2(-h, BLOCK * 0.42 - h + 3, BLOCK * 0.45, BLOCK * 0.58 - 3), Rect2(BLOCK * 0.45 - h + 3, BLOCK * 0.42 - h + 3, BLOCK * 0.55 - 3, BLOCK * 0.58 - 3)]
	elif layout == 2:
		lots = [Rect2(-h, -h, BLOCK * 0.62, BLOCK), Rect2(BLOCK * 0.62 - h + 3, -h, BLOCK * 0.38 - 3, BLOCK * 0.5 - 1.5), Rect2(BLOCK * 0.62 - h + 3, 1.5, BLOCK * 0.38 - 3, BLOCK * 0.5 - 1.5)]
	else:
		lots = [Rect2(-h + 6, -h + 6, BLOCK * 0.55, BLOCK * 0.55)]
		_plaza(c)
	for r in lots:
		var center: Vector2 = c + r.position + r.size * 0.5
		_building(Vector3(center.x, 0.18, center.y), Vector3(r.size.x, 0, r.size.y), d)
	if d == "liman":
		_containers(c)


func _plaza(c: Vector2) -> void:
	var p := Vector3(c.x + BLOCK * 0.28, 0.18, c.y + BLOCK * 0.28)
	_box(p + Vector3(0, 0.25, 0), Vector3(16, 0.5, 16), Game.pbr("concrete", Color(0.7, 0.7, 0.75), 0.4))
	var col: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	for k in range(16):
		var a := k * TAU / 16.0
		_neon(p + Vector3(cos(a) * 3.0, 4.5 + sin(a) * 3.0, 0), Vector3(1.3, 0.22, 0.22), col, Vector3(0, 0, a + PI * 0.5))
	_box(p + Vector3(0, 0.9, 0), Vector3(1.2, 0.8, 1.2), Game.paint(Color(0.15, 0.15, 0.17), 0.8, 0.3))


func _facade_mat(d: String, glass: bool) -> ShaderMaterial:
	var list: Array = FACADES.get(d, FACADES.cadde)
	var f = list[rng.randi_range(0, list.size() - 1)]
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
	if d == "eski":
		m.set_shader_parameter("trim", Color(0.35, 0.12, 0.1))
	if glass:
		m.set_shader_parameter("glass_amt", 1.0)
		m.set_shader_parameter("tint", [Color(0.45, 0.6, 0.72), Color(0.35, 0.45, 0.6), Color(0.55, 0.5, 0.7)][rng.randi_range(0, 2)])
	return m


func _building(base: Vector3, fp: Vector3, d: String) -> void:
	var tall_p: float = {"merkez": 0.9, "cadde": 0.3, "eski": 0.0, "sahil": 0.12, "liman": 0.0, "tekno": 0.95, "konut": 0.0}.get(d, 0.2)
	var tall := rng.randf() < tall_p
	var floors: int
	if (d == "merkez" or d == "tekno") and tall:
		floors = rng.randi_range(16, 40)
	elif tall:
		floors = rng.randi_range(8, 16)
	elif d == "eski":
		floors = rng.randi_range(1, 3)
	elif d == "liman":
		floors = rng.randi_range(1, 2)
	else:
		floors = rng.randi_range(1, 5)
	var height := 4.6 + floors * 3.4
	var glass := tall and rng.randf() < (0.8 if d == "tekno" else (0.7 if d == "merkez" else 0.4))
	var m := _facade_mat(d, glass)
	if d == "liman":
		m.set_shader_parameter("ground_h", height + 1.0)
	var setback := tall and (d == "merkez" or d == "tekno") and rng.randf() < 0.6
	var main_h := height * (0.65 if setback else 1.0)
	var mi := _box(base + Vector3(0, main_h * 0.5, 0), Vector3(fp.x, main_h, fp.z), m)
	mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
	_occluder(base + Vector3(0, main_h * 0.5, 0), Vector3(fp.x, main_h, fp.z))
	var top_y := main_h
	var top_fp := fp
	if setback:
		top_fp = fp * 0.68
		var h2 := height - main_h
		var m2 := _box(base + Vector3(0, main_h + h2 * 0.5, 0), Vector3(top_fp.x, h2, top_fp.z), m)
		m2.set_instance_shader_parameter("seed", rng.randf() * 100.0)
		top_y = height
	var trim := Game.paint(Color(0.92, 0.9, 0.86) if d != "eski" else Color(0.3, 0.1, 0.08), 0.0, 0.6)
	if d != "eski":
		_box(base + Vector3(0, top_y + 0.35, 0), Vector3(top_fp.x + 0.4, 0.7, top_fp.z + 0.4), trim, false)
	var ncol: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	if tall:
		_tower_neon(base, top_fp, top_y, ncol, setback, fp, main_h)
		if rng.randf() < (0.75 if d == "merkez" else 0.4):
			_hologram(base, fp, main_h)
		_box(base + Vector3(0, top_y + 4.0, 0), Vector3(0.3, 7.0, 0.3), Game.paint(Color(0.3, 0.3, 0.32), 0.8, 0.4), false)
		_neon(base + Vector3(0, top_y + 7.6, 0), Vector3(0.5, 0.5, 0.5), Color(1, 0.1, 0.1))
	elif d == "eski":
		_pagoda_roof(base, fp, height)
	elif d == "sahil":
		for k in range(2):
			var y := height - 0.4 - k * 0.6
			for s in [-1, 1]:
				_neon(base + Vector3(0, y, s * (fp.z * 0.5 + 0.06)), Vector3(fp.x * 0.98, 0.12, 0.08), ncol)
				_neon(base + Vector3(s * (fp.x * 0.5 + 0.06), y, 0), Vector3(0.08, 0.12, fp.z * 0.98), ncol)
	elif d == "liman":
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(fp.x, 3.0, fp.z)
		roof.mesh = pm
		roof.position = base + Vector3(0, height + 1.5, 0)
		roof.material_override = Game.paint(Color(0.45, 0.5, 0.52), 0.6, 0.5)
		add_child(roof)
	elif rng.randf() < 0.7:
		_box(base + Vector3(rng.randf_range(-fp.x, fp.x) * 0.25, height + 1.2, rng.randf_range(-fp.z, fp.z) * 0.25), Vector3(3, 1.6, 2.4), Game.paint(Color(0.7, 0.72, 0.74), 0.6, 0.4), false)
	if d != "liman":
		_shopfront(base, fp, d, floors)


func _houses(c: Vector2) -> void:
	var cols := [Color(0.98, 0.95, 0.9), Color(0.9, 0.82, 0.72), Color(0.82, 0.9, 0.95), Color(0.95, 0.85, 0.85), Color(0.85, 0.92, 0.82)]
	var roofs := [Color(0.55, 0.2, 0.15), Color(0.25, 0.28, 0.32), Color(0.4, 0.3, 0.22)]
	var grass := Game.pbr("grass", Color(0.6, 0.75, 0.5), 0.2)
	_box(Vector3(c.x, 0.2, c.y), Vector3(BLOCK - 2, 0.06, BLOCK - 2), grass, false)
	for gx in [-1, 1]:
		for gz in [-1, 1]:
			var p := Vector3(c.x + gx * BLOCK * 0.25, 0.18, c.y + gz * BLOCK * 0.25)
			var w := rng.randf_range(10, 14)
			var dpt := rng.randf_range(9, 12)
			var hh := rng.randf_range(5.0, 7.5)
			var m := _facade_mat("konut", false)
			m.set_shader_parameter("tint", cols[rng.randi_range(0, cols.size() - 1)])
			m.set_shader_parameter("ground_h", 3.2)
			m.set_shader_parameter("floor_h", 3.0)
			var mi := _box(p + Vector3(0, hh * 0.5, 0), Vector3(w, hh, dpt), m)
			mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
			var roof := MeshInstance3D.new()
			var pm := PrismMesh.new()
			var turn := rng.randf() < 0.5
			pm.size = Vector3(dpt + 1.2, 3.2, w + 1.2) if turn else Vector3(w + 1.2, 3.2, dpt + 1.2)
			roof.mesh = pm
			roof.position = p + Vector3(0, hh + 1.6, 0)
			roof.rotation.y = PI * 0.5 if turn else 0.0
			roof.material_override = Game.paint(roofs[rng.randi_range(0, roofs.size() - 1)], 0.0, 0.7)
			add_child(roof)
			_box(p + Vector3(0, 0.6, gz * BLOCK * 0.22), Vector3(BLOCK * 0.45, 0.9, 0.12), Game.paint(Color(0.95, 0.95, 0.95), 0.0, 0.6))


func _containers(c: Vector2) -> void:
	var cols := [Color(0.8, 0.2, 0.15), Color(0.15, 0.4, 0.75), Color(0.95, 0.7, 0.15), Color(0.2, 0.55, 0.3), Color(0.9, 0.9, 0.92)]
	for k in range(8):
		var p := Vector3(c.x + rng.randf_range(-22, 22), 0.18, c.y + rng.randf_range(10, 24))
		var stack := rng.randi_range(1, 3)
		for s in stack:
			var b := _box(p + Vector3(0, 1.3 + s * 2.6, 0), Vector3(2.5, 2.6, 6.1), Game.paint(cols[rng.randi_range(0, cols.size() - 1)], 0.5, 0.55))
			b.rotation.y = rng.randf_range(-0.05, 0.05)


func _tower_neon(base: Vector3, fp: Vector3, top_y: float, col: Color, setback: bool, fp0: Vector3, main_h: float) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var y0 := main_h if setback else 5.0
			var hh := top_y - y0
			_neon(base + Vector3(sx * (fp.x * 0.5 + 0.05), y0 + hh * 0.5, sz * (fp.z * 0.5 + 0.05)), Vector3(0.22, hh, 0.22), col)
	for s in [-1, 1]:
		_neon(base + Vector3(0, top_y + 0.75, s * (fp.z * 0.5 + 0.25)), Vector3(fp.x + 0.5, 0.25, 0.1), col)
		_neon(base + Vector3(s * (fp.x * 0.5 + 0.25), top_y + 0.75, 0), Vector3(0.1, 0.25, fp.z + 0.5), col)
	if setback:
		var c2: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
		for s in [-1, 1]:
			_neon(base + Vector3(0, main_h + 0.2, s * (fp0.z * 0.5 + 0.1)), Vector3(fp0.x, 0.2, 0.1), c2)
			_neon(base + Vector3(s * (fp0.x * 0.5 + 0.1), main_h + 0.2, 0), Vector3(0.1, 0.2, fp0.z), c2)


func _hologram(base: Vector3, fp: Vector3, h: float) -> void:
	var side := rng.randi_range(0, 3)
	var w := minf(14.0, (fp.x if side < 2 else fp.z) * 0.7)
	var hh := w * 1.3
	var y := clampf(h * 0.55, 14.0, maxf(14.0, h - hh * 0.5 - 2.0))
	if y - hh * 0.5 < 8.0 or y + hh * 0.5 > h:
		return
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, hh)
	q.mesh = qm
	q.material_override = holo_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var off: Vector3 = [Vector3(0, 0, fp.z * 0.5 + 0.6), Vector3(0, 0, -fp.z * 0.5 - 0.6), Vector3(fp.x * 0.5 + 0.6, 0, 0), Vector3(-fp.x * 0.5 - 0.6, 0, 0)][side]
	q.position = base + off + Vector3(0, y, 0)
	q.rotation.y = [0.0, PI, PI * 0.5, -PI * 0.5][side]
	var a: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	var b: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	q.set_instance_shader_parameter("col_a", a)
	q.set_instance_shader_parameter("col_b", b)
	q.set_instance_shader_parameter("kind", float(rng.randi_range(0, 2)))
	add_child(q)
	var ads: Array[String] = ["NEON GÖLGELER", "ANANAS SMOOTHIE", "TEKNO 3000", "GECE PAZARI", "HIZ KULÜBÜ", "TURBO DOJO"]
	var txt: String = ads[rng.randi_range(0, ads.size() - 1)]
	_label(txt, q.position + Vector3(0, -hh * 0.5 - 1.2, 0) + off.normalized() * 0.1, q.rotation.y, a, 96, 0.03)


func _pagoda_roof(base: Vector3, fp: Vector3, h: float) -> void:
	var tile := Game.paint([Color(0.55, 0.1, 0.08), Color(0.1, 0.35, 0.32), Color(0.2, 0.2, 0.25)][rng.randi_range(0, 2)], 0.1, 0.5)
	_pagoda(base, fp, h, tile, 2)


func _pagoda(base: Vector3, fp: Vector3, h: float, tile: Material, tiers: int) -> void:
	var gold := Game.paint(Color(0.95, 0.72, 0.25), 0.9, 0.3)
	var w := maxf(fp.x, fp.z)
	var y := h
	for tier in range(tiers):
		var shrink := 1.0 - tier * (0.7 / tiers)
		var r := (w * 0.5 + 1.6) * shrink * 1.414
		var roof := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.bottom_radius = r
		cm.top_radius = r * 0.35
		cm.height = 2.4 - tier * 0.3
		cm.radial_segments = 4
		roof.mesh = cm
		roof.material_override = tile
		roof.position = base + Vector3(0, y + cm.height * 0.5, 0)
		roof.rotation.y = PI * 0.25
		roof.scale = Vector3(fp.x / w, 1, fp.z / w)
		add_child(roof)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var tip := _box(base + Vector3(sx * (fp.x * 0.5 + 1.4) * shrink, y + 0.35, sz * (fp.z * 0.5 + 1.4) * shrink), Vector3(0.35, 0.18, 0.9), gold, false)
				tip.rotation = Vector3(0.5 * sz, PI * 0.25 * sx * sz, 0)
		if tier < tiers - 1:
			_box(base + Vector3(0, y + cm.height + 0.5, 0), Vector3(fp.x * 0.45 * shrink, 1.0, fp.z * 0.45 * shrink), Game.paint(Color(0.35, 0.1, 0.08), 0.0, 0.7), false)
		y += cm.height + 0.9
	_box(base + Vector3(0, y + 0.5, 0), Vector3(0.25, 1.4, 0.25), gold, false)


func _shopfront(base: Vector3, fp: Vector3, d: String, floors: int) -> void:
	if not (floors <= 6 or rng.randf() < 0.6):
		return
	var side := rng.randi_range(0, 3)
	var off: Vector3 = [Vector3(0, 0, fp.z * 0.5 + 0.9), Vector3(0, 0, -fp.z * 0.5 - 0.9), Vector3(fp.x * 0.5 + 0.9, 0, 0), Vector3(-fp.x * 0.5 - 0.9, 0, 0)][side]
	var yaw: float = [0.0, PI, PI * 0.5, -PI * 0.5][side]
	var along_x := side < 2
	var w: float = (fp.x if along_x else fp.z) * 0.7
	var awn_col: Color = [Color(0.85, 0.15, 0.2), Color(0.1, 0.45, 0.5), Color(0.95, 0.75, 0.2), Color(0.2, 0.2, 0.25), Color(0.95, 0.95, 0.95)][rng.randi_range(0, 4)]
	var awn := _box(base + off + Vector3(0, 3.6, 0), Vector3(w if along_x else 1.8, 0.12, 1.8 if along_x else w), Game.paint(awn_col, 0.0, 0.7), false)
	awn.rotation.x = 0.12 if side == 0 else (-0.12 if side == 1 else 0.0)
	awn.rotation.z = -0.12 if side == 2 else (0.12 if side == 3 else 0.0)
	var col: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	var txt: String = SIGNS[rng.randi_range(0, SIGNS.size() - 1)]
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	if rng.randf() < 0.5:
		var p := base + off * 0.95 + Vector3(0, 4.35, 0)
		_label(txt, p, yaw, col)
		var tw := txt.length() * 0.75 + 1.0
		_neon(p + Vector3(0, 0.75, 0), Vector3(tw if along_x else 0.06, 0.06, 0.06 if along_x else tw), col)
		_neon(p - Vector3(0, 0.75, 0), Vector3(tw if along_x else 0.06, 0.06, 0.06 if along_x else tw), col)
		_neon(p + right * tw * 0.5, Vector3(0.06, 1.56, 0.06), col)
		_neon(p - right * tw * 0.5, Vector3(0.06, 1.56, 0.06), col)
	else:
		# dikey tabela: cepheden taşan pano (çarpışmalı, başın üstünde)
		var p := base + off.normalized() * (((fp.z if along_x else fp.x) * 0.5) + 0.95) + right * (w * 0.5) + Vector3(0, 7.0, 0)
		var n := mini(txt.length(), 6)
		var hh := n * 1.05 + 0.6
		var psize := Vector3(0.25, hh, 1.3) if along_x else Vector3(1.3, hh, 0.25)
		_box(p + Vector3(0, -hh * 0.5 + 1.0, 0), psize, Game.paint(Color(0.06, 0.06, 0.08), 0.3, 0.4), true)
		for k in range(n):
			for s2: int in [-1, 1]:
				var lp: Vector3 = p + Vector3(0, -k * 1.05 + 0.6, 0) + right * (0.15 * s2)
				_label(txt[k], lp, yaw + PI * 0.5 * s2, col, 110, 0.009)
		_neon(p + Vector3(0, 1.32, 0), Vector3(0.3, 0.08, 1.4) if along_x else Vector3(1.4, 0.08, 0.3), col)
		_neon(p + Vector3(0, -hh + 0.68, 0), Vector3(0.3, 0.08, 1.4) if along_x else Vector3(1.4, 0.08, 0.3), col)
	if d == "eski":
		_neon(base + off * 1.05 + Vector3(0, 3.0, 0), Vector3(0.6, 0.8, 0.6), Color(1.0, 0.18, 0.08))


# ---------------------------------------------------------------- sokak eşyaları
func _merged(parts: Array) -> ArrayMesh:
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
		parts.append([seg, Transform3D(Basis(Vector3(0, 0, 1), -0.03 * i), Vector3(x, h + 0.65, 0)), bark])
		h += 1.28
		x += 0.05 * i
	var top := Vector3(x, h, 0)
	# yapraklar iki parçalı: önce hafifçe yukarı, sonra aşağı sarkar
	for k in range(12):
		var yaw := k * TAU / 12.0 + (k % 2) * 0.12
		var inner := QuadMesh.new()
		inner.size = Vector2(0.8, 1.8)
		inner.center_offset = Vector3(0, 0.9, 0)
		var b1 := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5 - 0.45 - (k % 3) * 0.1)
		parts.append([inner, Transform3D(b1, top), frond_mat])
		var tip_pos: Vector3 = top + b1 * Vector3(0, 1.75, 0)
		var outer := QuadMesh.new()
		outer.size = Vector2(0.7, 2.0)
		outer.center_offset = Vector3(0, 1.0, 0)
		var b2 := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5 + 0.55 + (k % 3) * 0.12)
		parts.append([outer, Transform3D(b2, tip_pos), frond_mat])
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


func _multi(mesh: Mesh, xforms: Array, mat: Material = null, vis_end := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
	add_child(mmi)
	return mmi


func _street_furniture() -> void:
	var palms := []
	var lamps := []
	var outer := BLOCK + WALK * 2.0
	var lamp_n := 0
	for bi in blocks.size():
		var r := blocks[bi]
		var c := r.get_center()
		var d := block_district[bi]
		var hw := outer * 0.5 - 1.2
		for s in [-1, 1]:
			var t := -hw + 6.0
			while t < hw - 4.0:
				var slot := int((t + hw) / 12.0)
				var odd := slot % 2 == 0
				var p1 := Vector3(c.x + t, 0.18, c.y + s * hw)
				var p2 := Vector3(c.x + s * hw, 0.18, c.y + t)
				var palm_ok := d == "sahil" or d == "cadde" or d == "konut" or (d == "merkez" and slot % 4 == 0)
				if odd and palm_ok:
					for p in [p1, p2]:
						palms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), p))
						_cyl_collider(p, 0.3, 4.0)
				elif not odd:
					lamps.append(Transform3D(Basis(Vector3.UP, -PI * 0.5 * s), p1))
					lamps.append(Transform3D(Basis(Vector3.UP, PI if s > 0 else 0.0), p2))
					for p in [p1, p2]:
						_cyl_collider(p, 0.18, 4.0)
						breakables.append(["lamp", p])
						lamp_n += 1
						if lamp_n % 2 == 0:
							continue
						var l := OmniLight3D.new()
						l.light_color = Color(1.0, 0.82, 0.58) if d != "eski" else Color(1.0, 0.55, 0.3)
						l.light_energy = 3.0
						l.omni_range = 17.0
						l.omni_attenuation = 1.3
						l.distance_fade_enabled = true
						l.distance_fade_begin = 60.0
						l.distance_fade_length = 20.0
						l.position = p + Vector3(0, 6.6, 0) + (Vector3(0, 0, -s * 1.6) if p == p1 else Vector3(-s * 1.6, 0, 0))
						l.visible = false
						add_child(l)
						street_lights.append(l)
				t += 12.0
	var x := -EDGE
	while x < EDGE:
		var p := Vector3(x, 0.18, EDGE + 4.0)
		palms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.35)), p))
		_cyl_collider(p, 0.3, 4.0)
		x += 14.0
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
	for key in ["bench", "bin", "hydrant", "plant"]:
		var sc := Game.model(key)
		if sc == null:
			continue
		for r in blocks:
			if rng.randf() < 0.45:
				continue
			var c := r.get_center()
			var n: Node3D = sc.instantiate()
			var s := 1 if rng.randf() < 0.5 else -1
			var t := rng.randf_range(-20, 20)
			n.position = Vector3(c.x + t, 0.18, c.y + s * (outer * 0.5 - 2.2))
			n.rotation.y = 0.0 if s > 0 else PI
			add_child(n)
			_cyl_collider(n.position, 0.35 if key != "bench" else 0.6, 1.0)
			breakables.append([key, n])
	for i in range(-GRID + 1, GRID):
		for j in range(-GRID + 1, GRID):
			var k := Vector3(i * CELL, 0, j * CELL)
			_traffic_light(k + Vector3(ROAD_W * 0.5 + 1.2, 0.18, ROAD_W * 0.5 + 1.2), 0)
			_traffic_light(k + Vector3(-ROAD_W * 0.5 - 1.2, 0.18, -ROAD_W * 0.5 - 1.2), 1)


func _traffic_light(p: Vector3, axis: int) -> void:
	var metal := Game.paint(Color(0.12, 0.12, 0.13), 0.6, 0.5)
	_box(p + Vector3(0, 2.6, 0), Vector3(0.18, 5.2, 0.18), metal)
	_box(p + Vector3(0, 5.0, 0), Vector3(0.45, 1.2, 0.35), metal, false)
	var red := _box(p + Vector3(0, 5.35, 0.19 if axis == 0 else -0.19), Vector3(0.26, 0.26, 0.05), Game.emissive(Color(1, 0.12, 0.08), 6.0), false)
	var green := _box(p + Vector3(0, 4.7, 0.19 if axis == 0 else -0.19), Vector3(0.26, 0.26, 0.05), Game.emissive(Color(0.15, 1, 0.45), 6.0), false)
	signal_lights.append([red, green, axis])


func _lanterns() -> void:
	## Eski Çarşı: sokakların üstünde fener dizileri
	var red := []
	var orange := []
	var wires := []
	for i in range(-GRID, GRID + 1):
		for j in range(-GRID, GRID):
			if not (districts.get(Vector2i(i - 1, j), "") == "eski" or districts.get(Vector2i(i, j), "") == "eski"):
				continue
			var z := j * CELL + 14.0
			while z < (j + 1) * CELL - 12.0:
				for k in range(7):
					var t := (k - 3) / 3.0
					var p := Vector3(i * CELL + t * (ROAD_W * 0.5 + 2.0), 7.2 - (1.0 - t * t) * 1.0, z)
					(red if k % 2 == 0 else orange).append(Transform3D(Basis(), p))
				wires.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(i * CELL, 7.0, z)))
				z += 9.0
	for j in range(-GRID, GRID + 1):
		for i in range(-GRID, GRID):
			if not (districts.get(Vector2i(i, j - 1), "") == "eski" or districts.get(Vector2i(i, j), "") == "eski"):
				continue
			var x := i * CELL + 14.0
			while x < (i + 1) * CELL - 12.0:
				for k in range(7):
					var t := (k - 3) / 3.0
					var p := Vector3(x, 7.2 - (1.0 - t * t) * 1.0, j * CELL + t * (ROAD_W * 0.5 + 2.0))
					(red if k % 2 == 0 else orange).append(Transform3D(Basis(), p))
				wires.append(Transform3D(Basis(), Vector3(x, 7.0, j * CELL)))
				x += 9.0
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.75
	sm.radial_segments = 10
	sm.rings = 6
	var mr := _multi(sm, red, neon_mat, 220.0)
	mr.set_instance_shader_parameter("neon_col", Color(1.0, 0.15, 0.08))
	mr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mo := _multi(sm, orange, neon_mat, 220.0)
	mo.set_instance_shader_parameter("neon_col", Color(1.0, 0.55, 0.12))
	mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wm := BoxMesh.new()
	wm.size = Vector3(0.03, 0.03, ROAD_W + 4.0)
	_multi(wm, wires, Game.paint(Color(0.05, 0.05, 0.05), 0.0, 0.8), 220.0)


# ---------------------------------------------------------------- monoray
func rail_point(s: float) -> Array:
	var R := RAIL_R
	var r := 12.0
	var L := 2.0 * (R - r)
	var arc := PI * 0.5 * r
	var per := 4.0 * (L + arc)
	s = fposmod(s, per)
	var k := int(s / (L + arc))
	var u := s - k * (L + arc)
	var centers := [Vector2(R - r, R - r), Vector2(-R + r, R - r), Vector2(-R + r, -R + r), Vector2(R - r, -R + r)]
	var th0 := k * PI * 0.5
	var p2: Vector2
	var d2: Vector2
	if u < L:
		var dirv := Vector2(cos(th0), sin(th0))
		var tan := Vector2(-sin(th0), cos(th0))
		p2 = (centers[(k + 3) % 4] as Vector2) + dirv * r + tan * u
		d2 = tan
	else:
		var th := th0 + (u - L) / r
		p2 = (centers[k] as Vector2) + Vector2(cos(th), sin(th)) * r
		d2 = Vector2(-sin(th), cos(th))
	return [Vector3(p2.x, RAIL_H, p2.y), Vector3(d2.x, 0, d2.y)]


func _monorail() -> void:
	var concrete := Game.pbr("concrete", Color(0.82, 0.82, 0.85), 0.4)
	var r := 12.0
	var per := ((RAIL_R * 2.0 - r * 2.0) + PI * 0.5 * r) * 4.0
	var s := 0.0
	var step := 4.0
	while s < per:
		var a: Array = rail_point(s)
		var b: Array = rail_point(s + step)
		var mid: Vector3 = (a[0] + b[0]) * 0.5
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0, 1.1, (b[0] - a[0]).length() + 0.08)
		seg.mesh = bm
		seg.material_override = concrete
		add_child(seg)
		seg.look_at_from_position(mid, mid + (b[0] - a[0]), Vector3.UP)
		var dir: Vector3 = (b[0] - a[0]).normalized()
		_neon(mid + Vector3(0, -0.6, 0), Vector3(0.12, 0.06, bm.size.z), Color(0.1, 0.9, 1.0), Vector3(0, atan2(dir.x, dir.z), 0), "rail")
		s += step
	s = 10.0
	while s < per:
		var p: Vector3 = rail_point(s)[0]
		var near_x: float = abs(fmod(abs(p.x) + CELL * 0.5, CELL) - CELL * 0.5)
		var near_z: float = abs(fmod(abs(p.z) + CELL * 0.5, CELL) - CELL * 0.5)
		if not (near_x < 14.0 and near_z < 14.0):
			var col := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.7
			cm.bottom_radius = 0.85
			cm.height = RAIL_H - 0.5
			cm.radial_segments = 12
			col.mesh = cm
			col.material_override = concrete
			col.position = Vector3(p.x, cm.height * 0.5, p.z)
			add_child(col)
			_cyl_collider(Vector3(p.x, 0, p.z), 0.8, RAIL_H - 0.5)
		s += 26.0
	_poi("monoray", "Monoray İstasyonu", "station", Vector3(RAIL_R, 0, 0))
	var body := Game.paint(Color(0.95, 0.95, 0.97), 0.4, 0.25, 0.8)
	for k in range(3):
		var car := Node3D.new()
		add_child(car)
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 1.4
		cm.height = 12.0
		mi.mesh = cm
		mi.rotation.x = PI * 0.5
		mi.scale = Vector3(1.0, 1.0, 1.15)
		mi.material_override = body
		mi.position.y = 2.0
		car.add_child(mi)
		for sd in [-1, 1]:
			var w := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(0.05, 0.7, 9.0)
			w.mesh = wb
			w.material_override = Game.emissive(Color(1.0, 0.9, 0.7), 1.5)
			w.position = Vector3(sd * 1.38, 2.3, 0)
			car.add_child(w)
			var st := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(0.06, 0.15, 10.5)
			st.mesh = sb
			st.material_override = neon_mat
			st.set_instance_shader_parameter("neon_col", Color(1.0, 0.15, 0.75))
			st.position = Vector3(sd * 1.4, 1.5, 0)
			car.add_child(st)
		train.append(car)
	_move_train(0.0)


func _move_train(delta: float) -> void:
	if train.is_empty():
		return
	_train_s += delta * 15.0
	for k in train.size():
		var a: Array = rail_point(_train_s - k * 13.2)
		var car: Node3D = train[k]
		car.position = a[0] + Vector3(0, 0.5, 0)
		car.look_at(car.position + a[1], Vector3.UP)


# ---------------------------------------------------------------- kıyılar, yollar, simge yapılar
func _road_strip(a: Vector3, b: Vector3, width: float) -> void:
	extra_roads.append([Vector2(a.x, a.z), Vector2(b.x, b.z), width])
	var mid := (a + b) * 0.5
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.3, a.distance_to(b) + 0.2)
	mi.mesh = bm
	mi.material_override = Game.pbr("asphalt", Color(0.75, 0.75, 0.75), 0.11, 0.8)
	add_child(mi)
	mi.look_at_from_position(mid, b, Vector3.UP)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.global_transform = mi.global_transform


func _coast() -> void:
	_poi("sahil", "Sahil", "beach", Vector3(0, 0, EDGE + 40))
	var wood := Game.paint(Color(0.45, 0.33, 0.22), 0.0, 0.85)
	var west := -EDGE - 70.0
	for k in range(4):
		var z := 60.0 + k * 60.0
		var pier_len := 70.0
		_box(Vector3(west - pier_len * 0.5 + 30.0, 1.4, z), Vector3(pier_len, 0.5, 8.0), wood)
		for q in range(0, int(pier_len), 8):
			_box(Vector3(west + 30.0 - q, -1.5, z - 3.6), Vector3(0.5, 6.0, 0.5), wood, false)
			_box(Vector3(west + 30.0 - q, -1.5, z + 3.6), Vector3(0.5, 6.0, 0.5), wood, false)
		_box(Vector3(west - 20.0, 0.6, z + 16.0), Vector3(42.0, 6.0, 10.0), Game.paint([Color(0.7, 0.15, 0.12), Color(0.15, 0.3, 0.55), Color(0.2, 0.2, 0.22)][k % 3], 0.3, 0.6))
		_box(Vector3(west - 26.0, 5.5, z + 16.0), Vector3(10.0, 4.0, 8.0), Game.paint(Color(0.92, 0.92, 0.9), 0.1, 0.6))
	for k in range(3):
		var p := Vector3(west + 22.0, 0, 90.0 + k * 60.0)
		var yel := Game.paint(Color(0.95, 0.7, 0.1), 0.4, 0.5)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_box(p + Vector3(sx * 4.0, 12.0, sz * 4.0), Vector3(0.8, 24.0, 0.8), yel)
		_box(p + Vector3(-12.0, 24.5, 0), Vector3(44.0, 1.6, 2.0), yel, false)
	_poi("liman", "Liman", "harbor", Vector3(west, 0, 150))
	_label("LİMAN", Vector3(-EDGE - 8, 9, 120), PI * 0.5, Color(1.0, 0.85, 0.2), 140, 0.05)
	# doğu yolu + köprü + güvenlikli ada yolu
	_road_strip(Vector3(EDGE, 0.0, 0), Vector3(BRIDGE_X0, 2.0, 0), 12.0)
	_road_strip(Vector3(BRIDGE_X0, 2.0, 0), Vector3(BRIDGE_X0 + 30.0, 6.0, 0), 12.0)
	_road_strip(Vector3(BRIDGE_X0 + 30.0, 6.0, 0), Vector3(BRIDGE_X1 - 30.0, 6.0, 0), 12.0)
	_road_strip(Vector3(BRIDGE_X1 - 30.0, 6.0, 0), Vector3(BRIDGE_X1, 3.2, 0), 12.0)
	var steel := Game.paint(Color(0.75, 0.2, 0.18), 0.7, 0.4)
	var x := BRIDGE_X0 + 30.0
	while x <= BRIDGE_X1 - 30.0:
		_box(Vector3(x, -3.0, 0), Vector3(3.0, 18.0, 3.0), Game.pbr("concrete", Color(0.8, 0.8, 0.8), 0.3), false)
		for s in [-1, 1]:
			_box(Vector3(x, 12.0, s * 6.4), Vector3(0.8, 12.0, 0.8), steel, false)
		x += 33.0
	for s in [-1, 1]:
		_box(Vector3((BRIDGE_X0 + BRIDGE_X1) * 0.5, 7.0, s * 6.2), Vector3(BRIDGE_X1 - BRIDGE_X0 - 60.0, 1.0, 0.3), steel)
		_neon(Vector3((BRIDGE_X0 + BRIDGE_X1) * 0.5, 18.2, s * 6.4), Vector3(BRIDGE_X1 - BRIDGE_X0 - 60.0, 0.15, 0.15), Color(1.0, 0.2, 0.5), Vector3.ZERO, "bridge")
	_road_strip(Vector3(BRIDGE_X1, 3.2, 0), Vector3(ISLE.x - 40.0, 3.2, ISLE.y), 12.0)
	# manastır yolu (rampa)
	var z0 := -EDGE
	var z1 := MON.z + 60.0
	var n := 12
	for k in n:
		var za := lerpf(z0, z1, float(k) / n)
		var zb := lerpf(z0, z1, float(k + 1) / n)
		var ya := clampf((-EDGE - za) / (absf(MON.z) - 60.0 - EDGE), 0.0, 1.0) * MON.y
		var yb := clampf((-EDGE - zb) / (absf(MON.z) - 60.0 - EDGE), 0.0, 1.0) * MON.y
		_road_strip(Vector3(MON.x, ya, za), Vector3(MON.x, yb, zb), 10.0)
	_label("KASIRGA MANASTIRI ↑", Vector3(MON.x + 7.0, 6.0, -EDGE - 12.0), 0.0, Color(1.0, 0.8, 0.4), 110, 0.03)


func _monastery() -> void:
	## Kasırga Manastırı: avlu, ana salon (üç katlı pagoda), çan kulesi, idman kuklaları, gong
	var c := MON
	var stone := Game.pbr("concrete", Color(0.75, 0.72, 0.68), 0.3)
	var wood := Game.paint(Color(0.55, 0.18, 0.12), 0.0, 0.7)
	var tile := Game.paint(Color(0.15, 0.32, 0.3), 0.1, 0.5)
	_box(c + Vector3(0, -0.4, 0), Vector3(110, 1.0, 110), stone)
	for spec in [[Vector3(0, 1.5, -54), Vector3(110, 3, 2)], [Vector3(-54, 1.5, 0), Vector3(2, 3, 110)], [Vector3(54, 1.5, 0), Vector3(2, 3, 110)],
			[Vector3(-34, 1.5, 54), Vector3(42, 3, 2)], [Vector3(34, 1.5, 54), Vector3(42, 3, 2)]]:
		_box(c + spec[0], spec[1], stone)
	for s in [-1, 1]:
		_box(c + Vector3(s * 7.0, 4.0, 56.0), Vector3(1.0, 8.0, 1.0), wood)
	_box(c + Vector3(0, 8.4, 56.0), Vector3(18.0, 0.8, 1.6), wood)
	_box(c + Vector3(0, 7.2, 56.0), Vector3(15.0, 0.5, 1.0), wood)
	_label("KASIRGA MANASTIRI", c + Vector3(0, 9.6, 57.0), 0.0, Color(1.0, 0.8, 0.4), 120, 0.03)
	var hall := c + Vector3(0, 0.1, -22)
	_box(hall + Vector3(0, 0.6, 0), Vector3(34, 1.2, 24), stone)
	var hm := _facade_mat("eski", false)
	hm.set_shader_parameter("tint", Color(0.85, 0.3, 0.22))
	_box(hall + Vector3(0, 5.2, 0), Vector3(26, 8.0, 18), hm)
	_pagoda(hall, Vector3(26, 0, 18), 9.2, tile, 3)
	var bell := c + Vector3(-36, 0, -30)
	_box(bell + Vector3(0, 5, 0), Vector3(6, 10, 6), hm)
	_pagoda(bell, Vector3(6, 0, 6), 10.0, tile, 2)
	var dummy_wood := Game.paint(Color(0.5, 0.36, 0.22), 0.0, 0.9)
	for k in range(6):
		var p := c + Vector3(-20 + k * 8.0, 0.1, 18.0)
		_box(p + Vector3(0, 1.2, 0), Vector3(0.5, 2.4, 0.5), dummy_wood)
		_box(p + Vector3(0, 1.8, 0), Vector3(1.8, 0.3, 0.3), dummy_wood, false)
	for s in [-1, 1]:
		for q in range(3):
			var p := c + Vector3(s * 12.0, 0.1, 40.0 - q * 18.0)
			_box(p + Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.9), stone)
			_neon(p + Vector3(0, 2.0, 0), Vector3(0.7, 0.5, 0.7), Color(1.0, 0.6, 0.25), Vector3.ZERO, "mon")
	var gong := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 1.6
	gm.bottom_radius = 1.6
	gm.height = 0.2
	gong.mesh = gm
	gong.rotation.x = PI * 0.5
	gong.position = c + Vector3(20, 3.2, -2)
	gong.material_override = Game.paint(Color(0.85, 0.6, 0.2), 1.0, 0.25)
	add_child(gong)
	for s in [-1, 1]:
		_box(c + Vector3(20 + s * 2.2, 2.4, -2), Vector3(0.4, 4.8, 0.4), wood)
	_box(c + Vector3(20, 4.9, -2), Vector3(4.8, 0.4, 0.4), wood, false)
	_poi("manastir", "Kasırga Manastırı", "monastery", c)


func _secure_island() -> void:
	var c := Vector3(ISLE.x, 3.0, ISLE.y)
	var wall := Game.pbr("concrete", Color(0.6, 0.62, 0.66), 0.3)
	_box(c + Vector3(0, 0.1, 0), Vector3(160, 0.4, 160), Game.pbr("concrete", Color(0.5, 0.52, 0.55), 0.2))
	for spec in [[Vector3(0, 4, -60), Vector3(120, 8, 2)], [Vector3(60, 4, 0), Vector3(2, 8, 120)], [Vector3(0, 4, 60), Vector3(120, 8, 2)],
			[Vector3(-60, 4, -36), Vector3(2, 8, 48)], [Vector3(-60, 4, 36), Vector3(2, 8, 48)]]:
		_box(c + spec[0], spec[1], wall)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var tp := c + Vector3(sx * 60, 0, sz * 60)
			_box(tp + Vector3(0, 8, 0), Vector3(5, 16, 5), wall)
			_neon(tp + Vector3(0, 16.5, 0), Vector3(5.4, 0.3, 5.4), Color(1.0, 0.1, 0.15), Vector3.ZERO, "isle")
	var core := _facade_mat("tekno", true)
	_box(c + Vector3(10, 14, 0), Vector3(40, 28, 30), core)
	_occluder(c + Vector3(10, 14, 0), Vector3(40, 28, 30))
	_neon(c + Vector3(10, 28.5, 0), Vector3(41, 0.4, 31), Color(1.0, 0.15, 0.75), Vector3.ZERO, "isle")
	_label("GÜVENLİKLİ ADA", c + Vector3(-62, 10, 0), -PI * 0.5, Color(1.0, 0.25, 0.3), 140, 0.045)
	_poi("ada", "Güvenlikli Ada", "secure", c)


func _landmarks() -> void:
	## hikâyedeki önemli mekânlar (dış cephe + harita noktası); iç mekânlar 2. güncellemede
	var bc := func(i: int, j: int) -> Vector3:
		return Vector3((i + 0.5) * CELL, 0.18, (j + 0.5) * CELL)
	var sm: Vector3 = bc.call(-2, 1)
	var sm_top := sm + Vector3(-12, 14, 22)
	for k in 18:
		var a := k * TAU / 18.0
		for row in range(5):
			var r := 2.4 * sin(PI * (row + 0.5) / 5.0) + 0.6
			_neon(sm_top + Vector3(cos(a) * r, row * 1.1, sin(a) * r), Vector3(0.35, 0.35, 0.35), Color(1.0, 0.8, 0.1), Vector3.ZERO, "smoothie")
	for k in 7:
		var a := k * TAU / 7.0
		_neon(sm_top + Vector3(cos(a) * 0.6, 6.4, sin(a) * 0.6), Vector3(0.25, 2.6, 0.25), Color(0.2, 1.0, 0.35), Vector3(cos(a) * 0.5, 0, sin(a) * 0.5), "smoothie")
	_label("ANANAS SMOOTHIE", sm + Vector3(-12, 6.0, 30.5), 0.0, Color(1.0, 0.85, 0.2), 128, 0.028)
	_poi("smoothie", "Ananas Smoothie", "food", sm + Vector3(-12, 0, 30))
	var dj: Vector3 = bc.call(1, -2)
	_label("TURBO DOJO", dj + Vector3(0, 9.0, 30.5), 0.0, Color(1.0, 0.2, 0.85), 128, 0.028)
	_poi("dojo", "Turbo Tarık'ın Dojosu", "dojo", dj + Vector3(0, 0, 30))
	var nd: Vector3 = bc.call(-3, -1)
	_label("NODA ERİŞTE EVİ", nd + Vector3(0, 6.0, 30.5), 0.0, Color(1.0, 0.35, 0.2), 128, 0.028)
	_poi("noodle", "Noda Erişte Evi", "food", nd + Vector3(0, 0, 30))
	var wp: Vector3 = bc.call(-4, 0)
	_label("KILIÇ & YILDIZ", wp + Vector3(30.5, 6.0, 0), PI * 0.5, Color(0.4, 0.9, 1.0), 128, 0.028)
	_poi("weapons", "Kılıç & Yıldız", "weapons", wp + Vector3(30, 0, 0))
	var bt: Vector3 = bc.call(0, 1)
	_label("GÖLGE BUTİK", bt + Vector3(0, 6.0, 30.5), 0.0, Color(0.7, 0.4, 1.0), 128, 0.028)
	_poi("boutique", "Gölge Butik", "clothes", bt + Vector3(0, 0, 30))
	var cl: Vector3 = bc.call(1, 2)
	_label("NEON KULÜP", cl + Vector3(0, 7.0, -30.5), PI, Color(0.2, 1.0, 1.0), 128, 0.028)
	_poi("club", "Neon Kulüp", "club", cl + Vector3(0, 0, -30))
	var pd: Vector3 = bc.call(-1, -3)
	_label("POLİS MERKEZİ", pd + Vector3(0, 7.0, 30.5), 0.0, Color(0.4, 0.6, 1.0), 128, 0.028)
	_poi("police", "Polis Merkezi", "police", pd + Vector3(0, 0, 30))
	var hs: Vector3 = bc.call(3, 1)
	_label("HASTANE", hs + Vector3(-30.5, 7.0, 0), -PI * 0.5, Color(1.0, 0.3, 0.3), 128, 0.028)
	_poi("hospital", "Hastane", "hospital", hs + Vector3(-30, 0, 0))
	var sp: Vector3 = bc.call(2, -1)
	_label("BOYA ATÖLYESİ", sp + Vector3(0, 6.0, 30.5), 0.0, Color(0.3, 1.0, 0.5), 128, 0.028)
	_poi("spray", "Boya Atölyesi", "spray", sp + Vector3(0, 0, 30))
	# Teknoloji Kulesi (Mimar'ın kulesi): adanın en yüksek yapısı
	var tk: Vector3 = bc.call(3, -3)
	var tower_h := 190.0
	var tm := _facade_mat("tekno", true)
	_box(tk + Vector3(0, tower_h * 0.5, 0), Vector3(30, tower_h, 30), tm)
	_occluder(tk + Vector3(0, tower_h * 0.5, 0), Vector3(30, tower_h, 30))
	_box(tk + Vector3(0, tower_h + 12.0, 0), Vector3(18, 24, 18), tm)
	_box(tk + Vector3(0, tower_h + 40.0, 0), Vector3(1.2, 32, 1.2), Game.paint(Color(0.8, 0.8, 0.85), 0.9, 0.2), false)
	for k in range(12):
		_neon(tk + Vector3(0, 20.0 + k * 15.0, 15.2), Vector3(30.4, 0.3, 0.2), Color(1.0, 0.15, 0.75), Vector3.ZERO, "tower")
		_neon(tk + Vector3(15.2, 20.0 + k * 15.0, 0), Vector3(0.2, 0.3, 30.4), Color(1.0, 0.15, 0.75), Vector3.ZERO, "tower")
	_neon(tk + Vector3(0, tower_h + 56.5, 0), Vector3(1.5, 1.5, 1.5), Color(1, 0.1, 0.1), Vector3.ZERO, "tower")
	_label("TEKNOLOJİ KULESİ", tk + Vector3(0, 14.0, 15.3), 0.0, Color(1.0, 0.3, 0.85), 128, 0.03)
	_poi("tower", "Teknoloji Kulesi", "tower", tk)


func _trees() -> void:
	var trunk := Game.paint(Color(0.35, 0.25, 0.18), 0.0, 0.9)
	var leaf := Game.paint(Color(0.16, 0.36, 0.18), 0.0, 0.85)
	var tr := CylinderMesh.new()
	tr.top_radius = 0.18
	tr.bottom_radius = 0.28
	tr.height = 3.0
	tr.radial_segments = 6
	var pine_parts := [[tr, Transform3D(Basis(), Vector3(0, 1.5, 0)), trunk]]
	for k in range(3):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 2.4 - k * 0.6
		cone.height = 3.2
		cone.radial_segments = 8
		pine_parts.append([cone, Transform3D(Basis(), Vector3(0, 3.2 + k * 1.8, 0)), leaf])
	var pine := _merged(pine_parts)
	var crown := SphereMesh.new()
	crown.radius = 2.6
	crown.height = 4.4
	crown.radial_segments = 10
	crown.rings = 6
	var roundt := _merged([[tr, Transform3D(Basis(), Vector3(0, 1.5, 0)), trunk], [crown, Transform3D(Basis(), Vector3(0, 4.6, 0)), Game.paint(Color(0.25, 0.45, 0.2), 0.0, 0.85)]])
	var chunks := {}
	for k in 9000:
		var x := rng.randf_range(-T_HALF, T_HALF)
		var z := rng.randf_range(-T_HALF, T_HALF)
		if absf(x) < EDGE + 14.0 and absf(z) < EDGE + 14.0:
			continue
		if absf(x - MON.x) < 14.0 and z < -EDGE and z > MON.z:
			continue
		if x > EDGE and absf(z) < 16.0:
			continue
		if Vector2(x, z).distance_to(Vector2(MON.x, MON.z)) < 80.0 or Vector2(x, z).distance_to(ISLE) < 150.0:
			continue
		if x < -EDGE and z > 0.0:
			continue
		var h := terrain_h(x, z)
		if h < 2.0:
			continue
		if absf(terrain_h(x + 3.0, z) - h) > 1.8 or absf(terrain_h(x, z + 3.0) - h) > 1.8:
			continue
		var is_pine := h > 18.0 or rng.randf() < 0.45
		var key := "%s_%d_%d" % ["p" if is_pine else "r", int(floor(x / 300.0)), int(floor(z / 300.0))]
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5)), Vector3(x, h - 0.2, z)))
		_cyl_collider(Vector3(x, h, z), 0.35, 4.0)
	for key in chunks.keys():
		_multi(pine if String(key).begins_with("p") else roundt, chunks[key], null, 600.0)


func _horizon() -> void:
	for k in range(7):
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * rng.randf_range(1900, 2500), -6, sin(a) * rng.randf_range(1900, 2500))
		var isl := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = rng.randf_range(80, 180)
		sp.height = sp.radius * 0.7
		isl.mesh = sp
		isl.position = p
		isl.material_override = Game.paint(Color(0.12, 0.18, 0.16), 0.0, 1.0)
		isl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(isl)


# ---------------------------------------------------------------- yardımcılar
func lane_points() -> Array:
	var pts := []
	for i in range(-GRID, GRID + 1):
		for j in range(-GRID, GRID + 1):
			pts.append(Vector3(i * CELL, 0, j * CELL))
	return pts


func sidewalk_loop(r: Rect2) -> Array:
	var c := r.get_center()
	var hw := r.size.x * 0.5 - 2.6
	return [Vector3(c.x - hw, 0.18, c.y - hw), Vector3(c.x + hw, 0.18, c.y - hw), Vector3(c.x + hw, 0.18, c.y + hw), Vector3(c.x - hw, 0.18, c.y + hw)]


func map_texture() -> ImageTexture:
	## harita/mini harita için ada görseli (deniz, kumsal, çimen, dağ, şehir)
	if _map_tex or _hn == 0:
		return _map_tex
	var img := Image.create(_hn, _hn, false, Image.FORMAT_RGBA8)
	for j in _hn:
		for i in _hn:
			var h := _hm[j * _hn + i]
			var x := -T_HALF + i * T_STEP
			var z := -T_HALF + j * T_STEP
			var c: Color
			if absf(x) <= EDGE and absf(z) <= EDGE:
				c = Color(0.3, 0.31, 0.35)
			elif h < SEA:
				c = Color(0.16, 0.36, 0.52).lerp(Color(0.07, 0.17, 0.3), clampf(-h / 9.0, 0.0, 1.0))
			elif h < 1.3:
				c = Color(0.86, 0.79, 0.58)
			elif h > 45.0:
				c = Color(0.42, 0.44, 0.4).lerp(Color(0.9, 0.9, 0.92), clampf((h - 75.0) / 40.0, 0.0, 1.0))
			else:
				c = Color(0.34, 0.55, 0.3).lerp(Color(0.24, 0.4, 0.22), clampf(h / 45.0, 0.0, 1.0))
			img.set_pixel(i, j, c)
	var di := Vector2(ISLE.x + T_HALF, ISLE.y + T_HALF) / T_STEP
	img.fill_rect(Rect2i(Vector2i(di) - Vector2i(6, 6), Vector2i(12, 12)), Color(0.36, 0.37, 0.42))
	_map_tex = ImageTexture.create_from_image(img)
	return _map_tex


func ground_y(x: float, z: float) -> float:
	if absf(x) <= EDGE and absf(z) <= EDGE:
		return 0.0
	return terrain_h(x, z)
