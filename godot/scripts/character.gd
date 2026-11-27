extends Node3D
class_name CharacterVisual
## Oyuncak tarzı karakter görseli + parça iskeleti (kök, bacaklar, gövde, kollar, kafa).
##  • Varsayılan: Kenney "Blocky Characters" (CC0) + kostüm dokusu (Kaan/Ela için özel).
##  • Admin bölümünden yüklenen modeller aynı iskelete bağlanır ve aynı animasyonları oynar:
##      - parça adları olan modeller (head/torso/arm-left…) → doğrudan pivotlara takılır
##      - iskeletli (Mixamo vb.) modeller → kemikler pivotlardan sürülür (PartDriver)
##      - iskeletsiz tek parça modeller → otomatik olarak parçalara bölünür

const SCALE := 0.68            # Kenney birimi (2,7) → ~1,84 m
const RIG_H := 2.7
const LOOPS := ["idle", "walk", "sprint", "sit", "drive", "holding-right", "holding-left", "holding-both", "wheelchair-sit", "static"]
const PARTS := ["root", "leg-left", "leg-right", "torso", "arm-left", "arm-right", "head"]

var anim: AnimationPlayer
var rig: Node3D               # Kenney sahnesinin kökü (animasyonun sürdüğü pivot ağacı)
var pivots := {}              # parça adı → Node3D
var cur := ""
var slot := ""
var mode := "blocky"          # blocky | parts | skinned | split
var driver: Node = null


func setup(slot_id: String, skin := "") -> void:
	slot = slot_id
	for c in get_children():
		c.queue_free()
	pivots.clear()
	cur = ""
	driver = null
	var cfg: Dictionary = Game.slot_cfg(slot_id)
	if cfg.get("type", "") == "glb" and FileAccess.file_exists(cfg.get("path", "")):
		if _build_custom(cfg.path):
			return
		push_warning("Özel model yüklenemedi: " + str(cfg.path))
	var sk := skin
	if cfg.get("type", "") == "skin":
		sk = cfg.get("path", skin)
	_build_blocky(sk)


# ---------------------------------------------------------------- temel iskelet
func _make_rig(hide_meshes: bool) -> bool:
	var sc := Game.blocky_scene()
	if sc == null:
		_build_fallback()
		return false
	rig = sc.instantiate()
	rig.scale = Vector3.ONE * SCALE
	add_child(rig)
	anim = rig.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer if rig.find_children("*", "AnimationPlayer", true, false).size() > 0 else null
	for p in PARTS:
		var n := rig.find_child(p, true, false)
		if n:
			pivots[p] = n
	if hide_meshes:
		for mi in rig.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).mesh = null
	if anim:
		for n in anim.get_animation_list():
			var a := anim.get_animation(n)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR if LOOPS.has(n) else Animation.LOOP_NONE
		play("idle", 0.0)
	return true


func _build_blocky(skin: String) -> void:
	mode = "blocky"
	if not _make_rig(false):
		return
	var tex := Game.load_texture(skin)
	if tex == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.62
	mat.metallic_specular = 0.35
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat


# ---------------------------------------------------------------- özel modeller
func _build_custom(path: String) -> bool:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		return false
	var scene: Node = doc.generate_scene(st)
	if scene == null or not (scene is Node3D):
		return false
	if not _make_rig(true):
		return false
	# modelin kendi animasyonlarını durdur
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
	var holder := Node3D.new()
	holder.name = "custom"
	rig.add_child(holder)
	holder.add_child(scene)
	var skels := scene.find_children("*", "Skeleton3D", true, false)
	var named := _find_named_parts(scene)
	if skels.size() > 0:
		mode = "skinned"
		_fit(holder, scene, skels[0] as Skeleton3D)
		var d := PartDriver.new()
		d.setup(skels[0] as Skeleton3D, self)
		(skels[0] as Skeleton3D).add_child(d)
		driver = d
	elif named.size() >= 4:
		mode = "parts"
		_fit(holder, scene, null)
		_attach_named(named)
	else:
		mode = "split"
		_fit(holder, scene, null)
		_auto_split(holder)
	_strip_position_tracks()
	return true


func _meshes(n: Node) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false)


func _aabb_in(space: Node3D, n: Node) -> AABB:
	var inv := space.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mi in _meshes(n):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var bb: AABB = m.mesh.get_aabb()
		var xf: Transform3D = inv * m.global_transform
		for i in range(8):
			var p: Vector3 = xf * bb.get_endpoint(i)
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


