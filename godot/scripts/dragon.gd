extends Node3D
class_name Dragon
## Element ejderhası (Kaan: Metal ejderi) — prosedürel, parçalı gövde (yılan gibi baş izini takip eder),
## çırpan kanatlar, parlayan gözler. B ile çağrılır ve binilir:
##  W/S hızlan-yavaşla · fare ile yön · Boşluk yüksel · C/Ctrl alçal · Shift hız · B in

const SEGS := 16
const GAP := 0.95

var player: Player
var vel := Vector3.ZERO
var speed := 0.0
var yaw := 0.0
var pitch := 0.0
var _head: Node3D
var _segs: Array = []
var _trail: Array = []
var _wings: Array = []
var _t := 0.0
var _leaving := false
var _mounted := false


func _ready() -> void:
	add_to_group("dragon")
	var metal := Game.paint(Color(0.32, 0.33, 0.36), 0.9, 0.3)
	var dark := Game.paint(Color(0.14, 0.14, 0.16), 0.8, 0.4)
	var glow := Game.emissive(Color(1.0, 0.5, 0.12), 4.0)
	_head = Node3D.new()
	add_child(_head)
	# baş: çene, burun, boynuzlar, gözler
	_part(_head, Vector3(0, 0, 0.6), Vector3(1.0, 0.7, 1.5), metal)
	_part(_head, Vector3(0, -0.3, 0.9), Vector3(0.8, 0.25, 1.2), dark)
	_part(_head, Vector3(0, 0.15, 1.45), Vector3(0.7, 0.45, 0.6), metal)
	for s in [-1.0, 1.0]:
		_part(_head, Vector3(s * 0.38, 0.22, 0.95), Vector3(0.12, 0.12, 0.12), glow)
		var horn := _part(_head, Vector3(s * 0.32, 0.55, 0.1), Vector3(0.12, 0.12, 0.9), Game.paint(Color(0.85, 0.75, 0.5), 0.6, 0.3))
		horn.rotation = Vector3(-0.6, s * 0.25, 0)
		var fin := _part(_head, Vector3(s * 0.55, 0.0, 0.2), Vector3(0.05, 0.5, 0.6), glow)
		fin.rotation.y = s * 0.4
	var eye_l := OmniLight3D.new()
	eye_l.light_color = Color(1.0, 0.5, 0.12)
	eye_l.light_energy = 2.0
	eye_l.omni_range = 5.0
	eye_l.position = Vector3(0, 0.3, 1.2)
	_head.add_child(eye_l)
	# gövde parçaları
	for i in SEGS:
		var seg := Node3D.new()
		add_child(seg)
		var k := float(i) / SEGS
		var r := lerpf(0.55, 0.16, k * k)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r * 2.0, r * 1.6, GAP * 1.15)
		mi.mesh = bm
		mi.material_override = metal if i % 2 == 0 else dark
		seg.add_child(mi)
		# sırt dikenleri (turuncu ışıklı)
		_part(seg, Vector3(0, r * 0.95, 0), Vector3(0.06, r * 0.7, 0.35), glow).rotation.x = -0.4
		if i == 3:
			for s in [-1.0, 1.0]:
				var wing := Node3D.new()
				wing.position = Vector3(s * r, r * 0.4, 0)
				seg.add_child(wing)
				var w1 := _part(wing, Vector3(s * 1.6, 0, 0), Vector3(3.2, 0.08, 1.8), Game.paint(Color(0.22, 0.23, 0.26), 0.7, 0.4))
				var w2 := _part(wing, Vector3(s * 3.8, 0, -0.4), Vector3(1.6, 0.06, 1.2), dark)
				_part(wing, Vector3(s * 1.6, 0.05, 0.9), Vector3(3.2, 0.1, 0.12), glow)
				var _u := [w1, w2]
				_wings.append(wing)
		if i == 2 or i == 9:
			for s in [-1.0, 1.0]:
				var leg := _part(seg, Vector3(s * r * 1.1, -r * 1.1, 0), Vector3(0.18, 0.7, 0.18), dark)
				leg.rotation.x = 0.5
		_segs.append(seg)
	var tail := _part(_segs[SEGS - 1], Vector3(0, 0, -0.6), Vector3(0.6, 0.05, 0.6), glow)
	tail.rotation.y = PI * 0.25
	Sfx.play("roar", global_position, 2.0)


