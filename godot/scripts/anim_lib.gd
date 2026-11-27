extends RefCounted
class_name AnimLib
## Gerçekçi animasyon kütüphanesi: Quaternius "Universal Animation Library" 1 + 2 (CC0).
## Kaynak iskeletteki hareket, açılışta bir kez "pişirilir" (her kare örneklenir):
##  • Oyuncak (bloklu) karakterler: kol/bacak/gövde/kafa pivotlarına yön tabanlı aktarım
##    (bacak = kalça→ayak yönü, kol = omuz→el yönü; ayak yere basacak şekilde kalça yüksekliği)
##  • İçe aktarılan iskeletli modeller: insansı kemik eşlemesi + dinlenme pozu hizalamasıyla
##    kemik dönüşleri aktarılır (dirsek/diz dahil).
## Sonuç standart Animation kaynaklarıdır; çalışırken ek maliyet yoktur.

const FPS := 30.0
## oyun adı: [kaynak kütüphane (1|2), kaynak animasyon, döngü]
const WANT := {
	"idle": [1, "Idle_Loop", true], "walk": [1, "Walk_Loop", true], "jog": [1, "Jog_Fwd_Loop", true], "sprint": [1, "Sprint_Loop", true],
	"crouch_idle": [1, "Crouch_Idle_Loop", true], "crouch_walk": [1, "Crouch_Fwd_Loop", true],
	"jump_start": [1, "Jump_Start", false], "jump": [1, "Jump_Loop", true], "land": [1, "Jump_Land", false],
	"punch_jab": [1, "Punch_Jab", false], "punch_cross": [1, "Punch_Cross", false], "sword_attack": [1, "Sword_Attack", false], "sword_idle": [1, "Sword_Idle", true],
	"drive": [1, "Driving_Loop", true], "die": [1, "Death01", false], "hit": [1, "Hit_Chest", false], "hit_head": [1, "Hit_Head", false], "roll": [1, "Roll", false],
	"swim": [1, "Swim_Fwd_Loop", true], "swim_idle": [1, "Swim_Idle_Loop", true], "sit": [1, "Sitting_Idle_Loop", true], "talk": [1, "Idle_Talking_Loop", true],
	"interact": [1, "Interact", false], "pickup": [1, "PickUp_Table", false], "dance": [1, "Dance_Loop", true], "spell": [1, "Spell_Simple_Shoot", false],
	"spell_idle": [1, "Spell_Simple_Idle_Loop", true], "pistol_idle": [1, "Pistol_Idle_Loop", true], "pistol_shoot": [1, "Pistol_Shoot", false], "push": [1, "Push_Loop", true],
	"walk_formal": [1, "Walk_Formal_Loop", true], "fix": [1, "Fixing_Kneeling", true],
	"sword_a": [2, "Sword_Regular_A", false], "sword_b": [2, "Sword_Regular_B", false], "sword_c": [2, "Sword_Regular_C", false], "sword_combo": [2, "Sword_Regular_Combo", false],
	"block": [2, "Sword_Block", true], "hook": [2, "Melee_Hook", false], "throw": [2, "OverhandThrow", false], "knockback": [2, "Hit_Knockback", false],
	"ninja_jump_start": [2, "NinjaJump_Start", false], "ninja_jump": [2, "NinjaJump_Idle_Loop", true], "ninja_land": [2, "NinjaJump_Land", false],
	"phone": [2, "Idle_TalkingPhone_Loop", true], "consume": [2, "Consume", false], "fold_arms": [2, "Idle_FoldArms_Loop", true],
	"get_up": [2, "LayToIdle", false], "slide": [2, "Slide_Loop", true], "yes": [2, "Yes", false], "no": [2, "Idle_No_Loop", false],
}
const CANON := ["hips", "spine", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r",
	"thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const CHILD := {"hips": "spine", "spine": "chest", "chest": "neck", "neck": "head", "upperarm_l": "forearm_l", "forearm_l": "hand_l",
	"upperarm_r": "forearm_r", "forearm_r": "hand_r", "thigh_l": "shin_l", "shin_l": "foot_l", "thigh_r": "shin_r", "shin_r": "foot_r"}

