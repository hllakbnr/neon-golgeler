extends RefCounted
class_name CityBuilder
## Neon Şehir: ızgara bloklar, binalar (world.json'dan), vitrinler ve tabelalar, sokak eşyaları,
## Eski Çarşı fenerleri, monoray, liman, sahil ve lunapark.

var w: World
var rng := RandomNumberGenerator.new()
var _wheel: Node3D
var _carousel: Node3D
var _coaster_car: Node3D
var _coaster_pts: Array = []
var _coaster_s := 0.0

const FACADES := {
	"cadde": [["plaster", Color(0.98, 0.93, 0.86)], ["brick", Color(1.0, 0.95, 0.92)], ["concrete", Color(0.86, 0.87, 0.9)], ["plaster", Color(0.85, 0.9, 0.95)], ["concrete", Color(0.75, 0.77, 0.82)]],
	"merkez": [["concrete", Color(0.75, 0.78, 0.84)], ["concrete", Color(0.55, 0.6, 0.7)], ["plaster", Color(0.9, 0.92, 0.95)]],
	"eski": [["plaster", Color(0.95, 0.88, 0.75)], ["brick", Color(0.85, 0.6, 0.5)], ["plaster", Color(0.75, 0.3, 0.25)], ["plaster", Color(0.9, 0.82, 0.68)]],
	"sahil": [["plaster", Color(1.0, 0.78, 0.82)], ["plaster", Color(0.7, 0.95, 0.92)], ["plaster", Color(1.0, 0.95, 0.75)], ["plaster", Color(0.85, 0.85, 1.0)], ["plaster", Color(1.0, 1.0, 0.98)]],
	"liman": [["concrete", Color(0.6, 0.62, 0.6)], ["brick", Color(0.8, 0.55, 0.45)], ["concrete", Color(0.7, 0.65, 0.55)]],
	"tekno": [["concrete", Color(0.7, 0.75, 0.82)], ["concrete", Color(0.5, 0.55, 0.65)]],
	"konut": [["plaster", Color(0.98, 0.95, 0.9)], ["plaster", Color(0.9, 0.85, 0.78)], ["brick", Color(0.95, 0.8, 0.75)], ["plaster", Color(0.82, 0.9, 0.85)]],
}
const LM_COL := {"noodle": Color(1.0, 0.35, 0.2), "weapons": Color(0.4, 0.9, 1.0), "boutique": Color(0.7, 0.4, 1.0), "club": Color(0.2, 1.0, 1.0),
	"police": Color(0.35, 0.55, 1.0), "hospital": Color(1.0, 0.25, 0.25), "spray": Color(0.3, 1.0, 0.5), "dojo": Color(1.0, 0.2, 0.85),
	"tower": Color(1.0, 0.15, 0.75), "market": Color(1.0, 0.25, 0.15), "bank": Color(1.0, 0.85, 0.3), "arcade": Color(0.4, 1.0, 0.3)}


func _init(world: World) -> void:
	w = world
	rng.seed = 4242


func build(progress: Callable) -> void:
	var cd: Dictionary = w.data.city
	_ground()
	for b in cd.blocks:
		var i := int(b.i)
		var j := int(b.j)
		w.districts[Vector2i(i, j)] = String(b.d)
	var k := 0
	for b in cd.blocks:
		_block(b)
		k += 1
		if k % 16 == 0:
			await w._step(progress, 0.25 + 0.1 * k / cd.blocks.size(), "Neon Şehir kuruluyor")
	k = 0
	for b in cd.buildings:
		_building(b)
		k += 1
		if k % 40 == 0:
			await w._step(progress, 0.35 + 0.12 * k / cd.buildings.size(), "Binalar")
	await w._step(progress, 0.48, "Sokaklar")
	_street_furniture()
	_lanterns()
	_monorail()
	await w._step(progress, 0.52, "Liman ve sahil")
	_harbor()
	_beach()
	_lunapark()


func tick(delta: float) -> void:
	if _wheel:
		_wheel.rotate_object_local(Vector3.FORWARD, delta * 0.08)
		for c in _wheel.get_children():
			if c.has_meta("cab"):
				c.global_rotation = Vector3(0, c.global_rotation.y, 0)
	if _carousel:
		_carousel.rotate_y(delta * 0.6)
	if _coaster_car and _coaster_pts.size() > 2:
		_coaster_s += delta * 14.0
		var n := _coaster_pts.size()
		var f := fposmod(_coaster_s / 4.0, n)
		var a: Vector3 = _coaster_pts[int(f) % n]
		var b: Vector3 = _coaster_pts[(int(f) + 1) % n]
		var p := a.lerp(b, f - floor(f))
		_coaster_car.global_position = p + Vector3(0, 0.6, 0)
		var dv := b - p
		if dv.length() > 0.05 and absf(dv.normalized().y) < 0.98:
			_coaster_car.look_at(b + Vector3(0, 0.6, 0), Vector3.UP)


# ---------------------------------------------------------------- zemin
func _ground() -> void:
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w.EDGE_X * 2.0, w.EDGE_Z * 2.0)
	pm.subdivide_width = 20
	pm.subdivide_depth = 16
	road.mesh = pm
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/road.gdshader")
	for slot in [["asph", "diff", "has_tex"], ["asph_n", "nor", "has_nor"], ["asph_r", "rough", "has_rough"]]:
		var t := Game.tex("asphalt", slot[1])
		if t:
			rm.set_shader_parameter(slot[0], t)
			rm.set_shader_parameter(slot[2], true)
	rm.set_shader_parameter("cell", w.CELL)
	rm.set_shader_parameter("road_w", w.ROAD_W)
	road.material_override = rm
	w.add_child(road)
	w._collider(Vector3(0, -0.5, 0), Vector3(w.EDGE_X * 2.0, 1.0, w.EDGE_Z * 2.0))
	var walk_mat := Game.pbr("sidewalk", Color(0.9, 0.88, 0.85), 0.35, 0.85)
	for s in [-1.0, 1.0]:
		w._box(Vector3(0, 0.09, s * (w.EDGE_Z + 3.0)), Vector3(w.EDGE_X * 2.0 + 12.0, 0.18, 6.0), walk_mat, false)
		w._box(Vector3(s * (w.EDGE_X + 3.0), 0.09, 0), Vector3(6.0, 0.18, w.EDGE_Z * 2.0), walk_mat, false)
		w._collider(Vector3(0, 0.04, s * (w.EDGE_Z + 3.0)), Vector3(w.EDGE_X * 2.0 + 12.0, 0.08, 6.0))
		w._collider(Vector3(s * (w.EDGE_X + 3.0), 0.04, 0), Vector3(6.0, 0.08, w.EDGE_Z * 2.0))


func _block(b: Dictionary) -> void:
	var c := Vector2(b.c[0], b.c[1])
	var d: String = b.d
	var outer := w.BLOCK + w.WALK * 2.0
	w.blocks.append(Rect2(c - Vector2(outer, outer) * 0.5, Vector2(outer, outer)))
	w.block_district.append(d)
	var walk_mat := Game.pbr("sidewalk", Color(0.9, 0.88, 0.85) if d != "eski" else Color(0.85, 0.78, 0.7), 0.35, 0.85)
	w._box(Vector3(c.x, 0.09, c.y), Vector3(outer, 0.18, outer), walk_mat, false)
	w._collider(Vector3(c.x, 0.04, c.y), Vector3(outer, 0.08, outer), 1)
	w._collider(Vector3(c.x, 0.12, c.y), Vector3(outer - 0.2, 0.24, outer - 0.2), 2)
	var curb := Game.pbr("concrete", Color(0.75, 0.75, 0.74), 0.5)
	for s in [-1.0, 1.0]:
		w._box(Vector3(c.x, 0.1, c.y + s * (outer * 0.5 - 0.15)), Vector3(outer, 0.2, 0.3), curb, false)
		w._box(Vector3(c.x + s * (outer * 0.5 - 0.15), 0.1, c.y), Vector3(0.3, 0.2, outer), curb, false)
	if d == "konut" or d == "lunapark":
		w._box(Vector3(c.x, 0.2, c.y), Vector3(w.BLOCK - 2, 0.06, w.BLOCK - 2), Game.pbr("grass", Color(0.6, 0.75, 0.5), 0.2), false)
	if b.get("plaza", false):
		_plaza(c)


