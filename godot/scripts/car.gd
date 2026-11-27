extends VehicleBody3D
class_name Car
## Sürülebilir araç (GTA4 hissi): ağır gövde, alçak ağırlık merkezi, sönümlü süspansiyon,
## yalpa önleyici (anti-roll) tork, hıza duyarlı direksiyon, el freniyle kayma.

var driven := false
var model := "sedan"
var body_color := Color(0.8, 0.1, 0.12)
var max_force := 6200.0
var max_brake := 55.0
var top_speed := 52.0            # m/s (~190 km/s)
var wheels: Array[VehicleWheel3D] = []
var lights := {}
var size := Vector3(2.2, 1.7, 3.9)
var seat := Vector3(0.45, 0.35, -0.05)
var _steer := 0.0
var _thr := 0.0
var _prop_t := 0.0
var horn_ok := true


func _ready() -> void:
	add_to_group("cars")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(func(b: Node):
		if b is TrafficCar:
			(b as TrafficCar).hit(linear_velocity))
	mass = 1450.0
	collision_mask = 1 | 2              # 2: araçlara özel kaldırım kenarı
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	angular_damp = 0.6
	linear_damp = 0.03
	var info := CarModel.build(self, model, body_color)
	size = info.size
	var c: Vector3 = info.center
	center_of_mass = Vector3(0, 0.18, c.z)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x * 0.94, size.y * 0.62, size.z * 0.97)
	shape.shape = bs
	shape.position = Vector3(c.x, c.y + size.y * 0.12, c.z)
	add_child(shape)
	seat = Vector3(size.x * 0.2, c.y - size.y * 0.44, c.z - size.z * 0.06)
	lights = CarModel.add_lights(self, info, true)
	for w in info.wheels:
		var wpos: Vector3 = w[0]
		var front: bool = wpos.z > c.z
		var vw := VehicleWheel3D.new()
		vw.position = wpos + Vector3(0, 0.06, 0)
		vw.use_as_steering = front
		vw.use_as_traction = not front or model.begins_with("suv")
		vw.wheel_radius = w[1]
		vw.wheel_rest_length = 0.14
		vw.suspension_travel = 0.16
		vw.suspension_stiffness = 85.0
		vw.suspension_max_force = 9000.0
		vw.damping_compression = 6.0
		vw.damping_relaxation = 7.5
		vw.wheel_friction_slip = 2.9 if front else 2.7
		vw.wheel_roll_influence = 0.02
		add_child(vw)
		wheels.append(vw)
		var mesh: Node3D = w[2]
		if mesh:
			# Kenney teker modelini fizik tekerine taşı (döner ve döner/direksiyon kırar)
			var gx := mesh.global_transform
			mesh.get_parent().remove_child(mesh)
			vw.add_child(mesh)
			mesh.global_transform = gx
			mesh.position = Vector3.ZERO
		else:
			vw.add_child(CarModel.tire_mesh(w[1]))


func set_driver(on: bool) -> void:
	driven = on
	if not on:
		engine_force = 0.0
		brake = 6.0


func fwd_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)


func _physics_process(delta: float) -> void:
	var lights_on: bool = Game.night > 0.4 and (driven or linear_velocity.length() > 0.5)
	for l in lights.get("spots", []):
		l.visible = lights_on
	_stabilize(delta)
	_prop_t -= delta
	var spd := linear_velocity.length()
	if spd > 2.5 and _prop_t <= 0.0:
		_prop_t = 0.05
		var w := get_parent() as World
		if w and w.in_city(global_position, 30.0):
			var b := global_transform.basis
			var front := global_position + b.z * size.z * 0.45 + Vector3(0, 0.6, 0)
			if w.hit_props(front, size.x * 0.6, linear_velocity * 0.9):
				linear_velocity *= 0.9
				if driven:
					var pl := get_tree().get_first_node_in_group("player") as Player
					if pl:
						pl.shake(0.25)
	if driven and horn_ok and not Game.paused and Input.is_action_just_pressed("horn"):
		Sfx.play("horn", global_position, -2.0)
	if not driven:
		return
	var thr := 0.0
	var brk := 0.0
	var st := 0.0
	if not Game.paused:
		thr = clamp(Input.get_action_strength("move_forward") + Input.get_action_strength("throttle"), 0.0, 1.0)
		brk = clamp(Input.get_action_strength("move_back") + Input.get_action_strength("brake"), 0.0, 1.0)
		st = Input.get_axis("move_right", "move_left")
	var v := fwd_speed()
	# gaz yumuşak gelir (ani tork → yalpa yok)
	_thr = move_toward(_thr, thr, delta * 2.5)
	# hıza duyarlı direksiyon: düşük hızda 0,6 rad, yüksek hızda ~0,16 rad
	var lim: float = lerp(0.6, 0.16, clamp(abs(v) / 38.0, 0.0, 1.0))
	var rate: float = 1.8 if st != 0.0 else 3.2     # bırakınca daha hızlı ortalanır
	_steer = move_toward(_steer, st * lim, delta * rate)
	steering = _steer
	if brk > 0.1 and v > 1.0:
		engine_force = 0.0
		brake = brk * max_brake
	elif brk > 0.1:
		engine_force = -brk * max_force * 0.5 * clamp(1.0 + v / 12.0, 0.0, 1.0)
		brake = 0.0
	else:
		var fall: float = clamp(1.0 - v / top_speed, 0.0, 1.0)
		engine_force = _thr * max_force * (0.35 + 0.65 * fall)
		brake = 0.0 if _thr > 0.05 else 0.9
	var hand := Input.is_action_pressed("handbrake") and not Game.paused
	for w in wheels:
		if not w.use_as_steering:
			w.wheel_friction_slip = 1.3 if hand else 2.7
			w.brake = max_brake * 0.8 if hand else brake
	if lights.has("brake"):
		lights.brake.emission_energy_multiplier = 5.0 if (brk > 0.1 and v > 0.5) or hand else (1.2 if lights_on else 0.4)


func _stabilize(delta: float) -> void:
	## GTA4 hissi: gövde hafif yatar ama devrilmez; yalpa ve baş vurma sönümlenir
	var b := global_transform.basis
	var av := b.inverse() * angular_velocity
	var damp := Vector3(av.x * 5.0, 0.0, av.z * 7.0) * mass
	apply_torque(-(b * damp))
	var up := b.y
	var tilt := up.cross(Vector3.UP)
	if up.dot(Vector3.UP) > 0.2:
		apply_torque(tilt * mass * 48.0)
	elif up.dot(Vector3.UP) < 0.2 and linear_velocity.length() < 2.0:
		# ters döndüyse yavaşça doğrult
		apply_torque(tilt.normalized() * mass * 25.0)
	var spd := linear_velocity.length()
	apply_central_force(-b.y * spd * spd * 1.4)
	apply_central_force(-linear_velocity * spd * 0.35)
	var _d := delta


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func repaint(c: Color) -> void:
	## Boya Atölyesi: gövde rengi değişir
	body_color = c
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if String(m.name).to_lower() != "body":
			continue
		var mat := m.material_override as StandardMaterial3D
		if mat == null:
			mat = m.get_active_material(0) as StandardMaterial3D
		if mat:
			var nm := mat.duplicate() as StandardMaterial3D
			nm.albedo_color = c.lightened(0.15)
			m.material_override = nm
