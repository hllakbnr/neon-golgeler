extends Node3D
class_name World
## Neon şehir: Asya esintili fütüristik metropol (merkezde neon kuleler ve hologramlar,
## kuzeyde pagoda çatılı Eski Çarşı ve fenerler, güneyde palmiyeli Sahil ve deniz),
## havada monoray, gece ıslak asfalt ve neon yansımaları, gün/gece döngüsü.

const CELL := 80.0
const ROAD_W := 12.0
const WALK := 5.0
const GRID := 3            # -GRID..GRID yol çizgileri → 6x6 blok
const BLOCK := CELL - ROAD_W - WALK * 2.0
const COAST := GRID * CELL + 6.0       # sahil şeridi başlangıcı (güney)
const RAIL_H := 15.0
const RAIL_R := 80.0                   # monoray halkası (merkez çevresi)

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var street_lights: Array[OmniLight3D] = []
var signal_lights: Array = []   # [mesh_red, mesh_green, axis]
var neon_labels: Array[Label3D] = []
var rng := RandomNumberGenerator.new()
var night := 0.0
var blocks: Array[Rect2] = []   # yayalar ve mini harita için
var districts := {}             # Vector2i → "merkez" | "eski" | "sahil" | "cadde"
var props: StaticBody3D         # sokak eşyalarının çarpışma gövdesi
var train: Array[Node3D] = []
var _train_s := 0.0
var _last_night := -1.0
var _shadow_t := 0.0

var b_shader: Shader = preload("res://shaders/building.gdshader")
var r_shader: Shader = preload("res://shaders/road.gdshader")
var s_shader: Shader = preload("res://shaders/sky.gdshader")
var f_shader: Shader = preload("res://shaders/frond.gdshader")
var neon_mat: ShaderMaterial
var holo_mat: ShaderMaterial

const NEON := [Color(1.0, 0.15, 0.75), Color(0.1, 0.95, 1.0), Color(1.0, 0.55, 0.1), Color(0.55, 0.3, 1.0), Color(0.3, 1.0, 0.45), Color(1.0, 0.2, 0.25), Color(1.0, 0.85, 0.2)]
const SIGNS := ["ERİŞTE", "DOJO", "NEON", "KAFE", "OTEL", "ÇAY", "SUSHİ", "ARCADE", "KULÜP", "BUTİK", "ECZANE", "RAMEN", "KARAOKE", "TEKNO", "MANGA", "BAR", "LOKUM", "DÖNER", "GECE", "SİNEMA"]


func build() -> void:
	rng.seed = 20261127
	neon_mat = ShaderMaterial.new()
	neon_mat.shader = load("res://shaders/neon.gdshader")
	holo_mat = ShaderMaterial.new()
	holo_mat.shader = load("res://shaders/holo.gdshader")
	props = StaticBody3D.new()
	add_child(props)
	_environment()
	_ground()
	_sea()
	for i in range(-GRID, GRID):
		for j in range(-GRID, GRID):
			_block(i, j)
	_outer_ring()
	_street_furniture()
	_lanterns()
	_monorail()
	_skyline()
	_bounds()
	update_time(Game.time_of_day, true)


func district(i: int, j: int) -> String:
	if j == -GRID:
		return "eski"
	if j == GRID - 1:
		return "sahil"
	if i >= -1 and i <= 0 and j >= -1 and j <= 0:
		return "merkez"
	return "cadde"


func district_at(p: Vector3) -> String:
	var i := int(floor(p.x / CELL))
	var j := int(floor(p.z / CELL))
	if p.z > GRID * CELL:
		return "sahil"
	return district(clampi(i, -GRID, GRID - 1), clampi(j, -GRID, GRID - 1))


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
	env.ssao_enabled = true
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
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	apply_quality()
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
	Game.settings_changed.connect(apply_quality)