static var _src := {}            # 1|2 → {root, sk, ap, map, rest}
static var _blocky_done := false
static var _holder: Node3D
static var _cache := {}          # model yolu → AnimationLibrary


static func available() -> bool:
	return ResourceLoader.exists("res://assets/anim/ual1.glb")


static func _norm(n: String) -> String:
	var out := ""
	for ch in n.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


static func _side(n: String) -> int:
	## 1 = sol, -1 = sağ, 0 = belirsiz (n: ham ad, küçük harf)
	var s := n.to_lower()
	if s.contains("left") or s.ends_with(".l") or s.ends_with("_l") or s.ends_with("-l") or s.ends_with(" l") or s.begins_with("l_") or s.begins_with("l.") or s.contains("_l_") or s.ends_with("l") and s.ends_with("_l"):
		return 1
	if s.contains("right") or s.ends_with(".r") or s.ends_with("_r") or s.ends_with("-r") or s.ends_with(" r") or s.begins_with("r_") or s.begins_with("r.") or s.contains("_r_"):
		return -1
	return 0


static func map_humanoid(sk: Skeleton3D) -> Dictionary:
	## herhangi bir insansı iskeleti ortak adlara eşle (Mixamo, UE, Rigify, Blender, UAL…)
	var m := {}
	var n := sk.get_bone_count()
	var spines := []
	for i in n:
		var raw := sk.get_bone_name(i).to_lower()
		for pre in ["mixamorig:", "mixamorig_", "mixamorig", "def-", "def_", "bip01_", "bip01 ", "armature_", "org-"]:
			if raw.begins_with(pre):
				raw = raw.substr(pre.length())
		var k := _norm(raw)
		var sd := _side(raw)
		if k.contains("thumb") or k.contains("index") or k.contains("middle") or k.contains("ring") or k.contains("pinky") or k.contains("finger") or k.contains("leaf") or k.contains("end") or k.contains("twist") or k.contains("eye") or k.contains("jaw") or k.contains("toe") or k.contains("ball"):
			continue
		if k in ["hips", "pelvis", "hip"] and not m.has("hips"):
			m.hips = i
		elif k.begins_with("spine") or k.contains("chest") or k == "torso":
			spines.append(i)
		elif k.begins_with("neck") and not m.has("neck"):
			m.neck = i
		elif k == "head" and not m.has("head"):
			m.head = i
		elif sd != 0:
			var suf := "_l" if sd > 0 else "_r"
			if k.contains("shoulder") or k.contains("clavicle"):
				continue
			if (k.contains("forearm") or k.contains("lowerarm") or k.contains("elbow")) and not m.has("forearm" + suf):
				m["forearm" + suf] = i
			elif (k.contains("upperarm") or k.contains("arm")) and not k.contains("fore") and not k.contains("lower") and not m.has("upperarm" + suf):
				m["upperarm" + suf] = i
			elif k.contains("hand") and not m.has("hand" + suf):
				m["hand" + suf] = i
			elif (k.contains("upleg") or k.contains("thigh") or k.contains("upperleg")) and not m.has("thigh" + suf):
				m["thigh" + suf] = i
			elif (k.contains("calf") or k.contains("shin") or k.contains("lowerleg") or k.contains("knee") or (k.contains("leg") and not k.contains("up"))) and not m.has("shin" + suf):
				m["shin" + suf] = i
			elif (k.contains("foot") or k.contains("ankle")) and not m.has("foot" + suf):
				m["foot" + suf] = i
	if spines.size() > 0:
		m.spine = spines[0]
		m.chest = spines[mini(spines.size() - 1, 2)]
	if not m.has("hips") and spines.size() > 0:
		var p := sk.get_bone_parent(spines[0])
		if p >= 0:
			m.hips = p
	return m


static func _char_xf(root: Node3D, sk: Skeleton3D) -> Transform3D:
	return root.global_transform.affine_inverse() * sk.global_transform


