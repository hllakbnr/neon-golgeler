extends RefCounted
class_name CarModel
## Prosedürel otomobil gövdesi (yuvarlatılmış hatlar, cam, jant, far) — model inmezse yedek.

static func build(parent: Node3D, color: Color) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.65
	paint.roughness = 0.28
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0
	paint.clearcoat_roughness = 0.04
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.09, 0.85)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.2
	glass.roughness = 0.02
	var trim := Game.paint(Color(0.05, 0.05, 0.06), 0.3, 0.5)
	var chrome := Game.paint(Color(0.9, 0.9, 0.92), 1.0, 0.12)
	_capsule(parent, Vector3(0, 0.72, 0), Vector3(1.86, 0.55, 4.4), paint)          # alt gövde
	_capsule(parent, Vector3(0, 1.18, -0.25), Vector3(1.6, 0.5, 2.3), glass)         # kabin camı
	_capsule(parent, Vector3(0, 1.43, -0.3), Vector3(1.5, 0.08, 1.7), paint)         # tavan
	_box(parent, Vector3(0, 0.55, 2.22), Vector3(1.7, 0.28, 0.1), trim)              # ön tampon
	_box(parent, Vector3(0, 0.55, -2.22), Vector3(1.7, 0.28, 0.1), trim)             # arka tampon
	_box(parent, Vector3(0, 0.78, 2.21), Vector3(0.7, 0.14, 0.04), chrome)           # ızgara
	for s in [-1, 1]:
		_box(parent, Vector3(s * 0.62, 0.85, 2.2), Vector3(0.42, 0.12, 0.06), Game.emissive(Color(1, 0.97, 0.9), 1.5))
		_box(parent, Vector3(s * 0.95, 1.05, 0.65), Vector3(0.18, 0.08, 0.12), trim)  # ayna


static func wheel(w: VehicleWheel3D) -> void:
	var tire := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.36
	cm.bottom_radius = 0.36
	cm.height = 0.26
	cm.radial_segments = 20
	tire.mesh = cm
	tire.rotation.z = PI * 0.5
	tire.material_override = Game.paint(Color(0.04, 0.04, 0.045), 0.0, 0.9)
	w.add_child(tire)
	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.22
	rm.bottom_radius = 0.22
	rm.height = 0.27
	rm.radial_segments = 12
	rim.mesh = rm
	rim.rotation.z = PI * 0.5
	rim.material_override = Game.paint(Color(0.75, 0.76, 0.78), 1.0, 0.25)
	w.add_child(rim)


static func _capsule(p: Node3D, pos: Vector3, size: Vector3, m: Material) -> void:
	# yuvarlatılmış kutu görünümü: kutu + yanlarda silindir kenar
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x - size.y * 0.5, size.y, size.z)
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	p.add_child(mi)
	for s in [-1, 1]:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = size.y * 0.5
		cm.bottom_radius = size.y * 0.5
		cm.height = size.z - size.y * 0.3
		cm.radial_segments = 14
		c.mesh = cm
		c.rotation.x = PI * 0.5
		c.position = pos + Vector3(s * (size.x * 0.5 - size.y * 0.25 - size.y * 0.25), 0, 0)
		c.material_override = m
		p.add_child(c)


static func _box(p: Node3D, pos: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	p.add_child(mi)