func _plaza(c: Vector2) -> void:
	var p := Vector3(c.x + w.BLOCK * 0.28, 0.18, c.y + w.BLOCK * 0.28)
	w._box(p + Vector3(0, 0.25, 0), Vector3(16, 0.5, 16), Game.pbr("concrete", Color(0.7, 0.7, 0.75), 0.4))
	var col: Color = w.NEON[rng.randi_range(0, w.NEON.size() - 1)]
	# heykel halkası kaidesine oturur (havada değil)
	w._box(p + Vector3(0, 1.0, 0), Vector3(1.4, 1.0, 1.4), Game.paint(Color(0.15, 0.15, 0.17), 0.8, 0.3))
	for k in range(16):
		var a := k * TAU / 16.0
		w._neon(p + Vector3(cos(a) * 3.0, 4.5 + sin(a) * 3.0, 0), Vector3(1.3, 0.22, 0.22), col, Vector3(0, 0, a + PI * 0.5))
	w._box(p + Vector3(0, 1.6, 0), Vector3(0.3, 0.6, 0.3), Game.paint(Color(0.15, 0.15, 0.17), 0.8, 0.3), false)


# ---------------------------------------------------------------- binalar
func _facade_mat(d: String, glass: bool) -> ShaderMaterial:
	var list: Array = FACADES.get(d, FACADES.cadde)
	var f = list[rng.randi_range(0, list.size() - 1)]
	var m := ShaderMaterial.new()
	m.shader = w.b_shader
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


func _building(b: Dictionary) -> void:
	rng.seed = int(b.get("seed", 1)) + 7
	var base := Vector3(b.c[0], 0.18, b.c[1])
	var fp := Vector3(b.s[0], 0, b.s[1])
	var d: String = b.d
	var k: String = b.k
	var hgt: float = b.h
	match k:
		"ev":
			_house(base, fp, b)
			return
		"depo":
			_warehouse(base, fp, hgt)
		"pagoda":
			_pagoda_building(base, fp, hgt, int(b.get("f", 1)))
		"kule":
			_tower(base, fp, hgt, d, bool(b.get("glass", false)), b)
		_:
			_mid(base, fp, hgt, d)
	if b.has("side"):
		_shopfront(base, fp, b)
	if b.has("lm"):
		_landmark(base, fp, hgt, b)


func _mid(base: Vector3, fp: Vector3, hgt: float, d: String) -> void:
	var m := _facade_mat(d, false)
	var mi := w._box(base + Vector3(0, hgt * 0.5, 0), Vector3(fp.x, hgt, fp.z), m)
	mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
	w._occluder(base + Vector3(0, hgt * 0.5, 0), Vector3(fp.x, hgt, fp.z))
	var top := base.y + hgt
	var trim := Game.paint(Color(0.92, 0.9, 0.86), 0.0, 0.6)
	_parapet(Vector3(base.x, top, base.z), fp, trim)
	# çatı üstü cihazları çatıya oturur
	for q in range(rng.randi_range(0, 2)):
		var p := Vector3(base.x + rng.randf_range(-fp.x, fp.x) * 0.25, top + 0.8, base.z + rng.randf_range(-fp.z, fp.z) * 0.25)
		w._box(p, Vector3(2.6, 1.6, 2.0), Game.paint(Color(0.7, 0.72, 0.74), 0.6, 0.4), false)
	if hgt > 14.0 and rng.randf() < 0.4:
		_water_tank(Vector3(base.x - fp.x * 0.2, top, base.z + fp.z * 0.2))
	if d == "sahil":
		var ncol: Color = w.NEON[rng.randi_range(0, w.NEON.size() - 1)]
		for s in [-1.0, 1.0]:
			w._neon(Vector3(base.x, top - 0.4, base.z + s * (fp.z * 0.5 + 0.06)), Vector3(fp.x * 0.98, 0.12, 0.08), ncol)
			w._neon(Vector3(base.x + s * (fp.x * 0.5 + 0.06), top - 0.4, base.z), Vector3(0.08, 0.12, fp.z * 0.98), ncol)


func _parapet(top: Vector3, fp: Vector3, mat: Material) -> void:
	for s in [-1.0, 1.0]:
		w._box(top + Vector3(0, 0.45, s * (fp.z * 0.5 - 0.15)), Vector3(fp.x, 0.9, 0.3), mat, false)
		w._box(top + Vector3(s * (fp.x * 0.5 - 0.15), 0.45, 0), Vector3(0.3, 0.9, fp.z - 0.6), mat, false)


func _water_tank(p: Vector3) -> void:
	var wood := Game.paint(Color(0.45, 0.32, 0.22), 0.0, 0.85)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			w._box(p + Vector3(sx * 1.1, 1.0, sz * 1.1), Vector3(0.2, 2.0, 0.2), wood, false)
	var t := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.6
	cm.bottom_radius = 1.6
	cm.height = 2.6
	cm.radial_segments = 14
	t.mesh = cm
	t.material_override = wood
	t.position = p + Vector3(0, 3.3, 0)
	w.add_child(t)
	var cap := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.05
	cc.bottom_radius = 1.75
	cc.height = 0.9
	cc.radial_segments = 14
	cap.mesh = cc
	cap.material_override = Game.paint(Color(0.3, 0.3, 0.32), 0.5, 0.5)
	cap.position = p + Vector3(0, 5.05, 0)
	w.add_child(cap)


func _tower(base: Vector3, fp: Vector3, hgt: float, d: String, glass: bool, b: Dictionary) -> void:
	var m := _facade_mat(d, glass)
	var setback := rng.randf() < 0.6 and not b.has("lm")
	var main_h := hgt * (0.65 if setback else 1.0)
	var mi := w._box(base + Vector3(0, main_h * 0.5, 0), Vector3(fp.x, main_h, fp.z), m)
	mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
	w._occluder(base + Vector3(0, main_h * 0.5, 0), Vector3(fp.x, main_h, fp.z))
	var top_y := main_h
	var top_fp := fp
	if setback:
		top_fp = fp * 0.68
		var h2 := hgt - main_h
		var m2 := w._box(base + Vector3(0, main_h + h2 * 0.5, 0), Vector3(top_fp.x, h2, top_fp.z), m)
		m2.set_instance_shader_parameter("seed", rng.randf() * 100.0)
		top_y = hgt
	_parapet(base + Vector3(0, top_y, 0), top_fp, Game.paint(Color(0.85, 0.86, 0.88), 0.2, 0.5))
	var col: Color = w.NEON[rng.randi_range(0, w.NEON.size() - 1)]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var y0 := main_h if setback else 5.0
			var hh := top_y - y0
			w._neon(base + Vector3(sx * (top_fp.x * 0.5 + 0.05), y0 + hh * 0.5, sz * (top_fp.z * 0.5 + 0.05)), Vector3(0.22, hh, 0.22), col)
	if setback:
		var c2: Color = w.NEON[rng.randi_range(0, w.NEON.size() - 1)]
		for s in [-1.0, 1.0]:
			w._neon(base + Vector3(0, main_h + 0.2, s * (fp.z * 0.5 + 0.1)), Vector3(fp.x, 0.2, 0.1), c2)
			w._neon(base + Vector3(s * (fp.x * 0.5 + 0.1), main_h + 0.2, 0), Vector3(0.1, 0.2, fp.z), c2)
	if rng.randf() < (0.75 if d == "merkez" else 0.4) and not b.has("lm"):
		_hologram(base, fp, main_h)
	# anten çatıya oturur, ucunda kırmızı uyarı ışığı
	var ant_h := 7.0
	w._box(base + Vector3(0, top_y + ant_h * 0.5, 0), Vector3(0.3, ant_h, 0.3), Game.paint(Color(0.3, 0.3, 0.32), 0.8, 0.4), false)
	w._neon(base + Vector3(0, top_y + ant_h + 0.2, 0), Vector3(0.5, 0.5, 0.5), Color(1, 0.1, 0.1))


