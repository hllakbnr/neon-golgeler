extends RefCounted
class_name PlacesBuilder
## Şehir dışı: yollar (şerit mesh + çarpışma), Kızıl Köprü, manastır merdiveni ve Kasırga Manastırı,
## bölgelerdeki simge yerler (harabeler, Atalar Geçidi heykelleri, Sis Kasabası, köy, tapınak…),
## ağaçlar ve kayalar.

var w: World
var rng := RandomNumberGenerator.new()
var road_mat: ShaderMaterial


func _init(world: World) -> void:
	w = world
	rng.seed = 909


# ---------------------------------------------------------------- yollar
func roads() -> void:
	road_mat = ShaderMaterial.new()
	road_mat.shader = load("res://shaders/road_ribbon.gdshader")
	for slot in [["asph", "diff", "has_tex"], ["asph_n", "nor", "has_nor"]]:
		var t := Game.tex("asphalt", slot[1])
		if t:
			road_mat.set_shader_parameter(slot[0], t)
			road_mat.set_shader_parameter(slot[2], true)
	for r in w.roads:
		var pts: Array[Vector3] = []
		for p in r.pts:
			var v := Vector3(p[0], p[1], p[2])
			if absf(v.x) < w.EDGE_X + 10.0 and absf(v.z) < w.EDGE_Z + 10.0:
				v.y = maxf(v.y, 0.2)
			pts.append(v)
		var width: float = r.width
		for k in pts.size() - 1:
			w.extra_roads.append([Vector2(pts[k].x, pts[k].z), Vector2(pts[k + 1].x, pts[k + 1].z), width])
		if String(r.kind) == "kopru":
			_bridge(pts, width)
		else:
			_ribbon(pts, width, String(r.kind), 0.22)
	_stairs()


func _ribbon(pts: Array[Vector3], width: float, kind: String, lift: float) -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var faces := PackedVector3Array()
	var dist := 0.0
	var n := pts.size()
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var t := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := Vector3(-t.z, 0, t.x) * width * 0.5
		var c: Vector3 = pts[i] + Vector3(0, lift, 0)
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var v := dist / width
		# üst yüzey + iki yanda aşağı inen etek (araziyle yol arasında boşluk görünmesin)
		verts.append_array([c - side - Vector3(0, 0.9, 0), c - side, c + side, c + side - Vector3(0, 0.9, 0)])
		uvs.append_array([Vector2(-0.05, v), Vector2(0.0, v), Vector2(1.0, v), Vector2(1.05, v)])
		norms.append_array([-side.normalized(), Vector3.UP, Vector3.UP, side.normalized()])
	for i in n - 1:
		var o := i * 4
		for q in [[0, 1], [1, 2], [2, 3]]:
			var a0: int = o + q[0]
			var a1: int = o + q[1]
			idx.append_array([a0, a0 + 4, a1, a1, a0 + 4, a1 + 4])
		faces.append_array([verts[o + 1], verts[o + 5], verts[o + 2], verts[o + 2], verts[o + 5], verts[o + 6]])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	var m := road_mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("highway", kind == "otoyol")
	mi.material_override = m
	w.add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(faces)
	cs.shape = sh
	sb.add_child(cs)
	w.add_child(sb)


