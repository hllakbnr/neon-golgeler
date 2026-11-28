extends Node
## Açılış akışı: şehir → anahtar görseller → ana menü (arkada canlı şehir) → yükleme ekranı → oyun.
## --shots=<klasör> ile çalışırsa (CI) ekran görüntülerini kaydedip kapanır.

var world: World
var menu: MainMenu
var hud: HUD
var player: Player
var menu_cam: Camera3D
var playing := false
var _orbit := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Game.pose_test:
		await _pose_test()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--selftest"):
		Game.test_mode = true
		_self_test()
		return
	if OS.get_cmdline_user_args().has("--buildtest"):
		await _build_test()
		get_tree().quit()
		return
	if Updater.should_run():
		var up := Updater.new()
		add_child(up)
		up.run()
		await up.finished
	var ld := LoadingScreen.new()
	add_child(ld)
	ld.step(0.02, "Ada hazırlanıyor")
	await get_tree().process_frame
	await get_tree().process_frame
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	await world.build(ld.step)
	menu_cam = Camera3D.new()
	menu_cam.fov = 55
	menu_cam.far = 2500
	world.add_child(menu_cam)
	menu_cam.make_current()
	ld.step(0.8, "Anahtar görseller çekiliyor")
	await _capture_keyart()
	ld.step(1.0, "Hazır")
	await get_tree().create_timer(0.4).timeout
	ld.queue_free()
	Game.time_of_day = 18.2
	menu = MainMenu.new()
	add_child(menu)
	menu.play_pressed.connect(_start_game)
	menu.resume_pressed.connect(_resume)
	menu.map_pressed.connect(func():
		_resume()
		open_map())
	menu.open(false)
	if Game.shots_dir != "":
		_run_shots()


func _capture_keyart() -> void:
	## anahtar görseller ayrı bir SubViewport'ta çekilir (yükleme ekranı açık kalır), diske de kaydedilir
	var M := World.MON
	var shots := [
		[Vector3(-163, 2.2, -8), Vector3(-158, 8.0, -80), 18.0],            # Eski Çarşı fenerleri
		[Vector3(-418, 3.0, 30), Vector3(-482, 2.0, 220), 11.0],            # Sahil
		[Vector3(-560, 90, 520), Vector3(100, 40, -150), 21.5],             # gece Neon Şehir
		[M + Vector3(70, 30, 150), M + Vector3(0, 8, -10), 8.0],            # Kasırga Manastırı
	]
	var sv := SubViewport.new()
	sv.size = Vector2i(1600, 900)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = get_viewport().msaa_3d
	sv.screen_space_aa = get_viewport().screen_space_aa
	add_child(sv)
	var cam := Camera3D.new()
	cam.fov = 55
	cam.far = 2500
	sv.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute("user://keyart")
	var k := 0
	for s in shots:
		Game.time_of_day = s[2]
		world.update_time(s[2], true)
		cam.look_at_from_position(s[0], s[1], Vector3.UP)
		for i in range(10):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		if img:
			Game.keyart.append(ImageTexture.create_from_image(img))
			img.save_jpg("user://keyart/k%d.jpg" % k, 0.85)
		k += 1
	sv.queue_free()


func _process(delta: float) -> void:
	if not playing and menu_cam:
		_orbit += delta * 0.035
		var c := Vector3(0, 25, 0)
		menu_cam.look_at_from_position(c + Vector3(cos(_orbit) * 210, 72 + sin(_orbit * 0.7) * 14, sin(_orbit) * 210), c, Vector3.UP)


const SPAWN := Vector3(-88.5, 0.4, -36.0)
const PEDS := 130
const TRAFFIC_N := 46
var dialog: DialogBox
var wanted: Wanted
var radio: Radio