func _hologram(base: Vector3, fp: Vector3, h: float) -> void:
	## cepheye yapışık reklam ekranı (çerçeveli; havada yazı yok)
	var side := rng.randi_range(0, 3)
	var wd := minf(14.0, (fp.x if side < 2 else fp.z) * 0.7)
	var hh := wd * 1.3
	var y := clampf(h * 0.55, 14.0, maxf(14.0, h - hh * 0.5 - 2.0))
	if y - hh * 0.5 < 8.0 or y + hh * 0.5 > h:
		return
	var n: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
	var half: float = fp.z * 0.5 if side < 2 else fp.x * 0.5
	var yaw: float = [0.0, PI, PI * 0.5, -PI * 0.5][side]
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(wd, hh)
	q.mesh = qm
	q.material_override = w.holo_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = base + n * (half + 0.18) + Vector3(0, y, 0)
	q.rotation.y = yaw
	q.set_instance_shader_parameter("col_a", w.NEON[rng.randi_range(0, w.NEON.size() - 1)])
	q.set_instance_shader_parameter("col_b", w.NEON[rng.randi_range(0, w.NEON.size() - 1)])
	q.set_instance_shader_parameter("kind", float(rng.randi_range(0, 2)))
	w.add_child(q)
	var frame := Game.paint(Color(0.1, 0.1, 0.12), 0.6, 0.4)
	var bas := Basis(Vector3.UP, yaw)
	var c := base + n * (half + 0.1) + Vector3(0, y, 0)
	for s in [-1.0, 1.0]:
		var t1 := w._box(c + bas * Vector3(0, s * (hh * 0.5 + 0.15), 0), Vector3(wd + 0.6, 0.3, 0.2), frame, false)
		t1.rotation.y = yaw
		var t2 := w._box(c + bas * Vector3(s * (wd * 0.5 + 0.15), 0, 0), Vector3(0.3, hh, 0.2), frame, false)
		t2.rotation.y = yaw


