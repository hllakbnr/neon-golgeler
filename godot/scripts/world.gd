extends Node3D
class_name World
## Neon Gölgeler kıtası. Coğrafya tools/make_world.py tarafından üretilen verilerden kurulur:
## data/world.json (yollar, şehir, yerler, ağaçlar) + world_h.bin (yükseklik) + world_c.bin (zemin rengi)
## + world_r.bin (bölgeler). Şehir (Neon Şehir) dünya merkezinde, kuzeybatı kıyısındadır.

const CELL := 80.0
const ROAD_W := 12.0
const WALK := 5.0
const GX := 5                           # bloklar: i = -GX..GX-1
const GZ := 4                           # bloklar: j = -GZ..GZ-1
const GRID := 5                         # eski kodla uyum (en büyük yarı ızgara)
const BLOCK := CELL - ROAD_W - WALK * 2.0
const CITY_X := GX * CELL
const CITY_Z := GZ * CELL
const EDGE_X := CITY_X + 6.0
const EDGE_Z := CITY_Z + 6.0
const EDGE := EDGE_X
const SEA := -1.2
const RAIL_H := 15.0
const RAIL_R := 80.0
const MON := Vector3(180, 190, -1000)   # Kasırga Manastırı platosu
const ISLE := Vector2(-1050, -950)      # Güvenlikli Ada
const BRIDGE_X0 := -406.0               # eski kodla uyum
const BRIDGE_X1 := -960.0

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
var pois: Array = []                    # {id, name, kind, pos} — harita/telefon
var doors: Array = []                   # {id, name, interior, pos, yaw} — iç mekân kapıları
var props: StaticBody3D
var train: Array[Node3D] = []
var breakables: Array = []              # [tür, düğüm/konum] — devrilebilir sokak eşyaları
var extra_roads: Array = []             # [a: Vector2, b: Vector2, genişlik] (mini harita)
var roads: Array = []                   # json yolları (rota için)
var data := {}
var x0 := 0.0
var z0 := 0.0
var step := 8.0
var hw := 0
var hh := 0
var heights := PackedFloat32Array()
var colors := PackedByteArray()
var regions := PackedByteArray()
var region_names := {}
var region_labels: Array = []           # [ad, Vector2] harita etiketleri
var map_tex: Texture2D
var height_tex: ImageTexture
var _train_s := 0.0
var _last_night := -1.0
var _shadow_t := 0.0
var _neon_buckets := {}
var _map_cache: ImageTexture

var b_shader: Shader = preload("res://shaders/building.gdshader")
var s_shader: Shader = preload("res://shaders/sky.gdshader")
var neon_mat: ShaderMaterial
var neon_batch_mat: ShaderMaterial
var holo_mat: ShaderMaterial
var city: CityBuilder
var places: PlacesBuilder

const NEON := [Color(1.0, 0.15, 0.75), Color(0.1, 0.95, 1.0), Color(1.0, 0.55, 0.1), Color(0.55, 0.3, 1.0), Color(0.3, 1.0, 0.45), Color(1.0, 0.2, 0.25), Color(1.0, 0.85, 0.2)]
const DISTRICT_NAMES := {"merkez": "Neon Bulvar", "cadde": "Neon Bulvar", "eski": "Eski Çarşı", "liman": "Liman", "tekno": "Teknoloji Merkezi",
	"konut": "Doğu Konutları", "sahil": "Sahil", "lunapark": "Neon Lunapark"}


