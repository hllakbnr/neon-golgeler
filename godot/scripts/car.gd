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


func _ready() -> void:
	add_to_group("cars")
	mass = 1450.0
	collision_mask = 1 | 2              # 2: araçlara özel kaldırım kenarı
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	angular_damp = 0.6
	linear_damp = 0.03
	var info := CarModel.build(self, model, body_color)
	size = info.size
	var c: Vector3 = info.center
	center_of_mass = Vector3(0, c.y - size.y * 0.32, c.z)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x * 0.94, size.y * 0.62, size.z * 0.97)
	shape.shape = bs
	shape.position = Vector3(c.x, c.y + size.y * 0.12, c.z)
	add_child(shape)
	seat = Vector3(size.x * 0.2, c.y - size.y * 0.44, c.z - size.z * 0.06)
	lights = CarModel.add_lights(self, info)
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
		vw.suspension_stiffness = 62.0
		vw.suspension_max_force = 9000.0
		vw.damping_compression = 4.6
		vw.damping_relaxation = 5.4
		vw.wheel_friction_slip = 3.3 if front else 3.1
		vw.wheel_roll_influence = 0.06
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
	if lights.has("head"):
		lights.head.emission_energy_multiplier = 3.0 if lights_on else 0.0
	_stabilize(delta)
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
			w.wheel_friction_slip = 1.5 if hand else 3.1
			w.brake = max_brake * 0.8 if hand else brake
	if lights.has("brake"):
		lights.brake.emission_energy_multiplier = 5.0 if (brk > 0.1 and v > 0.5) or hand else (1.2 if lights_on else 0.4)


func _stabilize(delta: float) -> void:
	## GTA4 tarzı: gövde yatar ama sönümlenir, sallanmaz; yüksek hızda yere basma kuvveti
	var b := global_transform.basis
	var av := b.inverse() * angular_velocity
	# yalpa (z) ve baş vurma (x) hızlarını sönümle
	var damp := Vector3(av.x * 2.2, 0.0, av.z * 3.2) * mass
	apply_torque(-(b * damp))
	# yalpa önleyici: gövdeyi dik tutmaya çalışan yay
	var up := b.y
	var tilt := up.cross(Vector3.UP)
	if up.dot(Vector3.UP) > 0.3:
		apply_torque(tilt * mass * 9.0)
	var spd := linear_velocity.length()
	apply_central_force(-b.y * spd * spd * 1.1)
	# hava direnci
	apply_central_force(-linear_velocity * spd * 0.35)


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6
