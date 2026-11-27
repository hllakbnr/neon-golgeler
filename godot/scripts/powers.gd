extends Node
class_name Powers
## Ninja güçleri
##  • X — Kasırga (spinjitzu): karakter dönen bir hortuma dönüşür, çarptığını savurur, eşyaları kırar
##  • Havada tekrar Boşluk — Hava kasırgası (airjitzu): yükselip süzülür
##  • Z — Element gücü (Kaan: Metal): yere vurur, metal şok dalgası etraftakileri savurur
##  • B — Element ejderhası: çağır / bin / gönder
## Kasırga modeli: "Spinjitzu (green)", AAV's 3D Models (Sketchfab), CC BY 4.0 — renkleri oyunda değiştirildi.

const C1 := Color(1.0, 0.5, 0.12)     # Kaan: turuncu kasırga gövdesi
const C2 := Color(0.85, 0.9, 1.0)     # metalik parlama

var p: Player
var spin_t := 0.0
var spin_cd := 0.0
var air_t := 0.0
var air_used := false
var elem_cd := 0.0
var dragon: Dragon = null
var _vortex: Node3D = null
var _hit_t := 0.0
var _snd: AudioStreamPlayer3D


func _init(player: Player) -> void:
	p = player


func spinning() -> bool:
	return spin_t > 0.0


func tick(delta: float) -> void:
	spin_cd = maxf(0.0, spin_cd - delta)
	elem_cd = maxf(0.0, elem_cd - delta)
	if p.is_on_floor():
		air_used = false
	var free := p.controls and not Game.paused and not p.combat.dead and p.phone == null and p.talk == null and p.car == null
	if spin_t > 0.0:
		spin_t -= delta
		_spin_update(delta)
		if spin_t <= 0.0:
			_spin_end()
	if air_t > 0.0:
		air_t -= delta
		if Input.is_action_pressed("jump") and p.velocity.y < -1.0:
			p.velocity.y = -1.0       # süzülme
		if air_t <= 0.0 and spin_t <= 0.0:
			_remove_vortex()
	if not free:
		return
	if dragon and is_instance_valid(dragon):
		if Input.is_action_just_pressed("dragon"):
			dragon.dismiss()
		return
	if Input.is_action_just_pressed("spinjitzu") and spin_cd <= 0.0 and spin_t <= 0.0:
		_spin_start()
	elif Input.is_action_just_pressed("element") and elem_cd <= 0.0 and p.is_on_floor():
		_element()
	elif Input.is_action_just_pressed("dragon"):
		_summon()
	elif Input.is_action_just_pressed("jump") and not p.is_on_floor() and not air_used and p.combat.stamina >= 20.0:
		_airjitzu()


# ---------------------------------------------------------------- kasırga
func _spin_start() -> void:
	if p.combat.stamina < 30.0:
		Game.notify("Kasırga için dayanıklılık yetersiz.", 2.0)
		return
	p.combat.stamina -= 30.0
	spin_t = 4.0
	spin_cd = 3.0
	_hit_t = 0.0
	_attach_vortex(1.0)
	Sfx.play("swoosh_big", p.global_position, 0.0)
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = Sfx.stream("swoosh_big")
	_snd.volume_db = -6.0
	p.add_child(_snd)
	_snd.play()
	_snd.finished.connect(func(): if is_instance_valid(_snd) and spin_t > 0.0: _snd.play())
	Fx.dust(p.global_position, 1.4)


func _spin_update(delta: float) -> void:
	p.visual.rotation.y += delta * 26.0
	p.visual.play("idle", 0.1)
	p.visual.lock_t = 0.1
	_hit_t -= delta
	if _hit_t > 0.0:
		return
	_hit_t = 0.2
	var c := p.global_position
	for g in ["people", "police", "dummies"]:
		for n in get_tree().get_nodes_in_group(g):
			var t := n as Node3D
			if t == null or (t.has_method("is_down") and t.is_down()):
				continue
			if t.global_position.distance_to(c) < 1.9:
				t.take_hit(22.0 * p.combat.dmg_mult, c, true, p, 0.0)
	if p.world:
		var v := p.velocity
		v.y = 0.0
		p.world.hit_props(c + Vector3(0, 0.8, 0), 1.6, v.normalized() * 6.0 if v.length() > 0.5 else Vector3(0, 0, 4))
	for n in get_tree().get_nodes_in_group("traffic"):
		var tc := n as TrafficCar
		if tc and tc.global_position.distance_to(c) < 3.2:
			tc.hit((tc.global_position - c).normalized() * 8.0)