func build(progress: Callable = Callable()) -> void:
	rng.seed = 20261128
	neon_mat = ShaderMaterial.new()
	neon_mat.shader = load("res://shaders/neon.gdshader")
	neon_batch_mat = ShaderMaterial.new()
	neon_batch_mat.shader = load("res://shaders/neon_batch.gdshader")
	holo_mat = ShaderMaterial.new()
	holo_mat.shader = load("res://shaders/holo.gdshader")
	props = StaticBody3D.new()
	add_child(props)
	_load_data()
	_environment()
	await _step(progress, 0.05, "Kıta yükleniyor")
	_terrain()
	await _step(progress, 0.2, "Deniz ve kıyılar")
	_water()
	city = CityBuilder.new(self)
	places = PlacesBuilder.new(self)
	await _step(progress, 0.25, "Neon Şehir kuruluyor")
	await city.build(progress)
	await _step(progress, 0.55, "Yollar ve köprüler")
	places.roads()
	_build_graph()
	await _step(progress, 0.62, "Kasırga Manastırı")
	places.monastery()
	await _step(progress, 0.66, "Simge yerler")
	places.landmarks()
	await _step(progress, 0.7, "Ormanlar")
	places.trees()
	_flush_neon()
	await _step(progress, 0.75, "Son dokunuşlar")
	update_time(Game.time_of_day, true)


var _t0 := 0


func _step(cb: Callable, v: float, txt: String) -> void:
	if OS.get_cmdline_user_args().has("--buildtest"):
		print("KURULUM %.2f  %s  (%d ms)" % [v, txt, Time.get_ticks_msec() - _t0])
		_t0 = Time.get_ticks_msec()
	if cb.is_valid():
		cb.call(v, txt)
	await get_tree().process_frame


