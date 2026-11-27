extends Node3D
class_name CharacterVisual
## Karakter görseli + parça iskeleti + gerçekçi animasyonlar (AnimLib / UAL, CC0).
##  • Varsayılan: Kenney "Blocky Characters" (CC0) + kostüm dokusu (Kaan/Ela için özel)
##  • Admin bölümünden yüklenen modeller (Element Arenası'ndaki sistemle aynı mantık):
##      - parça adları olan modeller (arm_R, leg_L, hips…) → doğrudan eklemlere takılır
##      - iskeletli modeller → kemiklere UAL animasyonları aktarılır (yoksa kendi animasyonları)
##      - iskeletsiz tek parça modeller → kollar/bacaklar otomatik bulunup ayrılır (ModelImport)

const SCALE := 0.68            # Kenney birimi (2,7) → ~1,84 m
const RIG_H := 2.7
const KENNEY_LOOPS := ["idle", "walk", "sprint", "sit", "drive", "holding-right", "holding-left", "holding-both", "static"]
const PARTS := ["root", "leg-left", "leg-right", "torso", "arm-left", "arm-right", "head"]
## bulunamayan animasyon için yedekler
const FALLBACK := {"jog": "sprint", "crouch_idle": "idle", "crouch_walk": "walk", "jump": "walk", "jump_start": "walk", "land": "idle",
	"punch_jab": "attack-melee-right", "punch_cross": "attack-melee-left", "sword_a": "attack-melee-right", "sword_b": "attack-melee-left",
	"sword_c": "attack-melee-right", "sword_attack": "attack-melee-right", "hit": "idle", "knockback": "die", "talk": "idle", "phone": "idle",
	"block": "idle", "throw": "attack-melee-right", "spell": "attack-melee-right", "kick": "attack-kick-right", "consume": "pick-up"}
## yürüme döngüsünün doğal hızı (m/s) — ayak kaymasın diye oynatma hızı buna göre ölçeklenir
const NOMINAL := {"walk": 1.15, "jog": 2.8, "sprint": 4.6, "crouch_walk": 0.9, "swim": 1.4}

static var _seg_cache := {}    # model yolu → segmentasyon sonucu

var anim: AnimationPlayer
var rig: Node3D               # Kenney sahnesinin kökü (animasyonun sürdüğü pivot ağacı)
var pivots := {}
var cur := ""
var slot := ""
var mode := "blocky"          # blocky | parts | split | skinned | own | fallback
var prefix := ""              # iskeletli modellerde "ual/"
var own := {}                 # kendi animasyonlu modellerde eşleme
var crouch := false
var leg_len := 1.0
var note := ""


func setup(slot_id: String, skin := "") -> void:
	slot = slot_id
	for c in get_children():
		c.queue_free()
	pivots.clear()
	cur = ""
	prefix = ""
	own.clear()
	note = ""
	var cfg: Dictionary = Game.slot_cfg(slot_id)
	if cfg.get("type", "") == "glb" and FileAccess.file_exists(cfg.get("path", "")):
		if _build_custom(cfg.path, bool(cfg.get("flip", false))):
			return
		push_warning("Özel model yüklenemedi: " + str(cfg.path))
		note = "Model okunamadı, varsayılan karakter kullanılıyor."
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
	var aps := rig.find_children("*", "AnimationPlayer", true, false)
	anim = aps[0] as AnimationPlayer if aps.size() > 0 else null
	for p in PARTS:
		var nd := rig.find_child(p, true, false)
		if nd:
			pivots[p] = nd
	if hide_meshes:
		for mi in rig.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).mesh = null
	if anim:
		AnimLib.bake_blocky(get_tree(), anim)
		for nm in anim.get_animation_list():
			var a := anim.get_animation(nm)
			if a and KENNEY_LOOPS.has(String(nm)) and not AnimLib.WANT.has(String(nm)):
				a.loop_mode = Animation.LOOP_LINEAR
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
func _build_custom(path: String, flip: bool) -> bool:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		return false
	var scene: Node = doc.generate_scene(st)
	if scene == null or not (scene is Node3D):
		return false
	var skels := scene.find_children("*", "Skeleton3D", true, false)
	var skinned := false
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin != null or String((mi as MeshInstance3D).skeleton) != "":
			skinned = true
	if skels.size() > 0 and skinned:
		return _build_skinned(scene, skels[0] as Skeleton3D, path, flip)
	return _build_static(scene, path, flip)