func _bridge(pts: Array[Vector3], width: float) -> void:
	## Kızıl Köprü: asma köprü — iki kule, zincir eğrisi ana halatlar, askılar, neon
	_ribbon(pts, width, "kopru", 0.0)
	var steel := Game.paint(Color(0.78, 0.18, 0.14), 0.6, 0.4)
	var concrete := Game.pbr("concrete", Color(0.8, 0.8, 0.8), 0.3)
	var n := pts.size()
	# alt kiriş ve ayaklar
	for i in range(0, n - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid := (a + b) * 0.5
		var girder := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(width - 1.0, 1.6, a.distance_to(b) + 0.05)
		girder.mesh = gm
		girder.material_override = Game.paint(Color(0.35, 0.36, 0.38), 0.5, 0.5)
		w.add_child(girder)
		girder.look_at_from_position(mid - Vector3(0, 1.0, 0), b - Vector3(0, 1.0, 0), Vector3.UP)
		if i % 4 == 0 and a.y > 3.0:
			var pil_h := a.y + 12.0
			w._box(Vector3(a.x, a.y - 1.8 - pil_h * 0.5, a.z), Vector3(3.0, pil_h, 3.0), concrete, false)
	var dir := (pts[n - 1] - pts[0])
	dir.y = 0
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var yaw := atan2(dir.x, dir.z)
	var bas := Basis(Vector3.UP, yaw)
	# kuleler: güvertenin %30 ve %70'inde
	var t_ids := [int(n * 0.3), int(n * 0.7)]
	var top_h := 46.0
	var tops := []
	for ti in t_ids:
		var p: Vector3 = pts[ti]
		for sd in [-1.0, 1.0]:
			var leg := w._box(p + side * sd * (width * 0.5 + 1.4) + Vector3(0, (top_h - 6.0) * 0.5, 0), Vector3(1.8, top_h + 6.0, 1.8), steel)
			leg.basis = bas
		for hy in [12.0, 26.0, top_h - 2.0]:
			var beam := w._box(p + Vector3(0, hy, 0), Vector3(width + 4.4, 1.4, 1.4), steel, false)
			beam.basis = bas
		w._neon_xf(Transform3D(bas, p + Vector3(0, top_h + 1.0, 0)), Vector3(width + 5.0, 0.3, 0.3), Color(1.0, 0.25, 0.45), "far_bridge")
		tops.append(p + Vector3(0, top_h - 1.0, 0))
	# ana halatlar
	var anchors := [pts[0] + Vector3(0, 1.2, 0), tops[0], tops[1], pts[n - 1] + Vector3(0, 1.2, 0)]
	for sd in [-1.0, 1.0]:
		var off: Vector3 = side * sd * (width * 0.5 + 1.4)
		for seg in range(3):
			var a: Vector3 = anchors[seg] + off
			var b: Vector3 = anchors[seg + 1] + off
			var sag := 26.0 if seg == 1 else 3.0
			var steps := 18 if seg == 1 else 8
			var prev := a
			for q in range(1, steps + 1):
				var u := float(q) / steps
				var cur := a.lerp(b, u) - Vector3(0, sag * 4.0 * u * (1.0 - u), 0)
				var mid := (prev + cur) * 0.5
				var dv := cur - prev
				var cb := Basis.looking_at(dv.normalized(), Vector3.UP)
				var cm := w._box(mid, Vector3(0.45, 0.45, dv.length() + 0.1), steel, false)
				cm.basis = cb
				w._neon_xf(Transform3D(cb, mid + Vector3(0, 0.32, 0)), Vector3(0.12, 0.12, dv.length()), Color(1.0, 0.25, 0.45), "far_bridge")
				# askı: halattan güverteye
				var deck_y := _deck_y(pts, cur)
				if cur.y > deck_y + 2.5 and q < steps:
					w._box(Vector3(cur.x, (cur.y + deck_y) * 0.5, cur.z), Vector3(0.12, cur.y - deck_y, 0.12), steel, false)
				prev = cur
	# korkuluk + yol kenarı neonları
	for i in range(0, n - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid := (a + b) * 0.5
		var d2 := (b - a)
		var cb := Basis.looking_at(d2.normalized(), Vector3.UP)
		for sd in [-1.0, 1.0]:
			var r := w._box(mid + cb.x * sd * (width * 0.5 - 0.2) + Vector3(0, 0.6, 0), Vector3(0.25, 1.2, d2.length() + 0.05), steel)
			r.basis = cb
			w._neon_xf(Transform3D(cb, mid + cb.x * sd * (width * 0.5 - 0.35) + Vector3(0, 0.05, 0)), Vector3(0.1, 0.1, d2.length()), Color(0.2, 0.9, 1.0), "far_bridge")


func _deck_y(pts: Array[Vector3], p: Vector3) -> float:
	var best := 1e9
	var y := 0.0
	for q in pts:
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < best:
			best = d
			y = q.y
	return y


func _stairs() -> void:
	## şehrin kuzeyinden manastıra uzanan uzun taş merdiven (yürüyüş rampası + basamak görüntüsü + toriiler)
	var a := Vector3(w.data.stair[0][0], w.data.stair[0][1], w.data.stair[0][2])
	var b := Vector3(w.data.stair[1][0], w.data.stair[1][1], w.data.stair[1][2])
	a.y = 0.18
	var L := Vector2(b.x - a.x, b.z - a.z).length()
	var rise := b.y - a.y
	var nsteps := int(rise / 0.24)
	var tread := L / nsteps
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var yaw := atan2(dir.x, dir.z)
	var bas := Basis(Vector3.UP, yaw)
	var xfs := []
	for k in nsteps:
		var p := a + dir * (k + 0.5) * tread + Vector3(0, (k + 0.5) * rise / nsteps - 0.12, 0)
		xfs.append(Transform3D(bas, p))
	var bm := BoxMesh.new()
	bm.size = Vector3(6.0, 0.24 + 0.3, tread + 0.02)
	w._multi(bm, xfs, Game.pbr("concrete", Color(0.78, 0.74, 0.68), 0.35), 900.0)
	# yürünebilir rampa (merdiven boyunca parçalar)
	var seg_n := 12
	for s in seg_n:
		var p0 := a.lerp(b, float(s) / seg_n)
		var p1 := a.lerp(b, float(s + 1) / seg_n)
		var mid := (p0 + p1) * 0.5
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(6.0, 0.3, p0.distance_to(p1) + 0.4)
		cs.shape = bs
		sb.add_child(cs)
		w.add_child(sb)
		sb.look_at_from_position(mid - Vector3(0, 0.15, 0), p1 - Vector3(0, 0.15, 0), Vector3.UP)
	# korkuluk duvarları, taş fenerler, kırmızı torii kapıları
	var stone := Game.pbr("concrete", Color(0.7, 0.66, 0.6), 0.3)
	var red := Game.paint(Color(0.8, 0.12, 0.08), 0.0, 0.5)
	var black := Game.paint(Color(0.08, 0.08, 0.08), 0.0, 0.6)
	var k := 0
	var d := 30.0
	while d < L - 10.0:
		var p := a + dir * d + Vector3(0, rise * d / L, 0)
		for sd in [-1.0, 1.0]:
			var lp: Vector3 = p + bas.x * sd * 3.6
			w._box(lp + Vector3(0, 0.6, 0), Vector3(0.7, 1.2, 0.7), stone)
			w._neon(lp + Vector3(0, 1.45, 0), Vector3(0.45, 0.5, 0.45), Color(1.0, 0.6, 0.25), Vector3.ZERO, "far_stairs")
		if k % 3 == 0:
			for sd in [-1.0, 1.0]:
				w._box(p + bas.x * sd * 3.8 + Vector3(0, 3.5, 0), Vector3(0.6, 7.0, 0.6), red)
			var beam := w._box(p + Vector3(0, 7.2, 0), Vector3(10.0, 0.6, 0.8), black, false)
			beam.rotation.y = yaw
			var beam2 := w._box(p + Vector3(0, 6.2, 0), Vector3(8.6, 0.4, 0.5), red, false)
			beam2.rotation.y = yaw
		k += 1
		d += 45.0
	w._board(a + Vector3(7.5, 3.0, 4.0), 0.0, 7.0, 1.4, "KASIRGA MANASTIRI", Color(1.0, 0.8, 0.4))
	for sd in [-1.0, 1.0]:
		w._box(a + Vector3(7.5 + sd * 3.2, 1.2, 4.0), Vector3(0.25, 2.4, 0.25), Game.paint(Color(0.3, 0.2, 0.15), 0.0, 0.7))


# ---------------------------------------------------------------- Kasırga Manastırı
func monastery() -> void:
	var c := w.MON
	var stone := Game.pbr("concrete", Color(0.78, 0.75, 0.7), 0.3)
	var wood := Game.paint(Color(0.6, 0.16, 0.1), 0.0, 0.7)
	var dark := Game.paint(Color(0.12, 0.08, 0.07), 0.0, 0.7)
	var tile := Color(0.12, 0.3, 0.28)
	var wall_m := Game.paint(Color(0.95, 0.9, 0.8), 0.0, 0.8)
	w._box(c + Vector3(0, -0.6, 0), Vector3(112, 1.2, 112), stone)
	# dış duvar (güneyde kapı boşluğu) + duvar üstü kiremit
	for spec in [[Vector3(0, 2.0, -55), Vector3(112, 4, 1.6)], [Vector3(-55, 2.0, 0), Vector3(1.6, 4, 112)], [Vector3(55, 2.0, 0), Vector3(1.6, 4, 112)],
			[Vector3(-33, 2.0, 55), Vector3(44, 4, 1.6)], [Vector3(33, 2.0, 55), Vector3(44, 4, 1.6)]]:
		w._box(c + spec[0], spec[1], wall_m)
		w._box(c + spec[0] + Vector3(0, 2.25, 0), Vector3(spec[1].x + 0.8, 0.5, spec[1].z + 0.8), Game.paint(tile, 0.1, 0.5), false)
	# kapı yapısı (iki katlı çatı, tabela kapı kirişinde)
	var g := c + Vector3(0, 0, 55)
	for s in [-1.0, 1.0]:
		w._box(g + Vector3(s * 6.0, 3.5, 0), Vector3(1.2, 7.0, 1.2), wood)
		w._box(g + Vector3(s * 6.0, 0.4, 0), Vector3(1.6, 0.8, 1.6), stone)
	w._box(g + Vector3(0, 7.4, 0), Vector3(15.0, 0.9, 3.0), wood, false)
	w.city.pagoda_roofs(g + Vector3(0, 7.85, 0), Vector3(14.0, 0, 4.0), tile, 2)
	w._board(g + Vector3(0, 6.1, 1.0), 0.0, 9.0, 1.4, "KASIRGA MANASTIRI", Color(1.0, 0.82, 0.35), Color(0.1, 0.05, 0.03))
	# kapıdaki ejderha heykelleri
	for s in [-1.0, 1.0]:
		var ds := g + Vector3(s * 10.0, 0, 4.0)
		w._box(ds + Vector3(0, 1.0, 0), Vector3(3.0, 2.0, 3.0), stone)
		var body := Game.paint(Color(0.2, 0.55, 0.3), 0.6, 0.35)
		w._box(ds + Vector3(0, 3.2, 0), Vector3(1.4, 2.4, 2.2), body, false)
		w._box(ds + Vector3(0, 4.8, 0.8), Vector3(1.2, 1.0, 1.8), body, false)
		w._box(ds + Vector3(0, 5.6, 1.3), Vector3(0.3, 0.8, 0.3), Game.paint(Color(0.95, 0.75, 0.25), 0.9, 0.3), false)
	# ana salon: yüksek taban, kırmızı sütunlar, üç katlı pagoda çatı
	var hall := c + Vector3(0, 0, -24)
	w._box(hall + Vector3(0, 0.8, 0), Vector3(38, 1.6, 26), stone)
	w._box(hall + Vector3(0, 0.8, 14.5), Vector3(14, 1.6, 3.0), stone)
	w._box(hall + Vector3(0, 5.6, 0), Vector3(28, 8.0, 18), wall_m)
	for k in range(8):
		var x := -13.0 + k * 26.0 / 7.0
		w._box(hall + Vector3(x, 5.6, 9.6), Vector3(0.9, 8.0, 0.9), wood)
	w._box(hall + Vector3(0, 3.6, 9.05), Vector3(5.0, 4.4, 0.1), dark, false)
	w.city.pagoda_roofs(hall + Vector3(0, 9.6, 0), Vector3(28, 0, 18), tile, 3)
	w._door("manastir", "Kasırga Manastırı", "manastir", hall + Vector3(0, 1.6, 12.0), 0.0)
	# çan kulesi ve yatakhaneler
	var bell := c + Vector3(-38, 0, -34)
	w._box(bell + Vector3(0, 5.0, 0), Vector3(6, 10, 6), wall_m)
	w.city.pagoda_roofs(bell + Vector3(0, 10.0, 0), Vector3(6, 0, 6), tile, 2)
	for s in [-1.0, 1.0]:
		var dorm := c + Vector3(s * 40.0, 0, 8.0)
		w._box(dorm + Vector3(0, 2.6, 0), Vector3(12, 5.2, 26), wall_m)
		w.city.pagoda_roofs(dorm + Vector3(0, 5.2, 0), Vector3(12, 0, 26), tile, 1)
	# idman alanı: direkler, dönen kuklalar, denge kirişi, kum torbaları
	var train_c := c + Vector3(0, 0, 22)
	var dw := Game.paint(Color(0.5, 0.36, 0.22), 0.0, 0.9)
	for k in range(10):
		var p := train_c + Vector3(-18 + (k % 5) * 9.0, 0, -6 + (k / 5) * 9.0)
		var hh := rng.randf_range(1.0, 3.0)
		w._box(p + Vector3(0, hh * 0.5, 0), Vector3(0.6, hh, 0.6), dw)
	for k in range(4):
		var p := train_c + Vector3(-12 + k * 8.0, 0, 12.0)
		w._box(p + Vector3(0, 1.2, 0), Vector3(0.5, 2.4, 0.5), dw)
		var arm := w._box(p + Vector3(0, 1.8, 0), Vector3(2.4, 0.25, 0.25), dw, false)
		arm.rotation.y = k * 0.7
	w._box(train_c + Vector3(16, 1.0, 6), Vector3(0.4, 0.3, 14.0), dw)
	for s in [-1.0, 1.0]:
		w._box(train_c + Vector3(16, 0.45, 6 + s * 6.5), Vector3(0.3, 0.9, 0.3), dw)
	# gong
	var gong := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 1.6
	gm.bottom_radius = 1.6
	gm.height = 0.2
	gong.mesh = gm
	gong.rotation.x = PI * 0.5
	gong.position = c + Vector3(20, 3.4, -2)
	gong.material_override = Game.paint(Color(0.85, 0.6, 0.2), 1.0, 0.25)
	w.add_child(gong)
	for s in [-1.0, 1.0]:
		w._box(c + Vector3(20 + s * 2.2, 2.5, -2), Vector3(0.4, 5.0, 0.4), wood)
	w._box(c + Vector3(20, 5.1, -2), Vector3(4.8, 0.4, 0.4), wood, false)
	# taş fenerler
	for s in [-1.0, 1.0]:
		for q in range(3):
			var p := c + Vector3(s * 12.0, 0, 44.0 - q * 14.0)
			w._box(p + Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.9), stone)
			w._neon(p + Vector3(0, 2.0, 0), Vector3(0.7, 0.5, 0.7), Color(1.0, 0.6, 0.25), Vector3.ZERO, "far_mon")
	# kiraz ağaçları avluda
	var sak := []
	for k in range(10):
		var a := k * TAU / 10.0
		sak.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * rng.randf_range(0.9, 1.2)), c + Vector3(cos(a) * 44.0, 0, sin(a) * 44.0)))
	w._multi(_tree_mesh("sakura"), sak)