func _hip_roof(wd: float, dp: float, rh: float, over: float, lift: float) -> ArrayMesh:
	## kalkık saçaklı kırma çatı (pagoda): taban dikdörtgen, mahya uzun kenar boyunca
	var a := wd * 0.5 + over
	var b := dp * 0.5 + over
	var c0 := Vector3(-a, lift, -b)
	var c1 := Vector3(a, lift, -b)
	var c2 := Vector3(a, lift, b)
	var c3 := Vector3(-a, lift, b)
	var r0: Vector3
	var r1: Vector3
	if wd >= dp:
		r0 = Vector3(-(a - b), rh, 0)
		r1 = Vector3(a - b, rh, 0)
	else:
		r0 = Vector3(0, rh, -(b - a))
		r1 = Vector3(0, rh, b - a)
	# saçak ortaları biraz aşağıda: köşeler kalkık görünür
	var m01 := Vector3(0, 0, -b)
	var m12 := Vector3(a, 0, 0)
	var m23 := Vector3(0, 0, b)
	var m30 := Vector3(-a, 0, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := []
	if wd >= dp:
		tris = [[c0, m01, r0], [m01, r1, r0], [m01, c1, r1], [c1, m12, r1], [m12, c2, r1], [c2, m23, r1], [m23, r0, r1], [m23, c3, r0], [c3, m30, r0], [m30, c0, r0]]
	else:
		tris = [[c0, m01, r0], [m01, c1, r0], [c1, m12, r0], [m12, r1, r0], [m12, c2, r1], [c2, m23, r1], [m23, c3, r1], [c3, m30, r1], [m30, r0, r1], [m30, c0, r0]]
	for t in tris:
		st.add_vertex(t[0])
		st.add_vertex(t[2])
		st.add_vertex(t[1])
	st.generate_normals()
	return st.commit()


func _pagoda_building(base: Vector3, fp: Vector3, hgt: float, floors: int) -> void:
	var m := _facade_mat("eski", false)
	var mi := w._box(base + Vector3(0, hgt * 0.5, 0), Vector3(fp.x, hgt, fp.z), m)
	mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
	w._occluder(base + Vector3(0, hgt * 0.5, 0), Vector3(fp.x, hgt, fp.z))
	var tile_col: Color = [Color(0.55, 0.1, 0.08), Color(0.1, 0.35, 0.32), Color(0.2, 0.2, 0.25)][rng.randi_range(0, 2)]
	pagoda_roofs(base + Vector3(0, hgt, 0), fp, tile_col, 2 if floors >= 2 else 1)


func pagoda_roofs(top: Vector3, fp: Vector3, tile_col: Color, tiers: int) -> void:
	var tile := Game.paint(tile_col, 0.1, 0.5)
	tile.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gold := Game.paint(Color(0.95, 0.72, 0.25), 0.9, 0.3)
	var wall := Game.paint(Color(0.35, 0.1, 0.08), 0.0, 0.7)
	var y := top.y
	var cur := fp
	for t in range(tiers):
		var rh := clampf(minf(cur.x, cur.z) * 0.28, 1.6, 5.0)
		var over := clampf(minf(cur.x, cur.z) * 0.12, 0.9, 2.2)
		var roof := MeshInstance3D.new()
		roof.mesh = _hip_roof(cur.x, cur.z, rh, over, 0.45)
		roof.material_override = tile
		roof.position = Vector3(top.x, y, top.z)
		w.add_child(roof)
		# kalkık köşelerde altın uçlar (saçağa bağlı)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var tip := w._box(Vector3(top.x + sx * (cur.x * 0.5 + over - 0.15), y + 0.55, top.z + sz * (cur.z * 0.5 + over - 0.15)), Vector3(0.3, 0.25, 0.3), gold, false)
				tip.rotation.y = PI * 0.25
				w._neon(Vector3(top.x + sx * (cur.x * 0.5 + over * 0.6), y - 0.35, top.z + sz * (cur.z * 0.5 + over * 0.6)), Vector3(0.5, 0.65, 0.5), Color(1.0, 0.2, 0.08))
		y += rh * 0.55
		if t < tiers - 1:
			cur = cur * 0.62
			w._box(Vector3(top.x, y + 1.1, top.z), Vector3(cur.x, 2.2, cur.z), wall, false)
			y += 2.2
	w._box(Vector3(top.x, y + rh_last(cur) * 0.4, top.z), Vector3(0.25, 1.6, 0.25), gold, false)


func rh_last(cur: Vector3) -> float:
	return clampf(minf(cur.x, cur.z) * 0.28, 1.6, 5.0)


func _warehouse(base: Vector3, fp: Vector3, hgt: float) -> void:
	var m := _facade_mat("liman", false)
	m.set_shader_parameter("ground_h", hgt + 1.0)
	w._box(base + Vector3(0, hgt * 0.5, 0), Vector3(fp.x, hgt, fp.z), m)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	var along_x := fp.x >= fp.z
	pm.size = Vector3(fp.z + 0.6, 3.0, fp.x + 0.6) if along_x else Vector3(fp.x + 0.6, 3.0, fp.z + 0.6)
	roof.mesh = pm
	roof.position = base + Vector3(0, hgt + 1.5, 0)
	roof.rotation.y = PI * 0.5 if along_x else 0.0
	roof.material_override = Game.paint(Color(0.45, 0.5, 0.52), 0.6, 0.5)
	w.add_child(roof)
	# yükleme kapıları
	var door := Game.paint(Color(0.35, 0.38, 0.4), 0.7, 0.45)
	for k in range(2):
		var x := base.x + (k - 0.5) * fp.x * 0.45
		w._box(Vector3(x, 2.4, base.z + fp.z * 0.5 + 0.05), Vector3(5.0, 4.6, 0.1), door, false)


func _house(base: Vector3, fp: Vector3, b: Dictionary) -> void:
	var cols := [Color(0.98, 0.95, 0.9), Color(0.9, 0.82, 0.72), Color(0.82, 0.9, 0.95), Color(0.95, 0.85, 0.85), Color(0.85, 0.92, 0.82)]
	var roofs := [Color(0.55, 0.2, 0.15), Color(0.25, 0.28, 0.32), Color(0.4, 0.3, 0.22)]
	var hh: float = b.h
	var m := _facade_mat("konut", false)
	m.set_shader_parameter("tint", cols[rng.randi_range(0, cols.size() - 1)])
	m.set_shader_parameter("ground_h", 3.2)
	m.set_shader_parameter("floor_h", 3.0)
	var mi := w._box(base + Vector3(0, hh * 0.5, 0), Vector3(fp.x, hh, fp.z), m)
	mi.set_instance_shader_parameter("seed", rng.randf() * 100.0)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	var turn := int(b.get("roof", 0)) == 1
	pm.size = Vector3(fp.z + 1.2, 3.2, fp.x + 1.2) if turn else Vector3(fp.x + 1.2, 3.2, fp.z + 1.2)
	roof.mesh = pm
	roof.position = base + Vector3(0, hh + 1.6, 0)
	roof.rotation.y = PI * 0.5 if turn else 0.0
	roof.material_override = Game.paint(roofs[rng.randi_range(0, roofs.size() - 1)], 0.0, 0.7)
	w.add_child(roof)
	var block_z := (floorf(base.z / w.CELL) + 0.5) * w.CELL
	var side := 1.0 if base.z > block_z else -1.0
	w._box(base + Vector3(0, 1.1, side * (fp.z * 0.5 + 0.05)), Vector3(1.2, 2.2, 0.1), Game.paint(Color(0.35, 0.22, 0.15), 0.0, 0.6), false)
	w._box(base + Vector3(0, 0.6, side * (fp.z * 0.5 + 4.0)), Vector3(fp.x + 6.0, 0.9, 0.12), Game.paint(Color(0.95, 0.95, 0.95), 0.0, 0.6))


func _shopfront(base: Vector3, fp: Vector3, b: Dictionary) -> void:
	var side := int(b.side)
	var n: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
	var yaw: float = [0.0, PI, PI * 0.5, -PI * 0.5][side]
	var along_x := side < 2
	var half: float = fp.z * 0.5 if along_x else fp.x * 0.5
	var wid: float = (fp.x if along_x else fp.z)
	var wall := base + n * half
	var is_lm := b.has("lm")
	var col: Color = LM_COL.get(String(b.get("lm", "")), w.NEON[rng.randi_range(0, w.NEON.size() - 1)])
	var text: String = String(b.get("name", b.get("sign", ""))).to_upper()
	# tente (duvara bağlı)
	var awn_col: Color = [Color(0.85, 0.15, 0.2), Color(0.1, 0.45, 0.5), Color(0.95, 0.75, 0.2), Color(0.2, 0.2, 0.25), Color(0.95, 0.95, 0.95)][rng.randi_range(0, 4)]
	var aw := minf(wid * 0.8, 18.0)
	var awn := w._box(wall + n * 0.9 + Vector3(0, 3.55, 0), Vector3(aw if along_x else 1.8, 0.12, 1.8 if along_x else aw), Game.paint(awn_col, 0.0, 0.7), false)
	if along_x:
		awn.rotation.x = 0.14 * n.z
	else:
		awn.rotation.z = -0.14 * n.x
	# tabela: duvara monte levha (tente üstünde)
	if text != "":
		var bw := clampf(text.length() * 0.75 + 1.6, 4.0, minf(wid * 0.9, 22.0))
		var bh := 1.5 if not is_lm else 2.2
		w._board(wall + n * 0.13 + Vector3(0, 4.35 + bh * 0.5, 0), yaw, bw, bh, text, col)
	# kapı
	var door_col := Color(0.05, 0.06, 0.07)
	var dw := 2.2 if not is_lm else 3.2
	var dm := w._box(wall + n * 0.04 + Vector3(0, 1.35, 0), Vector3(dw if along_x else 0.08, 2.7, 0.08 if along_x else dw), Game.paint(door_col, 0.2, 0.1), false)
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w._neon(wall + n * 0.1 + Vector3(0, 2.8, 0), Vector3(dw + 0.3 if along_x else 0.06, 0.08, 0.06 if along_x else dw + 0.3), col)
	if b.has("interior"):
		w._door(String(b.lm), String(b.name), String(b.interior), wall + n * 1.4 + Vector3(0, 0, 0), yaw)
	# dikey bıçak tabela: köşede, cepheye dik, başın çok üstünde
	if not is_lm and text != "" and rng.randf() < 0.45:
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var p := wall + right * (wid * 0.5 - 1.0) + n * 0.85 + Vector3(0, 7.5, 0)
		var nch := mini(text.length(), 6)
		var hh := nch * 1.0 + 0.8
		var blade := w._box(p, Vector3(0.25, hh, 1.4) if along_x else Vector3(1.4, hh, 0.25), Game.paint(Color(0.06, 0.06, 0.08), 0.3, 0.4), false)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for kk in range(nch):
			for s2: float in [-1.0, 1.0]:
				var lp: Vector3 = p + Vector3(0, hh * 0.5 - 0.9 - kk * 1.0, 0) + right * (0.14 * s2)
				w._label(text[kk], lp, yaw + PI * 0.5 * s2, col, 110, 0.0085)
		w._neon(p + Vector3(0, hh * 0.5 + 0.05, 0), Vector3(0.3, 0.08, 1.45) if along_x else Vector3(1.45, 0.08, 0.3), col)
		w._neon(p - Vector3(0, hh * 0.5 + 0.05, 0), Vector3(0.3, 0.08, 1.45) if along_x else Vector3(1.45, 0.08, 0.3), col)
	if b.d == "eski":
		w._neon(wall + n * 1.1 + Vector3(0, 3.0, 0), Vector3(0.6, 0.8, 0.6), Color(1.0, 0.18, 0.08))


func _landmark(base: Vector3, fp: Vector3, hgt: float, b: Dictionary) -> void:
	var id: String = b.lm
	var col: Color = LM_COL.get(id, Color.WHITE)
	var top := base + Vector3(0, hgt, 0)
	var nm: String = String(b.name).to_upper()
	w._poi(id, String(b.name), String(b.get("kind2", "shop")), Vector3(base.x, 0, base.z))
	match id:
		"tower":
			for k in range(12):
				w._neon(base + Vector3(0, 20.0 + k * 15.0, fp.z * 0.5 + 0.12), Vector3(fp.x + 0.4, 0.3, 0.2), col, Vector3.ZERO, "tower")
				w._neon(base + Vector3(fp.x * 0.5 + 0.12, 20.0 + k * 15.0, 0), Vector3(0.2, 0.3, fp.z + 0.4), col, Vector3.ZERO, "tower")
			var crown := w._box(top + Vector3(0, 12.0, 0), Vector3(fp.x * 0.6, 24.0, fp.z * 0.6), _facade_mat("tekno", true))
			crown.set_instance_shader_parameter("seed", 3.0)
			w._box(top + Vector3(0, 24.0 + 16.0, 0), Vector3(1.2, 32.0, 1.2), Game.paint(Color(0.8, 0.8, 0.85), 0.9, 0.2), false)
			w._neon(top + Vector3(0, 24.0 + 32.6, 0), Vector3(1.5, 1.5, 1.5), Color(1, 0.1, 0.1), Vector3.ZERO, "far_tower")
			w._board(base + Vector3(0, 9.0, fp.z * 0.5 + 0.13), 0.0, 18.0, 2.4, nm, col)
		"hospital":
			_roof_sign(top, fp, nm, col)
			var cross := Game.emissive(Color(1, 0.15, 0.15), 3.0)
			w._box(top + Vector3(fp.x * 0.3, 4.0, 0), Vector3(1.2, 4.0, 0.4), cross, false)
			w._box(top + Vector3(fp.x * 0.3, 4.0, 0), Vector3(4.0, 1.2, 0.4), cross, false)
			w._box(top + Vector3(fp.x * 0.3, 1.0, 0), Vector3(0.4, 2.0, 0.4), Game.paint(Color(0.3, 0.3, 0.3), 0.6, 0.4), false)
		"police":
			_roof_sign(top, fp, nm, col)
			w._box(top + Vector3(0, 0.15, 0), Vector3(12, 0.3, 12), Game.paint(Color(0.2, 0.22, 0.25), 0.2, 0.7), false)
			w._neon(top + Vector3(0, 0.32, 0), Vector3(9, 0.04, 0.6), Color(1, 1, 1))
		"dojo":
			_roof_sign(top, fp, "TURBO DOJO", col)
			var fist := Game.emissive(Color(1.0, 0.55, 0.1), 2.5)
			w._box(top + Vector3(-fp.x * 0.3, 2.5, 0), Vector3(2.6, 2.6, 2.6), fist, false)
		"weapons":
			_roof_sign(top, fp, nm, col)
			for s in [-1.0, 1.0]:
				var bl := w._box(top + Vector3(s * 3.0, 3.2, 0), Vector3(0.3, 6.0, 0.08), Game.paint(Color(0.85, 0.88, 0.92), 1.0, 0.15), false)
				bl.rotation.z = s * 0.5
		"club":
			_roof_sign(top, fp, nm, col)
			for k in range(6):
				var sp := SpotLight3D.new()
				sp.light_color = w.NEON[k % w.NEON.size()]
				sp.light_energy = 6.0
				sp.spot_range = 60.0
				sp.spot_angle = 8.0
				sp.position = top + Vector3((k - 2.5) * 2.0, 1.0, 0)
				sp.rotation = Vector3(PI * 0.45, (k - 2.5) * 0.3, 0)
				sp.set_meta("club", true)
				w.add_child(sp)
		_:
			_roof_sign(top, fp, nm, col)


func _roof_sign(top: Vector3, fp: Vector3, text: String, col: Color) -> void:
	## çatıdaki direkler üzerinde büyük isim tabelası (çatıya bağlı, havada durmaz)
	var bw := clampf(text.length() * 1.6 + 3.0, 8.0, fp.x * 0.95)
	var bh := 3.2
	var y := 2.6
	var metal := Game.paint(Color(0.2, 0.2, 0.22), 0.7, 0.4)
	for s in [-0.35, 0.35]:
		w._box(top + Vector3(s * bw, y * 0.5, fp.z * 0.3), Vector3(0.25, y, 0.25), metal, false)
	w._board(top + Vector3(0, y + bh * 0.5, fp.z * 0.3), 0.0, bw, bh, text, col)


# ---------------------------------------------------------------- sokak eşyaları
func _palm_mesh() -> ArrayMesh:
	var parts := []
	var bark := Game.paint(Color(0.45, 0.36, 0.27), 0.0, 0.9)
	var frond_mat := ShaderMaterial.new()
	frond_mat.shader = load("res://shaders/frond.gdshader")
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
	return w._merged(parts)


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
	return w._merged([[pole, Transform3D(Basis(), Vector3(0, 3.5, 0)), metal], [arm, Transform3D(Basis(), Vector3(0.85, 6.95, 0)), metal], [head, Transform3D(Basis(), Vector3(1.6, 6.9, 0)), metal], [glow, Transform3D(Basis(), Vector3(1.6, 6.82, 0)), Game.emissive(Color(1.0, 0.85, 0.6), 2.0)]])


func _street_furniture() -> void:
	var palms := []
	var lamps := []
	var outer := w.BLOCK + w.WALK * 2.0
	var lamp_n := 0
	for bi in w.blocks.size():
		var r := w.blocks[bi]
		var c := r.get_center()
		var d := w.block_district[bi]
		var hw := outer * 0.5 - 1.2
		for s in [-1.0, 1.0]:
			var t := -hw + 6.0
			while t < hw - 4.0:
				var slot := int((t + hw) / 12.0)
				var odd := slot % 2 == 0
				var p1 := Vector3(c.x + t, 0.18, c.y + s * hw)
				var p2 := Vector3(c.x + s * hw, 0.18, c.y + t)
				var palm_ok := d == "sahil" or d == "cadde" or d == "konut" or d == "lunapark" or (d == "merkez" and slot % 4 == 0)
				if odd and palm_ok:
					for p in [p1, p2]:
						palms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), p))
						w._cyl_collider(p, 0.3, 4.0)
				elif not odd:
					var l1 := Transform3D(Basis(Vector3.UP, -PI * 0.5 * s), p1)
					var l2 := Transform3D(Basis(Vector3.UP, PI if s > 0 else 0.0), p2)
					for lx in [[l1, p1], [l2, p2]]:
						lamps.append(lx[0])
						var p: Vector3 = lx[1]
						lamp_n += 1
						var light: OmniLight3D = null
						if lamp_n % 2 == 1:
							light = OmniLight3D.new()
							light.light_color = Color(1.0, 0.82, 0.58) if d != "eski" else Color(1.0, 0.55, 0.3)
							light.light_energy = 3.0
							light.omni_range = 17.0
							light.omni_attenuation = 1.3
							light.distance_fade_enabled = true
							light.distance_fade_begin = 60.0
							light.distance_fade_length = 20.0
							light.position = (lx[0] as Transform3D) * Vector3(1.6, 6.6, 0)
							light.visible = false
							w.add_child(light)
							w.street_lights.append(light)
						var lcs := CollisionShape3D.new()
						var lsh := CylinderShape3D.new()
						lsh.radius = 0.14
						lsh.height = 7.0
						lcs.shape = lsh
						lcs.position = p + Vector3(0, 3.5, 0)
						w.props.add_child(lcs)
						w.breakables.append({"kind": "lamp", "xf": lx[0], "list": "lamp", "idx": lamps.size() - 1, "light": light, "r": 0.18, "h": 7.0, "cs": lcs, "pos": p})
				t += 12.0
	# sahil şeridi palmiyeleri (batı kıyısı)
	var z := -w.EDGE_Z + 10.0
	while z < w.EDGE_Z:
		if z > 6.0:
			var p := Vector3(-w.EDGE_X - 4.0, 0.18, z)
			palms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.35)), p))
			w._cyl_collider(p, 0.3, 4.0)
		z += 14.0
	_multi_palms(palms)
	var lamp_mm := w._multi(_lamp_mesh(), lamps)
	for b in w.breakables:
		if b.get("list", "") == "lamp":
			b["mm"] = lamp_mm.multimesh
	for key in ["bench", "bin", "hydrant", "plant"]:
		var sc := Game.model(key)
		if sc == null:
			continue
		for r in w.blocks:
			if rng.randf() < 0.45:
				continue
			var c := r.get_center()
			var n: Node3D = sc.instantiate()
			var s := 1.0 if rng.randf() < 0.5 else -1.0
			var t := rng.randf_range(-20, 20)
			n.position = Vector3(c.x + t, 0.18, c.y + s * (outer * 0.5 - 2.2))
			n.rotation.y = 0.0 if s > 0 else PI
			w.add_child(n)
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.35 if key != "bench" else 0.7
			cy.height = 1.0
			cs.shape = cy
			cs.position.y = 0.5
			sb.add_child(cs)
			n.add_child(sb)
			w.breakables.append({"kind": key, "node": n, "r": cy.radius, "h": 1.0, "body": sb, "pos": n.position})
	for i in range(-w.GX + 1, w.GX):
		for j in range(-w.GZ + 1, w.GZ):
			var k := Vector3(i * w.CELL, 0, j * w.CELL)
			_traffic_light(k + Vector3(w.ROAD_W * 0.5 + 1.2, 0.18, w.ROAD_W * 0.5 + 1.2), 0)
			_traffic_light(k + Vector3(-w.ROAD_W * 0.5 - 1.2, 0.18, -w.ROAD_W * 0.5 - 1.2), 1)