static func _prepare(tree: SceneTree) -> bool:
	if _src.size() > 0:
		return true
	if not available():
		return false
	_holder = Node3D.new()
	_holder.name = "AnimLibKaynak"
	_holder.visible = false
	tree.root.add_child(_holder)
	if not _holder.is_inside_tree():
		# kök düğüm o an çocuklarını kuruyorsa ekleme başarısız olur; sonraki çağrıda yeniden denenir
		_holder.free()
		_holder = null
		return false
	for id in [1, 2]:
		var path := "res://assets/anim/ual%d.glb" % id
		if not ResourceLoader.exists(path):
			continue
		var sc: PackedScene = load(path)
		var root: Node3D = sc.instantiate()
		_holder.add_child(root)
		var sks := root.find_children("*", "Skeleton3D", true, false)
		var aps := root.find_children("*", "AnimationPlayer", true, false)
		if sks.is_empty() or aps.is_empty():
			continue
		var sk := sks[0] as Skeleton3D
		var ap := aps[0] as AnimationPlayer
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).visible = false
		var mp := map_humanoid(sk)
		var xf := _char_xf(root, sk)
		var rest := {}
		for c in mp.keys():
			rest[c] = xf * sk.get_bone_global_rest(mp[c])
		_src[id] = {"root": root, "sk": sk, "ap": ap, "map": mp, "rest": rest, "xf": xf}
	return _src.size() > 0


static func _anim_key(n: String) -> String:
	var k := n.get_slice("/", n.get_slice_count("/") - 1).to_lower()
	if k.ends_with("_loop"):
		k = k.substr(0, k.length() - 5)
	return _norm(k)


static func _anim_name(ap: AnimationPlayer, want: String) -> String:
	## sürümler arasında ad farkı olabilir (ör. "Walk_Loop" ↔ "Walk"); normalize ederek eşle
	var wk := _anim_key(want)
	for n in ap.get_animation_list():
		if String(n) == want or String(n).ends_with("/" + want):
			return n
	for n in ap.get_animation_list():
		if _anim_key(String(n)) == wk:
			return n
	return ""


static func _pose(s: Dictionary, anim: String, t: float) -> Dictionary:
	var ap: AnimationPlayer = s.ap
	if ap.current_animation != anim:
		ap.play(anim)
	ap.seek(t, true)
	var sk: Skeleton3D = s.sk
	var out := {}
	for c in s.map.keys():
		out[c] = s.xf * sk.get_bone_global_pose(s.map[c])
	return out


static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	a = a.normalized()
	b = b.normalized()
	if a.dot(b) < -0.9999:
		return Quaternion(Vector3.FORWARD, PI)
	return Quaternion(a, b)


# ---------------------------------------------------------------- oyuncak karakterler
static func bake_blocky(tree: SceneTree, ap: AnimationPlayer) -> void:
	## Kenney bloklu karakterin animasyon kütüphanesine UAL hareketlerini ekle (bir kez, paylaşılan kaynak)
	if _blocky_done or ap == null or not _prepare(tree):
		return
	_blocky_done = true
	var lib: AnimationLibrary = ap.get_animation_library("")
	if lib == null:
		return
	# pivot düğüm yolları (AnimationPlayer kökünden)
	var base: Node = ap.get_node_or_null(ap.root_node)
	if base == null:
		return
	var paths := {}
	for part in ["root", "torso", "head", "arm-left", "arm-right", "leg-left", "leg-right"]:
		var nd := base.find_child(part, true, false)
		if nd == null:
			return
		paths[part] = String(base.get_path_to(nd))
	for game_name in WANT.keys():
		var w: Array = WANT[game_name]
		if not _src.has(w[0]):
			continue
		var s: Dictionary = _src[w[0]]
		var an := _anim_name(s.ap, w[1])
		if an == "":
			continue
		var src_anim: Animation = (s.ap as AnimationPlayer).get_animation(an)
		var a := _bake_blocky_anim(s, an, src_anim.length, paths)
		a.loop_mode = Animation.LOOP_LINEAR if w[2] else Animation.LOOP_NONE
		if lib.has_animation(game_name):
			lib.remove_animation(game_name)
		lib.add_animation(game_name, a)