# ---------------------------------------------------------------- simge yerler
func _y(x: float, z: float) -> float:
	return w.terrain_h(x, z)


func landmarks() -> void:
	var stone := Game.pbr("concrete", Color(0.85, 0.72, 0.52), 0.3)
	var carved := Game.pbr("concrete", Color(0.7, 0.62, 0.52), 0.25)
	# Kum Altı Harabeleri: yarı gömülü sütunlar ve yılan başlı kemer
	var hr := Vector3(1180, 0, 760)
	hr.y = _y(hr.x, hr.z)
	for k in range(12):
		var a := k * TAU / 12.0
		var p := hr + Vector3(cos(a) * 24.0, 0, sin(a) * 24.0)
		p.y = _y(p.x, p.z) - 1.0
		var hgt := rng.randf_range(3.0, 9.0)
		var col := w._box(p + Vector3(0, hgt * 0.5, 0), Vector3(2.0, hgt, 2.0), stone)
		col.rotation = Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var snake := Game.paint(Color(0.3, 0.55, 0.35), 0.4, 0.5)
	w._box(hr + Vector3(0, 7.0, -30), Vector3(4.0, 14.0, 4.0), stone)
	w._box(hr + Vector3(0, 7.0, -14), Vector3(4.0, 14.0, 4.0), stone)
	w._box(hr + Vector3(0, 15.0, -22), Vector3(5.0, 3.0, 22.0), snake)
	w._box(hr + Vector3(0, 15.5, -9), Vector3(6.0, 4.0, 6.0), snake)
	for s in [-1.0, 1.0]:
		w._neon(hr + Vector3(s * 1.6, 16.6, -6.0), Vector3(0.6, 0.6, 0.2), Color(1.0, 0.85, 0.1), Vector3.ZERO, "far_ruins")
	# Atalar Geçidi: yolun iki yanında dev taş savaşçı heykelleri
	var pl: Array = w.data["pass"]
	for k in range(6):
		var u := float(k) / 5.0
		var a: Array = pl[0]
		var b: Array = pl[pl.size() - 1]
		var p := Vector3(lerpf(a[0], b[0], u), 0, lerpf(a[1], b[1], u))
		for sd in [-1.0, 1.0]:
			var q := p + Vector3(0, 0, sd * 34.0)
			q.y = _y(q.x, q.z)
			_statue(q, carved, -sd)
	_stilt_town(Vector3(2950, 0, 1950))
	_village(Vector3(1050, 0, 3300))
	_air_temple(Vector3(2160, 0, 1450))
	_volcano(Vector3(-1300, 0, 1250))
	_secure_island(Vector3(-1050, 0, -950))
	_cabin(Vector3(2700, 0, -260))
	_coves()
	_lighthouse(Vector3(2240, 0, -1480))