func _multi_palms(palms: Array) -> void:
	var palm_scene := Game.model("palm")
	if palm_scene:
		for tr in palms:
			var n: Node3D = palm_scene.instantiate()
			n.transform = tr
			w.add_child(n)
	else:
		w._multi(_palm_mesh(), palms)


func _traffic_light(p: Vector3, axis: int) -> void:
	var metal := Game.paint(Color(0.12, 0.12, 0.13), 0.6, 0.5)
	w._box(p + Vector3(0, 2.6, 0), Vector3(0.18, 5.2, 0.18), metal)
	w._box(p + Vector3(0, 5.0, 0), Vector3(0.45, 1.2, 0.35), metal, false)
	var red := w._box(p + Vector3(0, 5.35, 0.19 if axis == 0 else -0.19), Vector3(0.26, 0.26, 0.05), Game.emissive(Color(1, 0.12, 0.08), 6.0), false)
	var green := w._box(p + Vector3(0, 4.7, 0.19 if axis == 0 else -0.19), Vector3(0.26, 0.26, 0.05), Game.emissive(Color(0.15, 1, 0.45), 6.0), false)
	w.signal_lights.append([red, green, axis])


func _lanterns() -> void:
	## Eski Çarşı: sokakların üstünde fener dizileri (iki yandaki direklere gerili tel)
	var red := []
	var orange := []
	var wires := []
	var poles := []
	for i in range(-w.GX, w.GX + 1):
		for j in range(-w.GZ, w.GZ):
			if not (w.district(i - 1, j) == "eski" or w.district(i, j) == "eski"):
				continue
			var z := j * w.CELL + 14.0
			while z < (j + 1) * w.CELL - 12.0:
				for k in range(7):
					var t := (k - 3) / 3.0
					(red if k % 2 == 0 else orange).append(Transform3D(Basis(), Vector3(i * w.CELL + t * (w.ROAD_W * 0.5 + 2.0), 7.2 - (1.0 - t * t) * 1.0, z)))
				wires.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(i * w.CELL, 7.0, z)))
				for s in [-1.0, 1.0]:
					poles.append(Transform3D(Basis(), Vector3(i * w.CELL + s * (w.ROAD_W * 0.5 + 2.1), 3.6, z)))
				z += 9.0
	for j in range(-w.GZ, w.GZ + 1):
		for i in range(-w.GX, w.GX):
			if not (w.district(i, j - 1) == "eski" or w.district(i, j) == "eski"):
				continue
			var x := i * w.CELL + 14.0
			while x < (i + 1) * w.CELL - 12.0:
				for k in range(7):
					var t := (k - 3) / 3.0
					(red if k % 2 == 0 else orange).append(Transform3D(Basis(), Vector3(x, 7.2 - (1.0 - t * t) * 1.0, j * w.CELL + t * (w.ROAD_W * 0.5 + 2.0))))
				wires.append(Transform3D(Basis(), Vector3(x, 7.0, j * w.CELL)))
				for s in [-1.0, 1.0]:
					poles.append(Transform3D(Basis(), Vector3(x, 3.6, j * w.CELL + s * (w.ROAD_W * 0.5 + 2.1))))
				x += 9.0
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.75
	sm.radial_segments = 10
	sm.rings = 6
	var mr := w._multi(sm, red, w.neon_mat, 220.0)
	mr.set_instance_shader_parameter("neon_col", Color(1.0, 0.15, 0.08))
	mr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mo := w._multi(sm, orange, w.neon_mat, 220.0)
	mo.set_instance_shader_parameter("neon_col", Color(1.0, 0.55, 0.12))
	mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wm := BoxMesh.new()
	wm.size = Vector3(0.03, 0.03, w.ROAD_W + 4.4)
	w._multi(wm, wires, Game.paint(Color(0.05, 0.05, 0.05), 0.0, 0.8), 220.0)
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.1
	pm.height = 7.2
	pm.radial_segments = 6
	w._multi(pm, poles, Game.paint(Color(0.3, 0.12, 0.08), 0.0, 0.7), 220.0)