func apply_quality() -> void:
	if env == null:
		return
	var q: int = Game.settings.quality
	env.sdfgi_enabled = Game.settings.sdfgi and q >= 1
	env.sdfgi_cascades = 4 if q >= 2 else 3
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.9
	env.sdfgi_read_sky_light = true
	env.ssr_enabled = Game.settings.ssr and q >= 1
	env.ssr_max_steps = 96 if q >= 2 else 48
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.5
	env.ssr_depth_tolerance = 0.4
	env.ssil_enabled = q >= 2
	env.ssao_enabled = q >= 1
	env.volumetric_fog_enabled = q >= 2
	env.volumetric_fog_density = 0.005
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_gi_inject = 0.6
	if sun:
		sun.directional_shadow_max_distance = [100.0, 180.0, 260.0][q]
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])


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
	sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.5, 0.3), golden)
	sun.light_energy = lerp(0.0, 1.7, day)
	sun.visible = elev > -0.08
	var moon_ang := ang + PI
	moon.look_at_from_position(Vector3(cos(moon_ang) * 0.6, max(sin(moon_ang), 0.25), -0.5).normalized() * 100.0, Vector3.ZERO, Vector3.UP)
	moon.visible = not sun.visible
	# gökyüzü: gündüz mavi, gün batımı pembe-turuncu, gece mor (Vice City havası)
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
	# neon yazılar: gündüz sönük
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
	# kameraya en yakın birkaç sokak lambası gölge düşürür (gece)
	_shadow_t -= delta
	if _shadow_t <= 0.0 and night > 0.35:
		_shadow_t = 0.4
		var cam := get_viewport().get_camera_3d()
		if cam:
			var cp := cam.global_position
			var near := street_lights.duplicate()
			near.sort_custom(func(a, b): return a.global_position.distance_squared_to(cp) < b.global_position.distance_squared_to(cp))
			for i in near.size():
				(near[i] as OmniLight3D).shadow_enabled = i < 4


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


func _collider(pos: Vector3, size: Vector3, layer := 1) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)


func _cyl_collider(pos: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = pos + Vector3(0, h * 0.5, 0)
	props.add_child(cs)


func _neon(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, vis_end := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = neon_mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("neon_col", col)
	mi.set_instance_shader_parameter("phase", rng.randf())
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = 20.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)
	return mi


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
		lbl.visibility_range_end = 170.0
		lbl.visibility_range_end_margin = 20.0
		lbl.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(lbl)
	neon_labels.append(lbl)
	return lbl


# ---------------------------------------------------------------- zemin, deniz, sınırlar
func _ground() -> void:
	var x0 := -GRID * CELL - 70.0
	var x1 := GRID * CELL + 70.0
	var z0 := -GRID * CELL - 70.0
	var z1 := COAST
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z1 - z0)
	pm.subdivide_width = 12
	pm.subdivide_depth = 12
	road.mesh = pm
	road.position = Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
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
	_collider(Vector3((x0 + x1) * 0.5, -0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, 1.0, z1 - z0))