func _flat_surfaces(scene: Node3D) -> Array:
	## tüm yüzeyleri sahne kökü uzayına düzleştir: [{pos, nor, uv, idx, mat, name}]
	var tmp := Node3D.new()
	add_child(tmp)
	tmp.add_child(scene)
	var inv := scene.global_transform.affine_inverse()
	var out := []
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf: Transform3D = inv * m.global_transform
		var nm := String(m.name)
		var pn := m.get_parent()
		if pn and String(pn.name) != "" and pn != scene:
			nm = String(pn.name) + "|" + nm
		for s in m.mesh.get_surface_count():
			if m.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr := m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr = arr[Mesh.ARRAY_NORMAL]
			var uv = arr[Mesh.ARRAY_TEX_UV]
			var ix = arr[Mesh.ARRAY_INDEX]
			var pos := PackedVector3Array()
			pos.resize(v.size())
			var nor := PackedVector3Array()
			nor.resize(v.size())
			for i in v.size():
				pos[i] = xf * v[i]
				nor[i] = (xf.basis * (nr[i] if nr != null and nr.size() > i else Vector3.UP)).normalized()
			var idx: PackedInt32Array
			if ix != null and (ix as PackedInt32Array).size() > 0:
				idx = ix
			else:
				idx = PackedInt32Array()
				idx.resize(v.size())
				for i in v.size():
					idx[i] = i
			out.append({"pos": pos, "nor": nor, "uv": uv if uv != null else PackedVector2Array(), "idx": idx, "mat": m.get_active_material(s), "name": nm})
	tmp.remove_child(scene)
	tmp.queue_free()
	return out


func _build_static(scene: Node3D, path: String, flip: bool) -> bool:
	var surfs := _flat_surfaces(scene)
	scene.queue_free()
	if surfs.is_empty():
		return false
	# boyutlandır: boy RIG_H, ayak y=0, merkez x/z=0, yüz +Z (gerekirse çevir)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for s in surfs:
		for p in s.pos:
			lo = lo.min(p)
			hi = hi.max(p)
	var h := hi.y - lo.y
	if h < 1e-5:
		return false
	var k := RIG_H / h
	var cx := (lo.x + hi.x) * 0.5
	var cz := (lo.z + hi.z) * 0.5
	var geoms := []
	for s in surfs:
		var pos: PackedVector3Array = s.pos
		var nor: PackedVector3Array = s.nor
		for i in pos.size():
			var p: Vector3 = (pos[i] - Vector3(cx, lo.y, cz)) * k
			if flip:
				p = Vector3(-p.x, p.y, -p.z)
				nor[i] = Vector3(-nor[i].x, nor[i].y, -nor[i].z)
			pos[i] = p
		s.pos = pos
		s.nor = nor
		geoms.append({"pos": pos, "idx": s.idx})
	# önce adlandırılmış parçalar, sonra otomatik ayırma
	var names := []
	for s in surfs:
		names.append(s.name)
	var named := ModelImport.named_labels(names)
	var seg: Dictionary
	var key := path + ("|f" if flip else "")
	if not named.is_empty():
		mode = "parts"
		seg = _named_seg(geoms, named)
	elif _seg_cache.has(key):
		seg = _seg_cache[key]
		mode = "split"
	else:
		var mi := ModelImport.new()
		mi.H = RIG_H
		seg = mi.segment(geoms)
		_seg_cache[key] = seg
		mode = "split"
	if not _make_rig(true):
		return false
	var piv: Dictionary = seg.get("piv", {})
	if not seg.get("ok", false):
		note = "Kollar ve bacaklar ayırt edilemedi; model bütün gövdesiyle hareket ediyor."
	# eklem konumları (rig birimi; Kenney pivot ağacı: root → bacaklar, torso → kollar/kafa)
	var legY: float = (piv.legR.p.y + 0.02 * RIG_H) if piv.has("legR") else 1.0
	leg_len = legY
	var tY: float = piv.waist if piv.get("waist") != null else legY + 0.04 * RIG_H
	(pivots["torso"] as Node3D).position = Vector3(0, tY, 0)
	(pivots["head"] as Node3D).position = Vector3(0, RIG_H, 0) - Vector3(0, tY, 0)
	var frames := {0: Vector3(0, tY, 0), 5: Vector3.ZERO}
	var attach := {0: pivots["torso"], 5: pivots["root"]}
	for spec in [["armR", 1, "arm-right"], ["armL", 2, "arm-left"], ["legR", 3, "leg-right"], ["legL", 4, "leg-left"]]:
		if not piv.has(spec[0]):
			continue
		var pw: Vector3 = piv[spec[0]].p
		var pv: Node3D = pivots[spec[2]]
		var parent_world: Vector3 = Vector3(0, tY, 0) if spec[1] <= 2 else Vector3.ZERO
		pv.position = pw - parent_world
		frames[spec[1]] = pw
		var holder: Node3D = pv
		# T-pozdaki kolu aşağı indir (animasyonlar sarkan kola göre)
		if spec[1] <= 2 and piv[spec[0]].has("h"):
			var dir: Vector3 = piv[spec[0]].h - pw
			if dir.length() > 0.05 and atan2(abs(dir.x), maxf(0.01, -dir.y)) > 0.6:
				var fix := Node3D.new()
				fix.basis = Basis(AnimLib._arc(dir, Vector3.DOWN))
				pv.add_child(fix)
				holder = fix
		attach[spec[1]] = holder
	var tl: Array = seg.get("tl", [])
	for gi in surfs.size():
		var s: Dictionary = surfs[gi]
		var labels: PackedByteArray = tl[gi] if gi < tl.size() else PackedByteArray()
		var by := {}
		var ix: PackedInt32Array = s.idx
		for t in ix.size() / 3:
			var L: int = labels[t] if t < labels.size() else 0
			if not attach.has(L):
				L = 0
			if not by.has(L):
				by[L] = []
			by[L].append(t)
		for L in by.keys():
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var origin: Vector3 = frames.get(L, frames[0])
			var uv: PackedVector2Array = s.uv
			for t in by[L]:
				for e in 3:
					var vi: int = ix[t * 3 + e]
					st.set_normal(s.nor[vi])
					if uv.size() > vi:
						st.set_uv(uv[vi])
					st.add_vertex(s.pos[vi] - origin)
			if s.mat:
				st.set_material(s.mat)
			var am := st.commit()
			var out := MeshInstance3D.new()
			out.mesh = am
			(attach[L] as Node3D).add_child(out)
	_adapt_tracks()
	return true