func _statue(p: Vector3, mat: Material, face: float) -> void:
	var hgt := 30.0
	w._box(p + Vector3(0, 2.0, 0), Vector3(10, 4, 10), mat)
	for s in [-1.0, 1.0]:
		w._box(p + Vector3(s * 2.0, 4.0 + 5.5, 0), Vector3(2.6, 11.0, 3.0), mat, false)
	w._box(p + Vector3(0, 4.0 + 11.0 + 5.5, 0), Vector3(8.0, 11.0, 4.0), mat, false)
	w._box(p + Vector3(0, 4.0 + 22.0 + 2.5, 0), Vector3(4.2, 5.0, 4.2), mat, false)
	w._box(p + Vector3(0, hgt + 1.8, 0), Vector3(7.0, 1.0, 5.0), mat, false)
	for s in [-1.0, 1.0]:
		var arm := w._box(p + Vector3(s * 5.0, 4.0 + 16.0, face * 1.5), Vector3(2.2, 9.0, 2.2), mat, false)
		arm.rotation.x = -face * 0.5
	var sword := w._box(p + Vector3(0, 4.0 + 12.0, face * 4.6), Vector3(1.0, 22.0, 0.4), Game.paint(Color(0.55, 0.55, 0.6), 0.8, 0.3), false)
	sword.rotation.x = face * 0.06
	w._neon(p + Vector3(0, 4.0 + 23.5, face * 2.15), Vector3(2.6, 0.3, 0.1), Color(0.4, 0.9, 1.0), Vector3.ZERO, "far_pass")