func _sea() -> void:
	# sahil yürüyüş yolu, kum, deniz
	var x0 := -GRID * CELL - 70.0
	var x1 := GRID * CELL + 70.0
	var w := x1 - x0
	_box(Vector3(0, 0.09, COAST + 4.0), Vector3(w, 0.18, 8.0), Game.pbr("sidewalk", Color(0.95, 0.88, 0.8), 0.35, 0.8), false)
	_collider(Vector3(0, 0.04, COAST + 4.0), Vector3(w, 0.08, 8.0), 1)
	_collider(Vector3(0, 0.12, COAST + 4.1), Vector3(w, 0.24, 7.8), 2)
	var sand := MeshInstance3D.new()
	var sm := PlaneMesh.new()
	sm.size = Vector2(w, 34.0)
	sand.mesh = sm
	sand.position = Vector3(0, -0.45, COAST + 25.0)
	sand.rotation.x = deg_to_rad(1.9)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.93, 0.83, 0.62)
	smat.roughness = 0.95
	sand.material_override = smat
	add_child(sand)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 1.0, 34.0)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(0, -0.95, COAST + 25.0)
	sb.rotation.x = deg_to_rad(1.9)
	add_child(sb)
	# korkuluk (yürüyüş yolunun deniz tarafı), arada merdiven boşlukları
	var rail := Game.paint(Color(0.92, 0.92, 0.94), 0.8, 0.25)
	var x := x0 + 4.0
	while x < x1 - 4.0:
		if int((x - x0) / 40.0) % 3 != 1:
			_box(Vector3(x + 5.0, 1.0, COAST + 7.8), Vector3(10.0, 0.08, 0.08), rail, false)
			_box(Vector3(x, 0.55, COAST + 7.8), Vector3(0.1, 0.9, 0.1), rail, false)
		x += 10.0
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(3000, 1500)
	wm.subdivide_width = 120
	wm.subdivide_depth = 60
	water.mesh = wm
	water.position = Vector3(0, -0.7, COAST + 24.0 + 750.0)
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	water.material_override = wmat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# şehir dışı zemin (kenarlar)
	var outer := MeshInstance3D.new()
	var om := PlaneMesh.new()
	om.size = Vector2(3000, 3000)
	outer.mesh = om
	outer.position = Vector3(0, -0.06, -1500.0 + COAST)
	outer.material_override = Game.paint(Color(0.12, 0.12, 0.13), 0.0, 0.9)
	add_child(outer)


func _bounds() -> void:
	var e := GRID * CELL + 30.0
	var inv := 1
	_collider(Vector3(0, 10, -e), Vector3(e * 2.0 + 60, 40, 2), inv)
	_collider(Vector3(-e, 10, 0), Vector3(2, 40, e * 2.0 + 60), inv)
	_collider(Vector3(e, 10, 0), Vector3(2, 40, e * 2.0 + 60), inv)
	_collider(Vector3(0, 10, COAST + 40.0), Vector3(e * 2.0 + 60, 40, 2), inv)


# ---------------------------------------------------------------- bloklar & binalar
const FACADES := {
	"cadde": [["plaster", Color(0.98, 0.93, 0.86)], ["brick", Color(1.0, 0.95, 0.92)], ["concrete", Color(0.86, 0.87, 0.9)], ["plaster", Color(0.85, 0.9, 0.95)], ["concrete", Color(0.75, 0.77, 0.82)]],
	"merkez": [["concrete", Color(0.75, 0.78, 0.84)], ["concrete", Color(0.55, 0.6, 0.7)], ["plaster", Color(0.9, 0.92, 0.95)]],
	"eski": [["plaster", Color(0.95, 0.88, 0.75)], ["brick", Color(0.85, 0.6, 0.5)], ["plaster", Color(0.75, 0.3, 0.25)], ["plaster", Color(0.9, 0.82, 0.68)]],
	"sahil": [["plaster", Color(1.0, 0.78, 0.82)], ["plaster", Color(0.7, 0.95, 0.92)], ["plaster", Color(1.0, 0.95, 0.75)], ["plaster", Color(0.85, 0.85, 1.0)], ["plaster", Color(1.0, 1.0, 0.98)]],
}