func _spin_end() -> void:
	spin_t = 0.0
	if _snd and is_instance_valid(_snd):
		_snd.queue_free()
	_snd = null
	_remove_vortex()
	p.visual.lock_t = 0.0
	Fx.dust(p.global_position, 1.0)


func _attach_vortex(scale: float) -> void:
	_remove_vortex()
	_vortex = vortex(C1, C2)
	_vortex.scale = Vector3.ONE * scale
	p.add_child(_vortex)


func _remove_vortex() -> void:
	if _vortex and is_instance_valid(_vortex):
		var v := _vortex
		var tw := v.create_tween()
		tw.tween_property(v, "scale", Vector3(0.05, 1.4, 0.05), 0.25)
		tw.tween_callback(v.queue_free)
	_vortex = null


static func vortex(c1: Color, c2: Color) -> Node3D:
	## Element Arenası'ndaki kurulumun aynısı: model ~2,4 m genişlik, ~2,5 m yükseklik, gri doku × renk
	var root := Node3D.new()
	var spin := Node3D.new()
	root.add_child(spin)
	var body_sh := Shader.new()
	body_sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 col : source_color;
uniform float alpha = 0.82;
uniform float glow = 1.0;
void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.05) discard;
	float g = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = col.rgb * (0.35 + g * 1.3) * glow;
	ALPHA = alpha * t.a;
}
"""
	var glow_sh := Shader.new()
	glow_sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 col : source_color;
void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.05) discard;
	float g = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = col.rgb * g * 2.2;
	ALPHA = t.a;
}
"""
	var ps: PackedScene = load("res://assets/fx/spinjitzu.glb") if ResourceLoader.exists("res://assets/fx/spinjitzu.glb") else null
	if ps:
		var inst: Node3D = ps.instantiate()
		spin.add_child(inst)
		var ab := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var src := m.mesh.surface_get_material(0) as BaseMaterial3D
			var tex: Texture2D = src.albedo_texture if src else null
			var is_glow := src != null and (src.emission_enabled or String(src.resource_name).ends_with("1"))
			var sm := ShaderMaterial.new()
			sm.shader = glow_sh if is_glow else body_sh
			sm.set_shader_parameter("tex", tex)
			sm.set_shader_parameter("col", c2 if is_glow else c1)
			m.material_override = sm
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var xf := Transform3D()
			var nd: Node = m
			while nd != null and nd != inst:
				xf = (nd as Node3D).transform * xf
				nd = nd.get_parent()
			var b := xf * m.get_aabb()
			ab = b if first else ab.merge(b)
			first = false
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		if aps.size() > 0:
			var ap := aps[0] as AnimationPlayer
			var names := ap.get_animation_list()
			if names.size() > 0:
				var a := ap.get_animation(names[0])
				a.loop_mode = Animation.LOOP_LINEAR
				ap.play(names[0])
				ap.speed_scale = 2.2
		inst.scale = Vector3(2.4, 2.5, 2.4) / Vector3(maxf(ab.size.x, 0.1), maxf(ab.size.y, 0.1), maxf(ab.size.z, 0.1)) if not first else Vector3.ONE
	else:
		# model yoksa: üst üste dönen koniler
		for k in 5:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5 + k * 0.22
			cm.bottom_radius = 0.35 + k * 0.2
			cm.height = 0.5
			cm.radial_segments = 16
			mi.mesh = cm
			mi.material_override = Game.emissive(c1.lerp(c2, k / 5.0), 2.0)
			mi.transparency = 0.4
			mi.position.y = 0.3 + k * 0.48
			spin.add_child(mi)
	# iç halkalar ve yer halkası
	for k in 2:
		var tr := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.95 - k * 0.15
		tm.outer_radius = 1.05 - k * 0.15
		tr.mesh = tm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = c2 * 0.8
		tr.material_override = m
		tr.position.y = 0.8 + k * 0.9
		spin.add_child(tr)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 1.2
	rm.outer_radius = 1.45
	ring.mesh = rm
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m2.albedo_color = c1 * 0.6
	ring.material_override = m2
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.05
	root.add_child(ring)
	var l := OmniLight3D.new()
	l.light_color = c1
	l.light_energy = 2.5
	l.omni_range = 6.0
	l.position.y = 1.2
	root.add_child(l)
	var tw := spin.create_tween().set_loops()
	tw.tween_property(spin, "rotation:y", TAU, 0.35).from(0.0)
	root.scale = Vector3(0.05, 1.2, 0.05)
	var tw2 := root.create_tween()
	tw2.tween_property(root, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT)
	return root