func _stilt_town(c: Vector3) -> void:
	## Sis Kasabası: suyun üstünde kazıklara oturmuş ahşap evler, iskele yolları, fenerler
	var deck_y := 3.0
	var wood := Game.paint(Color(0.42, 0.3, 0.2), 0.0, 0.85)
	var dark := Game.paint(Color(0.25, 0.18, 0.12), 0.0, 0.9)
	var walls := [Color(0.55, 0.42, 0.3), Color(0.48, 0.35, 0.26), Color(0.62, 0.5, 0.36)]
	var houses := []
	for k in range(22):
		var a := rng.randf() * TAU
		var r := rng.randf_range(20.0, 150.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r * 0.8)
		var ok := true
		for q in houses:
			if (q as Vector3).distance_to(p) < 16.0:
				ok = false
		if not ok:
			continue
		houses.append(p)
	for hp in houses:
		var p: Vector3 = hp
		var g := _y(p.x, p.z)
		var base_y := maxf(g, w.SEA) + deck_y
		var sz := Vector3(rng.randf_range(7, 11), 0, rng.randf_range(7, 10))
		w._box(Vector3(p.x, base_y - 0.2, p.z), Vector3(sz.x + 4, 0.4, sz.z + 4), wood)
		for sx in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				var ph := base_y - minf(g, w.SEA) + 4.0
				w._box(Vector3(p.x + sx * (sz.x * 0.5 + 1.5), base_y - ph * 0.5, p.z + sz2 * (sz.z * 0.5 + 1.5)), Vector3(0.5, ph, 0.5), dark, false)
		var hh := rng.randf_range(4.0, 7.0)
		w._box(Vector3(p.x, base_y + hh * 0.5, p.z), Vector3(sz.x, hh, sz.z), Game.paint(walls[rng.randi_range(0, 2)], 0.0, 0.85))
		w.city.pagoda_roofs(Vector3(p.x, base_y + hh, p.z), sz, Color(0.25, 0.22, 0.2), 1)
		# evden merkeze iskele yolu
		var to_c: Vector3 = c - p
		to_c.y = 0
		var L := to_c.length()
		if L > 8.0:
			var mid := p + to_c * 0.5
			var walk := w._box(Vector3(mid.x, base_y - 0.2, mid.z), Vector3(2.4, 0.3, L), wood)
			walk.rotation.y = atan2(to_c.x, to_c.z)
			w._collider(Vector3(mid.x, base_y - 0.2, mid.z), Vector3(2.4, 0.3, L), 1, Vector3(0, atan2(to_c.x, to_c.z), 0))
		w._neon(Vector3(p.x + sz.x * 0.5 + 0.4, base_y + 2.5, p.z), Vector3(0.5, 0.7, 0.5), Color(1.0, 0.5, 0.2), Vector3.ZERO, "far_stiix")
	# meydan platformu ve yol bağlantısı
	var cy := maxf(_y(c.x, c.z), w.SEA) + deck_y
	w._box(Vector3(c.x, cy - 0.25, c.z), Vector3(40, 0.5, 40), wood)
	w._board(Vector3(c.x, cy + 5.5, c.z - 20.0), PI, 12.0, 2.0, "SİS KASABASI", Color(0.6, 0.9, 1.0))
	for s in [-1.0, 1.0]:
		w._box(Vector3(c.x + s * 5.0, cy + 2.6, c.z - 20.0), Vector3(0.4, 5.2, 0.4), dark)


