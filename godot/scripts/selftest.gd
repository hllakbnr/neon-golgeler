extends Node
class_name SelfTest
## Otomatik oyun testleri (godot --headless -- --selftest): bir "bot" oyunu oynar, hataları yakalar.
## Her sınama ✓ / ✗ yazar; sonunda özet ve user://selftest.txt raporu. CI her sürümde çalıştırır.

var boot: Node
var world: World
var player: Player
var results: Array = []
var _errors := 0


func _ok(name: String, pass_: bool, detail := "") -> void:
	results.append([name, pass_, detail])
	print(("TEST ✓ " if pass_ else "TEST ✗ ") + name + ("" if detail == "" else "  (" + detail + ")"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _place(p: Vector3, yaw := PI) -> void:
	if player.car:
		player.exit_car()
		await _frames(3)
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.yaw = yaw
	await _frames(4)


func run() -> void:
	world = boot.world
	player = boot.player
	await _frames(30)
	await _t_walls()
	await _t_peds_solid()
	await _t_peds_buildings()
	await _t_traffic()
	await _t_car_drive()
	await _t_props()
	await _t_spin_traffic()
	await _t_interiors()
	await _t_dragon()
	await _t_police_spawn()
	await _t_ui()
	var fails := 0
	var lines := PackedStringArray()
	for r in results:
		if not r[1]:
			fails += 1
		lines.append(("✓ " if r[1] else "✗ ") + String(r[0]) + ("" if String(r[2]) == "" else "  (" + String(r[2]) + ")"))
	var summary := "SONUÇ: %d sınama, %d hata" % [results.size(), fails]
	lines.append(summary)
	print(summary)
	var f := FileAccess.open("user://selftest.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
	if OS.has_environment("NG_ST_OUT"):
		var f2 := FileAccess.open(OS.get_environment("NG_ST_OUT"), FileAccess.WRITE)
		if f2:
			f2.store_string("\n".join(lines))


# ---------------------------------------------------------------- sınamalar
func _t_walls() -> void:
	## oyuncu bina duvarına yürür: içine girmemeli
	var inside := 0
	for k in 4:
		var c := Vector3(-120.0 + k * 80.0, 0.3, -40.0)       # blok merkezi
		var start := c + Vector3(0, 0, 36.0)                    # kaldırım (+z tarafı)
		await _place(start, 0.0)                                 # kamera +z'ye bakar → ileri = -z (binaya doğru)
		Input.action_press("move_forward")
		Input.action_press("sprint")
		for i in 90:
			await get_tree().physics_frame
			var p := player.global_position
			for bb in world.data.city.buildings:
				if absf(p.x - float(bb.c[0])) < float(bb.s[0]) * 0.5 - 0.3 and absf(p.z - float(bb.c[1])) < float(bb.s[1]) * 0.5 - 0.3:
					inside += 1
					break
		Input.action_release("move_forward")
		Input.action_release("sprint")
	_ok("Oyuncu bina duvarından geçmiyor", inside == 0, "%d kare bina içinde" % inside)


func _t_peds_solid() -> void:
	## oyuncu yayaya doğru yürür: içinden geçmemeli
	var ped: Pedestrian = null
	var bd := 1e9
	for n in get_tree().get_nodes_in_group("people"):
		var d := (n as Node3D).global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			ped = n
	if ped == null:
		_ok("Yaya katı (içinden geçilmez)", false, "yaya yok")
		return
	ped.state = Pedestrian.S.IDLE
	ped._t = 20.0
	var pp := ped.global_position
	await _place(pp + Vector3(0, 0.2, 3.0), 0.0)
	var minimum := 99.0
	Input.action_press("move_forward")
	for i in 70:
		await get_tree().physics_frame
		var d := Vector2(player.global_position.x - ped.global_position.x, player.global_position.z - ped.global_position.z).length()
		minimum = minf(minimum, d)
	Input.action_release("move_forward")
	_ok("Yaya katı (içinden geçilmez)", minimum > 0.35, "en yakın %.2f m" % minimum)


func _t_peds_buildings() -> void:
	## yayaları korkut, dövüştür, savur: hiçbiri bina içine girmemeli
	var peds: Array = get_tree().get_nodes_in_group("people")
	var k := 0
	for n in peds:
		var pd := n as Pedestrian
		if pd == null or pd._far:
			continue
		k += 1
		match k % 3:
			0:
				pd._start_flee(player)
			1:
				pd.take_hit(10.0, pd.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), true, player, 0.0)
			2:
				pd.threat = player
				pd.state = Pedestrian.S.FIGHT
	var bad := 0
	for i in 300:
		await get_tree().physics_frame
		if i % 10 == 0:
			for n in peds:
				var pd2 := n as Pedestrian
				if pd2 and is_instance_valid(pd2) and not world.walk_ok(pd2.global_position):
					bad += 1
	if Wanted.inst:
		Wanted.inst.clear()
	_ok("Yayalar bina içine girmiyor", bad == 0, "%d ihlal" % bad)


func _cars() -> Array:
	return get_tree().get_nodes_in_group("traffic")


func _t_traffic() -> void:
	## 60 saniyelik trafik: araçlar iç içe ya da üst üste olmamalı
	var overlaps := 0
	var stacked := 0
	var worst := ""
	for i in 3600:
		await get_tree().physics_frame
		if i % 30 != 0:
			continue
		var cs := _cars()
		for a in cs.size():
			var ca := cs[a] as TrafficCar
			if ca.global_position.y > 1.2 and ca.crashed <= 0.0:
				stacked += 1
			for b in range(a + 1, cs.size()):
				var cb := cs[b] as TrafficCar
				var d := ca.global_position - cb.global_position
				if Vector2(d.x, d.z).length() < 1.6 and absf(d.y) < 1.5:
					overlaps += 1
					worst = "%s ~ %s" % [ca.global_position.snapped(Vector3.ONE * 0.1), cb.global_position.snapped(Vector3.ONE * 0.1)]
					if OS.has_environment("NG_DBG"):
						print("OVL t=%d a[%s c=%.1f v=%.1f %s>%s fr=%s] b[%s c=%.1f v=%.1f %s>%s fr=%s]" % [i, ca.name, ca.crashed, ca.speed, ca.from, ca.to, ca.freeze, cb.name, cb.crashed, cb.speed, cb.from, cb.to, cb.freeze])
	_ok("Trafik: araçlar iç içe girmiyor (60 sn)", overlaps <= 2, "%d çakışma %s" % [overlaps, worst])
	_ok("Trafik: araç üst üste binmiyor", stacked == 0, "%d" % stacked)


func _t_car_drive() -> void:
	## oyuncu arabaya biner, ileri sürer, frenler, iner
	var car: Car = null
	var bd := 1e9
	for c in get_tree().get_nodes_in_group("cars"):
		var d := (c as Node3D).global_position.distance_to(player.global_position)
		if d < bd and (c as Car).model != "tractor":
			bd = d
			car = c
	if car == null:
		_ok("Araba sürüşü", false, "araba yok")
		return
	await _place(car.global_position + Vector3(1.6, 0.3, 0))
	player._try_enter()
	await _frames(10)
	var p0 := car.global_position
	await _hold("move_forward", 180)
	var moved := car.global_position.distance_to(p0)
	var spd := car.linear_velocity.length()
	await _hold("move_back", 120)
	var upright := car.global_transform.basis.y.y > 0.8
	player.exit_car()
	await _frames(10)
	_ok("Araba sürüşü: hızlanıyor", moved > 8.0, "%.1f m, %.1f m/s" % [moved, spd])
	_ok("Araba sürüşü: devrilmiyor", upright)
	_ok("Araçtan inince oyuncu yerde", absf(player.global_position.y - world.city_floor(player.global_position)) < 1.0 or player.is_on_floor())


func _t_props() -> void:
	var b0: Dictionary = world.breakables[3]
	var ok := world.hit_props(Vector3(b0.pos.x, b0.pos.y + 1.0, b0.pos.z), 1.0, Vector3(5, 0, 0))
	await _frames(60)
	_ok("Eşya kırılıyor ve fizikle düşüyor", ok and world.breaker.debris.size() > 0)


func _t_spin_traffic() -> void:
	## arabaların yanında kasırga: hiçbir araç havaya fırlamamalı
	var c := _cars()[0] as TrafficCar
	await _place(c.global_position + Vector3(2.5, 0.3, 0))
	player.combat.stamina = 100.0
	player.powers.spin_cd = 0.0
	player.powers._spin_start()
	var hidden := not player.visual.visible
	var high := 0.0
	for i in 240:
		await get_tree().physics_frame
		for n in _cars():
			high = maxf(high, (n as Node3D).global_position.y)
	_ok("Kasırgada karakter gizleniyor", hidden)
	_ok("Kasırga arabaları fırlatmıyor", high < 3.0, "en yüksek %.1f m" % high)
	await _frames(60)


func _t_interiors() -> void:
	var bad := []
	for d in world.doors:
		if String(d.interior) == "atolye":
			continue
		await _place((d.pos as Vector3) + Vector3(0, 0.3, 0))
		world.try_door(player)
		await get_tree().create_timer(1.2).timeout
		var ins: String = world.interiors.current
		if ins == "":
			bad.append(String(d.interior) + ":girmedi")
			continue
		# içeride 2 sn yürü: düşmemeli, duvardan çıkmamalı
		var b: Dictionary = world.interiors.built[ins]
		await _hold("move_forward", 120)
		var p := player.global_position
		var root: Node3D = b.root
		var lp := p - root.global_position
		var st: Dictionary = Interiors.STYLE[ins]
		if absf(lp.x) > float(st.w) * 0.5 or absf(lp.z) > float(st.d) * 0.5 or lp.y < -0.5:
			bad.append(ins + ":dışarı/düştü")
		player.global_position = b.door
		world.try_door(player)
		await get_tree().create_timer(1.2).timeout
		if world.interiors.current != "":
			bad.append(ins + ":çıkamadı")
	_ok("İç mekânlara girip çıkılıyor, içeride kalınıyor", bad.is_empty(), ", ".join(bad))


func _t_dragon() -> void:
	await _place(Vector3(-88.5, 0.4, -36.0))
	player.powers._summon()
	await _frames(30)
	await _hold("move_forward", 120)
	await _hold("jump", 60)
	var flew := player.global_position.y > 4.0
	var d := player.powers.dragon
	d.dismiss()
	for i in 240:
		await get_tree().physics_frame
		if player.mount == null:
			break
	await _frames(30)
	var g := world.city_floor(player.global_position) if world.in_city(player.global_position) else world.ground_y(player.global_position.x, player.global_position.z)
	_ok("Ejderha uçuyor", flew)
	_ok("Ejderhadan inince bulunduğun yere iniliyor", player.mount == null and absf(player.global_position.y - g) < 30.0 and player.global_position.distance_to(Vector3(-88.5, 0, -36)) > 5.0, "y=%.1f zemin=%.1f" % [player.global_position.y, g])


func _t_police_spawn() -> void:
	await _place(Vector3(-88.5, 0.4, -36.0))
	var before := {}
	for n in get_tree().get_nodes_in_group("police"):
		before[n] = true
	Wanted.inst._raise(3, player.global_position)
	var seen_spawn := 0
	for i in 300:
		await get_tree().physics_frame
		for n in get_tree().get_nodes_in_group("police"):
			if before.has(n):
				continue
			before[n] = true
			var cam := get_viewport().get_camera_3d()
			var p := (n as Node3D).global_position
			if cam and not cam.is_position_behind(p) and cam.global_position.distance_to(p) < 40.0:
				var sp := cam.unproject_position(p)
				if Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).has_point(sp) and (n as Pedestrian).spawned:
					seen_spawn += 1
	Wanted.inst.clear()
	_ok("Polis gözümüzün önünde belirmiyor", seen_spawn == 0, "%d görünür doğma" % seen_spawn)


func _t_ui() -> void:
	## arayüzler: açılıp kapanırken hata vermemeli
	var m: MapScreen = boot.open_map()
	await get_tree().process_frame
	m._pick_cat(2)
	m._focus_sel(true)
	await get_tree().process_frame
	m.closed.emit()
	m.queue_free()
	await get_tree().process_frame
	var ph := Phone.new()
	ph.player = player
	player.phone = ph
	boot.add_child(ph)
	for app in ["kisiler", "mesaj", "yolculuk", "banka", "radyo", "neongram", "gardirop"]:
		ph._open(app)
		await get_tree().process_frame
		ph._back()
	ph.close()
	Input.action_press("weapon_wheel")
	player.combat._open_wheel()
	await _frames(5)
	Input.action_release("weapon_wheel")
	await _frames(5)
	_ok("Harita, telefon, silah çarkı açılıp kapanıyor", true)
