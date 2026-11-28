extends Node3D
class_name Vortex
## Kasırga (spinjitzu) görseli — Element Arenası'ndaki kurulumun birebir uyarlaması:
## "Spinjitzu (green)" modeli (AAV's 3D Models, CC BY 4.0) gri tonlu doku × element rengi,
## düz parlak katmanlar toplamalı karışımla; içte piksel dokulu kutu katmanları (dolgu + çekirdek),
## üç yay halka ve yerde parlayan halka. Model 4,4 × 4,6 birime ölçeklenir, grup 0,55 ölçekli.

var c1 := Color(1.0, 0.5, 0.12)
var c2 := Color(0.85, 0.9, 1.0)
var parts: Array = []        # [düğüm, hız, halka mı]
var _t := 0.0
var grow := 0.0
var size := 1.0

static var _px: ImageTexture


static func _pixel_tex() -> ImageTexture:
	if _px:
		return _px
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for x in 16:
		for y in 16:
			var v := 0.55 + rng.randf() * 0.45
			img.set_pixel(x, y, Color(v, v, v))
	_px = ImageTexture.create_from_image(img)
	return _px


static func _gray(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var lo := 1.0
	var hi := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.04:
				var l := 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
				lo = minf(lo, l)
				hi = maxf(hi, l)
	var k := 1.0 / (hi - lo) if hi > lo else 1.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
			var v := 0.35 + 0.65 * clampf((l - lo) * k, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, c.a))
	return ImageTexture.create_from_image(img)


func _mat(col: Color, tex: Texture2D, opacity: float, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col, opacity)
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _ready() -> void:
	var g := Node3D.new()
	g.name = "g"
	add_child(g)
	var ps: PackedScene = load("res://assets/fx/spinjitzu.glb") if ResourceLoader.exists("res://assets/fx/spinjitzu.glb") else null
	if ps:
		var holder := Node3D.new()
		g.add_child(holder)
		var inst: Node3D = ps.instantiate()
		holder.add_child(inst)
		# animasyon dinlenme pozunda sınırlar
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		var meshes := inst.find_children("*", "MeshInstance3D", true, false)
		for mi in meshes:
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var xf := Transform3D()
			var nd: Node = m
			while nd != null and nd != holder:
				xf = (nd as Node3D).transform * xf
				nd = nd.get_parent()
			var ab := xf * m.get_aabb()
			lo = lo.min(ab.position)
			hi = hi.max(ab.end)
		var sz := hi - lo
		if sz.y > 0.0:
			var kx := 4.4 / maxf(sz.x, sz.z)
			var ky := 4.6 / sz.y
			holder.scale = Vector3(kx, ky, kx)
			holder.position = Vector3(-(lo.x + hi.x) * 0.5 * kx, -lo.y * ky, -(lo.z + hi.z) * 0.5 * kx)
		for mi in meshes:
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var src := m.mesh.surface_get_material(0) as BaseMaterial3D
			var ab := m.get_aabb()
			var glow := ab.size.y < 0.01
			m.material_override = _mat(c2 if glow else c1, _gray(src.albedo_texture if src else null), 0.95 if glow else 0.82, glow)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		if aps.size() > 0:
			var ap := aps[0] as AnimationPlayer
			var names := ap.get_animation_list()
			if names.size() > 0:
				ap.get_animation(names[0]).loop_mode = Animation.LOOP_LINEAR
				ap.speed_scale = 2.2
				ap.play(names[0])
		parts.append([holder, 9.0, false])
	# iç dolgu ve çekirdek: piksel dokulu, yukarı doğru genişleyen kutu katmanları
	var fm := _mat(c1, _pixel_tex(), 0.78, false)
	var fill := Node3D.new()
	var cm := _mat(c2, _pixel_tex(), 0.7, true)
	var core := Node3D.new()
	for i in 9:
		var t := i / 8.0
		var w := 0.5 + t * 2.6
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, 0.5, w)
		b.mesh = bm
		b.material_override = fm
		b.position.y = 0.25 + i * 0.5
		b.rotation.y = i * 0.4
		fill.add_child(b)
		var w2 := 0.28 + t * 1.1
		var c := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(w2, 0.5, w2)
		c.mesh = cbm
		c.material_override = cm
		c.position.y = 0.25 + i * 0.5
		c.rotation.y = -i * 0.4
		core.add_child(c)
	g.add_child(fill)
	g.add_child(core)
	parts.append([fill, 7.0, false])
	parts.append([core, -11.0, false])
	# üç yay halka
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 2.4 + i * 0.45 - 0.03
		tm.outer_radius = 2.4 + i * 0.45 + 0.03
		tm.rings = 64
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = _mat(c1 if i % 2 else c2, null, 0.6, true)
		var piv := Node3D.new()
		piv.position.y = 0.6 + i * 1.1
		piv.add_child(ring)
		g.add_child(piv)
		parts.append([piv, -6.0 - i * 2.0, true])
	# yerde parlayan halka
	var gr := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 3.4
	gm.bottom_radius = 3.4
	gm.height = 0.02
	gr.mesh = gm
	var grm := _mat(c1, null, 0.45, true)
	gr.material_override = grm
	gr.position.y = 0.03
	g.add_child(gr)
	var l := OmniLight3D.new()
	l.light_color = c1
	l.light_energy = 3.0
	l.omni_range = 7.0
	l.position.y = 1.4
	add_child(l)
	scale = Vector3.ONE * 0.55 * 0.55


func _process(delta: float) -> void:
	_t += delta
	grow = minf(1.0, grow + delta * 5.0)
	scale = Vector3.ONE * 0.55 * (0.55 + 0.45 * grow) * size
	for i in parts.size():
		var p: Array = parts[i]
		var n := p[0] as Node3D
		var spd: float = p[1]
		if p[2]:
			n.rotation.y += spd * delta * (1.0 + 0.35 * sin(_t * 3.0 + i))
			n.rotation.x = sin(_t * 4.0 + i) * 0.28
		else:
			n.rotation.y += spd * delta * (1.0 + 0.35 * sin(_t * 3.0 + i))
			if i > 0:
				n.scale = Vector3(1.0 + sin(_t * 9.0 + i) * 0.08, 1.0 + sin(_t * 6.0 + i * 1.7) * 0.12, 1.0 + sin(_t * 9.0 + i) * 0.08)