func _village(c: Vector3) -> void:
	var walls := [Color(0.95, 0.9, 0.8), Color(0.9, 0.82, 0.7)]
	for k in range(14):
		var a := rng.randf() * TAU
		var r := rng.randf_range(15.0, 110.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = _y(p.x, p.z)
		var sz := Vector3(rng.randf_range(7, 10), 0, rng.randf_range(6, 9))
		w._box(p + Vector3(0, 0.4, 0), Vector3(sz.x + 1.5, 0.8, sz.z + 1.5), Game.pbr("concrete", Color(0.7, 0.68, 0.62), 0.3))
		w._box(p + Vector3(0, 0.8 + 2.0, 0), Vector3(sz.x, 4.0, sz.z), Game.paint(walls[k % 2], 0.0, 0.85))
		w.city.pagoda_roofs(p + Vector3(0, 4.8, 0), sz, Color(0.18, 0.2, 0.24), 1)
		w._neon(p + Vector3(sz.x * 0.5 + 0.5, 3.0, 0), Vector3(0.5, 0.7, 0.5), Color(1.0, 0.35, 0.15), Vector3.ZERO, "far_village")
	# çay bahçesi: teraslarda yeşil sıralar
	var tea_c := Vector3(880, 0, 3180)
	var rows := []
	for r in range(14):
		for q in range(10):
			var p := tea_c + Vector3(-60 + q * 12.0, 0, -45 + r * 6.5)
			p.y = _y(p.x, p.z) + 0.5
			rows.append(Transform3D(Basis(), p))
	var hedge := BoxMesh.new()
	hedge.size = Vector3(11.0, 1.1, 1.6)
	w._multi(hedge, rows, Game.paint(Color(0.2, 0.42, 0.15), 0.0, 0.9), 700.0)
	var sign_p := tea_c + Vector3(-70, 0, -55)
	sign_p.y = _y(sign_p.x, sign_p.z)
	for s in [-1.0, 1.0]:
		w._box(sign_p + Vector3(s * 3.0, 1.5, 0), Vector3(0.25, 3.0, 0.25), Game.paint(Color(0.35, 0.22, 0.14), 0.0, 0.8))
	w._board(sign_p + Vector3(0, 3.4, 0), 0.0, 7.5, 1.2, "BİLGE ÇAY BAHÇESİ", Color(0.6, 1.0, 0.5), Color(0.2, 0.12, 0.06))


func _air_temple(c: Vector3) -> void:
	## Hava Tapınağı: sıradağların tepesinde, dört katlı pagoda; çevresinde süzülen kayalar
	var best := c
	var bh := -1e9
	for k in range(60):
		var p := c + Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-120, 120))
		var h := _y(p.x, p.z)
		if h > bh:
			bh = h
			best = p
	best.y = bh
	var stone := Game.pbr("concrete", Color(0.8, 0.78, 0.74), 0.3)
	w._box(best + Vector3(0, 1.0, 0), Vector3(30, 4.0, 30), stone)
	var walls := Game.paint(Color(0.95, 0.92, 0.85), 0.0, 0.8)
	var y := 3.0
	var sz := Vector3(16, 0, 16)
	for t in range(4):
		w._box(best + Vector3(0, y + 2.0, 0), Vector3(sz.x, 4.0, sz.z), walls)
		w.city.pagoda_roofs(best + Vector3(0, y + 4.0, 0), sz, Color(0.15, 0.4, 0.6), 1)
		y += 7.0
		sz *= 0.78
	for k in range(7):
		var a := k * TAU / 7.0
		var p := best + Vector3(cos(a) * 34.0, 10.0 + (k % 3) * 6.0, sin(a) * 34.0)
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(2.5, 4.5)
		sm.height = sm.radius * 1.4
		sm.radial_segments = 8
		sm.rings = 5
		rock.mesh = sm
		rock.material_override = stone
		rock.position = p
		w.add_child(rock)
	for p in w.pois:
		if p.id == "hava":
			p.pos = best


func _volcano(c: Vector3) -> void:
	var best := c
	var bh := -1e9
	for k in range(40):
		var p := c + Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		var h := _y(p.x, p.z)
		if h > bh:
			bh = h
			best = p
	var lava := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 26.0
	cm.bottom_radius = 26.0
	cm.height = 0.5
	cm.radial_segments = 24
	lava.mesh = cm
	lava.material_override = Game.emissive(Color(1.0, 0.35, 0.05), 6.0)
	lava.position = Vector3(c.x, bh - 14.0, c.z)
	w.add_child(lava)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.4, 0.1)
	l.light_energy = 8.0
	l.omni_range = 90.0
	l.position = lava.position + Vector3(0, 10, 0)
	w.add_child(l)


