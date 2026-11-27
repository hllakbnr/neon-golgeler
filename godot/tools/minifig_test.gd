extends SceneTree
## Yerel deneme: ayrı parçalı oyuncak figürde kol / el ayrımı (godot --headless --script)

func _box(st: SurfaceTool, c: Vector3, s: Vector3, rot := Basis()) -> void:
	var bm := BoxMesh.new()
	bm.size = s
	st.append_from(bm, 0, Transform3D(rot, c))


func _init() -> void:
	var H := 2.7
	var geoms := []
	var parts := {
		"legR": [Vector3(-0.25, 0.42, 0.0), Vector3(0.46, 0.84, 0.5)],
		"legL": [Vector3(0.25, 0.42, 0.0), Vector3(0.46, 0.84, 0.5)],
		"hips": [Vector3(0, 0.93, 0.0), Vector3(1.0, 0.16, 0.5)],
		"torso": [Vector3(0, 1.42, 0.0), Vector3(0.95, 0.8, 0.48)],
		"head": [Vector3(0, 2.06, 0.0), Vector3(0.6, 0.5, 0.6)],
		"helmet": [Vector3(0, 2.35, 0.0), Vector3(0.7, 0.32, 0.7)],
		"pad": [Vector3(0.48, 1.86, 0.0), Vector3(0.45, 0.12, 0.5)],
	}
	for k in parts:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_box(st, parts[k][0], parts[k][1])
		var m := st.commit()
		var a := m.surface_get_arrays(0)
		geoms.append({"pos": a[Mesh.ARRAY_VERTEX], "idx": a[Mesh.ARRAY_INDEX], "name": k})
	for s in [-1.0, 1.0]:
		# bükük kol: üst kol aşağı-dışa, ön kol öne; el ayrı küçük parça (kalça hizasında)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_box(st, Vector3(s * 0.58, 1.55, 0.0), Vector3(0.22, 0.5, 0.26), Basis(Vector3.FORWARD, s * 0.15))
		_box(st, Vector3(s * 0.63, 1.2, 0.12), Vector3(0.2, 0.22, 0.42), Basis(Vector3.RIGHT, -0.5))
		var m := st.commit()
		var a := m.surface_get_arrays(0)
		geoms.append({"pos": a[Mesh.ARRAY_VERTEX], "idx": a[Mesh.ARRAY_INDEX], "name": "arm%d" % int(s)})
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		_box(st2, Vector3(s * 0.63, 1.04, 0.33), Vector3(0.16, 0.16, 0.16))
		var m2 := st2.commit()
		var a2 := m2.surface_get_arrays(0)
		geoms.append({"pos": a2[Mesh.ARRAY_VERTEX], "idx": a2[Mesh.ARRAY_INDEX], "name": "hand%d" % int(s)})
	var mi := ModelImport.new()
	mi.H = H
	var seg := mi.segment(geoms)
	print("ok=", seg.get("ok"), " info=", seg.get("info"))
	var tl: Array = seg.tl
	for gi in geoms.size():
		var labs: PackedByteArray = tl[gi]
		var cnt := {}
		for l in labs:
			cnt[l] = cnt.get(l, 0) + 1
		print("  ", geoms[gi].name, " → ", cnt)
	for k in seg.piv:
		print("  piv ", k, " ", seg.piv[k])
	quit()
