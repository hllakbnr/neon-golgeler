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
static var _res := {}             # kavşak → içinden geçen araç (aynı anda tek araç)
var pursuit: Node3D = null      # polis: kovalanan hedef
var police_unit := false        # aranma sistemiyle gelen ekip (işi bitince gider)
var _siren: Array = []
var _siren_snd: AudioStreamPlayer3D
var _deployed := false
var _siren_t := 0.0


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
	if CarModel.PLAIN.has(model):
		var pc := CarModel.random_paint()
		for mi in find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if String(m.name).to_lower() == "body":
				var mat := m.material_override as StandardMaterial3D
				if mat == null:
					mat = m.get_active_material(0) as StandardMaterial3D
				if mat:
					var nm := mat.duplicate() as StandardMaterial3D
					nm.albedo_color = pc.lightened(0.15)
					m.material_override = nm
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
	if model == "police":
		_add_siren()


func _add_siren() -> void:
	for k in 2:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.14, 0.22)
		mi.mesh = bm
		mi.material_override = Game.emissive(Color(1, 0.1, 0.1) if k == 0 else Color(0.15, 0.3, 1.0), 0.3)
		mi.position = Vector3(-0.25 + 0.5 * k, 1.62, 0.0)
		add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.1, 0.1) if k == 0 else Color(0.2, 0.35, 1.0)
		l.omni_range = 12.0
		l.light_energy = 0.0
		l.position = mi.position + Vector3(0, 0.3, 0)
		add_child(l)
		_siren.append([mi, l])


func _siren_update(delta: float) -> void:
	if _siren.is_empty():
		return
	var on := pursuit != null
	_siren_t += delta * 6.0
	for k in _siren.size():
		var ph := sin(_siren_t + k * PI) > 0.0
		var mat := (_siren[k][0] as MeshInstance3D).material_override as StandardMaterial3D
		mat.emission_energy_multiplier = (6.0 if ph else 0.4) if on else 0.3
		(_siren[k][1] as OmniLight3D).light_energy = (5.0 if ph else 0.0) if on else 0.0
	if on and _siren_snd == null:
		_siren_snd = AudioStreamPlayer3D.new()
		_siren_snd.stream = Sfx.stream("siren")
		_siren_snd.unit_size = 14.0
		_siren_snd.max_distance = 220.0
		_siren_snd.volume_db = -4.0
		add_child(_siren_snd)
		_siren_snd.play()
	elif not on and _siren_snd:
		_siren_snd.queue_free()
		_siren_snd = null


func end_pursuit() -> void:
	pursuit = null
	max_speed = 11.0


func _node_pos(n: Vector2i) -> Vector3:
	return Vector3(n.x * world.CELL, 0, n.y * world.CELL)


func _lane_offset(a: Vector2i, b: Vector2i) -> Vector3:
	var d := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
	return Vector3(-d.z, 0, d.x) * -2.9   # sağ şerit


func _place() -> void:
	var p := _node_pos(from) + _lane_offset(from, to)
	var tgt := _node_pos(to) + _lane_offset(from, to)
	# şeritte boş bir yer ara: başka aracın içine/üstüne doğma
	var dir := (tgt - p)
	dir.y = 0.0
	var seg := dir.length()
	if seg > 1.0:
		dir /= seg
		var others := get_tree().get_nodes_in_group("traffic") + get_tree().get_nodes_in_group("cars")
		var k := 8.0
		while k < seg - 8.0:
			var c := p + dir * k
			var free := true
			for n in others:
				if n != self and is_instance_valid(n) and (n as Node3D).is_inside_tree() and (n as Node3D).global_position.distance_to(c) < 6.0:
					free = false
					break
			if free:
				p = c
				break
			k += 7.0
	global_position = p
	if from != to and tgt.distance_to(p) > 0.1:
		look_at(tgt, Vector3.UP, true)


func _next() -> void:
	var opts := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = to + d
		if n == from or not world.node_ok(n):
			continue
		opts.append(n)
	from = to
	if pursuit and is_instance_valid(pursuit) and opts.size() > 0:
		var pp := pursuit.global_position
		opts.sort_custom(func(a, b): return _node_pos(a).distance_to(pp) < _node_pos(b).distance_to(pp))
		to = opts[0]
		return
	to = opts[randi() % opts.size()] if opts.size() > 0 else from


func _on_body(b: Node) -> void:
	if crashed > 0.0:
		return
	if b is Car or (b is TrafficCar and (b as TrafficCar).crashed > 0.0):
		hit((b as RigidBody3D).linear_velocity)


func _release() -> void:
	for k in _res.keys():
		if _res[k] == self:
			_res.erase(k)


func _exit_tree() -> void:
	_release()


func hit(other_vel: Vector3) -> void:
	## çarpışma: kinematikten gerçek fiziğe geç
	if crashed > 0.0:
		return
	_release()
	other_vel.y = minf(other_vel.y, 0.5)
	crashed = 7.0
	var fwd := global_transform.basis.z
	freeze = false
	linear_velocity = fwd * speed + Vector3(other_vel.x, 0.0, other_vel.z) * 0.35
	angular_velocity = Vector3(0, randf_range(-0.6, 0.6), 0)
	speed = 0.0
	if lights.has("brake"):
		lights.brake.emission_energy_multiplier = 5.0