func _secure_island(c: Vector3) -> void:
	c.y = maxf(_y(c.x, c.z), 1.0)
	var wall := Game.pbr("concrete", Color(0.6, 0.62, 0.66), 0.3)
	w._box(c + Vector3(0, 0.1, 0), Vector3(150, 0.6, 150), Game.pbr("concrete", Color(0.5, 0.52, 0.55), 0.2))
	for spec in [[Vector3(0, 4, -60), Vector3(120, 8, 2)], [Vector3(-60, 4, 0), Vector3(2, 8, 120)], [Vector3(0, 4, 60), Vector3(120, 8, 2)],
			[Vector3(60, 4, -36), Vector3(2, 8, 48)], [Vector3(60, 4, 36), Vector3(2, 8, 48)]]:
		w._box(c + spec[0], spec[1], wall)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tp := c + Vector3(sx * 60, 0, sz * 60)
			w._box(tp + Vector3(0, 8, 0), Vector3(5, 16, 5), wall)
			w._neon(tp + Vector3(0, 16.5, 0), Vector3(5.4, 0.3, 5.4), Color(1.0, 0.1, 0.15), Vector3.ZERO, "far_isle")
	var core := w.city._facade_mat("tekno", true)
	w._box(c + Vector3(-10, 14, 0), Vector3(40, 28, 30), core)
	w._neon(c + Vector3(-10, 28.5, 0), Vector3(41, 0.4, 31), Color(1.0, 0.15, 0.75), Vector3.ZERO, "far_isle")
	w._board(c + Vector3(61.5, 10, 0), PI * 0.5, 16.0, 2.4, "GÜVENLİKLİ ADA", Color(1.0, 0.25, 0.3))


func _cabin(c: Vector3) -> void:
	c.y = _y(c.x, c.z)
	var logs := Game.paint(Color(0.45, 0.3, 0.18), 0.0, 0.9)
	w._box(c + Vector3(0, 2.2, 0), Vector3(9, 4.4, 7), logs)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(10.4, 3.4, 8.4)
	roof.mesh = pm
	roof.position = c + Vector3(0, 6.1, 0)
	roof.material_override = Game.paint(Color(0.92, 0.94, 0.98), 0.0, 0.6)
	w.add_child(roof)
	w._box(c + Vector3(3, 6.0, 0), Vector3(0.9, 3.0, 0.9), Game.paint(Color(0.4, 0.4, 0.42), 0.0, 0.8), false)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 2.0
	l.omni_range = 12.0
	l.position = c + Vector3(0, 2.5, 4.5)
	w.add_child(l)


func _coves() -> void:
	var rock := Game.pbr("concrete", Color(0.55, 0.52, 0.48), 0.2)
	for k in range(14):
		var p := Vector3(rng.randf_range(1100, 1900), 0, rng.randf_range(4560, 4680))
		var g := _y(p.x, p.z)
		if g > w.SEA - 0.5:
			continue
		var hgt := rng.randf_range(18, 46)
		var s := w._box(Vector3(p.x, g + hgt * 0.5, p.z), Vector3(rng.randf_range(6, 12), hgt - g, rng.randf_range(6, 12)), rock)
		s.rotation.y = rng.randf() * TAU


func _lighthouse(c: Vector3) -> void:
	var best := c
	var bh := -1e9
	for k in range(40):
		var p := c + Vector3(rng.randf_range(-150, 150), 0, rng.randf_range(-150, 150))
		var h := _y(p.x, p.z)
		if h > bh and h < 60.0:
			bh = h
			best = p
	best.y = bh
	var white := Game.paint(Color(0.96, 0.96, 0.96), 0.0, 0.5)
	var red := Game.paint(Color(0.85, 0.12, 0.1), 0.0, 0.5)
	for k in range(5):
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 3.2 - k * 0.35
		cm.bottom_radius = 3.5 - k * 0.35
		cm.height = 5.0
		seg.mesh = cm
		seg.material_override = white if k % 2 == 0 else red
		seg.position = best + Vector3(0, 2.5 + k * 5.0, 0)
		w.add_child(seg)
	w._cyl_collider(best, 3.4, 25.0)
	w._neon(best + Vector3(0, 26.5, 0), Vector3(2.0, 2.0, 2.0), Color(1.0, 0.95, 0.7), Vector3.ZERO, "far_light")
	var sp := SpotLight3D.new()
	sp.light_energy = 12.0
	sp.spot_range = 300.0
	sp.spot_angle = 10.0
	sp.position = best + Vector3(0, 26.5, 0)
	sp.set_meta("lighthouse", true)
	w.add_child(sp)
	w._poi("fener", "Kuzey Feneri", "lighthouse", best)