func _block(i: int, j: int) -> void:
	var c := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)
	var d := district(i, j)
	districts[Vector2i(i, j)] = d
	var outer := BLOCK + WALK * 2.0
	blocks.append(Rect2(c - Vector2(outer, outer) * 0.5, Vector2(outer, outer)))
	# kaldırım: görsel 0,18 m; oyuncu için 0,08 m (rahat çıkar), araçlar için 0,24 m kenar
	var walk_mat := Game.pbr("sidewalk", Color(0.9, 0.88, 0.85) if d != "eski" else Color(0.85, 0.78, 0.7), 0.35, 0.85)
	_box(Vector3(c.x, 0.09, c.y), Vector3(outer, 0.18, outer), walk_mat, false)
	_collider(Vector3(c.x, 0.04, c.y), Vector3(outer, 0.08, outer), 1)
	_collider(Vector3(c.x, 0.12, c.y), Vector3(outer - 0.2, 0.24, outer - 0.2), 2)
	var curb := Game.pbr("concrete", Color(0.75, 0.75, 0.74), 0.5)
	for s in [-1, 1]:
		_box(Vector3(c.x, 0.1, c.y + s * (outer * 0.5 - 0.15)), Vector3(outer, 0.2, 0.3), curb, false)
		_box(Vector3(c.x + s * (outer * 0.5 - 0.15), 0.1, c.y), Vector3(0.3, 0.2, outer), curb, false)
	var lots := []
	var h := BLOCK * 0.5
	var layout := rng.randi_range(0, 2)
	if d == "merkez":
		layout = rng.randi_range(0, 1) * 3   # 0: dört kule · 3: tek büyük kule + plaza
	if layout == 0:
		lots = [Rect2(-h, -h, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(2, -h, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(-h, 2, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2), Rect2(2, 2, BLOCK * 0.5 - 2, BLOCK * 0.5 - 2)]
	elif layout == 1:
		lots = [Rect2(-h, -h, BLOCK, BLOCK * 0.42), Rect2(-h, BLOCK * 0.42 - h + 3, BLOCK * 0.45, BLOCK * 0.58 - 3), Rect2(BLOCK * 0.45 - h + 3, BLOCK * 0.42 - h + 3, BLOCK * 0.55 - 3, BLOCK * 0.58 - 3)]
	elif layout == 2:
		lots = [Rect2(-h, -h, BLOCK * 0.62, BLOCK), Rect2(BLOCK * 0.62 - h + 3, -h, BLOCK * 0.38 - 3, BLOCK * 0.5 - 1.5), Rect2(BLOCK * 0.62 - h + 3, 1.5, BLOCK * 0.38 - 3, BLOCK * 0.5 - 1.5)]
	else:
		lots = [Rect2(-h + 6, -h + 6, BLOCK * 0.55, BLOCK * 0.55)]
		_plaza(c, d)
	for r in lots:
		var center: Vector2 = c + r.position + r.size * 0.5
		_building(Vector3(center.x, 0.18, center.y), Vector3(r.size.x, 0, r.size.y), d)


func _plaza(c: Vector2, d: String) -> void:
	# kule önü meydan: yükseltilmiş platform, ortada neon heykel halkası
	var p := Vector3(c.x + BLOCK * 0.28, 0.18, c.y + BLOCK * 0.28)
	_box(p + Vector3(0, 0.25, 0), Vector3(16, 0.5, 16), Game.pbr("concrete", Color(0.7, 0.7, 0.75), 0.4))
	var col: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
	for k in range(16):
		var a := k * TAU / 16.0
		_neon(p + Vector3(cos(a) * 3.0, 4.5 + sin(a) * 3.0, 0), Vector3(1.3, 0.22, 0.22), col, Vector3(0, 0, a + PI * 0.5))
	_box(p + Vector3(0, 0.9, 0), Vector3(1.2, 0.8, 1.2), Game.paint(Color(0.15, 0.15, 0.17), 0.8, 0.3))


func _facade_mat(d: String, glass: bool) -> ShaderMaterial:
	var list: Array = FACADES[d]
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
	var tall_p: float = {"merkez": 0.9, "cadde": 0.3, "eski": 0.0, "sahil": 0.12}[d]
	var tall := rng.randf() < tall_p
	var floors: int
	if d == "merkez" and tall:
		floors = rng.randi_range(16, 36)
	elif tall:
		floors = rng.randi_range(8, 16)
	elif d == "eski":
		floors = rng.randi_range(1, 3)
	else:
		floors = rng.randi_range(1, 5)
	var height := 4.6 + floors * 3.4
	var glass := tall and rng.randf() < (0.7 if d == "merkez" else 0.4)
	var m := _facade_mat(d, glass)
	# merkez kuleleri: üstte daralan kademeler
	var setback := tall and d == "merkez" and rng.randf() < 0.6
	var main_h := height * (0.65 if setback else 1.0)
	var mi := _box(base + Vector3(0, main_h * 0.5, 0), Vector3(fp.x, main_h, fp.z), m)
	mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
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
		if rng.randf() < (0.75 if d == "merkez" else 0.35):
			_hologram(base, fp, main_h)
		# çatıda anten / ikaz ışığı
		_box(base + Vector3(0, top_y + 4.0, 0), Vector3(0.3, 7.0, 0.3), Game.paint(Color(0.3, 0.3, 0.32), 0.8, 0.4), false)
		_neon(base + Vector3(0, top_y + 7.6, 0), Vector3(0.5, 0.5, 0.5), Color(1, 0.1, 0.1))
	elif d == "eski":
		_pagoda_roof(base, fp, height)
	elif d == "sahil":
		# art deco: çatı hizasında yatay neon bantlar
		for k in range(2):
			var y := height - 0.4 - k * 0.6
			for s in [-1, 1]:
				_neon(base + Vector3(0, y, s * (fp.z * 0.5 + 0.06)), Vector3(fp.x * 0.98, 0.12, 0.08), ncol)
				_neon(base + Vector3(s * (fp.x * 0.5 + 0.06), y, 0), Vector3(0.08, 0.12, fp.z * 0.98), ncol)
	elif rng.randf() < 0.7:
		_box(base + Vector3(rng.randf_range(-fp.x, fp.x) * 0.25, height + 1.2, rng.randf_range(-fp.z, fp.z) * 0.25), Vector3(3, 1.6, 2.4), Game.paint(Color(0.7, 0.72, 0.74), 0.6, 0.4), false)
	# zemin kat: tente + tabela (sokağa bakan cephe)
	_shopfront(base, fp, d, floors)


func _tower_neon(base: Vector3, fp: Vector3, top_y: float, col: Color, setback: bool, fp0: Vector3, main_h: float) -> void:
	# köşelerde dikey neon şeritler + taç halkası
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
	var y := clampf(h * 0.55, 14.0, h - hh * 0.5 - 2.0)
	if y - hh * 0.5 < 8.0:
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
	var ads: Array[String] = ["NEON GÖLGELER", "ANANAS SMOOTHIE", "TEKNO 3000", "GECE PAZARI", "HIZ KULÜBÜ"]
	var txt: String = ads[rng.randi_range(0, 4)]
	_label(txt, q.position + Vector3(0, -hh * 0.5 - 1.2, 0) + off.normalized() * 0.1, q.rotation.y, a, 96, 0.03)


func _pagoda_roof(base: Vector3, fp: Vector3, h: float) -> void:
	var tile := Game.paint([Color(0.55, 0.1, 0.08), Color(0.1, 0.35, 0.32), Color(0.2, 0.2, 0.25)][rng.randi_range(0, 2)], 0.1, 0.5)
	var gold := Game.paint(Color(0.95, 0.72, 0.25), 0.9, 0.3)
	var w := maxf(fp.x, fp.z)
	var y := h
	for tier in range(2):
		var r := (w * 0.5 + 1.6) * (1.0 - tier * 0.38) * 1.414
		var roof := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.bottom_radius = r
		cm.top_radius = r * 0.35
		cm.height = 2.4 - tier * 0.4
		cm.radial_segments = 4
		roof.mesh = cm
		roof.material_override = tile
		roof.position = base + Vector3(0, y + cm.height * 0.5, 0)
		roof.rotation.y = PI * 0.25
		roof.scale = Vector3(fp.x / w, 1, fp.z / w)
		add_child(roof)
		# kalkık saçak uçları
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var tip := _box(base + Vector3(sx * (fp.x * 0.5 + 1.4) * (1.0 - tier * 0.38), y + 0.35, sz * (fp.z * 0.5 + 1.4) * (1.0 - tier * 0.38)), Vector3(0.35, 0.18, 0.9), gold, false)
				tip.rotation = Vector3(0.5 * sz, PI * 0.25 * sx * sz, 0)
		if tier == 0:
			_box(base + Vector3(0, y + cm.height + 0.5, 0), Vector3(fp.x * 0.45, 1.0, fp.z * 0.45), Game.paint(Color(0.35, 0.1, 0.08), 0.0, 0.7), false)
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
	if rng.randf() < 0.5:
		# yatay tabela + neon çerçeve
		var p := base + off * 0.95 + Vector3(0, 4.35, 0)
		_label(txt, p, yaw, col)
		var tw := txt.length() * 0.75 + 1.0
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		_neon(p + Vector3(0, 0.75, 0), Vector3(tw if along_x else 0.06, 0.06, 0.06 if along_x else tw), col, Vector3.ZERO, 170.0)
		_neon(p - Vector3(0, 0.75, 0), Vector3(tw if along_x else 0.06, 0.06, 0.06 if along_x else tw), col, Vector3.ZERO, 170.0)
		_neon(p + right * tw * 0.5, Vector3(0.06, 1.56, 0.06), col, Vector3.ZERO, 170.0)
		_neon(p - right * tw * 0.5, Vector3(0.06, 1.56, 0.06), col, Vector3.ZERO, 170.0)
	else:
		# dikey tabela (köşeden dışarı taşan pano, harfler üst üste)
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var normal := off.normalized()
		var p := base + off.normalized() * (((fp.z if along_x else fp.x) * 0.5) + 1.0) + right * (w * 0.5) + Vector3(0, 6.5, 0)
		var n := mini(txt.length(), 6)
		var hh := n * 1.05 + 0.6
		var panel := _box(p + Vector3(0, -hh * 0.5 + 1.0, 0), Vector3(0.25, hh, 1.3) if along_x else Vector3(1.3, hh, 0.25), Game.paint(Color(0.06, 0.06, 0.08), 0.3, 0.4), false)
		panel.rotation.y = 0.0
		for k in range(n):
			for s2: int in [-1, 1]:
				var lp: Vector3 = p + Vector3(0, -k * 1.05 + 0.6, 0) + right * (0.15 * s2)
				_label(txt[k], lp, yaw + PI * 0.5 * s2, col, 110, 0.009)
		_neon(p + Vector3(0, 1.32, 0), Vector3(0.3, 0.08, 1.4) if along_x else Vector3(1.4, 0.08, 0.3), col, Vector3.ZERO, 170.0)
		_neon(p + Vector3(0, -hh + 0.68, 0), Vector3(0.3, 0.08, 1.4) if along_x else Vector3(1.4, 0.08, 0.3), col, Vector3.ZERO, 170.0)
		var _unused := normal
	# eski çarşı: kapıda kırmızı fener
	if d == "eski":
		var lan := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.35
		sp.height = 0.8
		lan.mesh = sp
		lan.material_override = neon_mat
		lan.set_instance_shader_parameter("neon_col", Color(1.0, 0.18, 0.08))
		lan.position = base + off * 1.05 + Vector3(0, 3.0, 0)
		add_child(lan)


func _outer_ring() -> void:
	# haritanın kuzey / doğu / batı kenarında dolgu binalar (dışarısı boş görünmesin)
	var e := GRID * CELL
	var step := 26.0
	var t := -e - 40.0
	while t < e + 40.0:
		for side in range(3):
			var pos: Vector3
			var fp := Vector3(step - 3.0, 0, rng.randf_range(16, 30))
			if side == 0:
				pos = Vector3(t, 0, -e - 8.0 - fp.z * 0.5)
			elif side == 1:
				pos = Vector3(-e - 8.0 - fp.z * 0.5, 0, t)
				fp = Vector3(fp.z, 0, fp.x)
			else:
				pos = Vector3(e + 8.0 + fp.z * 0.5, 0, t)
				fp = Vector3(fp.z, 0, fp.x)
			if side > 0 and t > e - 4.0:
				continue
			var d := "eski" if side == 0 else ("merkez" if rng.randf() < 0.3 else "cadde")
			if side == 0:
				_building(pos, fp, "cadde" if rng.randf() < 0.5 else "eski")
			else:
				_building(pos, fp, d)
		t += step
	# kenar kaldırımları
	var walk_mat := Game.pbr("sidewalk", Color(0.9, 0.88, 0.85), 0.35, 0.85)
	_box(Vector3(0, 0.09, -e - 8.0), Vector3(e * 2.0 + 80, 0.18, 4.0), walk_mat, false)
	_box(Vector3(-e - 8.0, 0.09, 0), Vector3(4.0, 0.18, e * 2.0 + 80), walk_mat, false)
	_box(Vector3(e + 8.0, 0.09, 0), Vector3(4.0, 0.18, e * 2.0 + 80), walk_mat, false)


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


func _multi(mesh: Mesh, xforms: Array, mat: Material = null) -> MultiMeshInstance3D:
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
	add_child(mmi)
	return mmi


func _street_furniture() -> void:
	var palms := []
	var lamps := []
	var outer := BLOCK + WALK * 2.0
	for bi in blocks.size():
		var r := blocks[bi]
		var c := r.get_center()
		var d := district_at(Vector3(c.x, 0, c.y))
		var hw := outer * 0.5 - 1.2
		for s in [-1, 1]:
			var t := -hw + 6.0
			while t < hw - 4.0:
				var slot := int((t + hw) / 12.0)
				var odd := slot % 2 == 0
				var p1 := Vector3(c.x + t, 0.18, c.y + s * hw)
				var p2 := Vector3(c.x + s * hw, 0.18, c.y + t)
				var palm_ok := d == "sahil" or d == "cadde" or (d == "merkez" and slot % 4 == 0)
				if odd and palm_ok:
					for p in [p1, p2]:
						palms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), p))
						_cyl_collider(p, 0.3, 4.0)
				elif not odd:
					lamps.append(Transform3D(Basis(Vector3.UP, -PI * 0.5 * s), p1))
					lamps.append(Transform3D(Basis(Vector3.UP, PI if s > 0 else 0.0), p2))
					for p in [p1, p2]:
						_cyl_collider(p, 0.18, 4.0)
						var l := OmniLight3D.new()
						l.light_color = Color(1.0, 0.82, 0.58) if d != "eski" else Color(1.0, 0.55, 0.3)
						l.light_energy = 2.4
						l.omni_range = 15.0
						l.omni_attenuation = 1.3
						l.shadow_enabled = false
						l.distance_fade_enabled = true
						l.distance_fade_begin = 70.0
						l.distance_fade_length = 25.0
						l.position = p + Vector3(0, 6.6, 0) + (Vector3(0, 0, -s * 1.6) if p == p1 else Vector3(-s * 1.6, 0, 0))
						l.visible = false
						add_child(l)
						street_lights.append(l)
				t += 12.0
	# sahil yürüyüş yolu palmiyeleri
	var x := -GRID * CELL - 40.0
	while x < GRID * CELL + 40.0:
		var p := Vector3(x, 0.18, COAST + 5.5)
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
	# banklar, çöp kutuları, yangın muslukları, saksılar (model varsa)
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
	# trafik ışıkları (her iç kavşak)
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
	# Eski Çarşı: sokakların üstünde fener dizileri
	var red := []
	var orange := []
	var wires := []
	var z0 := -GRID * CELL
	var z1 := -GRID * CELL + CELL
	# doğu-batı yönündeki yollar (z sabit) boyunca, yolu enlemesine geçen diziler
	for zc in [z0, z1]:
		var x := -GRID * CELL + 14.0
		while x < GRID * CELL - 10.0:
			if abs(fmod(abs(x), CELL)) > 10.0 and abs(fmod(abs(x), CELL)) < CELL - 10.0:
				for k in range(7):
					var t := (k - 3) / 3.0
					var p := Vector3(x, 7.2 - (1.0 - t * t) * 1.0, zc + t * (ROAD_W * 0.5 + 2.0))
					var tr := Transform3D(Basis(), p)
					if k % 2 == 0:
						red.append(tr)
					else:
						orange.append(tr)
				wires.append(Transform3D(Basis(), Vector3(x, 7.0, zc)))
			x += 9.0
	# kuzey-güney yollar (x sabit), eski çarşı bölgesinde
	for i in range(-GRID, GRID + 1):
		var xc := i * CELL
		var z := z0 + 12.0
		while z < z1 - 10.0:
			for k in range(7):
				var t := (k - 3) / 3.0
				var p := Vector3(xc + t * (ROAD_W * 0.5 + 2.0), 7.2 - (1.0 - t * t) * 1.0, z)
				if k % 2 == 0:
					red.append(Transform3D(Basis(), p))
				else:
					orange.append(Transform3D(Basis(), p))
			wires.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xc, 7.0, z)))
			z += 9.0
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.75
	sm.radial_segments = 10
	sm.rings = 6
	var mr := _multi(sm, red, neon_mat)
	mr.set_instance_shader_parameter("neon_col", Color(1.0, 0.15, 0.08))
	mr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mo := _multi(sm, orange, neon_mat)
	mo.set_instance_shader_parameter("neon_col", Color(1.0, 0.55, 0.12))
	mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wm := BoxMesh.new()
	wm.size = Vector3(0.03, 0.03, ROAD_W + 4.0)
	_multi(wm, wires, Game.paint(Color(0.05, 0.05, 0.05), 0.0, 0.8))