static func _bake_blocky_anim(s: Dictionary, an: String, length: float, paths: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = maxf(length, 0.05)
	var tr := {}
	for part in ["torso", "head", "arm-left", "arm-right", "leg-left", "leg-right"]:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(String(paths[part])))
		tr[part] = t
	var tpos := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(tpos, NodePath(String(paths["root"])))
	var rest: Dictionary = s.rest
	var has := func(k): return rest.has(k)
	if not (has.call("thigh_l") and has.call("foot_l") and has.call("thigh_r") and has.call("foot_r") and has.call("chest")):
		return a
	var src_leg: float = (rest.foot_l.origin - rest.thigh_l.origin).length()
	var rest_foot_y: float = minf(rest.foot_l.origin.y, rest.foot_r.origin.y)
	var L := 1.0                      # Kenney bacak boyu (pivot y=1 → ayak y=0)
	var k := L / maxf(src_leg, 0.01)
	var n := int(ceil(a.length * FPS))
	for f in range(n + 1):
		var time := minf(f / FPS, a.length)
		var p := _pose(s, an, time)
		# gövde: omurga çizgisinin yönü (kalça→boyun) + göğsün yatay dönüşü; katı blokta abartmasın diye yumuşatılır
		var top_k: String = "neck" if p.has("neck") and rest.has("neck") else "chest"
		var spine_rest: Vector3 = rest[top_k].origin - rest.hips.origin
		var spine_cur: Vector3 = p[top_k].origin - p.hips.origin
		var chest_d: Quaternion = (p.chest.basis * rest.chest.basis.inverse()).get_rotation_quaternion()
		var swing := Quaternion.IDENTITY.slerp(_arc(spine_rest, spine_cur), 0.85)
		var torso_q: Quaternion = swing * Quaternion(Vector3.UP, chest_d.get_euler().y * 0.8)
		a.rotation_track_insert_key(tr.torso, time, torso_q)
		if p.has("head") and rest.has("head"):
			var hq: Quaternion = (p.head.basis * rest.head.basis.inverse()).get_rotation_quaternion()
			a.rotation_track_insert_key(tr.head, time, torso_q.inverse() * hq)
		for sd in [["l", "arm-left"], ["r", "arm-right"]]:
			var ua: String = "upperarm_" + String(sd[0])
			var hd: String = "hand_" + String(sd[0])
			if p.has(ua) and p.has(hd):
				var d: Vector3 = p[hd].origin - p[ua].origin
				a.rotation_track_insert_key(tr[sd[1]], time, torso_q.inverse() * _arc(Vector3.DOWN, d))
		var dl: Vector3 = (p.foot_l.origin - p.thigh_l.origin).normalized()
		var dr: Vector3 = (p.foot_r.origin - p.thigh_r.origin).normalized()
		a.rotation_track_insert_key(tr["leg-left"], time, _arc(Vector3.DOWN, dl))
		a.rotation_track_insert_key(tr["leg-right"], time, _arc(Vector3.DOWN, dr))
		# kalça yüksekliği: alttaki ayak yere bassın, havadaysa kaldır
		var low_l: bool = p.foot_l.origin.y <= p.foot_r.origin.y
		var dsup: Vector3 = dl if low_l else dr
		var lift: float = maxf(0.0, minf(p.foot_l.origin.y, p.foot_r.origin.y) - rest_foot_y) * k
		var hip_h: float = L * clampf(-dsup.y, 0.15, 1.0) + lift
		var sway: float = (p.hips.origin.x - rest.hips.origin.x) * k * 0.6 if p.has("hips") else 0.0
		a.position_track_insert_key(tpos, time, Vector3(sway, hip_h - L, 0))
	return a


