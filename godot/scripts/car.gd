extends VehicleBody3D
class_name Car
## Sürülebilir araç: gerçek fizik (VehicleBody3D), metalik vernikli boya, farlar/stop lambaları.
## driven=false iken park hâlinde durur; trafik araçları için traffic.gd kullanılır.

var driven := false
var body_color := Color(0.8, 0.1, 0.12)
var max_force := 2600.0
var max_brake := 60.0
var steer_limit := 0.5
var head_lights: Array[SpotLight3D] = []
var brake_mat: StandardMaterial3D
var _steer := 0.0


func _ready() -> void:
	add_to_group("cars")
	mass = 1250.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0.1)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 0.9, 4.4)
	shape.shape = bs
	shape.position.y = 0.75
	add_child(shape)
	CarModel.build(self, body_color)
	brake_mat = StandardMaterial3D.new()
	brake_mat.albedo_color = Color(0.4, 0.02, 0.02)
	brake_mat.emission_enabled = true
	brake_mat.emission = Color(1, 0.05, 0.03)
	brake_mat.emission_energy_multiplier = 0.6
	for s in [-1, 1]:
		var tl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 0.1, 0.04)
		tl.mesh = bm
		tl.material_override = brake_mat
		tl.position = Vector3(s * 0.65, 0.85, -2.21)
		add_child(tl)
		var sl := SpotLight3D.new()
		sl.light_color = Color(1, 0.95, 0.85)
		sl.light_energy = 6.0
		sl.spot_range = 35.0
		sl.spot_angle = 28.0
		sl.position = Vector3(s * 0.62, 0.75, 2.25)
		sl.rotation.x = -0.08
		sl.rotation.y = PI
		sl.visible = false
		add_child(sl)
		head_lights.append(sl)
	for p in [[-0.82, 1.35, true], [0.82, 1.35, true], [-0.82, -1.35, false], [0.82, -1.35, false]]:
		var w := VehicleWheel3D.new()
		w.position = Vector3(p[0], 0.42, p[1])
		w.use_as_steering = p[2]
		w.use_as_traction = not p[2]
		w.wheel_radius = 0.36
		w.wheel_rest_length = 0.12
		w.suspension_travel = 0.18
		w.suspension_stiffness = 45.0
		w.damping_compression = 0.9
		w.damping_relaxation = 1.1
		w.wheel_friction_slip = 2.6
		w.wheel_roll_influence = 0.2
		add_child(w)
		CarModel.wheel(w)


func set_driver(on: bool) -> void:
	driven = on
	if not on:
		engine_force = 0.0
		brake = 8.0


func _physics_process(delta: float) -> void:
	var lights_on: bool = RenderingServer.global_shader_parameter_get("night") > 0.4 and (driven or linear_velocity.length() > 0.5)
	for l in head_lights:
		l.visible = lights_on
	if not driven:
		return
	var thr := 0.0
	var brk := 0.0
	if not Game.paused:
		thr = Input.get_action_strength("move_forward") + Input.get_action_strength("throttle")
		brk = Input.get_action_strength("move_back") + Input.get_action_strength("brake")
	var fwd_speed := linear_velocity.dot(-global_transform.basis.z * -1.0)
	var st := Input.get_axis("move_right", "move_left") if not Game.paused else 0.0
	var speed_k: float = clamp(1.0 - abs(fwd_speed) / 45.0, 0.35, 1.0)
	_steer = move_toward(_steer, st * steer_limit * speed_k, delta * 2.6)
	steering = _steer
	if brk > 0.1 and fwd_speed > 1.0:
		engine_force = 0.0
		brake = brk * max_brake * 0.5
	elif brk > 0.1:
		engine_force = -brk * max_force * 0.6
		brake = 0.0
	else:
		engine_force = thr * max_force * clamp(1.0 - fwd_speed / 55.0, 0.0, 1.0)
		brake = 0.0 if thr > 0.05 else 1.5
	if Input.is_action_pressed("handbrake") and not Game.paused:
		brake = max_brake
	brake_mat.emission_energy_multiplier = 4.0 if brk > 0.1 else 0.6


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6