func _named_seg(geoms: Array, labels: Array) -> Dictionary:
	## Element Arenası namedSeg: parça adlarından etiket + eklem noktaları
	var tl := []
	var V := {}
	for gi in geoms.size():
		var L: int = labels[gi]
		var nt: int = (geoms[gi].idx as PackedInt32Array).size() / 3
		var b := PackedByteArray()
		b.resize(nt)
		b.fill(L)
		tl.append(b)
		if not V.has(L):
			V[L] = []
		V[L].append(geoms[gi].pos)
	var piv := {}
	var ext := func(L) -> Vector2:
		var mn := 1e9
		var mx := -1e9
		for p in V.get(L, []):
			for v in p:
				mn = minf(mn, v.y)
				mx = maxf(mx, v.y)
		return Vector2(mn, mx)
	var band := func(L, lo: float, hi: float):
		var s := Vector3.ZERO
		var k := 0
		for p in V.get(L, []):
			for v in p:
				if v.y >= lo and v.y <= hi:
					s += v
					k += 1
		return s / k if k > 0 else null
	var leg_top := -1e9
	for spec in [[1, "armR"], [2, "armL"]]:
		if not V.has(spec[0]):
			continue
		var e: Vector2 = ext.call(spec[0])
		var top = band.call(spec[0], e.y - 0.06 * RIG_H, e.y)
		var hc = band.call(spec[0], e.x, e.x + 0.07 * RIG_H)
		if top != null:
			piv[spec[1]] = {"p": Vector3(top.x, e.y - 0.035 * RIG_H, top.z), "h": hc if hc != null else top}
	for spec in [[3, "legR"], [4, "legL"]]:
		if not V.has(spec[0]):
			continue
		var e: Vector2 = ext.call(spec[0])
		var top = band.call(spec[0], e.y - 0.05 * RIG_H, e.y)
		if top != null:
			leg_top = maxf(leg_top, e.y)
			piv[spec[1]] = {"p": Vector3(top.x, e.y - 0.02 * RIG_H, top.z)}
	piv["waist"] = leg_top + 0.03 * RIG_H if leg_top > -1e9 else null
	return {"ok": true, "tl": tl, "piv": piv}


func _adapt_tracks() -> void:
	## özel modelin bacak boyuna göre kök yüksekliği izini ölçekle, diğer konum izlerini kaldır
	if anim == null:
		return
	var s := leg_len / 1.0
	for ln in anim.get_animation_library_list():
		var lib := anim.get_animation_library(ln).duplicate(true) as AnimationLibrary
		for an in lib.get_animation_list():
			var a := lib.get_animation(an)
			for t in range(a.get_track_count() - 1, -1, -1):
				if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
					continue
				var p := String(a.track_get_path(t))
				if not p.get_slice(":", 0).ends_with("root"):
					a.remove_track(t)
					continue
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) * s)
		anim.remove_animation_library(ln)
		anim.add_animation_library(ln, lib)


