extends Node3D
class_name Dragon
## Element ejderhası — uzun yılansı gövde, çatlak desenli parlayan pullar (element renginde),
## iri baş (açılan çene, dişler, boynuzlar, parlayan gözler), zarlı büyük kanatlar, pençeli bacaklar,
## yüzgeçli kuyruk. Gövde parçaları başın izini takip eder.
## Sürüş (araba gibi): W hızlan · S yavaşla · A/D dön · Boşluk yüksel · C alçal · Shift hız · B in
## Kamera kendiliğinden arkaya geçer; fareyle etrafa bakılabilir.

const SEGS := 22
const GAP := 0.8

var player: Player
var base_col := Color(0.16, 0.17, 0.2)      # Kaan: koyu metal
var glow_col := Color(1.0, 0.45, 0.1)       # turuncu enerji çatlakları
var vel := Vector3.ZERO
var speed := 0.0
var yaw := 0.0
var pitch := 0.0
var _head: Node3D
var _jaw: Node3D
var _segs: Array = []
var _trail: Array = []
var _wings: Array = []
var _legs: Array = []
var _t := 0.0
var _leaving := false
var _landing := false
var _mounted := false
var _scale_mat: ShaderMaterial
var _horn_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D


func _scales_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec4 base : source_color = vec4(0.16, 0.17, 0.2, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float energy = 3.5;
varying vec3 lp;
vec2 h2(vec2 p) { p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
float cracks(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = h2(i + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 uv = vec2(atan(lp.x, lp.y) * 1.6, lp.z * 2.4 + NODE_POSITION_WORLD.x * 0.3 + NODE_POSITION_WORLD.z * 0.3);
	float e = cracks(uv * 2.2);
	float line = 1.0 - smoothstep(0.03, 0.11, e);
	float pulse = 0.7 + 0.3 * sin(TIME * 3.0 + lp.z * 4.0);
	vec3 scale_col = base.rgb * (0.7 + 0.6 * smoothstep(0.1, 0.5, e));
	ALBEDO = mix(scale_col, glow.rgb, line * 0.6);
	EMISSION = glow.rgb * line * energy * pulse;
	METALLIC = 0.6;
	ROUGHNESS = 0.35;
}
"""
	return sh


func _ready() -> void:
	add_to_group("dragon")
	_scale_mat = ShaderMaterial.new()
	_scale_mat.shader = _scales_shader()
	_scale_mat.set_shader_parameter("base", base_col)
	_scale_mat.set_shader_parameter("glow", glow_col)
	_horn_mat = Game.paint(Color(0.92, 0.9, 0.84), 0.1, 0.35)
	_glow_mat = Game.emissive(glow_col, 5.0)
	var membrane := StandardMaterial3D.new()
	membrane.albedo_color = Color(glow_col.lerp(base_col, 0.55), 0.82)
	membrane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
	membrane.emission_enabled = true
	membrane.emission = glow_col * 0.35
	membrane.roughness = 0.6
	_build_head()
	for i in SEGS:
		var seg := Node3D.new()
		add_child(seg)
		var k := float(i) / SEGS
		# boyun ince, gövde kalın, kuyruk incelir
		var r := 0.55 + 0.45 * sin(clampf((k - 0.02) / 0.75, 0.0, 1.0) * PI) - 0.42 * smoothstep(0.55, 1.0, k)
		r = maxf(r, 0.12)
		_ell(seg, Vector3.ZERO, Vector3(r * 1.9, r * 1.6, GAP * 1.9), _scale_mat)
		# sırt dikenleri
		if i % 2 == 0 and i < SEGS - 1:
			_cone(seg, Vector3(0, r * 0.8, 0), r * 0.35, r * 1.1, _horn_mat, Vector3(-0.5, 0, 0))
		# karın plakası
		_ell(seg, Vector3(0, -r * 0.45, 0), Vector3(r * 1.3, r * 0.6, GAP * 1.6), Game.paint(base_col.lightened(0.25), 0.4, 0.5))
		if i == 5:
			for sd in [-1.0, 1.0]:
				_wings.append(_build_wing(seg, sd, r, membrane))
		if i == 4 or i == 13:
			for sd in [-1.0, 1.0]:
				_legs.append(_build_leg(seg, sd, r))
		if i == SEGS - 1:
			var fin := _ell(seg, Vector3(0, 0, -0.6), Vector3(1.6, 0.08, 1.2), membrane)
			fin.rotation.y = PI * 0.25
		_segs.append(seg)
	Sfx.play("roar", global_position, 2.0)


func _ell(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.scale = size
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cone(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos + Vector3(0, h * 0.5, 0)
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_head() -> void:
	_head = Node3D.new()
	add_child(_head)
	# kafatası ve burun
	_ell(_head, Vector3(0, 0.1, 0.2), Vector3(1.25, 1.0, 1.5), _scale_mat)
	_ell(_head, Vector3(0, 0.05, 1.2), Vector3(0.95, 0.62, 1.6), _scale_mat)
	_ell(_head, Vector3(0, 0.12, 1.95), Vector3(0.7, 0.45, 0.7), _scale_mat)
	# kaş çıkıntıları + parlayan gözler
	for sd in [-1.0, 1.0]:
		_ell(_head, Vector3(sd * 0.38, 0.42, 0.75), Vector3(0.35, 0.18, 0.7), _scale_mat)
		_ell(_head, Vector3(sd * 0.4, 0.3, 0.95), Vector3(0.2, 0.14, 0.24), _glow_mat)
		# boynuzlar ve yanak dikenleri
		_cone(_head, Vector3(sd * 0.35, 0.45, -0.25), 0.14, 1.4, _horn_mat, Vector3(-1.1, 0, sd * 0.35))
		_cone(_head, Vector3(sd * 0.55, 0.0, 0.0), 0.08, 0.7, _horn_mat, Vector3(-1.3, 0, sd * 0.9))
		# üst dişler
		for k in 4:
			_cone(_head, Vector3(sd * 0.3, -0.18, 1.2 + k * 0.22), 0.05, 0.22, _horn_mat, Vector3(PI, 0, 0))
	# açılıp kapanan alt çene
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.2, 0.4)
	_head.add_child(_jaw)
	_ell(_jaw, Vector3(0, -0.12, 0.9), Vector3(0.8, 0.3, 1.8), _scale_mat)
	for sd in [-1.0, 1.0]:
		for k in 4:
			_cone(_jaw, Vector3(sd * 0.27, -0.02, 0.6 + k * 0.24), 0.045, 0.2, _horn_mat)
	# ağız içi ışıltısı
	_ell(_head, Vector3(0, -0.15, 1.1), Vector3(0.5, 0.15, 1.0), _glow_mat)
	var l := OmniLight3D.new()
	l.light_color = glow_col
	l.light_energy = 3.0
	l.omni_range = 7.0
	l.position = Vector3(0, 0.3, 1.0)
	_head.add_child(l)


func _build_wing(seg: Node3D, sd: float, r: float, membrane: Material) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(sd * r * 0.8, r * 0.5, 0.0)
	seg.add_child(root)
	var bone := _horn_mat
	# kol kemiği ve parmaklar
	var arm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.14
	cm.height = 3.4
	arm.mesh = cm
	arm.material_override = _scale_mat
	arm.rotation.z = -sd * PI * 0.5
	arm.position = Vector3(sd * 1.7, 0.3, 0.3)
	root.add_child(arm)
	var tip := Vector3(sd * 3.4, 0.3, 0.3)
	var fingers := [Vector3(sd * 6.6, 0.0, -0.6), Vector3(sd * 5.6, 0.0, -2.2), Vector3(sd * 3.8, 0.0, -3.2)]
	for f in fingers:
		var fv: Vector3 = f
		var fm := MeshInstance3D.new()
		var fc := CylinderMesh.new()
		fc.top_radius = 0.03
		fc.bottom_radius = 0.07
		fc.height = tip.distance_to(fv)
		fm.mesh = fc
		fm.material_override = bone
		root.add_child(fm)
		fm.position = (tip + fv) * 0.5
		var dir := (fv - tip).normalized()
		fm.basis = Basis(Quaternion(Vector3.UP, dir))
	# zar: omuzdan parmak uçlarına üçgenler
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var poly := [Vector3(0, 0, 0.6), tip, fingers[0], fingers[1], fingers[2], Vector3(sd * 0.4, 0, -1.6)]
	for k in range(1, poly.size() - 1):
		for v in [poly[0], poly[k], poly[k + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	# parmaklar arası hafif kavis (alt kenar)
	var mesh := st.commit()
	var mm := MeshInstance3D.new()
	mm.mesh = mesh
	mm.material_override = membrane
	root.add_child(mm)
	# pençe ucu
	_cone(root, tip, 0.08, 0.4, _horn_mat, Vector3(0, 0, -sd * PI * 0.5))
	return root


func _build_leg(seg: Node3D, sd: float, r: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(sd * r * 0.75, -r * 0.4, 0)
	seg.add_child(hip)
	var thigh := _ell(hip, Vector3(sd * 0.15, -0.45, 0.1), Vector3(0.38, 0.95, 0.45), _scale_mat)
	thigh.rotation.x = 0.4
	var shin := _ell(hip, Vector3(sd * 0.2, -1.0, -0.15), Vector3(0.24, 0.8, 0.28), _scale_mat)
	shin.rotation.x = -0.5
	for k in 3:
		_cone(hip, Vector3(sd * 0.2 + (k - 1) * 0.09, -1.35, 0.0), 0.04, 0.28, _horn_mat, Vector3(PI * 0.5, 0, 0))
	return hip


func mount() -> void:
	_mounted = true
	yaw = player.yaw + PI
	_trail.clear()
	for i in SEGS * 6 + 6:
		_trail.append(global_position - Vector3(sin(yaw), 0, cos(yaw)) * i * GAP / 6.0)
	player.mount = self
	player.visual.play("sit", 0.2)
	speed = 6.0
	vel = Vector3(sin(yaw), 0.5, cos(yaw)) * 8.0
	Fx.ring(player.global_position, glow_col, 7.0, 0.6)
	Game.notify("Ejderha: W hızlan · S yavaşla · A/D dön · Boşluk yüksel · C alçal · Shift hız · B in", 6.0)


func dismiss() -> void:
	## B: yere iner, oyuncu bırakılır, ejderha uçup gider. Suyun üstünde inilmez.
	if _leaving or _landing:
		return
	var w := player.world if player else null
	if w and _mounted:
		var g := w.ground_y(global_position.x, global_position.z)
		if g < World.SEA + 0.3 and not w.in_city(global_position):
			Game.notify("Suyun üstünde inemezsin — karaya yaklaş.", 2.5)
			return
	if _mounted:
		_landing = true
		return
	_leave()


func _leave() -> void:
	_leaving = true
	_mounted = false
	_landing = false
	if player and player.mount == self:
		player.dismount()
	Sfx.play("roar", global_position, 0.0, 1.15)


func seat() -> Vector3:
	var s: Node3D = _segs[2]
	return s.global_position + Vector3(0, 0.95, 0)


func _ground(p: Vector3) -> float:
	var w := player.world if player else null
	if w == null:
		return 0.0
	var g := maxf(w.ground_y(p.x, p.z), World.SEA)
	if w.in_city(p):
		g = maxf(g, 0.0)
	return g


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
	var g := _ground(global_position)
	if _landing:
		speed = move_toward(speed, 0.0, delta * 20.0)
		vel = vel.lerp(Vector3(0, -9.0, 0) + Vector3(sin(yaw), 0, cos(yaw)) * speed, minf(1.0, delta * 4.0))
		global_position += vel * delta
		if global_position.y <= g + 2.2:
			global_position.y = g + 2.2
			_update_body(delta)
			_leave()
			return
		_update_body(delta)
		return
	var ctl := player.controls and not Game.paused
	var thr := 0.0
	var turn := 0.0
	var up := 0.0
	if ctl:
		thr = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		turn = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		if Input.is_action_pressed("jump"):
			up = 1.0
		elif Input.is_action_pressed("crouch"):
			up = -1.0
	var top := 46.0 if Input.is_action_pressed("sprint") else 26.0
	if thr > 0.0:
		speed = move_toward(speed, top, delta * 12.0 * thr)
	elif thr < 0.0:
		speed = move_toward(speed, 0.0, delta * 22.0)
	else:
		speed = move_toward(speed, minf(speed, 10.0), delta * 3.0)
	# dönüş: hızlıyken daha geniş yay; yatış (roll) görsel
	yaw += turn * delta * lerpf(1.9, 1.1, clampf(speed / top, 0.0, 1.0))
	pitch = lerpf(pitch, up * 0.45, minf(1.0, delta * 3.0))
	var fwd := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var want := fwd * speed + Vector3(0, up * 9.0, 0)
	if speed < 2.0:
		want.y += sin(_t * 2.0) * 0.6
	vel = vel.lerp(want, minf(1.0, delta * 2.5))
	var np := global_position + vel * delta
	var gn := _ground(np)
	if np.y < gn + 2.4:
		np.y = gn + 2.4
		vel.y = maxf(vel.y, 0.0)
	np.y = minf(np.y, 650.0)
	global_position = np
	_update_body(delta, turn)
	if speed > 12.0:
		for n in get_tree().get_nodes_in_group("people"):
			var pd := n as Pedestrian
			if pd and not pd.is_down() and pd.global_position.distance_to(global_position) < 2.8:
				pd.take_hit(30.0, global_position, true, player, 0.0, vel * 0.5)


func _update_body(delta: float, turn := 0.0) -> void:
	_head.global_position = global_position
	var hv := vel if vel.length() > 0.5 else Vector3(sin(yaw), 0, cos(yaw))
	var hd := hv.normalized()
	if absf(hd.y) < 0.98:
		_head.look_at(global_position + hd, Vector3.UP, true)
		_head.rotate_object_local(Vector3.FORWARD, -turn * 0.35)
	if _trail.is_empty() or _trail[0].distance_to(global_position) > GAP / 6.0:
		_trail.push_front(global_position)
		if _trail.size() > SEGS * 6 + 8:
			_trail.pop_back()
	for i in _segs.size():
		var a: Vector3 = _trail[mini((i + 1) * 6, _trail.size() - 1)]
		var b: Vector3 = _trail[mini((i + 1) * 6 - 3, _trail.size() - 1)]
		var seg := _segs[i] as Node3D
		seg.global_position = a + Vector3(0, sin(_t * 3.0 - i * 0.45) * 0.15, 0)
		var d := b - a
		if d.length() > 0.01 and absf(d.normalized().y) < 0.98:
			seg.look_at(seg.global_position + d, Vector3.UP, true)
	# kanat çırpma (yavaşken daha hızlı), çene, bacaklar
	var fast := speed > 8.0
	var flap := sin(_t * (4.0 if fast else 6.0)) * (0.5 if fast else 0.7)
	for k in _wings.size():
		var wn := _wings[k] as Node3D
		var sd := 1.0 if k % 2 == 0 else -1.0
		wn.rotation.z = flap * sd
		wn.rotation.y = -sd * (0.25 if fast else 0.05)
	_jaw.rotation.x = 0.12 + 0.12 * sin(_t * 1.7)
	for k in _legs.size():
		(_legs[k] as Node3D).rotation.x = (0.9 if fast else 0.2) + sin(_t * 2.0 + k) * 0.1
	var _d := delta