func _start_game() -> void:
	menu.visible = false
	var ld := LoadingScreen.new()
	add_child(ld)
	ld.step(0.05, "Kaan hazırlanıyor")
	await get_tree().process_frame
	# oyuncu: Kaan, merkezin batısındaki caddede kaldırımda
	player = Player.new()
	player.world = world
	world.add_child(player)
	player.global_position = SPAWN
	player.yaw = PI
	ld.step(0.25, "Araçlar park ediliyor")
	await get_tree().process_frame
	# park hâlindeki araçlar (yol kenarında)
	var M := World.MON
	var parked := [["sedan-sports", Vector3(-84.6, 0.5, -46.0), 0.0], ["taxi", Vector3(-84.6, 0.5, -24.0), 0.0], ["suv", Vector3(-75.4, 0.5, -12.0), PI],
		["police", Vector3(-155.4, 0.5, 30.0), 0.0], ["hatchback-sports", Vector3(84.6, 0.5, 30.0), 0.0], ["van", Vector3(-164.6, 0.5, 60.0), 0.0],
		["suv-luxury", Vector3(20.0, 0.5, 235.4), -PI * 0.5], ["sedan", Vector3(124.0, 0.5, -155.4), PI * 0.5],
		["truck", Vector3(-440.0, 0.6, -40.0), 0.0], ["sedan-sports", Vector3(-430.0, 0.6, -110.0), PI],
		["suv", Vector3(225.0, -1.0, -925.0), PI], ["hatchback-sports", Vector3(450.0, -1.0, 4.0), -PI * 0.5],
		["police", Vector3(-1000.0, -1.0, -920.0), 0.0], ["suv", Vector3(2930.0, -1.0, 1660.0), PI],
		["race", Vector3(155.4, 0.5, -60.0), 0.0], ["race-future", Vector3(244.6, 0.5, 60.0), PI], ["ambulance", Vector3(235.4, 0.5, -30.0), 0.0],
		["delivery", Vector3(-235.4, 0.5, -140.0), 0.0], ["garbage-truck", Vector3(-4.6, 0.5, 140.0), PI], ["firetruck", Vector3(-84.6, 0.5, 140.0), PI],
		["truck-flat", Vector3(-450.0, 0.6, -200.0), 0.0], ["tractor", Vector3(880.0, -1.0, 3150.0), 0.0], ["sedan", Vector3(4.6, 0.5, -100.0), 0.0]]
	for p in parked:
		var c := Car.new()
		c.model = p[0]
		world.add_child(c)
		var pos: Vector3 = p[1]
		if pos.y < 0.0:
			pos.y = world.ground_y(pos.x, pos.z) + 1.2
		c.global_position = pos
		c.rotation.y = p[2]
	ld.step(0.45, "Trafik başlıyor")
	await get_tree().process_frame
	# trafik: her araç farklı bir kavşaktan başlar (üst üste doğmaz)
	var nodes := []
	for x in range(-World.GX, World.GX + 1):
		for y in range(-World.GZ, World.GZ + 1):
			if Vector3(x * World.CELL, 0, y * World.CELL).distance_to(SPAWN) > 40.0:
				nodes.append(Vector2i(x, y))
	nodes.shuffle()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in range(mini(TRAFFIC_N, nodes.size())):
		var a: Vector2i = nodes[i]
		dirs.shuffle()
		var to := a
		for d in dirs:
			var n: Vector2i = a + d
			if world.node_ok(n):
				to = n
				break
		var t := TrafficCar.new()
		t.world = world
		t.model = CarModel.TRAFFIC[i % CarModel.TRAFFIC.size()]
		t.from = a
		t.to = to
		world.add_child(t)
	ld.step(0.65, "Sokaklar doluyor")
	await get_tree().process_frame
	wanted = Wanted.new()
	wanted.player = player
	wanted.world = world
	add_child(wanted)
	radio = Radio.new()
	radio.player = player
	add_child(radio)
	# yayalar
	var yaya_slots := []
	for k in Game.SLOTS.keys():
		if String(k).begins_with("yaya"):
			yaya_slots.append(k)
	for i in range(PEDS):
		var r: Rect2 = world.blocks[(i * 7) % world.blocks.size()]
		var loop := world.sidewalk_loop(r)
		var n := Pedestrian.new()
		n.world = world
		n.slot = "polis" if i % 13 == 5 else yaya_slots[i % yaya_slots.size()]
		n.role = "police" if i % 13 == 5 else "civ"
		n.path = loop if i % 2 == 0 else [loop[0], loop[3], loop[2], loop[1]]
		n.idx = randi() % loop.size()
		world.add_child(n)
		n.global_position = loop[n.idx].lerp(loop[(n.idx + 1) % loop.size()], randf())
		if i % 12 == 11:
			ld.step(0.65 + i * 0.0018, "Sokaklar doluyor")
			await get_tree().process_frame
	ld.step(0.88, "Işıklar yakılıyor")
	hud = HUD.new()
	hud.player = player
	hud.world = world
	add_child(hud)
	dialog = DialogBox.new()
	add_child(dialog)
	Game.time_of_day = 16.5
	for i in range(20):
		await get_tree().process_frame
		ld.step(0.88 + i * 0.006, "Işıklar yakılıyor")
	ld.step(1.0, "Hazır")
	await get_tree().create_timer(0.6).timeout
	ld.queue_free()
	playing = true
	menu_cam.current = false
	player.cam.make_current()
	if Game.shots_dir == "" and not Game.test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var intro := Intro.new()
		intro.world = world
		intro.player = player
		add_child(intro)
		intro.finished.connect(func(): get_tree().create_timer(1.0).timeout.connect(func(): dialog.play_scene("intro")))