# ---------------------------------------------------------------- monoray
func _monorail() -> void:
	var concrete := Game.pbr("concrete", Color(0.82, 0.82, 0.85), 0.4)
	var r := 12.0
	var per := ((w.RAIL_R * 2.0 - r * 2.0) + PI * 0.5 * r) * 4.0
	var s := 0.0
	var stp := 4.0
	while s < per:
		var a: Array = w.rail_point(s)
		var b: Array = w.rail_point(s + stp)
		var mid: Vector3 = (a[0] + b[0]) * 0.5
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0, 1.1, (b[0] - a[0]).length() + 0.08)
		seg.mesh = bm
		seg.material_override = concrete
		w.add_child(seg)
		seg.look_at_from_position(mid, mid + (b[0] - a[0]), Vector3.UP)
		var dir: Vector3 = (b[0] - a[0]).normalized()
		w._neon(mid + Vector3(0, -0.6, 0), Vector3(0.12, 0.06, bm.size.z), Color(0.1, 0.9, 1.0), Vector3(0, atan2(dir.x, dir.z), 0), "rail")
		s += stp
	s = 10.0
	while s < per:
		var p: Vector3 = w.rail_point(s)[0]
		var near_x: float = abs(fmod(abs(p.x) + w.CELL * 0.5, w.CELL) - w.CELL * 0.5)
		var near_z: float = abs(fmod(abs(p.z) + w.CELL * 0.5, w.CELL) - w.CELL * 0.5)
		if not (near_x < 14.0 and near_z < 14.0):
			var col := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.7
			cm.bottom_radius = 0.85
			cm.height = w.RAIL_H - 0.5
			cm.radial_segments = 12
			col.mesh = cm
			col.material_override = concrete
			col.position = Vector3(p.x, cm.height * 0.5, p.z)
			w.add_child(col)
			w._cyl_collider(Vector3(p.x, 0, p.z), 0.8, w.RAIL_H - 0.5)
		s += 26.0
	w._poi("monoray", "Monoray İstasyonu", "station", Vector3(w.RAIL_R, 0, 0))
	var body := Game.paint(Color(0.95, 0.95, 0.97), 0.4, 0.25, 0.8)
	for k in range(3):
		var car := Node3D.new()
		w.add_child(car)
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
		for sd in [-1.0, 1.0]:
			var wn := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(0.05, 0.7, 9.0)
			wn.mesh = wb
			wn.material_override = Game.emissive(Color(1.0, 0.9, 0.7), 1.5)
			wn.position = Vector3(sd * 1.38, 2.3, 0)
			car.add_child(wn)
		w.train.append(car)
	w._move_train(0.0)


# ---------------------------------------------------------------- liman
func container_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/container.gdshader")
	return m


var _cont_mesh: ArrayMesh


func container_mesh() -> ArrayMesh:
	## 6.1 x 2.6 x 2.44 konteyner: yanlar oluklu (gölgelendiricide), uçta kapı çubukları, köşe dökümleri
	if _cont_mesh:
		return _cont_mesh
	var bm := BoxMesh.new()
	bm.size = Vector3(2.44, 2.59, 6.06)
	var am := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(bm, 0, Transform3D())
	st.generate_tangents()
	st.set_material(container_material())
	st.commit(am)
	var corner := BoxMesh.new()
	corner.size = Vector3(0.2, 0.2, 0.2)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				st2.append_from(corner, 0, Transform3D(Basis(), Vector3(sx * 1.17, sy * 1.25, sz * 2.98)))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.05, 2.3, 0.06)
	for k in range(4):
		st2.append_from(bar, 0, Transform3D(Basis(), Vector3(-0.9 + k * 0.6, 0, -3.06)))
	st2.set_material(Game.paint(Color(0.15, 0.15, 0.15), 0.6, 0.6))
	st2.commit(am)
	_cont_mesh = am
	return am


func _containers(origin: Vector3, rows: int, cols: int, max_stack: int, along_x := false) -> void:
	var cols_list := [Color(0.72, 0.18, 0.13), Color(0.12, 0.33, 0.62), Color(0.9, 0.62, 0.12), Color(0.18, 0.48, 0.28), Color(0.86, 0.86, 0.84),
		Color(0.48, 0.26, 0.55), Color(0.85, 0.42, 0.12), Color(0.3, 0.3, 0.32)]
	var xfs := []
	var cs := []
	for r in range(rows):
		for c in range(cols):
			if rng.randf() < 0.15:
				continue
			var stack := rng.randi_range(1, max_stack)
			for s in range(stack):
				var off := Vector3(r * 2.9, 1.3 + s * 2.6, c * 6.5)
				if along_x:
					off = Vector3(c * 6.5, 1.3 + s * 2.6, r * 2.9)
				var bas := Basis(Vector3.UP, (PI * 0.5 if along_x else 0.0) + rng.randf_range(-0.02, 0.02))
				var xf := Transform3D(bas, origin + off)
				xfs.append(xf)
				cs.append(cols_list[rng.randi_range(0, cols_list.size() - 1)])
				var ext := Vector3(2.44, 2.59, 6.06) if not along_x else Vector3(6.06, 2.59, 2.44)
				w._collider(xf.origin, ext)
	w._multi(container_mesh(), xfs, null, 500.0, cs)