# ---------------------------------------------------------------- iskeletli özel modeller
static func bake_skinned(tree: SceneTree, model_key: String, root: Node3D, sk: Skeleton3D, ap: AnimationPlayer) -> int:
	## hedef iskelete UAL animasyonlarını aktar; eşlenen kemik sayısını döndürür
	if not _prepare(tree):
		return 0
	var tm := map_humanoid(sk)
	var need := ["hips", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r"]
	for c in need:
		if not tm.has(c):
			return 0
	var lib: AnimationLibrary
	if _cache.has(model_key):
		lib = _cache[model_key]
	else:
		lib = _bake_skinned_lib(tree, root, sk, tm)
		_cache[model_key] = lib
	if ap.has_animation_library("ual"):
		ap.remove_animation_library("ual")
	ap.add_animation_library("ual", lib)
	return tm.size()


static func _bake_skinned_lib(_tree: SceneTree, root: Node3D, sk: Skeleton3D, tm: Dictionary) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var txf := _char_xf(root, sk)
	var S := txf.basis.orthonormalized()
	var Si := S.inverse()
	var n := sk.get_bone_count()
	var rest_g := []
	for i in n:
		rest_g.append(txf * sk.get_bone_global_rest(i))
	var canon_of := {}
	for c in tm.keys():
		canon_of[tm[c]] = c
	var sk_path := String(root.get_path_to(sk))
	for game_name in WANT.keys():
		var w: Array = WANT[game_name]
		if not _src.has(w[0]):
			continue
		var s: Dictionary = _src[w[0]]
		var an := _anim_name(s.ap, w[1])
		if an == "":
			continue
		var srest: Dictionary = s.rest
		# dinlenme pozu hizalaması (T-poz ↔ A-poz farkı)
		var corr := {}
		for c in tm.keys():
			if not srest.has(c):
				continue
			var ch: String = CHILD.get(c, "")
			if ch != "" and tm.has(ch) and srest.has(ch):
				var dt: Vector3 = rest_g[tm[ch]].origin - rest_g[tm[c]].origin
				var ds: Vector3 = srest[ch].origin - srest[c].origin
				if dt.length() > 0.0001 and ds.length() > 0.0001:
					corr[c] = Basis(_arc(dt, ds))
		var src_len: float = (srest.foot_l.origin - srest.thigh_l.origin).length() if srest.has("foot_l") else 0.9
		var tgt_len: float = (rest_g[tm.foot_l].origin - rest_g[tm.thigh_l].origin).length() if tm.has("foot_l") else src_len
		var kk := tgt_len / maxf(src_len, 0.001)
		var a := Animation.new()
		var length: float = (s.ap as AnimationPlayer).get_animation(an).length
		a.length = maxf(length, 0.05)
		a.loop_mode = Animation.LOOP_LINEAR if w[2] else Animation.LOOP_NONE
		var tracks := {}
		for b in canon_of.keys():
			var t := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(t, NodePath(sk_path + ":" + sk.get_bone_name(b)))
			tracks[b] = t
		var hips: int = tm.hips
		var tpos := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(tpos, NodePath(sk_path + ":" + sk.get_bone_name(hips)))
		var frames := int(ceil(a.length * FPS))
		for f in range(frames + 1):
			var time := minf(f / FPS, a.length)
			var p := _pose(s, an, time)
			var g := []
			g.resize(n)
			for i in n:
				var par := sk.get_bone_parent(i)
				var parent_b: Basis = Basis() if par < 0 else g[par]
				var local_rest: Basis = sk.get_bone_rest(i).basis
				var cur: Basis = parent_b * S * local_rest if par < 0 else parent_b * local_rest
				if par < 0:
					cur = S * local_rest
				if canon_of.has(i):
					var c: String = canon_of[i]
					if p.has(c) and srest.has(c):
						var D: Basis = p[c].basis.orthonormalized() * srest[c].basis.orthonormalized().inverse()
						var C: Basis = corr.get(c, Basis())
						cur = D * C * rest_g[i].basis.orthonormalized()
				g[i] = cur
				if canon_of.has(i):
					var lb: Basis = (Si * cur) if par < 0 else (g[par] as Basis).inverse() * cur
					if par < 0:
						lb = Si * cur
					a.rotation_track_insert_key(tracks[i], time, lb.orthonormalized().get_rotation_quaternion())
			if p.has("hips") and srest.has("hips"):
				var dpos: Vector3 = (p.hips.origin - srest.hips.origin) * kk
				var par_h := sk.get_bone_parent(hips)
				var par_basis: Basis = S if par_h < 0 else (g[par_h] as Basis)
				var sc: float = maxf(txf.basis.get_scale().x, 0.000001)
				var local_d: Vector3 = par_basis.inverse() * dpos / sc
				a.position_track_insert_key(tpos, time, sk.get_bone_rest(hips).origin + local_d)
		lib.add_animation(game_name, a)
	return lib
