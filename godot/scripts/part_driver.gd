extends SkeletonModifier3D
class_name PartDriver
## İskeletli (Mixamo, Blender vb.) bir modelin kemiklerini oyuncak iskeletindeki
## pivotların dönüşleriyle sürer. Böylece herhangi bir insansı model, oyunun
## tüm animasyonlarını (yürü, koş, sür, vur, düş…) kullanabilir.

var sk: Skeleton3D
var vis: CharacterVisual
var map := {}          # parça → kemik indeksi
var corr := {}         # parça → Quaternion (kolları T-pozdan aşağı indiren düzeltme)
var hips := -1
var hips_rest := Vector3.ZERO


func setup(s: Skeleton3D, v: CharacterVisual) -> void:
	sk = s
	vis = v
	var names := []
	for i in sk.get_bone_count():
		names.append(_clean(sk.get_bone_name(i)))
	map["head"] = _first(names, func(n): return n == "head" or n.ends_with("head") and not n.contains("top") and not n.contains("end"))
	map["torso"] = _first(names, func(n): return n == "spine" or n == "spine1" or n.begins_with("spine") or n.contains("chest") or n == "torso")
	map["arm-left"] = _limb(names, true, ["upperarm", "upper_arm", "arm"], ["fore", "lower", "hand", "shoulder", "clavicle", "twist"])
	map["arm-right"] = _limb(names, false, ["upperarm", "upper_arm", "arm"], ["fore", "lower", "hand", "shoulder", "clavicle", "twist"])
	map["leg-left"] = _limb(names, true, ["upleg", "thigh", "upperleg", "upper_leg", "leg"], ["lower", "low", "calf", "shin", "foot", "toe", "twist"])
	map["leg-right"] = _limb(names, false, ["upleg", "thigh", "upperleg", "upper_leg", "leg"], ["lower", "low", "calf", "shin", "foot", "toe", "twist"])
	hips = _first(names, func(n): return n == "hips" or n == "pelvis" or n == "root" or n.contains("hip"))
	if hips >= 0:
		hips_rest = sk.get_bone_rest(hips).origin
	for k in map.keys():
		if map[k] < 0:
			map.erase(k)
	# kollar ve bacaklar: dinlenme yönü → aşağı düzeltmesi
	for k in ["arm-left", "arm-right", "leg-left", "leg-right"]:
		if not map.has(k):
			continue
		var b: int = map[k]
		var child := _first_child(b)
		if child < 0:
			continue
		var a := sk.get_bone_global_rest(b).origin
		var c := sk.get_bone_global_rest(child).origin
		var d := (c - a).normalized()
		var down := _sk_basis().inverse() * Vector3.DOWN
		down = down.normalized()
		if d.length() > 0.5 and d.dot(down) < 0.999:
			corr[k] = Quaternion(d, down)


func _clean(n: String) -> String:
	n = n.to_lower()
	for pre in ["mixamorig:", "mixamorig_", "armature_", "def-", "def_", "bip01_", "bip01 "]:
		if n.begins_with(pre):
			n = n.substr(pre.length())
	return n


func _first(names: Array, f: Callable) -> int:
	for i in names.size():
		if f.call(names[i]):
			return i
	return -1


func _side(n: String, left: bool) -> bool:
	var s := "l" if left else "r"
	var word := "left" if left else "right"
	return n.contains(word) or n.ends_with("_" + s) or n.ends_with("." + s) or n.begins_with(s + "_") or n.ends_with(" " + s) or n.ends_with("-" + s) or n.begins_with(s + ".")


func _limb(names: Array, left: bool, want: Array, avoid: Array) -> int:
	for w in want:
		for i in names.size():
			var n: String = names[i]
			if not _side(n, left) or not n.contains(w):
				continue
			var bad := false
			for a in avoid:
				if n.contains(a) and not (a == "low" and w.contains("low")):
					bad = true
			if not bad:
				return i
	return -1


func _first_child(b: int) -> int:
	var ch := sk.get_bone_children(b)
	return ch[0] if ch.size() > 0 else -1


func _sk_basis() -> Basis:
	## iskelet uzayının karakter köküne göre yönelimi (ölçeksiz)
	var root: Node3D = vis.rig
	return (root.global_transform.basis.inverse() * sk.global_transform.basis).orthonormalized()


func _process_modification() -> void:
	if sk == null or vis == null or vis.rig == null:
		return
	var S := _sk_basis()
	var Si := S.inverse()
	var rig_b: Basis = vis.rig.global_transform.basis.orthonormalized()
	# işlenme sırası: üst kemikler önce (indeks sırası genelde hiyerarşiktir)
	var order := map.keys()
	order.sort_custom(func(a, b): return map[a] < map[b])
	for part in order:
		var pv: Node3D = vis.pivots.get(part)
		if pv == null:
			continue
		var b: int = map[part]
		var delta_model: Basis = rig_b.inverse() * pv.global_transform.basis.orthonormalized()
		var delta_sk: Basis = Si * delta_model * S
		var rest_g: Basis = sk.get_bone_global_rest(b).basis.orthonormalized()
		var target: Basis = delta_sk * rest_g
		if corr.has(part):
			target = delta_sk * Basis(corr[part]) * rest_g
		var parent := sk.get_bone_parent(b)
		var parent_g := Basis()
		if parent >= 0:
			parent_g = sk.get_bone_global_pose(parent).basis.orthonormalized()
		sk.set_bone_pose_rotation(b, (parent_g.inverse() * target).get_rotation_quaternion())
	# kök sallanması (yürürken hafif yukarı-aşağı)
	if hips >= 0 and vis.pivots.has("root"):
		var r: Node3D = vis.pivots["root"]
		sk.set_bone_pose_position(hips, hips_rest + Si * (r.position * 0.0))