func _fit(holder: Node3D, scene: Node3D, sk: Skeleton3D) -> void:
	## modeli iskelet ölçüsüne (2,7 birim boy) getir, ayakları zemine ve merkeze oturt
	var box := _aabb_in(rig, scene)
	var h := box.size.y
	var bottom := box.position.y
	if sk:
		# iskeletli modellerde mesh AABB'si güvenilmez → kemik konumları
		var lo := INF
		var hi := -INF
		for i in sk.get_bone_count():
			var p: Vector3 = rig.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_rest(i).origin)
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		if hi > lo:
			h = (hi - lo) * 1.1
			bottom = lo - (hi - lo) * 0.02
	if h < 0.0001:
		return
	var s := RIG_H / h
	holder.scale = Vector3.ONE * s
	var c := box.get_center()
	holder.position = Vector3(-c.x * s, -bottom * s, -c.z * s)


func _find_named_parts(scene: Node) -> Dictionary:
	var out := {}
	var keys := {"head": ["head", "kafa"], "torso": ["torso", "body", "chest", "govde", "gövde"],
		"arm-left": ["arm-left", "arm_left", "armleft", "leftarm", "arm.l", "arm_l", "sol_kol", "solkol"],
		"arm-right": ["arm-right", "arm_right", "armright", "rightarm", "arm.r", "arm_r", "sag_kol", "sagkol"],
		"leg-left": ["leg-left", "leg_left", "legleft", "leftleg", "leg.l", "leg_l", "sol_bacak"],
		"leg-right": ["leg-right", "leg_right", "legright", "rightleg", "leg.r", "leg_r", "sag_bacak"]}
	for n in scene.find_children("*", "Node3D", true, false):
		var nm := String(n.name).to_lower()
		for k in keys.keys():
			if out.has(k):
				continue
			for pat in keys[k]:
				if nm == pat or nm.begins_with(pat):
					out[k] = n
					break
	return out


func _attach_named(named: Dictionary) -> void:
	for k in named.keys():
		if not pivots.has(k):
			continue
		var src: Node3D = named[k]
		var pv: Node3D = pivots[k]
		var gx := src.global_transform
		src.get_parent().remove_child(src)
		pv.add_child(src)
		src.global_transform = gx


func _auto_split(holder: Node3D) -> void:
	## iskeletsiz modeli boy oranlarından bacak / gövde / kol / kafa parçalarına böl
	var inv := rig.global_transform.affine_inverse()
	var tris := []   # [Vector3 a,b,c (rig uzayı), normal'lar, uv'ler, malzeme]
	var verts := PackedVector3Array()
	for mi in _meshes(holder):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf: Transform3D = inv * m.global_transform
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm = arr[Mesh.ARRAY_NORMAL]
			var uv = arr[Mesh.ARRAY_TEX_UV]
			var idx = arr[Mesh.ARRAY_INDEX]
			var mat: Material = m.get_active_material(s)
			var ids: PackedInt32Array = idx if idx != null and idx.size() > 0 else PackedInt32Array(range(v.size()))
			for t in range(0, ids.size() - 2, 3):
				var tri := []
				for k in range(3):
					var i: int = ids[t + k]
					var p: Vector3 = xf * v[i]
					verts.append(p)
					var nn: Vector3 = (xf.basis * nrm[i]).normalized() if nrm != null and nrm.size() > i else Vector3.UP
					var tt: Vector2 = uv[i] if uv != null and uv.size() > i else Vector2.ZERO
					tri.append([p, nn, tt])
				tri.append(mat)
				tris.append(tri)
	if tris.is_empty():
		return
	var lm := _landmarks(verts)
	var crotch: float = lm.crotch
	var torso_hw: float = lm.torso_hw
	var neck: float = lm.neck
	# pivotları bu modelin oranlarına taşı (animasyonlar yalnızca dönüş kullanır)
	var k := crotch / 1.0
	var torso_y := 0.7 * k
	pivots["leg-left"].position = Vector3(torso_hw * 0.5, crotch, 0)
	pivots["leg-right"].position = Vector3(-torso_hw * 0.5, crotch, 0)
	pivots["torso"].position = Vector3(0, torso_y, 0)
	pivots["arm-left"].position = Vector3(torso_hw, neck - 0.08 - torso_y, 0)
	pivots["arm-right"].position = Vector3(-torso_hw, neck - 0.08 - torso_y, 0)
	pivots["head"].position = Vector3(0, neck - torso_y, 0)
	var groups := {}
	for tri in tris:
		var c: Vector3 = (tri[0][0] + tri[1][0] + tri[2][0]) / 3.0
		var part := "torso"
		if c.y >= neck and abs(c.x) <= torso_hw * 1.4:
			part = "head"
		elif abs(c.x) > torso_hw and c.y > crotch * 0.9 and c.y < neck + 0.1:
			part = "arm-left" if c.x > 0 else "arm-right"
		elif c.y < crotch:
			part = "leg-left" if c.x > 0 else "leg-right"
		if not groups.has(part):
			groups[part] = {}
		var mat: Material = tri[3]
		if not groups[part].has(mat):
			groups[part][mat] = []
		groups[part][mat].append(tri)
	for part in groups.keys():
		var pv: Node3D = pivots[part]
		var origin: Vector3 = pv.global_position
		origin = inv * origin
		var am := ArrayMesh.new()
		for mat in groups[part].keys():
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for tri in groups[part][mat]:
				for kk in range(3):
					st.set_normal(tri[kk][1])
					st.set_uv(tri[kk][2])
					st.add_vertex(tri[kk][0] - origin)
			if mat:
				st.set_material(mat)
			st.commit(am)
		var out := MeshInstance3D.new()
		out.mesh = am
		pv.add_child(out)
	holder.queue_free()


