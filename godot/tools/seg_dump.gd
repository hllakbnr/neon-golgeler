extends SceneTree
## Yerel tanı: bir .glb modelini otomatik ayırıp etiketleri JSON'a döker (godot --headless --script ... -- <glb> <çıktı>)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var out: String = args[1]
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		print("yüklenemedi")
		quit()
		return
	print("yüklendi ", Time.get_ticks_msec())
	var scene: Node3D = doc.generate_scene(st)
	print("sahne ", Time.get_ticks_msec())
	var surfs := []
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D()
		var nd: Node = m
		while nd != null and nd is Node3D:
			xf = (nd as Node3D).transform * xf
			nd = nd.get_parent()
		for si in m.mesh.get_surface_count():
			var a := m.mesh.surface_get_arrays(si)
			var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			for i in pos.size():
				pos[i] = xf * pos[i]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(pos.size()))
			surfs.append({"pos": pos, "idx": idx})
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for s in surfs:
		for p in s.pos:
			lo = lo.min(p)
			hi = hi.max(p)
	var k := 2.7 / (hi.y - lo.y)
	var geoms := []
	for s in surfs:
		var pos: PackedVector3Array = s.pos
		for i in pos.size():
			pos[i] = (pos[i] - Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)) * k
		geoms.append({"pos": pos, "idx": s.idx})
	print("yüzey ", surfs.size(), " ", Time.get_ticks_msec())
	var mi := ModelImport.new()
	mi.H = 2.7
	var t0 := Time.get_ticks_msec()
	var seg := mi.segment(geoms)
	print("süre ms ", Time.get_ticks_msec() - t0, " info ", seg.get("info"), " piv ", seg.get("piv"))
	var res := {"g": [], "piv": {}}
	for gi in geoms.size():
		var tl: PackedByteArray = seg.tl[gi]
		var idx: PackedInt32Array = geoms[gi].idx
		var pos: PackedVector3Array = geoms[gi].pos
		var tris := []
		for t in range(0, idx.size(), 3):
			var c: Vector3 = (pos[idx[t]] + pos[idx[t + 1]] + pos[idx[t + 2]]) / 3.0
			tris.append([snappedf(c.x, 0.001), snappedf(c.y, 0.001), snappedf(c.z, 0.001), tl[t / 3]])
		res.g.append(tris)
	for kk in seg.piv:
		if seg.piv[kk] == null:
			continue
		res.piv[kk] = {"p": [seg.piv[kk].p.x, seg.piv[kk].p.y, seg.piv[kk].p.z], "h": [seg.piv[kk].h.x, seg.piv[kk].h.y, seg.piv[kk].h.z]} if seg.piv[kk].has("h") else {"p": [seg.piv[kk].p.x, seg.piv[kk].p.y, seg.piv[kk].p.z]}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	quit()