func _harbor() -> void:
	var qx0 := -w.EDGE_X
	var qx1 := -w.EDGE_X - 82.0
	var quay := Game.pbr("concrete", Color(0.62, 0.62, 0.6), 0.25)
	# rıhtım: şehir zeminiyle aynı yükseklikte (0.05)
	w._box(Vector3((qx0 + qx1) * 0.5, -0.25, -w.EDGE_Z * 0.5 - 2.0), Vector3(qx0 - qx1, 0.6, w.EDGE_Z + 4.0), quay)
	w._box(Vector3(qx1 + 0.4, -0.8, -w.EDGE_Z * 0.5 - 2.0), Vector3(0.8, 1.7, w.EDGE_Z + 4.0), Game.pbr("concrete", Color(0.45, 0.45, 0.44), 0.2), false)
	w._neon(Vector3(qx1 + 0.3, 0.08, -w.EDGE_Z * 0.5), Vector3(0.25, 0.1, w.EDGE_Z), Color(1.0, 0.8, 0.15), Vector3.ZERO, "liman")
	# kıyı babaları
	var bol := Game.paint(Color(0.15, 0.15, 0.16), 0.5, 0.5)
	var zb := -w.EDGE_Z + 6.0
	while zb < -4.0:
		w._box(Vector3(qx1 + 1.2, 0.4, zb), Vector3(0.5, 0.7, 0.5), bol)
		zb += 12.0
	# iskeleler (rıhtımla aynı yükseklikte, kazıklar suda)
	var wood := Game.paint(Color(0.45, 0.33, 0.22), 0.0, 0.85)
	for k in range(3):
		var z := -60.0 - k * 90.0
		var plen := 64.0
		w._box(Vector3(qx1 - plen * 0.5, -0.2, z), Vector3(plen, 0.5, 8.0), wood)
		var q := 4.0
		while q < plen:
			for s in [-1.0, 1.0]:
				w._box(Vector3(qx1 - q, -3.4, z + s * 3.6), Vector3(0.5, 6.0, 0.5), wood, false)
			q += 8.0
		var hull: Color = [Color(0.7, 0.15, 0.12), Color(0.15, 0.3, 0.55), Color(0.1, 0.45, 0.35)][k]
		var ship := Vector3(qx1 - 34.0, 0.0, z + 17.0)
		w._box(ship + Vector3(0, 0.6, 0), Vector3(46.0, 6.0, 10.0), Game.paint(hull, 0.3, 0.6))
		w._box(ship + Vector3(-15.0, 5.6, 0), Vector3(10.0, 4.4, 8.6), Game.paint(Color(0.92, 0.92, 0.9), 0.1, 0.6))
		w._neon(ship + Vector3(-15.0, 7.9, 0), Vector3(10.2, 0.15, 8.8), Color(0.2, 0.9, 1.0), Vector3.ZERO, "liman")
		_containers(ship + Vector3(-6.0, 3.6, -3.0), 2, 4, 2, true)
	# vinçler (rıhtımda, raylar üstünde)
	var yel := Game.paint(Color(0.95, 0.72, 0.1), 0.4, 0.5)
	for k in range(3):
		var p := Vector3(qx1 + 14.0, 0.05, -50.0 - k * 95.0)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				w._box(p + Vector3(sx * 6.0, 15.0, sz * 5.0), Vector3(1.0, 30.0, 1.0), yel)
		for hy in [10.0, 22.0]:
			for sz in [-1.0, 1.0]:
				w._box(p + Vector3(0, hy, sz * 5.0), Vector3(12.8, 0.7, 0.7), yel, false)
		w._box(p + Vector3(-18.0, 30.5, 0), Vector3(56.0, 2.0, 2.6), yel, false)
		w._box(p + Vector3(8.0, 29.5, 0), Vector3(7.0, 3.4, 3.4), Game.paint(Color(0.3, 0.3, 0.32), 0.5, 0.5), false)
		w._box(p + Vector3(2.0, 32.4, 0), Vector3(4.0, 3.0, 4.0), Game.paint(Color(0.95, 0.95, 0.92), 0.1, 0.5), false)
		w._neon(p + Vector3(-45.8, 30.5, 0), Vector3(0.4, 0.4, 0.4), Color(1, 0.15, 0.1), Vector3.ZERO, "liman")
	# konteyner istifleri (rıhtımda)
	_containers(Vector3(-w.EDGE_X - 30.0, 0.05, -300.0), 6, 4, 4)
	_containers(Vector3(-w.EDGE_X - 30.0, 0.05, -150.0), 6, 3, 3)
	# liman kapısı (tabela iki direğe bağlı)
	var gate := Vector3(-w.EDGE_X - 8.0, 0.05, -12.0)
	var metal := Game.paint(Color(0.2, 0.2, 0.22), 0.6, 0.4)
	for s in [-1.0, 1.0]:
		w._box(gate + Vector3(0, 4.0, s * 7.0), Vector3(0.6, 8.0, 0.6), metal)
	w._board(gate + Vector3(0, 8.6, 0), PI * 0.5, 15.0, 2.2, "LİMAN", Color(1.0, 0.85, 0.2))


# ---------------------------------------------------------------- sahil
func _beach() -> void:
	var pole := Game.paint(Color(0.92, 0.92, 0.9), 0.2, 0.5)
	var canopy_cols := [Color(0.95, 0.25, 0.3), Color(0.15, 0.6, 0.85), Color(1.0, 0.8, 0.2), Color(0.3, 0.8, 0.5), Color(1.0, 0.5, 0.7)]
	var z := 14.0
	while z < w.EDGE_Z + 30.0:
		var x := -w.EDGE_X - rng.randf_range(22.0, 48.0)
		var y := w.terrain_h(x, z)
		if y > w.SEA + 0.4:
			var p := Vector3(x, y, z + rng.randf_range(-3, 3))
			w._box(p + Vector3(0, 1.3, 0), Vector3(0.1, 2.6, 0.1), pole, false)
			w._cyl_collider(p, 0.12, 2.6)
			var cn := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 1.7
			cm.height = 0.55
			cm.radial_segments = 10
			cn.mesh = cm
			cn.material_override = Game.paint(canopy_cols[rng.randi_range(0, canopy_cols.size() - 1)], 0.0, 0.7)
			cn.position = p + Vector3(0, 2.6, 0)
			w.add_child(cn)
			for sd in [-1.0, 1.0]:
				var lp := p + Vector3(1.6, 0.0, sd * 1.2)
				var ly := w.terrain_h(lp.x, lp.z)
				var l := w._box(Vector3(lp.x, ly + 0.32, lp.z), Vector3(1.9, 0.12, 0.7), Game.paint(Color(1, 1, 1), 0.0, 0.6), false)
				l.rotation.z = 0.15
				for lx in [-0.8, 0.8]:
					w._box(Vector3(lp.x + lx, ly + 0.14, lp.z), Vector3(0.06, 0.28, 0.6), pole, false)
				w._collider(Vector3(lp.x, ly + 0.25, lp.z), Vector3(1.9, 0.5, 0.7))
		z += rng.randf_range(18.0, 28.0)
	for tz in [60.0, 220.0]:
		var p := Vector3(-w.EDGE_X - 40.0, 0.0, tz)
		p.y = w.terrain_h(p.x, p.z)
		var wood := Game.paint(Color(0.95, 0.95, 0.92), 0.0, 0.7)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				w._box(p + Vector3(sx * 1.2, 1.6, sz * 1.2), Vector3(0.2, 3.2, 0.2), wood)
		w._box(p + Vector3(0, 4.2, 0), Vector3(3.0, 2.2, 3.0), Game.paint(Color(0.95, 0.3, 0.25), 0.0, 0.6))
		w._box(p + Vector3(0, 5.5, 0), Vector3(3.6, 0.3, 3.6), wood, false)
		w._board(p + Vector3(1.55, 4.3, 0), PI * 0.5, 2.6, 0.7, "CANKURTARAN", Color(1, 1, 1), Color(0.8, 0.1, 0.1), 64)
	# Ananas Smoothie kulübesi (dev neon ananas çatıda, yazı kulübenin tabelasında)
	var k := Vector3(-w.EDGE_X - 16.0, 0.18, 150.0)
	var hut := Game.paint(Color(0.98, 0.85, 0.35), 0.0, 0.6)
	w._box(k + Vector3(0, 2.0, 0), Vector3(8.0, 4.0, 10.0), hut)
	w._box(k + Vector3(0, 4.15, 0), Vector3(9.5, 0.3, 11.5), Game.paint(Color(0.2, 0.55, 0.3), 0.0, 0.7), false)
	var top := k + Vector3(0, 4.3, 0)
	for kk in 18:
		var a := kk * TAU / 18.0
		for row in range(5):
			var r := 1.8 * sin(PI * (row + 0.5) / 5.0) + 0.4
			w._neon(top + Vector3(cos(a) * r, 0.5 + row * 0.85, sin(a) * r), Vector3(0.3, 0.3, 0.3), Color(1.0, 0.8, 0.1), Vector3.ZERO, "smoothie")
	for kk in 7:
		var a := kk * TAU / 7.0
		w._neon(top + Vector3(cos(a) * 0.45, 5.3, sin(a) * 0.45), Vector3(0.22, 2.2, 0.22), Color(0.2, 1.0, 0.35), Vector3(cos(a) * 0.5, 0, sin(a) * 0.5), "smoothie")
	w._board(k + Vector3(4.12, 3.0, 0), PI * 0.5, 7.5, 1.3, "ANANAS SMOOTHIE", Color(1.0, 0.85, 0.2))
	w._door("smoothie", "Ananas Smoothie", "smoothie", k + Vector3(5.5, 0, 0), PI * 0.5)
	# plaj voleybolu filesi
	var vb := Vector3(-w.EDGE_X - 30.0, 0, 300.0)
	vb.y = w.terrain_h(vb.x, vb.z)
	for s in [-1.0, 1.0]:
		w._box(vb + Vector3(0, 1.3, s * 4.5), Vector3(0.12, 2.6, 0.12), pole)
	w._box(vb + Vector3(0, 2.2, 0), Vector3(0.04, 0.9, 9.0), Game.paint(Color(1, 1, 1, 1), 0.0, 0.8), false)


