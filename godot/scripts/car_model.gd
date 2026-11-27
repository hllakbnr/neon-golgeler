extends RefCounted
class_name CarModel
## Araç görselleri: Kenney Car Kit (CC0) oyuncak tarzı modeller; inmezse prosedürel yedek.
## build() → {"ok": bool, "size": Vector3 (gövde boyutu), "wheels": [[konum, yarıçap, mesh düğümü]]}

const SCALE := 1.5
const DRIVABLE := ["sedan", "sedan-sports", "hatchback-sports", "taxi", "suv", "suv-luxury", "van", "police"]
const TRAFFIC := ["sedan", "sedan", "taxi", "suv", "van", "hatchback-sports", "suv-luxury", "delivery", "truck", "sedan-sports"]


static func build(parent: Node3D, model: String, color := Color(0.8, 0.1, 0.12)) -> Dictionary:
	var sc := Game.car_scene(model)
	if sc == null:
		return _fallback(parent, color)
	var inst: Node3D = sc.instantiate()
	inst.scale = Vector3.ONE * SCALE
	parent.add_child(inst)
	var wheels := []
	var body_box := AABB()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nm := String(m.name)
		if nm.begins_with("wheel"):
			var bb: AABB = m.mesh.get_aabb()
			var pos: Vector3 = m.position * SCALE
			wheels.append([pos, bb.size.y * 0.5 * SCALE, m])
		elif nm == "body":
			var bb2: AABB = m.mesh.get_aabb()
			body_box = AABB((m.position + bb2.position) * SCALE, bb2.size * SCALE)
		# boya: hafif vernik
		var am := m.get_active_material(0)
		if am is StandardMaterial3D:
			var nmat := (am as StandardMaterial3D).duplicate() as StandardMaterial3D
			nmat.roughness = 0.35
			nmat.metallic = 0.15
			nmat.metallic_specular = 0.6
			nmat.clearcoat_enabled = true
			nmat.clearcoat = 0.6
			nmat.clearcoat_roughness = 0.08
			m.material_override = nmat
	return {"ok": true, "size": body_box.size, "center": body_box.get_center(), "wheels": wheels, "node": inst}


static func _fallback(parent: Node3D, color: Color) -> Dictionary:
	var paint := Game.paint(color, 0.5, 0.3, 1.0)
	var glass := Game.paint(Color(0.05, 0.07, 0.09), 0.2, 0.05)
	_box(parent, Vector3(0, 0.72, 0), Vector3(1.86, 0.6, 4.2), paint)
	_box(parent, Vector3(0, 1.25, -0.25), Vector3(1.6, 0.55, 2.2), glass)
	var wheels := []
	for p in [[-0.82, 1.35], [0.82, 1.35], [-0.82, -1.35], [0.82, -1.35]]:
		wheels.append([Vector3(p[0], 0.4, p[1]), 0.4, null])
	return {"ok": false, "size": Vector3(1.9, 1.5, 4.2), "center": Vector3(0, 0.75, 0), "wheels": wheels, "node": null}


static func tire_mesh(r: float) -> MeshInstance3D:
	var tire := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.28
	cm.radial_segments = 18
	tire.mesh = cm
	tire.rotation.z = PI * 0.5
	tire.material_override = Game.paint(Color(0.05, 0.05, 0.055), 0.0, 0.85)
	return tire


static func _box(p: Node3D, pos: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	p.add_child(mi)


static func add_lights(parent: Node3D, info: Dictionary) -> Dictionary:
	## farlar (SpotLight + parlayan yüzey) ve stop lambaları
	var size: Vector3 = info.size
	var c: Vector3 = info.center
	var front := c.z + size.z * 0.5
	var back := c.z - size.z * 0.5
	var hy := c.y - size.y * 0.12
	var brake := StandardMaterial3D.new()
	brake.albedo_color = Color(0.5, 0.03, 0.03)
	brake.emission_enabled = true
	brake.emission = Color(1, 0.05, 0.03)
	brake.emission_energy_multiplier = 0.4
	var head := StandardMaterial3D.new()
	head.albedo_color = Color(0.95, 0.95, 0.9)
	head.emission_enabled = true
	head.emission = Color(1, 0.95, 0.85)
	head.emission_energy_multiplier = 0.0
	var spots: Array[SpotLight3D] = []
	for s in [-1, 1]:
		var tl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x * 0.18, 0.12, 0.04)
		tl.mesh = bm
		tl.material_override = brake
		tl.position = Vector3(s * size.x * 0.36, hy, back - 0.02)
		parent.add_child(tl)
		var hl := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(size.x * 0.16, 0.1, 0.04)
		hl.mesh = hm
		hl.material_override = head
		hl.position = Vector3(s * size.x * 0.34, hy, front + 0.02)
		parent.add_child(hl)
		var sl := SpotLight3D.new()
		sl.light_color = Color(1, 0.95, 0.85)
		sl.light_energy = 7.0
		sl.spot_range = 38.0
		sl.spot_angle = 30.0
		sl.spot_attenuation = 0.8
		sl.shadow_enabled = s > 0
		sl.position = Vector3(s * size.x * 0.34, hy, front + 0.1)
		sl.rotation = Vector3(-0.07, PI, 0)
		sl.visible = false
		sl.distance_fade_enabled = true
		sl.distance_fade_begin = 60.0
		sl.distance_fade_length = 20.0
		parent.add_child(sl)
		spots.append(sl)
	return {"brake": brake, "head": head, "spots": spots}