func _deploy() -> void:
	## olay yerine varınca iki polis iner
	if world == null:
		return
	var r := world.blocks[0]
	var bd := 1e9
	for b in world.blocks:
		var d := Vector2(global_position.x, global_position.z).distance_to(b.get_center())
		if d < bd:
			bd = d
			r = b
	for k in 2:
		var o := Pedestrian.new()
		o.role = "police"
		o.slot = "polis"
		o.spawned = true
		o.world = world
		o.path = world.sidewalk_loop(r)
		world.add_child(o)
		o.global_position = global_position + global_transform.basis.x * (1.6 if k == 0 else -1.6) + Vector3(0, 0.05, 0)
		o.state = Pedestrian.S.FIGHT
		o.threat = pursuit
		o.hostile = true


func _recover() -> void:
	## durulduysa ve oyuncu görmüyorsa en yakın kavşaktan yoluna devam et
	var up_ok := global_transform.basis.y.y > 0.8
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var far := pl == null or pl.global_position.distance_to(global_position) > 45.0
	if linear_velocity.length() > 0.5 or not (up_ok or far):
		crashed = 1.0
		return
	var ni := Vector2i(clampi(int(round(global_position.x / world.CELL)), -world.GX, world.GX), clampi(int(round(global_position.z / world.CELL)), -world.GZ, world.GZ))
	# başka aracın üstünde/içinde kaldıysa ya da yoldan çıktıysa şeride yerleştir
	var overlap := false
	var push := Vector3.ZERO
	for n in get_tree().get_nodes_in_group("traffic") + get_tree().get_nodes_in_group("cars"):
		if n != self and (n as Node3D).global_position.distance_to(global_position) < 3.2:
			overlap = true
			var sep: Vector3 = global_position - (n as Node3D).global_position
			sep.y = 0.0
			push += sep.normalized() if sep.length() > 0.05 else global_transform.basis.x
	if overlap and not far:
		# oyuncu yakında: ışınlamak yerine yavaşça birbirinden ayrıl
		global_position += push.normalized() * 0.8
		global_position.y = maxf(global_position.y, 0.0)
		crashed = 0.4
		return
	from = ni
	to = ni
	_next()
	if not up_ok or overlap or global_position.y > 0.6 or far:
		_place()
	else:
		global_rotation = Vector3(0, global_rotation.y, 0)
		global_position.y = 0.0
	freeze = true
	crashed = 0.0


func _physics_process(delta: float) -> void:
	if world == null or Game.paused:
		return
	_siren_update(delta)
	if crashed > 0.0:
		crashed -= delta
		if crashed <= 0.0:
			_recover()
		return
	if police_unit and pursuit == null:
		var cam := get_viewport().get_camera_3d()
		if cam == null or cam.global_position.distance_to(global_position) > 160.0:
			queue_free()
			return
	var target := _node_pos(to) + _lane_offset(from, to)
	var to_t := target - global_position
	to_t.y = 0.0
	var dist := to_t.length()
	var want := max_speed
	if pursuit and is_instance_valid(pursuit):
		max_speed = 17.0
		var pd := pursuit.global_position.distance_to(global_position)
		if pd < 24.0 and not (pursuit is Player and (pursuit as Player).car):
			want = 0.0
			if not _deployed and speed < 1.0:
				_deployed = true
				_deploy()
		elif pd > 40.0:
			_deployed = false
	# ışık: x yönündeki hareket faz 0'da, z yönündeki faz 1'de yeşil
	var along_x: bool = from.y == to.y
	var tm := Time.get_ticks_msec()
	var phase := int(tm / 8000) % 2
	var green := (phase == 0) == along_x and (tm % 8000) < 6300   # son 1,7 sn herkese kırmızı (kavşak boşalsın)
	var stop_line: float = world.ROAD_W * 0.5 + 4.0
	if not green and pursuit == null and dist > stop_line - 1.0 and dist < stop_line + 8.0:
		want = 0.0 if dist < stop_line + 1.5 else 3.0
	# kavşak sırası: kavşakta başka araç varsa girmeden bekle
	if dist < stop_line + 7.0 and dist > 3.0:
		var occ: Variant = _res.get(to)
		if occ != null and is_instance_valid(occ) and occ != self and (occ as Node3D).global_position.distance_to(_node_pos(to)) < minf(stop_line + 4.0, dist):
			if dist > stop_line - 1.0:
				want = 0.0 if dist < stop_line + 1.5 else minf(want, 3.0)
		elif dist < stop_line + 1.0 or green or pursuit:
			_res[to] = self
	# önündeki engeller (araçlar, yayalar, oyuncu)
	var fwd := global_transform.basis.z
	for n in get_tree().get_nodes_in_group("traffic") + get_tree().get_nodes_in_group("cars") + get_tree().get_nodes_in_group("people") + get_tree().get_nodes_in_group("police") + get_tree().get_nodes_in_group("player"):
		if n == self or not (n is Node3D):
			continue
		if n is Pedestrian and (n as Pedestrian).is_down():
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