# ---------------------------------------------------------------- veri
func _load_data() -> void:
	var f := FileAccess.open("res://data/world.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	x0 = data.x0
	z0 = data.z0
	step = data.step
	hw = int(data.w)
	hh = int(data.h)
	heights = FileAccess.get_file_as_bytes("res://data/world_h.bin").to_float32_array()
	colors = FileAccess.get_file_as_bytes("res://data/world_c.bin")
	regions = FileAccess.get_file_as_bytes("res://data/world_r.bin")
	for r in data.regions:
		region_names[int(r[0])] = String(r[1])
		if int(r[0]) > 1:
			region_labels.append([String(r[1]), Vector2(r[2][0], r[2][1])])
	for p in data.pois:
		pois.append({"id": p.id, "name": p.name, "kind": p.kind, "pos": Vector3(p.pos[0], p.pos[1], p.pos[2])})
	roads = data.roads
	if ResourceLoader.exists("res://data/map.png"):
		map_tex = load("res://data/map.png")
	var img := Image.create_from_data(hw, hh, false, Image.FORMAT_RF, FileAccess.get_file_as_bytes("res://data/world_h.bin"))
	height_tex = ImageTexture.create_from_image(img)


func h_at(i: int, j: int) -> float:
	return heights[clampi(j, 0, hh - 1) * hw + clampi(i, 0, hw - 1)]


func terrain_h(x: float, z: float) -> float:
	var fx := (x - x0) / step
	var fz := (z - z0) / step
	var i := int(floor(fx))
	var j := int(floor(fz))
	var tx := fx - i
	var tz := fz - j
	var a := lerpf(h_at(i, j), h_at(i + 1, j), tx)
	var b := lerpf(h_at(i, j + 1), h_at(i + 1, j + 1), tx)
	return lerpf(a, b, tz)


func ground_y(x: float, z: float) -> float:
	if absf(x) <= EDGE_X and absf(z) <= EDGE_Z:
		return 0.0
	return terrain_h(x, z)


func in_city(p: Vector3, margin := 0.0) -> bool:
	return absf(p.x) <= EDGE_X + margin and absf(p.z) <= EDGE_Z + margin


func district(i: int, j: int) -> String:
	return districts.get(Vector2i(i, j), "cadde")


func district_at(p: Vector3) -> String:
	if absf(p.x) <= EDGE_X and absf(p.z) <= EDGE_Z:
		var i := clampi(int(floor(p.x / CELL)), -GX, GX - 1)
		var j := clampi(int(floor(p.z / CELL)), -GZ, GZ - 1)
		return district(i, j)
	if p.x < -EDGE_X and absf(p.z) <= EDGE_Z + 60.0:
		return "liman" if p.z < 0.0 else "sahil"
	return "r%d" % region_id(p)


func region_id(p: Vector3) -> int:
	var i := clampi(int(round((p.x - x0) / step)), 0, hw - 1)
	var j := clampi(int(round((p.z - z0) / step)), 0, hh - 1)
	return regions[j * hw + i]


func district_name(p: Vector3) -> String:
	var d := district_at(p)
	if d.begins_with("r"):
		return region_names.get(int(d.substr(1)), "")
	return DISTRICT_NAMES.get(d, "")


func map_texture() -> Texture2D:
	return map_tex


func world_rect() -> Rect2:
	return Rect2(x0, z0, (hw - 1) * step, (hh - 1) * step)


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
	env.fog_density = 0.00022
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.12
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
	env.ambient_light_energy = lerp(0.3, 1.0, day)
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
			if is_instance_valid(l):
				l.visible = lamps_on and not l.get_meta("broken", false)
	var phase := int(Time.get_ticks_msec() / 8000) % 2
	for s in signal_lights:
		var green: bool = (phase == 0) == (s[2] == 0)
		s[0].visible = not green
		s[1].visible = green


func _process(delta: float) -> void:
	update_time(Game.time_of_day)
	_move_train(delta)
	if city:
		city.tick(delta)
	if breaker:
		breaker.tick(delta)
	_shadow_t -= delta
	if _shadow_t <= 0.0 and night > 0.35:
		_shadow_t = 0.6
		var cam := get_viewport().get_camera_3d()
		if cam:
			var cp := cam.global_position
			var best: Array = []
			for l in street_lights:
				if not is_instance_valid(l):
					continue
				var d := l.global_position.distance_squared_to(cp)
				if d < 1600.0:
					best.append([d, l])
				else:
					l.shadow_enabled = false
			best.sort_custom(func(a, b): return a[0] < b[0])
			for i in best.size():
				(best[i][1] as OmniLight3D).shadow_enabled = i < 3


# ---------------------------------------------------------------- arazi
func _terrain() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var gt := Game.tex("grass", "diff")
	if gt:
		mat.set_shader_parameter("grass_tex", gt)
		mat.set_shader_parameter("has_grass", true)
	var rt := Game.tex("concrete", "diff")
	if rt:
		mat.set_shader_parameter("rock_tex", rt)
		mat.set_shader_parameter("has_rock", true)
	var C := 64
	var cz := 0
	while cz < hh - 1:
		var cx := 0
		while cx < hw - 1:
			var nx := mini(C, hw - 1 - cx)
			var nz := mini(C, hh - 1 - cz)
			var hi := _chunk_mesh(cx, cz, nx, nz, 1)
			if hi:
				var mi := MeshInstance3D.new()
				mi.mesh = hi
				mi.material_override = mat
				mi.visibility_range_end = 950.0
				mi.visibility_range_end_margin = 60.0
				add_child(mi)
				var lo := _chunk_mesh(cx, cz, nx, nz, 4)
				if lo:
					var ml := MeshInstance3D.new()
					ml.mesh = lo
					ml.material_override = mat
					ml.visibility_range_begin = 950.0
					ml.visibility_range_begin_margin = 60.0
					ml.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					add_child(ml)
			cx += C
		cz += C
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = hw
	hs.map_depth = hh
	hs.map_data = heights
	cs.shape = hs
	cs.scale = Vector3(step, 1.0, step)
	cs.position = Vector3(x0 + (hw - 1) * step * 0.5, 0.0, z0 + (hh - 1) * step * 0.5)
	body.add_child(cs)
	add_child(body)


func _chunk_mesh(cx: int, cz: int, nx: int, nz: int, s: int) -> ArrayMesh:
	var ii: Array[int] = []
	var i := 0
	while i < nx:
		ii.append(i)
		i += s
	ii.append(nx)
	var jj: Array[int] = []
	var j := 0
	while j < nz:
		jj.append(j)
		j += s
	jj.append(nz)
	var cw := ii.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(cw * jj.size())
	norms.resize(cw * jj.size())
	cols.resize(cw * jj.size())
	var k := 0
	for jv in jj:
		var gj := cz + jv
		for iv in ii:
			var gi := cx + iv
			var hgt := heights[gj * hw + gi]
			verts[k] = Vector3(x0 + gi * step, hgt, z0 + gj * step)
			var dx := h_at(gi + 1, gj) - h_at(gi - 1, gj)
			var dz := h_at(gi, gj + 1) - h_at(gi, gj - 1)
			norms[k] = Vector3(-dx, 2.0 * step, -dz).normalized()
			var ci := (gj * hw + gi) * 4
			cols[k] = Color(colors[ci] / 255.0, colors[ci + 1] / 255.0, colors[ci + 2] / 255.0, colors[ci + 3] / 255.0)
			k += 1
	var idx := PackedInt32Array()
	for b in jj.size() - 1:
		for a in cw - 1:
			var v0 := b * cw + a
			var v1 := v0 + 1
			var v2 := v0 + cw
			var v3 := v2 + 1
			var p0 := verts[v0]
			var p3 := verts[v3]
			if maxf(maxf(p0.y, p3.y), maxf(verts[v1].y, verts[v2].y)) < SEA - 7.0:
				continue
			var mx := (p0.x + p3.x) * 0.5
			var mz := (p0.z + p3.z) * 0.5
			if absf(mx) < EDGE_X - 10.0 and absf(mz) < EDGE_Z - 10.0:
				continue
			idx.append_array([v0, v1, v2, v1, v3, v2])
	if idx.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


func _water() -> void:
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(16000, 16000)
	wm.subdivide_width = 200
	wm.subdivide_depth = 200
	water.mesh = wm
	var r := world_rect()
	water.position = Vector3(r.get_center().x, SEA, r.get_center().y)
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	wmat.set_shader_parameter("height_tex", height_tex)
	wmat.set_shader_parameter("world_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	wmat.set_shader_parameter("sea_y", SEA)
	water.material_override = wmat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ---------------------------------------------------------------- yardımcılar (CityBuilder / PlacesBuilder kullanır)
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


func _collider(pos: Vector3, size: Vector3, layer := 1, rot := Vector3.ZERO) -> StaticBody3D:
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
	return sb


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


func _neon_xf(xf: Transform3D, size: Vector3, col: Color, bucket := "") -> void:
	var key := bucket if bucket != "" else "%d_%d" % [int(floor(xf.origin.x / 160.0)), int(floor(xf.origin.z / 160.0))]
	if not _neon_buckets.has(key):
		_neon_buckets[key] = []
	_neon_buckets[key].append([xf, size, col, rng.randf()])


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
		if not String(key).begins_with("far"):
			mi.visibility_range_end = 1400.0
		add_child(mi)
	_neon_buckets.clear()


func _label(text: String, pos: Vector3, yaw: float, col: Color, size := 96, px := 0.012, glow := true) -> Label3D:
	## yazılar yalnızca bir tabelanın/levhanın ÖNÜNDE kullanılır (havada yazı yok)
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = size
	lbl.pixel_size = px
	lbl.outline_size = 0
	lbl.shaded = not glow
	lbl.double_sided = false
	lbl.set_meta("c", col)
	lbl.modulate = col
	if Game.font_display:
		lbl.font = Game.font_display
	lbl.position = pos
	lbl.rotation.y = yaw
	lbl.visibility_range_end = 220.0 if px < 0.03 else 600.0
	lbl.visibility_range_end_margin = 20.0
	lbl.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(lbl)
	if glow:
		neon_labels.append(lbl)
	return lbl


func _board(center: Vector3, yaw: float, w: float, hgt: float, text: String, col: Color, board := Color(0.06, 0.06, 0.08), font := 110) -> void:
	## tabela: koyu levha + neon çerçeve + önünde yazı (levha cepheye ya da direklere bağlıdır)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var bx := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, hgt, 0.22)
	bx.mesh = bm
	bx.material_override = Game.paint(board, 0.3, 0.45)
	bx.position = center
	bx.rotation.y = yaw
	add_child(bx)
	var b := Basis(Vector3.UP, yaw)
	for s in [-1.0, 1.0]:
		_neon_xf(Transform3D(b, center + b * Vector3(0, s * (hgt * 0.5 - 0.05), 0.13)), Vector3(w - 0.1, 0.07, 0.05), col)
		_neon_xf(Transform3D(b, center + b * Vector3(s * (w * 0.5 - 0.05), 0, 0.13)), Vector3(0.07, hgt - 0.1, 0.05), col)
	var px := minf((w - 0.6) / maxf(1.0, text.length() * 0.62 * font * 0.01), (hgt * 0.7) / (font * 0.01)) * 0.01
	_label(text, center + fwd * 0.14, yaw, col, font, px)


func _poi(id: String, name: String, kind: String, pos: Vector3) -> void:
	pois.append({"id": id, "name": name, "kind": kind, "pos": pos})


func _door(id: String, name: String, interior: String, pos: Vector3, yaw: float) -> void:
	doors.append({"id": id, "name": name, "interior": interior, "pos": pos, "yaw": yaw})


func _multi(mesh: Mesh, xforms: Array, mat: Material = null, vis_end := 0.0, cols: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = vis_end * 0.08
	add_child(mmi)
	return mmi


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


func _move_train(delta: float) -> void:
	if train.is_empty():
		return
	_train_s += delta * 15.0
	for k in train.size():
		var a: Array = rail_point(_train_s - k * 13.2)
		var car: Node3D = train[k]
		car.position = a[0] + Vector3(0, 0.5, 0)
		var dv: Vector3 = a[1]
		if dv.length() > 0.001 and absf(dv.normalized().y) < 0.98:
			car.look_at(car.position + dv, Vector3.UP)


# ---------------------------------------------------------------- yaya / trafik yardımcıları
func lane_points() -> Array:
	var pts := []
	for i in range(-GX, GX + 1):
		for j in range(-GZ, GZ + 1):
			pts.append(Vector3(i * CELL, 0, j * CELL))
	return pts


func sidewalk_loop(r: Rect2) -> Array:
	var c := r.get_center()
	var hwid := r.size.x * 0.5 - 2.6
	return [Vector3(c.x - hwid, 0.18, c.y - hwid), Vector3(c.x + hwid, 0.18, c.y - hwid), Vector3(c.x + hwid, 0.18, c.y + hwid), Vector3(c.x - hwid, 0.18, c.y + hwid)]


func walk_ok(p: Vector3) -> bool:
	## şehirde bina adalarının içi (kaldırım şeridi hariç) yürünemez
	if not in_city(p):
		return true
	var half := CELL * 0.5 - ROAD_W * 0.5 - WALK + 0.3
	var cx := (floorf(p.x / CELL) + 0.5) * CELL
	var cz := (floorf(p.z / CELL) + 0.5) * CELL
	return not (absf(p.x - cx) < half and absf(p.z - cz) < half)


func walk_step(from: Vector3, to: Vector3) -> Vector3:
	## duvara çarpınca kayarak ilerle
	if walk_ok(to):
		return to
	var a := Vector3(to.x, to.y, from.z)
	if walk_ok(a):
		return a
	var b := Vector3(from.x, to.y, to.z)
	if walk_ok(b):
		return b
	return Vector3(from.x, to.y, from.z)


func city_floor(p: Vector3) -> float:
	## şehirde kaldırım 0,18 m, yol 0
	if not in_city(p):
		return ground_y(p.x, p.z)
	var dx := absf(p.x - roundf(p.x / CELL) * CELL)
	var dz := absf(p.z - roundf(p.z / CELL) * CELL)
	return 0.0 if (dx < ROAD_W * 0.5 or dz < ROAD_W * 0.5) else 0.18


func poi_pos(id: String) -> Vector3:
	for p in pois:
		if p.id == id:
			return p.pos
	return Vector3(-88.5, 0, -36.0)


func respawn_point(kind: String) -> Vector3:
	## yer işaretine (hastane, karakol…) en yakın kavşağın köşesindeki kaldırım
	var pos := poi_pos(kind)
	var n := astar.get_closest_point(Vector3(pos.x, 0, pos.z))
	var rp := astar.get_point_position(n) if n >= 0 else pos
	var d := pos - rp
	var off := Vector3(signf(d.x) if absf(d.x) > 0.1 else 1.0, 0, signf(d.z) if absf(d.z) > 0.1 else 1.0)
	return rp + off * (ROAD_W * 0.5 + 2.5) + Vector3(0, 0.4, 0)


var breaker: PropBreaker
var interiors: Interiors


func try_door(pl: Player) -> bool:
	if interiors == null:
		interiors = Interiors.new()
		interiors.world = self
		add_child(interiors)
	return interiors.try_use(pl)


func door_prompt(p: Vector3, in_car := false) -> String:
	if interiors == null:
		if nearest_door(p, 7.0 if in_car else 2.6).is_empty():
			return ""
		interiors = Interiors.new()
		interiors.world = self
		add_child(interiors)
	return interiors.prompt(p, in_car)


func hit_props(center: Vector3, radius: float, impulse: Vector3) -> bool:
	if breaker == null:
		breaker = PropBreaker.new(self)
	return breaker.hit(center, radius, impulse)


func node_ok(n: Vector2i) -> bool:
	return n.x >= -GX and n.x <= GX and n.y >= -GZ and n.y <= GZ


# ---------------------------------------------------------------- yol ağı (GPS rotası)
var astar := AStar3D.new()


func _build_graph() -> void:
	var id := 0
	var city_ids := {}
	for i in range(-GX, GX + 1):
		for j in range(-GZ, GZ + 1):
			astar.add_point(id, Vector3(i * CELL, 0, j * CELL))
			city_ids[Vector2i(i, j)] = id
			id += 1
	for k in city_ids.keys():
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = k + d
			if city_ids.has(n):
				astar.connect_points(city_ids[k], city_ids[n])
	for r in roads:
		var pts: Array = r.pts
		var prev := -1
		var acc := 0.0
		var last_p := Vector3.ZERO
		for k in pts.size():
			var p := Vector3(pts[k][0], 0, pts[k][2])
			if k > 0:
				acc += p.distance_to(last_p)
			last_p = p
			if k == 0 or k == pts.size() - 1 or acc >= 40.0:
				acc = 0.0
				if k == 0 or k == pts.size() - 1:
					var near := astar.get_closest_point(p)
					if near >= 0 and astar.get_point_position(near).distance_to(p) < 90.0:
						if prev >= 0 and prev != near:
							astar.connect_points(prev, near)
						prev = near
						continue
				astar.add_point(id, p)
				if prev >= 0:
					astar.connect_points(prev, id)
				prev = id
				id += 1


func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := astar.get_closest_point(Vector3(from.x, 0, from.z))
	var b := astar.get_closest_point(Vector3(to.x, 0, to.z))
	var out := PackedVector3Array([Vector3(from.x, 0, from.z)])
	if a >= 0 and b >= 0:
		out.append_array(astar.get_point_path(a, b))
	out.append(Vector3(to.x, 0, to.z))
	return out


func nearest_door(p: Vector3, max_d := 3.0) -> Dictionary:
	var best := {}
	var bd := max_d
	for d in doors:
		var dd: float = (d.pos as Vector3).distance_to(p)
		if dd < bd:
			bd = dd
			best = d
	return best