# ---------------------------------------------------------------- hava kasırgası
func _airjitzu() -> void:
	air_used = true
	p.combat.stamina -= 20.0
	p.velocity.y = 8.5
	air_t = 2.2
	if spin_t <= 0.0:
		_attach_vortex(0.6)
	Sfx.play("swoosh_big", p.global_position, -4.0, 1.3)


# ---------------------------------------------------------------- element gücü (Metal)
func _element() -> void:
	if p.combat.stamina < 35.0:
		Game.notify("Element gücü için dayanıklılık yetersiz.", 2.0)
		return
	p.combat.stamina -= 35.0
	elem_cd = 6.0
	var L := p.visual.action("spell", 1.3)
	p.combat.busy = L * 0.8
	await get_tree().create_timer(L * 0.4).timeout
	if not is_instance_valid(p):
		return
	var c := p.global_position
	Sfx.play("metal", c, 2.0, 0.6)
	Sfx.play("punch_heavy", c, 2.0, 0.7)
	Fx.ring(c + Vector3(0, 0.15, 0), C2, 8.0, 0.6)
	Fx.ring(c + Vector3(0, 0.3, 0), C1, 6.0, 0.45)
	Fx.sparks(c + Vector3(0, 0.3, 0), C1)
	Fx.dust(c, 2.5)
	p.shake(0.4)
	for g in ["people", "police", "dummies"]:
		for n in get_tree().get_nodes_in_group(g):
			var t := n as Node3D
			if t == null or (t.has_method("is_down") and t.is_down()):
				continue
			var d := t.global_position.distance_to(c)
			if d < 8.0:
				t.take_hit(lerpf(32.0, 12.0, d / 8.0) * p.combat.dmg_mult, c, true, p, 0.0)
	if p.world:
		for k in 8:
			var a := k * TAU / 8.0
			p.world.hit_props(c + Vector3(cos(a), 0.0, sin(a)) * 4.0 + Vector3(0, 0.8, 0), 3.2, Vector3(cos(a), 0.3, sin(a)) * 8.0)
	for g2 in ["traffic", "cars"]:
		for n in get_tree().get_nodes_in_group(g2):
			var rb := n as RigidBody3D
			if rb == null or rb == p.car:
				continue
			var rel := rb.global_position - c
			if rel.length() < 9.0:
				if rb is TrafficCar:
					(rb as TrafficCar).hit(rel.normalized() * 6.0)
				else:
					rb.apply_central_impulse((rel.normalized() + Vector3(0, 0.4, 0)) * rb.mass * 5.0)


# ---------------------------------------------------------------- ejderha
func _summon() -> void:
	if dragon and is_instance_valid(dragon):
		return
	if Wanted.inst and Wanted.inst.stars >= 4:
		Game.notify("Ejderha bu kadar polisin arasına gelmez!", 2.5)
		return
	dragon = Dragon.new()
	dragon.player = p
	p.get_parent().add_child(dragon)
	dragon.global_position = p.global_position + Vector3(0, 2.0, 0)
	dragon.mount()
