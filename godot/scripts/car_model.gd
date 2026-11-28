extends RefCounted
class_name CarModel
## Araç görselleri: Kenney Car Kit (CC0) oyuncak tarzı modeller; inmezse prosedürel yedek.
## build() → {"ok": bool, "size": Vector3 (gövde boyutu), "wheels": [[konum, yarıçap, mesh düğümü]]}

const SCALE := 1.5
const DRIVABLE := ["sedan", "sedan-sports", "hatchback-sports", "taxi", "suv", "suv-luxury", "van", "police", "race", "race-future",
	"truck", "delivery", "ambulance", "garbage-truck", "firetruck", "truck-flat", "tractor"]
const TRAFFIC := ["sedan", "sedan", "sedan", "taxi", "taxi", "suv", "van", "hatchback-sports", "suv-luxury", "delivery", "delivery-flat",
	"truck", "truck-flat", "sedan-sports", "garbage-truck", "ambulance", "race"]
## araç sınıfları: kütle, motor gücü, azami hız, vites sayısı, motor sesi tonu
const SPECS := {
	"sedan": [1350.0, 6000.0, 50.0, 5, 1.0], "taxi": [1400.0, 6000.0, 48.0, 5, 1.0], "police": [1500.0, 8200.0, 60.0, 6, 0.95],
	"sedan-sports": [1300.0, 8400.0, 64.0, 6, 1.15], "hatchback-sports": [1150.0, 7200.0, 58.0, 6, 1.2],
	"race": [1050.0, 10500.0, 78.0, 6, 1.3], "race-future": [1000.0, 11500.0, 84.0, 6, 1.4],
	"suv": [1900.0, 7600.0, 50.0, 5, 0.85], "suv-luxury": [2000.0, 8400.0, 54.0, 6, 0.9], "van": [2100.0, 6800.0, 42.0, 5, 0.8],
	"delivery": [2600.0, 7400.0, 38.0, 5, 0.75], "truck": [3800.0, 9800.0, 34.0, 6, 0.65], "truck-flat": [3500.0, 9400.0, 34.0, 6, 0.65],
	"ambulance": [2700.0, 8200.0, 44.0, 5, 0.8], "garbage-truck": [5200.0, 11000.0, 28.0, 6, 0.6], "firetruck": [5600.0, 12000.0, 30.0, 6, 0.6],
	"tractor": [2400.0, 7000.0, 18.0, 4, 0.7]}
const PLAIN := ["sedan", "sedan-sports", "hatchback-sports", "suv", "suv-luxury", "van", "race", "race-future", "truck", "delivery", "truck-flat"]


static func spec(model: String) -> Array:
	return SPECS.get(model, SPECS.sedan)


static func random_paint() -> Color:
	var pal := [Color(0.75, 0.08, 0.1), Color(0.1, 0.2, 0.55), Color(0.92, 0.92, 0.94), Color(0.08, 0.08, 0.09), Color(0.55, 0.57, 0.6),
		Color(0.1, 0.4, 0.22), Color(0.95, 0.75, 0.1), Color(0.95, 0.4, 0.05), Color(0.45, 0.1, 0.4), Color(0.2, 0.6, 0.75), Color(0.6, 0.45, 0.3)]
	return pal[randi() % pal.size()]


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


static func add_lights(parent: Node3D, info: Dictionary, shadows := false) -> Dictionary:
	## farlar (yalnızca ışık; Kenney modelinde far zaten boyalı) ve gövdeye gömülü stop lambaları
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
	var spots: Array[SpotLight3D] = []
	for s in [-1, 1]:
		var tl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x * 0.16, 0.1, 0.06)
		tl.mesh = bm
		tl.material_override = brake
		tl.position = Vector3(s * size.x * 0.34, hy, back + 0.02)
		tl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(tl)
		var sl := SpotLight3D.new()
		sl.light_color = Color(1, 0.95, 0.85)
		sl.light_energy = 7.0
		sl.spot_range = 38.0
		sl.spot_angle = 30.0
		sl.spot_attenuation = 0.8
		sl.shadow_enabled = shadows and s > 0
		sl.position = Vector3(s * size.x * 0.34, hy, front - 0.3)
		sl.rotation = Vector3(-0.07, PI, 0)
		sl.visible = false
		sl.distance_fade_enabled = true
		sl.distance_fade_begin = 50.0
		sl.distance_fade_length = 15.0
		parent.add_child(sl)
		spots.append(sl)
	return {"brake": brake, "spots": spots}