func _part(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func mount() -> void:
	_mounted = true
	yaw = player.yaw + PI
	_trail.clear()
	for i in SEGS * 6 + 6:
		_trail.append(global_position - Vector3(sin(yaw), 0, cos(yaw)) * i * GAP / 6.0)
	player.mount = self
	player.visual.play("sit", 0.2)
	speed = 6.0
	vel = Vector3(sin(yaw), 0.6, cos(yaw)) * 8.0
	Fx.ring(player.global_position, Color(1.0, 0.5, 0.12), 6.0, 0.6)
	Game.notify("Ejderha: W hızlan · fare yön · Boşluk yüksel · C alçal · Shift hız · B in", 5.0)


func dismiss() -> void:
	if _leaving:
		return
	_leaving = true
	_mounted = false
	if player and player.mount == self:
		player.dismount()
	Sfx.play("roar", global_position, 0.0, 1.15)


func seat() -> Vector3:
	return _head.global_position - _head.global_transform.basis.z * 1.3 + Vector3(0, 0.85, 0)


func _physics_process(delta: float) -> void:
	if Game.paused:
		return
	_t += delta
	if _leaving:
		vel = vel.lerp(Vector3(sin(yaw), 0.9, cos(yaw)) * 28.0, delta * 1.5)
		global_position += vel * delta
		_update_body(delta)
		if _t > 30.0 or (player and global_position.distance_to(player.global_position) > 220.0):
			queue_free()
		return
	if not _mounted:
		return
	# yönlendirme: kamera yönü
	var target_yaw := player.yaw + PI
	yaw = lerp_angle(yaw, target_yaw, minf(1.0, delta * 2.2))
	var up := 0.0
	if player.controls:
		if Input.is_action_pressed("jump"):
			up = 1.0
		elif Input.is_action_pressed("crouch") or Input.is_action_pressed("move_back") and speed < 3.0:
			up = -1.0
	var thr := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back") * 0.8 if player.controls else 0.0
	var top := 42.0 if Input.is_action_pressed("sprint") else 24.0
	speed = clampf(speed + thr * delta * 14.0 - (0.0 if thr > 0.0 else delta * 4.0), 0.0, top)
	pitch = lerpf(pitch, clampf(-player.pitch * 0.9, -0.6, 0.6) + up * 0.5, minf(1.0, delta * 3.0))
	var fwd := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var want := fwd * speed + Vector3(0, up * 8.0, 0)
	if speed < 2.0:
		want.y += sin(_t * 2.0) * 0.6        # havada süzülme
	vel = vel.lerp(want, minf(1.0, delta * 2.5))
	var np := global_position + vel * delta
	# zemin / deniz üstünde kal
	var w := player.world
	if w:
		var g := maxf(w.ground_y(np.x, np.z), World.SEA)
		if w.in_city(np):
			g = maxf(g, 0.0)
		if np.y < g + 2.5:
			np.y = g + 2.5
			vel.y = maxf(vel.y, 0.0)
		np.y = minf(np.y, 650.0)
	global_position = np
	_update_body(delta)
	# çarpışma: yol üstündekileri savurur
	if speed > 12.0:
		for n in get_tree().get_nodes_in_group("people"):
			var pd := n as Pedestrian
			if pd and not pd.is_down() and pd.global_position.distance_to(global_position) < 2.5:
				pd.take_hit(30.0, global_position, true, player, 0.0, vel * 0.5)


func _update_body(delta: float) -> void:
	_head.global_position = global_position
	var hv := vel if vel.length() > 0.5 else Vector3(sin(yaw), 0, cos(yaw))
	var tgt := global_position + hv.normalized()
	if tgt.distance_to(global_position) > 0.01 and absf(hv.normalized().y) < 0.99:
		_head.look_at(tgt, Vector3.UP, true)
	# iz: başın geçtiği yerler; parçalar iz üzerinde sıralanır
	if _trail.is_empty() or _trail[0].distance_to(global_position) > GAP / 6.0:
		_trail.push_front(global_position)
		if _trail.size() > SEGS * 6 + 8:
			_trail.pop_back()
	for i in _segs.size():
		var a: Vector3 = _trail[mini((i + 1) * 6, _trail.size() - 1)]
		var b: Vector3 = _trail[mini((i + 1) * 6 - 3, _trail.size() - 1)]
		var seg := _segs[i] as Node3D
		seg.global_position = a + Vector3(0, sin(_t * 3.0 - i * 0.5) * 0.12, 0)
		var d := b - a
		if d.length() > 0.01 and absf(d.normalized().y) < 0.99:
			seg.look_at(seg.global_position + d, Vector3.UP, true)
	# kanat çırpma
	var flap := sin(_t * (5.0 if speed > 8.0 else 3.0)) * (0.55 if speed > 2.0 else 0.35)
	for k in _wings.size():
		var wn := _wings[k] as Node3D
		wn.rotation.z = flap * (1.0 if k % 2 == 0 else -1.0)
	var _d := delta
