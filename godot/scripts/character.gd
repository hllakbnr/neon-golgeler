extends Node3D
class_name CharacterVisual
## İskeletli insan modeli (Xbot, MIT) + kostüm renkleri + saç; animasyon geçişleri.
## Model inmediyse yuvarlatılmış parçalı yedek gövde kullanılır.

var anim: AnimationPlayer
var skeleton: Skeleton3D
var cur := ""
var fallback: Node3D
var _phase := 0.0


func setup(body: Color, joints: Color, hair := Color(0.08, 0.07, 0.07), hair_style := "short") -> void:
	var sc := Game.character_scene()
	if sc:
		var m: Node3D = sc.instantiate()
		add_child(m)
		_normalize(m)
		anim = _find(m, "AnimationPlayer") as AnimationPlayer
		skeleton = _find(m, "Skeleton3D") as Skeleton3D
		_tint(m, body, joints)
		if anim:
			for n in anim.get_animation_list():
				var a := anim.get_animation(n)
				if a:
					a.loop_mode = Animation.LOOP_LINEAR
			play("idle", 0.0)
		if skeleton:
			_hair(hair, hair_style)
	else:
		_build_fallback(body, joints, hair)


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


func _normalize(m: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	if first or aabb.size.y < 0.01:
		return
	var s := 1.8 / aabb.size.y
	if s < 0.5 or s > 2.0:
		m.scale *= s


func _tint(m: Node, body: Color, joints: Color) -> void:
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			var nm: String = src.resource_name.to_lower() if src else ""
			var mat := StandardMaterial3D.new()
			var is_joint := nm.find("joint") >= 0
			mat.albedo_color = joints if is_joint else body
			mat.roughness = 0.45 if is_joint else 0.6
			mat.metallic = 0.25 if is_joint else 0.0
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.3
			mi.set_surface_override_material(i, mat)


func _hair(col: Color, style: String) -> void:
	var idx := -1
	for i in skeleton.get_bone_count():
		var bn := skeleton.get_bone_name(i).to_lower()
		if bn.ends_with("head") and bn.find("top") < 0:
			idx = i
			break
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	skeleton.add_child(att)
	att.bone_name = skeleton.get_bone_name(idx)
	var holder := Node3D.new()
	att.add_child(holder)
	# kemik ölçeğini dengele → saç dünya biriminde ~ kafa boyutu
	await get_tree().process_frame
	var ws := att.global_transform.basis.get_scale()
	holder.scale = Vector3.ONE / max(ws.x, 0.0001)
	holder.global_rotation = global_rotation
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.75
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.115
	sm.height = 0.16
	cap.mesh = sm
	cap.material_override = mat
	cap.position = Vector3(0, 0.15, -0.01)
	holder.add_child(cap)
	if style == "braid":
		for k in range(5):
			var b := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.045 - k * 0.004
			bs.height = bs.radius * 2.0
			b.mesh = bs
			b.material_override = mat
			b.position = Vector3(0.06, 0.08 - k * 0.075, -0.07 - k * 0.01)
			holder.add_child(b)
	elif style == "short":
		for k in range(5):
			var sp := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.04
			cm.height = 0.1
			sp.mesh = cm
			sp.material_override = mat
			sp.position = Vector3(-0.06 + k * 0.03, 0.24, -0.02 + (k % 2) * 0.03)
			sp.rotation = Vector3(-0.4, 0, (k - 2) * 0.2)
			holder.add_child(sp)


func play(name: String, blend := 0.25, speed := 1.0) -> void:
	if anim == null:
		cur = name
		return
	var target := name
	if not anim.has_animation(target):
		target = "idle" if anim.has_animation("idle") else (anim.get_animation_list()[0] if anim.get_animation_list().size() > 0 else "")
	if target == "":
		return
	if target != cur:
		anim.play(target, blend)
		cur = target
	anim.speed_scale = speed


func set_motion(speed: float, on_ground := true) -> void:
	if speed < 0.3:
		play("idle", 0.3)
	elif speed < 3.4:
		play("walk", 0.25, clamp(speed / 1.6, 0.7, 1.6))
	else:
		play("run", 0.2, clamp(speed / 5.5, 0.8, 1.4))
	if fallback:
		_animate_fallback(speed)


# ---------------------------------------------------------------- yedek gövde
func _build_fallback(body: Color, joints: Color, hair: Color) -> void:
	fallback = Node3D.new()
	add_child(fallback)
	var parts := {"torso": [Vector3(0.42, 0.6, 0.24), Vector3(0, 1.25, 0), body], "head": [Vector3(0.22, 0.26, 0.24), Vector3(0, 1.7, 0), Color(0.85, 0.65, 0.5)],
		"hair": [Vector3(0.24, 0.1, 0.26), Vector3(0, 1.85, 0), hair], "legL": [Vector3(0.16, 0.85, 0.18), Vector3(0.11, 0.48, 0), joints], "legR": [Vector3(0.16, 0.85, 0.18), Vector3(-0.11, 0.48, 0), joints],
		"armL": [Vector3(0.12, 0.6, 0.13), Vector3(0.29, 1.22, 0), body], "armR": [Vector3(0.12, 0.6, 0.13), Vector3(-0.29, 1.22, 0), body]}
	for k in parts.keys():
		var p = parts[k]
		var pivot := Node3D.new()
		pivot.name = k
		pivot.position = p[1] + Vector3(0, p[0].y * 0.5, 0) if k.begins_with("leg") or k.begins_with("arm") else p[1]
		fallback.add_child(pivot)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.position = Vector3(0, -p[0].y * 0.5, 0) if k.begins_with("leg") or k.begins_with("arm") else Vector3.ZERO
		mi.material_override = Game.paint(p[2], 0.0, 0.5, 0.3)
		pivot.add_child(mi)


func _animate_fallback(speed: float) -> void:
	_phase += get_process_delta_time() * (2.0 + speed * 1.4)
	var a: float = sin(_phase) * clamp(speed / 5.0, 0.0, 1.0) * 0.9
	for k in ["legL", "armR"]:
		fallback.get_node(k).rotation.x = a
	for k in ["legR", "armL"]:
		fallback.get_node(k).rotation.x = -a