# ---------------------------------------------------------------- ağaçlar ve kayalar
func _tree_mesh(kind: String) -> ArrayMesh:
	var trunk := Game.paint(Color(0.35, 0.25, 0.18), 0.0, 0.9)
	var tr := CylinderMesh.new()
	tr.top_radius = 0.18
	tr.bottom_radius = 0.28
	tr.height = 3.0
	tr.radial_segments = 6
	match kind:
		"cam":
			var parts := [[tr, Transform3D(Basis(), Vector3(0, 1.5, 0)), trunk]]
			var leaf := Game.paint(Color(0.14, 0.32, 0.17), 0.0, 0.85)
			for k in range(3):
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 2.4 - k * 0.6
				cone.height = 3.2
				cone.radial_segments = 8
				parts.append([cone, Transform3D(Basis(), Vector3(0, 3.2 + k * 1.8, 0)), leaf])
			return w._merged(parts)
		"hus":
			var bark := Game.paint(Color(0.92, 0.9, 0.86), 0.0, 0.8)
			var t2 := CylinderMesh.new()
			t2.top_radius = 0.12
			t2.bottom_radius = 0.2
			t2.height = 6.0
			t2.radial_segments = 6
			var crown := SphereMesh.new()
			crown.radius = 1.9
			crown.height = 5.0
			crown.radial_segments = 8
			crown.rings = 5
			return w._merged([[t2, Transform3D(Basis(), Vector3(0, 3.0, 0)), bark], [crown, Transform3D(Basis(), Vector3(0, 6.2, 0)), Game.paint(Color(0.85, 0.88, 0.8), 0.0, 0.85)]])
		"palmiye":
			return w.city._palm_mesh()
		"kaktus":
			var cac := Game.paint(Color(0.3, 0.5, 0.25), 0.0, 0.8)
			var body := CapsuleMesh.new()
			body.radius = 0.45
			body.height = 5.0
			var arm := CapsuleMesh.new()
			arm.radius = 0.32
			arm.height = 2.2
			return w._merged([[body, Transform3D(Basis(), Vector3(0, 2.5, 0)), cac], [arm, Transform3D(Basis(), Vector3(0.9, 3.0, 0)), cac], [arm, Transform3D(Basis(), Vector3(-0.85, 2.5, 0)), cac]])
		"kuru":
			var dead := Game.paint(Color(0.4, 0.33, 0.26), 0.0, 0.95)
			var br := CylinderMesh.new()
			br.top_radius = 0.04
			br.bottom_radius = 0.12
			br.height = 2.4
			br.radial_segments = 5
			return w._merged([[tr, Transform3D(Basis(), Vector3(0, 1.5, 0)), dead], [br, Transform3D(Basis(Vector3(0, 0, 1), 0.7), Vector3(0.6, 3.4, 0)), dead],
				[br, Transform3D(Basis(Vector3(0, 0, 1), -0.6), Vector3(-0.5, 3.0, 0)), dead], [br, Transform3D(Basis(Vector3(1, 0, 0), 0.6), Vector3(0, 3.6, 0.5)), dead]])
		"sakura":
			var pink := Game.paint(Color(1.0, 0.68, 0.82), 0.0, 0.8)
			var parts := [[tr, Transform3D(Basis(), Vector3(0, 1.5, 0)), Game.paint(Color(0.3, 0.2, 0.18), 0.0, 0.9)]]
			for p in [Vector3(0, 4.2, 0), Vector3(1.2, 3.8, 0.4), Vector3(-1.1, 3.9, -0.3), Vector3(0.2, 4.0, 1.2), Vector3(-0.2, 3.7, -1.2)]:
				var s := SphereMesh.new()
				s.radius = 1.5
				s.height = 2.6
				s.radial_segments = 8
				s.rings = 5
				parts.append([s, Transform3D(Basis(), p), pink])
			return w._merged(parts)
		_:
			var crown := SphereMesh.new()
			crown.radius = 2.6
			crown.height = 4.4
			crown.radial_segments = 10
			crown.rings = 6
			return w._merged([[tr, Transform3D(Basis(), Vector3(0, 1.5, 0)), trunk], [crown, Transform3D(Basis(), Vector3(0, 4.6, 0)), Game.paint(Color(0.25, 0.45, 0.2), 0.0, 0.85)]])


func trees() -> void:
	var td: Dictionary = w.data.trees
	for kind in td.keys():
		var flat: Array = td[kind]
		if flat.is_empty():
			continue
		var mesh := _tree_mesh(kind)
		var chunks := {}
		var i := 0
		while i + 3 < flat.size():
			var x: float = flat[i]
			var y: float = flat[i + 1]
			var z: float = flat[i + 2]
			var s: float = flat[i + 3]
			i += 4
			var key := "%d_%d" % [int(floor(x / 500.0)), int(floor(z / 500.0))]
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(Transform3D(Basis(Vector3.UP, fmod(x * 13.1 + z * 7.7, TAU)).scaled(Vector3.ONE * s), Vector3(x, y, z)))
			if kind != "kaktus":
				w._cyl_collider(Vector3(x, y, z), 0.3 * s, 4.0)
		for key in chunks.keys():
			var mmi := w._multi(mesh, chunks[key], null, 900.0 if kind == "cam" else 700.0)
			mmi.visibility_range_end_margin = 60.0
	# kayalar
	var rf: Array = w.data.rocks
	var xfs := []
	var cols := []
	var i := 0
	while i + 3 < rf.size():
		var p := Vector3(rf[i], rf[i + 1], rf[i + 2])
		var s: float = rf[i + 3]
		i += 4
		var bas := Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)).scaled(Vector3(s * rng.randf_range(0.9, 1.6), s * rng.randf_range(0.6, 1.1), s * rng.randf_range(0.9, 1.5)))
		xfs.append(Transform3D(bas, p))
		var reg := w.region_id(p)
		cols.append(Color(0.68, 0.38, 0.24) if reg == 7 else (Color(0.85, 0.68, 0.36) if reg in [4, 6] else Color(0.52, 0.5, 0.47)))
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = s * 0.9
		cs.shape = sh
		cs.position = p
		w.props.add_child(cs)
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 1.6
	rock.radial_segments = 7
	rock.rings = 4
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.roughness = 0.95
	w._multi(rock, xfs, rm, 800.0, cols)