func _unhandled_input(e: InputEvent) -> void:
	if playing and e is InputEventKey and e.pressed and not e.is_echo() and (e as InputEventKey).keycode == KEY_F9 and not get_tree().paused:
		var br := BugReport.new()
		br.player = player
		br.world = world
		add_child(br)
		get_viewport().set_input_as_handled()
		return
	if playing and e.is_action_pressed("map") and not get_tree().paused:
		open_map()
		get_viewport().set_input_as_handled()
		return
	if playing and e.is_action_pressed("pause") and not get_tree().paused:
		_pause()
		get_viewport().set_input_as_handled()
	if playing and e is InputEventMouseButton and e.pressed and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func open_map() -> MapScreen:
	var m := MapScreen.new()
	m.world = world
	m.player = player
	get_tree().paused = true
	Game.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	m.closed.connect(func():
		get_tree().paused = false
		Game.paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Game.shots_dir == "" else Input.MOUSE_MODE_VISIBLE)
	add_child(m)
	return m


func _pause() -> void:
	get_tree().paused = true
	Game.paused = true
	menu.open(true)


func _resume() -> void:
	menu.visible = false
	get_tree().paused = false
	Game.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- CI ekran görüntüleri
func _pose_test() -> void:
	## hızlı animasyon denetimi: her animasyon belirli bir anda dondurulup tek karede gösterilir
	await get_tree().process_frame
	var root := Node3D.new()
	add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	floor_mi.mesh = pm
	root.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 9.0, 27.0), Vector3(0, 0.6, -2.0), Vector3.UP)
	cam.make_current()
	var mf := "user://test_minifig.glb"
	_make_test_minifig(mf)
	var tests := [["kaan", "idle", 0.5], ["kaan", "walk", 0.2], ["kaan", "walk", 0.55], ["kaan", "jog", 0.2], ["kaan", "sprint", 0.2], ["kaan", "crouch_idle", 0.5],
		["kaan", "crouch_walk", 0.3], ["kaan", "punch_cross", 0.18], ["kaan", "sword_a", 0.2], ["kaan", "jump", 0.2], ["kaan", "drive", 0.3], ["kaan", "die", 2.0],
		["xbot", "idle", 0.5], ["xbot", "walk", 0.2], ["xbot", "jog", 0.2], ["xbot", "punch_cross", 0.18], ["xbot", "crouch_idle", 0.5],
		["mini", "idle", 0.5], ["mini", "walk", 0.2], ["mini", "jog", 0.2], ["mini", "punch_cross", 0.18], ["mini", "crouch_walk", 0.3]]
	Game.admin.slots["yaya1"] = {"type": "glb", "path": "res://assets/chars/human.glb"}
	Game.admin.slots["yaya2"] = {"type": "glb", "path": mf}
	var per_row := 12
	for i in tests.size():
		var t: Array = tests[i]
		var slot: String = {"kaan": "kaan", "xbot": "yaya1", "mini": "yaya2"}[t[0]]
		var v := CharacterVisual.new()
		root.add_child(v)
		v.setup(slot, Game.slot_default_skin(slot))
		var row := i / per_row
		var col := i % per_row
		v.position = Vector3((col - (per_row - 1) * 0.5) * 2.1, 0, -row * 3.2)
		v.rotation.y = 0.5
		v.play(t[1], 0.0)
		if v.anim:
			var nm := v._resolve(t[1])
			if nm != "":
				v.anim.play(nm, 0.0)
				v.anim.seek(minf(t[2], v.anim.get_animation(nm).length), true)
				v.anim.pause()
		var lbl := Label3D.new()
		lbl.text = "%s\n%s" % [t[0], t[1]]
		lbl.font_size = 40
		lbl.pixel_size = 0.006
		lbl.position = v.position + Vector3(0, 2.25, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(lbl)
		print("POZ ", t[0], " ", t[1], " mod=", v.mode, " çözülen=", v._resolve(t[1]), " not=", v.note)
	for k in range(6):
		await get_tree().process_frame
	await Game.shot("poz_" + str(Game.version))
	cam.look_at_from_position(Vector3(-7.5, 1.7, 6.0), Vector3(-7.5, 1.0, 0), Vector3.UP)
	for k in range(3):
		await get_tree().process_frame
	await Game.shot("poz_yakin")
	cam.look_at_from_position(Vector3(3.2, 2.0, 3.6), Vector3(3.2, 1.0, -3.2), Vector3.UP)
	for k in range(3):
		await get_tree().process_frame
	await Game.shot("poz_minifig")
	# yönetici önizlemesindeki sıra: iskeletli model oynarken tek parça modele geçiş (CI'da çökme vardı)
	var pv := CharacterVisual.new()
	root.add_child(pv)
	pv.position = Vector3(0, 0, 4)
	pv.setup("yaya1", "texture-a.png")
	pv.play("walk")
	for k in range(10):
		await get_tree().process_frame
	pv.play_once("punch_cross", 0.1)
	for k in range(10):
		await get_tree().process_frame
	print("GEÇİŞ başlıyor")
	pv.setup("yaya2", "texture-b.png")
	pv.play("walk")
	for k in range(20):
		await get_tree().process_frame
	print("GEÇİŞ tamam mod=", pv.mode)
	await Game.shot("poz_gecis")
	# yönetici paneli: oyun duraklatılmışken, alt görüntü alanında aynı sıra
	get_tree().paused = true
	var ap := AdminPanel.new()
	add_child(ap)
	for k in range(10):
		await get_tree().process_frame
	ap.list.select(3)
	ap._select("yaya1")
	for k in range(15):
		await get_tree().process_frame
	ap.preview.play_once("punch_cross", 0.1)
	for k in range(10):
		await get_tree().process_frame
	print("PANEL geçiş başlıyor")
	Game.admin.slots.erase("yaya1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_minifig.glb"))
	_make_test_minifig("user://test_minifig.glb")
	ap.list.select(4)
	ap._select("yaya2")
	for k in range(20):
		await get_tree().process_frame
	print("PANEL geçiş tamam mod=", ap.preview.mode)
	await Game.shot("poz_panel")