# ---------------------------------------------------------------- monoray
func rail_point(s: float) -> Array:
	## merkezi çevreleyen yuvarlatılmış kare halka: [konum, yön]
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
		# altında neon şerit
		var ns := _neon(mid + Vector3(0, -0.6, 0), Vector3(0.12, 0.06, bm.size.z), Color(0.1, 0.9, 1.0))
		ns.look_at_from_position(mid + Vector3(0, -0.6, 0), mid + Vector3(0, -0.6, 0) + (b[0] - a[0]), Vector3.UP)
		s += step
	# sütunlar (kavşaklardan uzak)
	s = 10.0
	while s < per:
		var p: Vector3 = rail_point(s)[0]
		var near_x: float = abs(fmod(abs(p.x) + CELL * 0.5, CELL) - CELL * 0.5)
		var near_z: float = abs(fmod(abs(p.z) + CELL * 0.5, CELL) - CELL * 0.5)
		if near_x > 14.0 or near_z > 14.0:
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
	# tren: 3 vagon
	var body := Game.paint(Color(0.95, 0.95, 0.97), 0.4, 0.25, 0.8)
	var stripe := Color(1.0, 0.15, 0.75)
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
			st.set_instance_shader_parameter("neon_col", stripe)
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


func _skyline() -> void:
	# uzak siluet (kuzey, doğu, batı): ışıklı kuleler
	var far := GRID * CELL + 120.0
	for i in range(80):
		var a := PI + i * PI / 80.0 + rng.randf() * 0.02
		var d := far + rng.randf_range(0, 260)
		var h := rng.randf_range(30, 170)
		var m := ShaderMaterial.new()
		m.shader = b_shader
		m.set_shader_parameter("tint", Color(0.6, 0.65, 0.75).lerp(Color(0.85, 0.8, 0.9), rng.randf()))
		m.set_shader_parameter("glass_amt", 1.0 if rng.randf() < 0.6 else 0.0)
		var pos := Vector3(cos(a) * d, h * 0.5, sin(a) * d * 1.1)
		var mi := _box(pos, Vector3(rng.randf_range(18, 40), h, rng.randf_range(18, 40)), m, false)
		mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if rng.randf() < 0.4:
			var c: Color = NEON[rng.randi_range(0, NEON.size() - 1)]
			_neon(pos + Vector3(0, h * 0.5 + 0.3, 0), Vector3(20, 0.5, 0.5), c)
	# denizde uzak ada siluetleri
	for k in range(5):
		var p := Vector3(rng.randf_range(-700, 700), -2, rng.randf_range(900, 1300))
		var isl := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = rng.randf_range(60, 140)
		sp.height = sp.radius * 0.6
		isl.mesh = sp
		isl.position = p
		isl.material_override = Game.paint(Color(0.12, 0.18, 0.16), 0.0, 1.0)
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