func _build_skinned(scene: Node3D, sk: Skeleton3D, path: String, flip: bool) -> bool:
	mode = "skinned"
	var holder := Node3D.new()
	holder.name = "custom"
	add_child(holder)
	holder.add_child(scene)
	# boyutlandır (kemik konumlarına göre)
	var lo := INF
	var hi := -INF
	var inv := holder.global_transform.affine_inverse()
	var cx := 0.0
	var cz := 0.0
	for i in sk.get_bone_count():
		var p: Vector3 = inv * (sk.global_transform * sk.get_bone_global_rest(i).origin)
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		cx += p.x
		cz += p.z
	cx /= maxf(1, sk.get_bone_count())
	cz /= maxf(1, sk.get_bone_count())
	var h := (hi - lo) * 1.08
	if h < 1e-5:
		return false
	var k := RIG_H * SCALE / h
	holder.scale = Vector3.ONE * k
	holder.position = Vector3(-cx * k, -(lo - (hi - lo) * 0.02) * k, -cz * k)
	if flip:
		holder.rotation.y = PI
		holder.position = Vector3(cx * k, holder.position.y, cz * k)
	var aps := scene.find_children("*", "AnimationPlayer", true, false)
	anim = aps[0] as AnimationPlayer if aps.size() > 0 else null
	var own_names := []
	if anim:
		anim.stop()
		own_names = anim.get_animation_list()
	else:
		anim = AnimationPlayer.new()
		scene.add_child(anim)
		anim.root_node = anim.get_path_to(scene)
	var mapped := AnimLib.bake_skinned(get_tree(), path, scene, sk, anim)
	if mapped >= 8:
		prefix = "ual/"
		note = "İskeletli model: %d kemik eşlendi, oyunun tüm animasyonları aktarıldı." % mapped
	elif own_names.size() > 0:
		mode = "own"
		# Element Arenası gibi: modelin kendi animasyonlarını adlarına göre eşle
		var pick := func(re_s: String) -> String:
			var re := RegEx.new()
			re.compile("(?i)" + re_s)
			for nm in own_names:
				if re.search(String(nm)):
					return nm
			return ""
		own = {"idle": pick.call("idle|stand|breath|wait"), "walk": pick.call("walk"), "jog": pick.call("run|jog"), "sprint": pick.call("run|sprint|jog"),
			"attack": pick.call("attack|punch|slash|kick|strike|combat|fight|hit")}
		if own.idle == "":
			own.idle = own_names[0]
		for nm in own_names:
			var a := anim.get_animation(nm)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
		note = "İskeletli model: kendi animasyonları kullanılıyor (%d adet)." % own_names.size()
	else:
		note = "İskeleti tanınamadı ve animasyonu yok; model sabit duruyor."
	play("idle", 0.0)
	return true


# ---------------------------------------------------------------- animasyon
func _resolve(name: String) -> String:
	if anim == null:
		return ""
	if mode == "own":
		var m: String = own.get(name, "")
		if m == "" and (name.begins_with("punch") or name.begins_with("sword") or name.contains("kick")):
			m = own.get("attack", "")
		if m == "":
			m = own.get("walk", "") if name.contains("walk") or name == "jog" else own.get("idle", "")
		return m
	if anim.has_animation(prefix + name):
		return prefix + name
	var fb: String = FALLBACK.get(name, "")
	if fb != "" and anim.has_animation(prefix + fb):
		return prefix + fb
	if anim.has_animation(prefix + "idle"):
		return prefix + "idle"
	return ""


func play(name: String, blend := 0.2, speed := 1.0) -> void:
	var target := _resolve(name)
	if target == "":
		cur = name
		return
	if target != cur:
		anim.play(target, blend)
		cur = target
	anim.speed_scale = speed


func play_once(name: String, blend := 0.1, speed := 1.0) -> void:
	cur = ""
	play(name, blend, speed)


func has_anim(name: String) -> bool:
	return anim != null and anim.has_animation(prefix + name)


func anim_length(name: String) -> float:
	var t := _resolve(name)
	return anim.get_animation(t).length if t != "" else 0.5


func set_motion(speed: float, on_ground := true) -> void:
	var k := 1.0 if mode == "skinned" else 0.75
	if not on_ground:
		play("jump", 0.2)
	elif crouch:
		if speed < 0.25:
			play("crouch_idle", 0.25)
		else:
			play("crouch_walk", 0.2, clampf(speed / (NOMINAL.crouch_walk * k), 0.6, 2.0))
	elif speed < 0.3:
		play("idle", 0.3)
	elif speed < 2.2:
		play("walk", 0.25, clampf(speed / (NOMINAL.walk * k), 0.6, 1.5))
	elif speed < 5.4:
		play("jog", 0.25, clampf(speed / (NOMINAL.jog * k), 0.7, 1.4))
	else:
		play("sprint", 0.25, clampf(speed / (NOMINAL.sprint * k), 0.8, 1.35))


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