func _self_test() -> void:
	await get_tree().process_frame
	world = World.new()
	add_child(world)
	await world.build(Callable())
	menu_cam = Camera3D.new()
	world.add_child(menu_cam)
	menu = MainMenu.new()
	add_child(menu)
	await _start_game()
	var st := SelfTest.new()
	st.boot = self
	add_child(st)
	await st.run()
	get_tree().quit()


func _build_test() -> void:
	## yerel/CI hızlı deneme: dünyayı kur, oyunu başlat, birkaç saniye oynat, haritayı aç (çizim beklemez)
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	world = World.new()
	add_child(world)
	await world.build(Callable())
	print("DUNYA %d ms, poi %d, kapı %d, bina %d" % [Time.get_ticks_msec() - t0, world.pois.size(), world.doors.size(), world.data.city.buildings.size()])
	menu_cam = Camera3D.new()
	world.add_child(menu_cam)
	menu = MainMenu.new()
	add_child(menu)
	await _start_game()
	for k in range(120):
		await get_tree().physics_frame
	print("OYUNCU ", player.global_position, " bölge=", world.district_name(player.global_position))
	var r := world.route(player.global_position, Vector3(180, 0, -1000))
	print("ROTA nokta=", r.size())
	# dövüş / aranma / eşya kırma denemesi
	for id in Weapons.ORDER:
		player.combat.equip(id)
	player.combat.equip("katana")
	var ped: Pedestrian = null
	var bd := 1e9
	for n in get_tree().get_nodes_in_group("people"):
		var d := (n as Node3D).global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			ped = n
	if ped:
		player.global_position = ped.global_position + Vector3(1.0, 0.3, 0)
		player.visual.rotation.y = atan2(-1.0, 0.0)
		for k in range(6):
			player.combat.busy = 0.0
			player.combat._attack(k == 5)
			for j in range(45):
				await get_tree().physics_frame
		print("DOVUS yaya can=%.0f durum=%d yildiz=%d" % [ped.health, ped.state, wanted.stars])
	wanted._raise(3, player.global_position)
	for j in range(240):
		await get_tree().physics_frame
	print("POLIS yaya=%d araba=%d yildiz=%d" % [get_tree().get_nodes_in_group("police").size(), wanted.cars.size(), wanted.stars])
	var b0: Dictionary = world.breakables[0]
	var okp := world.hit_props(Vector3(b0.pos.x, b0.pos.y + 1.0, b0.pos.z), 1.0, Vector3(5, 0, 0))
	for j in range(30):
		await get_tree().physics_frame
	print("ESYA kirildi=", okp, " tur=", b0.kind, " parca=", world.breaker.debris.size())
	player.combat.take_hit(500.0, player.global_position + Vector3(1, 0, 0), true, null)
	await get_tree().create_timer(5.0).timeout
	print("YENIDEN can=%.0f konum=%s yildiz=%d" % [player.combat.health, player.global_position, wanted.stars])
	# iç mekânlar + dükkân
	for d in world.doors:
		if String(d.interior) == "atolye":
			continue
		player.global_position = (d.pos as Vector3) + Vector3(0, 0.3, 0)
		await get_tree().physics_frame
		var pr: String = world.door_prompt(player.global_position)
		var ok := world.try_door(player)
		await get_tree().create_timer(1.2).timeout
		var ins := world.interiors.current
		player.global_position = world.interiors.built[ins].counter if ins != "" else player.global_position
		await get_tree().physics_frame
		var pr2: String = world.door_prompt(player.global_position)
		if ins != "":
			world.try_door(player)
			await get_tree().process_frame
			for n in get_children():
				if n is ShopUI:
					(n as ShopUI)._buy()
					(n as ShopUI)._close()
			player.global_position = world.interiors.built[ins].door
			world.try_door(player)
			await get_tree().create_timer(1.2).timeout
		print("KAPI %s istem='%s' girdi=%s ic='%s' tezgah='%s' para=%d" % [d.interior, pr, ok, ins, pr2, Game.money])
	# telefon, radyo, kıyafet, güçler, ejderha
	player.global_position = SPAWN
	await get_tree().physics_frame
	var ph := Phone.new()
	ph.player = player
	player.phone = ph
	add_child(ph)
	for app in ["kisiler", "mesaj", "yolculuk", "banka", "radyo", "neongram", "gardirop"]:
		ph._open(app)
		await get_tree().process_frame
		ph._back()
	ph.close()
	radio.select("neonfm")
	print("RADYO istasyon=", radio.station)
	Outfits.apply(player, "ates")
	await get_tree().process_frame
	print("KIYAFET ", Game.outfit)
	player.powers._spin_start()
	for j in range(60):
		await get_tree().physics_frame
	print("KASIRGA kalan=%.1f" % player.powers.spin_t)
	player.combat.stamina = 100.0
	player.powers.elem_cd = 0.0
	player.powers._element()
	await get_tree().create_timer(1.5).timeout
	player.powers._summon()
	for j in range(120):
		await get_tree().physics_frame
	print("EJDERHA binildi=%s y=%.1f" % [player.mount != null, player.global_position.y])
	player.powers.dragon.dismiss()
	for j in range(60):
		await get_tree().physics_frame
	print("EJDERHA indi=%s" % [player.mount == null])
	var mp := open_map()
	await get_tree().process_frame
	mp.queue_free()
	print("BITTI")