func _landmarks(verts: PackedVector3Array) -> Dictionary:
	var H := RIG_H
	# kasık: alttan yukarı, ortada (|x| küçük) nokta bulunmayan en yüksek dilim
	var crotch := 0.45 * H
	var step := 0.02 * H
	var y := 0.08 * H
	var last_gap := -1.0
	while y < 0.62 * H:
		var hit := false
		for p in verts:
			if p.y >= y and p.y < y + step and abs(p.x) < 0.025 * H:
				hit = true
				break
		if not hit:
			last_gap = y + step
		elif last_gap > 0.0:
			break
		y += step
	if last_gap > 0.15 * H:
		crotch = last_gap
	# gövde yarı genişliği: kasık-boyun bandında |x| histogramındaki ilk boşluk
	var bins := PackedInt32Array()
	bins.resize(60)
	for p in verts:
		if p.y > crotch + 0.05 * H and p.y < 0.8 * H:
			var b := int(abs(p.x) / (0.01 * H))
			if b < 60:
				bins[b] += 1
	var torso_hw := 0.17 * H
	var seen := false
	for b in range(60):
		if bins[b] > 0:
			seen = true
		elif seen and b > 5:
			torso_hw = b * 0.01 * H
			break
	# boyun: gövde genişliği içindeki en dar dilim (0,62H–0,92H)
	var neck := 0.8 * H
	var best := INF
	var widest := 0.0
	y = 0.62 * H
	while y < 0.92 * H:
		var w := 0.0
		for p in verts:
			if p.y >= y and p.y < y + step and abs(p.x) <= torso_hw * 1.05:
				w = maxf(w, abs(p.x))
		if w > 0.0 and w < best:
			best = w
			neck = y + step * 0.5
		widest = maxf(widest, w)
		y += step
	if widest > 0.0 and best > widest * 0.9:
		neck = 0.74 * H
	return {"crotch": crotch, "torso_hw": torso_hw, "neck": neck}


func _strip_position_tracks() -> void:
	## özel modellerde pivot konumları değiştiği için yalnızca kök konum izini bırak
	if anim == null:
		return
	for ln in anim.get_animation_library_list():
		var lib := anim.get_animation_library(ln).duplicate(true) as AnimationLibrary
		for an in lib.get_animation_list():
			var a := lib.get_animation(an)
			for t in range(a.get_track_count() - 1, -1, -1):
				var path := String(a.track_get_path(t))
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D and not path.ends_with("root"):
					a.remove_track(t)
		anim.remove_animation_library(ln)
		anim.add_animation_library(ln, lib)


# ---------------------------------------------------------------- animasyon
func play(name: String, blend := 0.2, speed := 1.0) -> void:
	if anim == null:
		cur = name
		return
	var target := name
	if not anim.has_animation(target):
		target = "idle"
		if not anim.has_animation(target):
			return
	if target != cur:
		anim.play(target, blend)
		cur = target
	anim.speed_scale = speed


func play_once(name: String, blend := 0.1, speed := 1.0) -> void:
	cur = ""
	play(name, blend, speed)


func set_motion(speed: float, on_ground := true) -> void:
	if not on_ground:
		play("walk", 0.2, 0.4)
	elif speed < 0.3:
		play("idle", 0.25)
	elif speed < 3.6:
		play("walk", 0.2, clamp(speed / 1.5, 0.7, 2.0))
	else:
		play("sprint", 0.2, clamp(speed / 5.0, 0.8, 1.6))


# ---------------------------------------------------------------- model yoksa yedek
func _build_fallback() -> void:
	mode = "fallback"
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.8
	mi.mesh = cm
	mi.position.y = 0.9
	add_child(mi)