# ---------------------------------------------------------------- lunapark
func _lunapark() -> void:
	var c11 := Vector3(1.5 * w.CELL, 0.18, 3.5 * w.CELL)    # (1,3) atlıkarınca
	var c21 := Vector3(2.5 * w.CELL, 0.18, 3.5 * w.CELL)    # (2,3) dönme dolap
	var c12 := Vector3(2.5 * w.CELL, 0.18, 2.5 * w.CELL)    # (2,2) hız treni
	var c22 := Vector3(1.5 * w.CELL, 0.18, 2.5 * w.CELL)    # (1,2) giriş + tezgâhlar
	w._poi("lunapark", "Neon Lunapark", "fun", c22)
	# dönme dolap
	var steel := Game.paint(Color(0.92, 0.92, 0.95), 0.7, 0.3)
	var hub := c21 + Vector3(0, 24.0, 0)
	for s in [-1.0, 1.0]:
		for f in [-1.0, 1.0]:
			var leg := w._box(c21 + Vector3(f * 7.0, 12.0, s * 2.5), Vector3(0.8, 26.0, 0.8), steel)
			leg.rotation.z = -f * 0.28
	_wheel = Node3D.new()
	_wheel.position = hub
	w.add_child(_wheel)
	var R := 20.0
	for k in range(16):
		var a := k * TAU / 16.0
		var spoke := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.25, R, 0.25)
		spoke.mesh = sb
		spoke.material_override = steel
		spoke.position = Vector3(cos(a), sin(a), 0) * R * 0.5
		spoke.rotation.z = a - PI * 0.5
		_wheel.add_child(spoke)
		var rim := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.3, 2.0 * R * sin(PI / 16.0) + 0.2, 0.3)
		rim.mesh = rb
		rim.material_override = w.neon_mat
		rim.set_instance_shader_parameter("neon_col", w.NEON[k % w.NEON.size()])
		rim.position = Vector3(cos(a + PI / 16.0), sin(a + PI / 16.0), 0) * R * cos(PI / 16.0)
		rim.rotation.z = a + PI / 16.0
		_wheel.add_child(rim)
		var cab := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(2.2, 2.0, 2.0)
		cab.mesh = cbm
		cab.material_override = Game.paint(w.NEON[k % w.NEON.size()], 0.2, 0.4)
		cab.position = Vector3(cos(a), sin(a), 0) * R + Vector3(0, -1.3, 0)
		cab.set_meta("cab", true)
		_wheel.add_child(cab)
	# atlıkarınca
	_carousel = Node3D.new()
	_carousel.position = c11
	w.add_child(_carousel)
	var roofm := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.5
	rc.bottom_radius = 9.0
	rc.height = 3.0
	rc.radial_segments = 16
	roofm.mesh = rc
	roofm.material_override = Game.paint(Color(0.9, 0.2, 0.35), 0.1, 0.5)
	roofm.position.y = 6.5
	_carousel.add_child(roofm)
	var plat := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 8.5
	pc.bottom_radius = 8.5
	pc.height = 0.5
	pc.radial_segments = 24
	plat.mesh = pc
	plat.material_override = Game.paint(Color(0.95, 0.85, 0.6), 0.2, 0.5)
	plat.position.y = 0.3
	_carousel.add_child(plat)
	for k in range(12):
		var a := k * TAU / 12.0
		var post := MeshInstance3D.new()
		var pb := CylinderMesh.new()
		pb.top_radius = 0.08
		pb.bottom_radius = 0.08
		pb.height = 4.6
		post.mesh = pb
		post.material_override = Game.paint(Color(0.95, 0.8, 0.3), 1.0, 0.2)
		post.position = Vector3(cos(a) * 6.5, 2.8, sin(a) * 6.5)
		_carousel.add_child(post)
		var horse := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.5, 0.8, 1.6)
		horse.mesh = hb
		horse.material_override = Game.paint(Color(1, 1, 1), 0.0, 0.4)
		horse.position = Vector3(cos(a) * 6.5, 1.6 + (k % 2) * 0.4, sin(a) * 6.5)
		horse.rotation.y = -a
		_carousel.add_child(horse)
	w._cyl_collider(c11, 8.6, 1.0)
	# hız treni: blok içinde kapalı halka (sütunlar üstünde), tepesi ve dalışı olan
	var pts := []
	for k in range(64):
		var t := k * TAU / 64.0
		var x := cos(t) * 22.0
		var z := sin(2.0 * t) * 14.0
		var y := 6.0 + 8.0 * maxf(0.0, sin(t)) + 3.0 * sin(3.0 * t)
		pts.append(c12 + Vector3(x, y, z))
	_coaster_pts = pts
	var rail := Game.paint(Color(0.95, 0.2, 0.3), 0.6, 0.3)
	for k in range(pts.size()):
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % pts.size()]
		var mid := (a + b) * 0.5
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.6, 0.35, a.distance_to(b) + 0.1)
		seg.mesh = bm
		seg.material_override = rail
		w.add_child(seg)
		seg.look_at_from_position(mid, b, Vector3.UP)
		if k % 4 == 0:
			w._box(Vector3(a.x, (a.y + 0.18) * 0.5, a.z), Vector3(0.35, a.y - 0.18, 0.35), steel, false)
	_coaster_car = Node3D.new()
	w.add_child(_coaster_car)
	var car := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(1.8, 1.0, 3.2)
	car.mesh = cb
	car.material_override = Game.paint(Color(1.0, 0.85, 0.1), 0.3, 0.3)
	_coaster_car.add_child(car)
	# giriş kemeri (tabela kemere bağlı) + tezgâhlar
	var gate := c22 + Vector3(-w.BLOCK * 0.5 - 3.0, 0, 0)
	var arch := Game.paint(Color(0.2, 0.05, 0.3), 0.3, 0.4)
	for s in [-1.0, 1.0]:
		w._box(gate + Vector3(0, 4.0, s * 6.0), Vector3(1.0, 8.0, 1.0), arch)
	w._board(gate + Vector3(0, 9.0, 0), -PI * 0.5, 13.0, 2.4, "NEON LUNAPARK", Color(1.0, 0.3, 0.9))
	var stall_cols := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 0.95), Color(0.95, 0.85, 0.3), Color(0.4, 0.9, 0.5)]
	for k in range(4):
		var p := c22 + Vector3(8.0, 0, -18.0 + k * 12.0)
		w._box(p + Vector3(0, 1.4, 0), Vector3(4.0, 2.8, 4.0), Game.paint(Color(0.95, 0.93, 0.88), 0.0, 0.6))
		var awn := w._box(p + Vector3(0, 3.1, 0), Vector3(4.6, 0.3, 4.6), Game.paint(stall_cols[k], 0.0, 0.6), false)
		awn.rotation.z = 0.08