func _make_test_minifig(path: String) -> bool:
	## tek yüzeyli, iskeletsiz, oyuncak figür benzeri test modeli üretip glb olarak yazar
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts := [[Vector3(-0.245, 0.5, 0), Vector3(0.45, 1.0, 0.5)], [Vector3(0.245, 0.5, 0), Vector3(0.45, 1.0, 0.5)],
		[Vector3(0, 1.125, 0), Vector3(0.96, 0.25, 0.5)], [Vector3(0, 1.62, 0), Vector3(0.9, 0.75, 0.45)],
		[Vector3(-0.6, 1.62, 0), Vector3(0.24, 0.7, 0.3)], [Vector3(0.6, 1.62, 0), Vector3(0.24, 0.7, 0.3)],
		[Vector3(-0.6, 1.17, 0.02), Vector3(0.2, 0.2, 0.2)], [Vector3(0.6, 1.17, 0.02), Vector3(0.2, 0.2, 0.2)],
		[Vector3(0, 2.05, 0), Vector3(0.3, 0.1, 0.3)], [Vector3(0, 2.35, 0), Vector3(0.6, 0.5, 0.6)]]
	for p in parts:
		var bm := BoxMesh.new()
		bm.size = p[1]
		st.append_from(bm, 0, Transform3D(Basis(), p[0]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.8, 0.2)
	mi.material_override = mat
	var root := Node3D.new()
	root.add_child(mi)
	mi.owner = root
	var doc := GLTFDocument.new()
	var gs := GLTFState.new()
	if doc.append_from_scene(root, gs) != OK:
		root.free()
		return false
	var err := doc.write_to_filesystem(gs, path)
	root.free()
	return err == OK


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _free_cam(pos: Vector3, look: Vector3) -> void:
	menu_cam.current = true
	menu_cam.look_at_from_position(pos, look, Vector3.UP)


func _player_cam() -> void:
	menu_cam.current = false
	player.cam.make_current()


func _set_time(h: float) -> void:
	Game.time_of_day = h
	world.update_time(h, true)


func _run_shots() -> void:
	await _wait(30)
	await Game.shot("01_menu")
	menu.settings_ui.visible = true
	menu.settings_ui.select_tab(3)
	await _wait(10)
	await Game.shot("02_ayarlar")
	menu.settings_ui.visible = false
	var ld := LoadingScreen.new()
	add_child(ld)
	ld.step(0.62, "Şehir blokları")
	await _wait(18)
	await Game.shot("03_yukleme")
	ld.queue_free()
	await _start_game()
	_set_time(11.0)
	await _wait(24)
	await Game.shot("04_gunduz")
	dialog.play_scene("intro")
	_set_time(18.4)
	await _wait(18)
	await Game.shot("05_gunbatimi_diyalog")
	_set_time(22.5)
	await _wait(18)
	await Game.shot("06_gece")
	# araç: sürücü koltuğunda, gündüz
	_set_time(12.5)
	var car: Car = get_tree().get_nodes_in_group("cars")[0]
	player.global_position = car.global_position + Vector3(2.2, 0, 0)
	await _wait(5)
	player._try_enter()
	await _wait(20)
	_free_cam(car.global_position + Vector3(4.2, 2.3, 5.0), car.global_position + Vector3(0, 1.0, 0))
	await _wait(10)
	await Game.shot("07_arac")
	# sürüş: 3 sn gaz, oyuncu kamerasından (FPS, kamera, araç duruşu)
	_player_cam()
	Input.action_press("move_forward")
	await _wait(18)
	Input.action_press("move_left", 0.6)
	await _wait(25)
	await Game.shot("22_surus")
	Input.action_release("move_left")
	Input.action_release("move_forward")
	await _wait(20)
	player.exit_car()
	await _wait(16)
	await Game.shot("23_inis")
	# yakın plan karakter (önden)
	player.global_position = SPAWN + Vector3(0, 0, 4)
	player.visual.rotation.y = PI
	await _wait(20)
	var pp := player.global_position
	_free_cam(pp + Vector3(0.6, 1.6, -3.4), pp + Vector3(0, 1.1, 0))
	await _wait(10)
	await Game.shot("08_karakter")
	player.visual.crouch = true
	player.visual.set_motion(0.0, true)
	await _wait(20)
	await Game.shot("24_egilme")
	player.visual.crouch = false
	# gece şehir manzaraları
	_set_time(22.0)
	_free_cam(Vector3(-118, 34, -118), Vector3(0, 12, 0))
	await _wait(18)
	await Game.shot("09_gece_merkez")
	_free_cam(Vector3(-163, 2.2, -8), Vector3(-158, 8.0, -80))
	await _wait(16)
	await Game.shot("10_eski_carsi")
	_free_cam(Vector3(-6, 2.4, -58), Vector3(-6, 6.0, 10))
	await _wait(16)
	await Game.shot("11_gece_cadde")
	_set_time(18.1)
	_free_cam(Vector3(-418, 3.0, 30), Vector3(-482, 2.0, 220))
	await _wait(18)
	await Game.shot("12_sahil_gunbatimi")
	_set_time(15.0)
	_free_cam(Vector3(175, 78, 175), Vector3(40, 15, 40))
	await _wait(16)
	await Game.shot("13_monoray")
	# ada: havadan, manastır, köprü, liman
	_free_cam(Vector3(500, 2300, 3600), Vector3(900, 0, 1200))
	await _wait(18)
	await Game.shot("18_ada_hava")
	var M := World.MON
	_set_time(9.5)
	_free_cam(M + Vector3(45, 20, 105), M + Vector3(0, 8, -20))
	await _wait(18)
	await Game.shot("19_manastir")
	_set_time(19.8)
	_free_cam(Vector3(-520, 24, -240), Vector3(-760, 14, -650))
	await _wait(18)
	await Game.shot("20_kopru")
	_set_time(17.2)
	_free_cam(Vector3(-400, 16, 0), Vector3(-470, 2, -200))
	await _wait(18)
	await Game.shot("21_liman")
	_set_time(12.0)
	for spec in [["28_col", Vector3(950, 70, 250), Vector3(1250, 10, 800)], ["29_gecit", Vector3(1880, 90, 560), Vector3(2100, 45, 640)],
			["30_sis", Vector3(2830, 30, 1820), Vector3(2950, 3, 1950)], ["31_lunapark", Vector3(70, 32, 150), Vector3(200, 12, 280)],
			["32_kanyon", Vector3(1150, 120, 1700), Vector3(1400, 30, 2050)], ["33_huslar", Vector3(2450, 90, -150), Vector3(2700, 40, -350)]]:
		var g := world.ground_y(spec[1].x, spec[1].z)
		_free_cam(spec[1] + Vector3(0, maxf(0.0, g + 15.0 - spec[1].y), 0), spec[2])
		await _wait(14)
		await Game.shot(spec[0])
	var mp := open_map()
	await _wait(8)
	await Game.shot("34_harita")
	mp._zoom = 0.9
	mp._cam = Vector2(0, 0)
	mp.canvas.queue_redraw()
	await _wait(4)
	await Game.shot("35_harita_sehir")
	mp.closed.emit()
	mp.queue_free()
	await _wait(2)
	# arazi çarpışması: oyuncu tepede yürüyebiliyor mu
	_set_time(13.0)
	var tp := Vector3(60, world.terrain_h(60, -430) + 1.5, -430)
	player.global_position = tp
	player.velocity = Vector3.ZERO
	_player_cam()
	await _wait(20)
	print("ARAZI oyuncu_y=", player.global_position.y, " arazi_y=", world.terrain_h(player.global_position.x, player.global_position.z))
	await Game.shot("25_arazi")
	# dövüş: katana, yaya karşılık veriyor; aranma yıldızları; silah çarkı; etkileşim menüsü
	_set_time(18.2)
	player.global_position = Vector3(-88.5, 0.3, -52.0)
	player.yaw = PI + 0.25
	player.visual.rotation.y = 0.0
	var foe := Pedestrian.new()
	foe.world = world
	foe.slot = "yaya3"
	foe.path = world.sidewalk_loop(world.blocks[0])
	world.add_child(foe)
	foe.global_position = Vector3(-88.5, 0.18, -50.4)
	foe.brave = true
	foe.threat = player
	foe.hostile = true
	foe.state = Pedestrian.S.FIGHT
	player.combat.equip("katana")
	_player_cam()
	await _wait(12)
	player.combat.busy = 0.0
	player.combat._attack(false)
	await _wait(9)
	await Game.shot("36_dovus")
	wanted._raise(3, player.global_position)
	await _wait(40)
	await Game.shot("37_aranma")
	Input.action_press("weapon_wheel")
	player.combat._open_wheel()
	await _wait(10)
	await Game.shot("38_silah_carki")
	Input.action_release("weapon_wheel")
	await _wait(4)
	wanted.clear()
	Game.set_slowmo(1.0)
	if is_instance_valid(foe):
		foe._set_walk()
		foe.global_position = player.global_position + Vector3(1.4, 0, 0)
		var tm := TalkMenu.new()
		tm.player = player
		tm.ped = foe
		player.talk = tm
		add_child(tm)
		await _wait(8)
		await Game.shot("39_etkilesim")
		tm._close()
	# giriş sineması (ilk kare) ve eşya sekmesi
	var intro := Intro.new()
	intro.world = world
	intro.player = player
	add_child(intro)
	await _wait(8)
	await Game.shot("47_giris")
	intro._skip = true
	await _wait(12)
	player.controls = true
	_player_cam()
	# güçler: kasırga, ejderha
	player.combat.stamina = 100.0
	player.powers._spin_start()
	await _wait(16)
	await Game.shot("40_kasirga")
	player.powers._spin_end()
	await _wait(6)
	player.global_position = Vector3(-440.0, 1.0, 170.0)
	player.velocity = Vector3.ZERO
	_set_time(17.6)
	await _wait(6)
	player.powers._summon()
	await _wait(5)
	player.pitch = -0.12
	player.yaw = PI * 0.5
	for j in range(40):
		Input.action_press("move_forward")
		await get_tree().process_frame
	Input.action_release("move_forward")
	await Game.shot("41_ejderha")
	player.powers.dragon.dismiss()
	await _wait(10)
	player.global_position = SPAWN
	player.velocity = Vector3.ZERO
	await _wait(10)
	# telefon
	var ph := Phone.new()
	ph.player = player
	player.phone = ph
	add_child(ph)
	await _wait(8)
	await Game.shot("42_telefon")
	ph._open("neongram")
	await _wait(4)
	await Game.shot("43_telefon_neongram")
	ph.close()
	await _wait(8)
	# dükkân ve kulüp iç mekânları
	for d in world.doors:
		if String(d.interior) in ["restoran", "kulup", "silah"]:
			player.global_position = (d.pos as Vector3) + Vector3(0, 0.3, 0)
			await _wait(2)
			world.try_door(player)
			await _wait(14)
			var ins: String = world.interiors.current
			if ins != "":
				player.global_position = world.interiors.built[ins].counter + Vector3(0, 0, -2.5)
				player.yaw = PI
				await _wait(8)
				await Game.shot("44_ic_" + ins)
				if ins == "restoran":
					world.try_door(player)
					player.global_position = world.interiors.built[ins].counter
					world.try_door(player)
					await _wait(8)
					await Game.shot("45_dukkan_menusu")
					for n in get_children():
						if n is ShopUI:
							(n as ShopUI)._close()
				player.global_position = world.interiors.built[ins].door
				world.try_door(player)
				await _wait(14)
	# radyo çarkı (araçta)
	var car0: Car = null
	for c in get_tree().get_nodes_in_group("cars"):
		car0 = c
		break
	if car0:
		player.global_position = car0.global_position + Vector3(1.5, 0.3, 0)
		await _wait(3)
		player._try_enter()
		await _wait(10)
		Input.action_press("radio")
		radio._open_wheel()
		await _wait(10)
		await Game.shot("46_radyo_carki")
		Input.action_release("radio")
		await _wait(4)
		player.exit_car()
		await _wait(10)
	_player_cam()
	_pause()
	await _wait(10)
	var ap := AdminPanel.new()
	add_child(ap)
	await _wait(25)
	await Game.shot("14_yonetici")
	# iskeletli özel model testi (admin yuvasına geçici olarak bağla, kaydetme)
	if FileAccess.file_exists("res://assets/chars/human.glb"):
		Game.admin.slots["yaya1"] = {"type": "glb", "path": "res://assets/chars/human.glb"}
		ap.list.select(3)
		ap._select("yaya1")
		await _wait(16)
		await Game.shot("16_ozel_model_yuru")
		ap.preview.play_once("punch_cross", 0.1)
		await _wait(12)
		await Game.shot("17_ozel_model_yumruk")
		Game.admin.slots.erase("yaya1")
	# tek parça "minifig" testi poz testinde (animtest.yml) yapılıyor
	ap.queue_free()
	await _wait(5)
	await Game.shot("15_duraklat")
	get_tree().quit()
