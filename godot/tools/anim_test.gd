extends SceneTree
## CI tanı betiği: AnimLib (UAL aktarımı) adım adım denetlenir. Oyunu çalıştırmaz.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== AnimLib testi")
	var ok := AnimLib._prepare(self)
	print("prepare: ", ok, " kaynaklar: ", AnimLib._src.keys())
	for id in AnimLib._src.keys():
		var s: Dictionary = AnimLib._src[id]
		var ap: AnimationPlayer = s.ap
		var names := ap.get_animation_list()
		print(id, " anim sayısı: ", names.size(), " örnek: ", names.slice(0, 6))
		print(id, " kütüphaneler: ", ap.get_animation_library_list(), " root_node=", ap.root_node, " active=", ap.active)
		print(id, " eşleme: ", s.map)
		print(id, " TÜM: ", names)
		var missing := []
		for g in AnimLib.WANT.keys():
			var w: Array = AnimLib.WANT[g]
			if w[0] == id and AnimLib._anim_name(ap, w[1]) == "":
				missing.append(w[1])
		print(id, " BULUNAMAYAN: ", missing)
		var want: String = "Walk_Loop" if id == 1 else "Sword_Regular_A"
		var an := AnimLib._anim_name(ap, want)
		print(id, " anim adı: '", an, "'")
		if an != "":
			var a: Animation = ap.get_animation(an)
			print("  uzunluk=", a.length, " iz sayısı=", a.get_track_count(), " ilk iz=", a.track_get_path(0) if a.get_track_count() > 0 else "")
			var r: Dictionary = s.rest
			for t in [0.0, 0.25, 0.5]:
				var p := AnimLib._pose(s, an, t)
				if p.has("thigh_l") and r.has("thigh_l"):
					var q1 := Quaternion(p.thigh_l.basis.orthonormalized())
					var q2 := Quaternion(r.thigh_l.basis.orthonormalized())
					print("  t=", t, " uyluk_sol açı farkı=", rad_to_deg(q1.angle_to(q2)), " ayak_sol=", p.foot_l.origin, " pos=", ap.current_animation_position)
	# bloklu karakter
	var path := ""
	var d := DirAccess.open("res://assets/kenney/blocky")
	if d:
		for f in d.get_files():
			if f.ends_with(".glb") and path == "":
				path = "res://assets/kenney/blocky/" + f
	print("bloklu sahne: ", path)
	if path != "":
		var sc: PackedScene = load(path)
		var inst: Node = sc.instantiate()
		root.add_child(inst)
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		print(" AP sayısı: ", aps.size())
		if aps.size() > 0:
			var ap: AnimationPlayer = aps[0]
			var base: Node = ap.get_node_or_null(ap.root_node)
			print(" kütüphaneler: ", ap.get_animation_library_list(), " root_node=", ap.root_node, " base=", base, " ağaç:")
			inst.print_tree_pretty()
			for part in ["root", "torso", "head", "arm-left", "arm-right", "leg-left", "leg-right"]:
				print("  ", part, " → ", base.find_child(part, true, false) if base else null)
			print(" lib(''): ", ap.get_animation_library(""))
			AnimLib.bake_blocky(self, ap)
			print(" pişirme sonrası: ", ap.get_animation_list())
			for nm in ["crouch_idle", "walk", "idle"]:
				if ap.has_animation(nm):
					var a := ap.get_animation(nm)
					print(" ", nm, " iz=", a.get_track_count(), " uzunluk=", a.length)
					for t in a.get_track_count():
						var k := a.track_get_key_count(t)
						print("   ", a.track_get_path(t), " tür=", a.track_get_type(t), " anahtar=", k, " örnek=", a.track_get_key_value(t, mini(6, k - 1)) if k > 0 else null)
	# iskeletli
	if ResourceLoader.exists("res://assets/chars/human.glb"):
		var hs: PackedScene = load("res://assets/chars/human.glb")
		var h: Node3D = hs.instantiate()
		root.add_child(h)
		var sk: Skeleton3D = h.find_children("*", "Skeleton3D", true, false)[0]
		var aps2 := h.find_children("*", "AnimationPlayer", true, false)
		var ap2: AnimationPlayer = aps2[0] if aps2.size() > 0 else null
		print("Xbot kemik: ", sk.get_bone_count(), " AP: ", ap2)
		var n := AnimLib.bake_skinned(self, "test", h, sk, ap2)
		print(" eşlenen: ", n, " kütüphaneler: ", ap2.get_animation_library_list())
		if ap2.has_animation("ual/walk"):
			var a := ap2.get_animation("ual/walk")
			for t in mini(4, a.get_track_count()):
				var k := a.track_get_key_count(t)
				print("   ", a.track_get_path(t), " anahtar=", k, " örnek=", a.track_get_key_value(t, mini(6, k - 1)) if k > 0 else null)
	print("== bitti")
	quit()
