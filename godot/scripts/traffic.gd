extends RigidBody3D
class_name TrafficCar
## Şerit takip eden trafik aracı: sağ şerit, kavşakta ışığa uyar, öndeki araç/yayaya fren yapar.
## Sürerken kinematiktir (donuk); çarpılınca gerçek fizik gövdesine döner (savrulur, iç içe geçmez),
## birkaç saniye sonra durulup oyuncu uzaktaysa yoluna devam eder.

var world: World
var from := Vector2i.ZERO
var to := Vector2i.ZERO
var speed := 0.0
var max_speed := 11.0
var model := "sedan"
var half_len := 2.0
var lights := {}
var wheel_nodes: Array = []
var crashed := 0.0


func _ready() -> void:
	add_to_group("traffic")
	mass = 1300.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_mask = 1 | 2
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.4
	angular_damp = 1.6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	physics_material_override = pm
	body_entered.connect(_on_body)
	var info := CarModel.build(self, model)
	var sz: Vector3 = info.size
	var c: Vector3 = info.center
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, c.y - sz.y * 0.2, c.z)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(sz.x * 0.94, sz.y * 0.8, sz.z * 0.97)
	shape.shape = bs
	shape.position = c
	add_child(shape)
	half_len = sz.z * 0.5
	lights = CarModel.add_lights(self, info)
	for w in info.wheels:
		if w[2] == null:
			var t := CarModel.tire_mesh(w[1])
			t.position = w[0]
			add_child(t)
			wheel_nodes.append(t)
		else:
			wheel_nodes.append(w[2])
	_place()


func _node_pos(n: Vector2i) -> Vector3:
	return Vector3(n.x * world.CELL, 0, n.y * world.CELL)


func _lane_offset(a: Vector2i, b: Vector2i) -> Vector3:
	var d := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
	return Vector3(-d.z, 0, d.x) * -2.9   # sağ şerit


func _place() -> void:
	var p := _node_pos(from) + _lane_offset(from, to)
	global_position = p
	look_at(_node_pos(to) + _lane_offset(from, to), Vector3.UP, true)


func _next() -> void:
	var opts := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = to + d
		if n == from or not world.node_ok(n):
			continue
		opts.append(n)
	from = to
	to = opts[randi() % opts.size()] if opts.size() > 0 else from


func _on_body(b: Node) -> void:
	if crashed > 0.0:
		return
	if b is Car or (b is TrafficCar and (b as TrafficCar).crashed > 0.0):
		hit((b as RigidBody3D).linear_velocity)


func hit(other_vel: Vector3) -> void:
	## çarpışma: kinematikten gerçek fiziğe geç
	if crashed > 0.0:
		return
	crashed = 7.0
	var fwd := global_transform.basis.z
	freeze = false
	linear_velocity = fwd * speed + other_vel * 0.35
	angular_velocity = Vector3(0, randf_range(-0.6, 0.6), 0)
	speed = 0.0
	if lights.has("brake"):
		lights.brake.emission_energy_multiplier = 5.0


func _recover() -> void:
	## durulduysa ve oyuncu görmüyorsa en yakın kavşaktan yoluna devam et
	var up_ok := global_transform.basis.y.y > 0.8
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var far := pl == null or pl.global_position.distance_to(global_position) > 45.0
	if linear_velocity.length() > 0.5 or not (up_ok or far):
		crashed = 1.0
		return
	var ni := Vector2i(clampi(int(round(global_position.x / world.CELL)), -world.GX, world.GX), clampi(int(round(global_position.z / world.CELL)), -world.GZ, world.GZ))
	from = ni
	to = ni
	_next()
	if not up_ok:
		_place()
	else:
		global_rotation = Vector3(0, global_rotation.y, 0)
		global_position.y = 0.0
	freeze = true
	crashed = 0.0


func _physics_process(delta: float) -> void:
	if world == null or Game.paused:
		return
	if crashed > 0.0:
		crashed -= delta
		if crashed <= 0.0:
			_recover()
		return
	var target := _node_pos(to) + _lane_offset(from, to)
	var to_t := target - global_position
	to_t.y = 0.0
	var dist := to_t.length()
	var want := max_speed
	# ışık: x yönündeki hareket faz 0'da, z yönündeki faz 1'de yeşil
	var along_x: bool = from.y == to.y
	var phase := int(Time.get_ticks_msec() / 8000) % 2
	var green := (phase == 0) == along_x
	var stop_line: float = world.ROAD_W * 0.5 + 4.0
	if not green and dist > stop_line - 1.0 and dist < stop_line + 8.0:
		want = 0.0 if dist < stop_line + 1.5 else 3.0
	# önündeki engeller (araçlar, yayalar, oyuncu)
	var fwd := global_transform.basis.z
	for n in get_tree().get_nodes_in_group("traffic") + get_tree().get_nodes_in_group("cars") + get_tree().get_nodes_in_group("people") + get_tree().get_nodes_in_group("player"):
		if n == self or not (n is Node3D):
			continue
		var rel: Vector3 = (n as Node3D).global_position - global_position
		var ahead := rel.dot(fwd)
		if ahead <= 0.0 or ahead > 14.0:
			continue
		var lateral := (rel - fwd * ahead).length()
		if lateral < 2.3:
			want = min(want, max(0.0, (ahead - half_len - 3.0) * 1.2))
	var prev := speed
	speed = move_toward(speed, want, delta * (6.0 if want > speed else 12.0))
	var lon: bool = Game.night > 0.4
	for l in lights.get("spots", []):
		l.visible = lon
	if lights.has("brake"):
		lights.brake.emission_energy_multiplier = 5.0 if speed < prev - 0.01 or speed < 0.1 else (1.2 if lon else 0.3)
	for wn in wheel_nodes:
		(wn as Node3D).rotate_object_local(Vector3.RIGHT, speed * delta / 0.45)
	if dist < 2.0:
		_next()
		return
	var dir: Vector3 = to_t / maxf(dist, 0.001)
	var new_fwd := fwd.slerp(dir, min(1.0, delta * 3.0)).normalized()
	global_position += new_fwd * speed * delta
	look_at(global_position + new_fwd, Vector3.UP, true)
