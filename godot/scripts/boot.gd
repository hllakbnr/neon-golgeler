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
	menu.open(false)
	if Game.shots_dir != "":
		_run_shots()


func _capture_keyart() -> void:
	## anahtar görseller ayrı bir SubViewport'ta çekilir (yükleme ekranı açık kalır), diske de kaydedilir
	var M := World.MON
	var shots := [
		[Vector3(-163, 2.2, 76), Vector3(-158, 8.0, 10), 18.0],            # Eski Çarşı fenerleri
		[Vector3(-70, 3.0, 334), Vector3(40, 2.5, 352), 11.0],              # Sahil
		[Vector3(-210, 70, 230), Vector3(120, 40, -150), 21.5],             # gece Neon Bulvar + kule
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
var dialog: DialogBox


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
		["police", Vector3(-4.6, 0.5, -120.0), 0.0], ["hatchback-sports", Vector3(84.6, 0.5, 30.0), 0.0], ["van", Vector3(-164.6, 0.5, 60.0), 0.0],
		["suv-luxury", Vector3(20.0, 0.5, 235.4), -PI * 0.5], ["sedan", Vector3(124.0, 0.5, -155.4), PI * 0.5],
		["sedan-sports", Vector3(60.0, 0.6, 335.0), -PI * 0.5], ["truck", Vector3(-345.0, 1.9, 70.0), 0.0],
		["suv", M + Vector3(-2.0, 1.5, 64.0), PI], ["police", Vector3(World.ISLE.x - 70.0, 3.8, World.ISLE.y + 8.0), -PI * 0.5],
		["hatchback-sports", Vector3(World.EDGE + 40.0, 1.2, -4.0), -PI * 0.5]]
	for p in parked:
		var c := Car.new()
		c.model = p[0]
		world.add_child(c)
		c.global_position = p[1]
		c.rotation.y = p[2]
	ld.step(0.45, "Trafik başlıyor")
	await get_tree().process_frame
	# trafik: her araç farklı bir kavşaktan başlar (üst üste doğmaz)
	var nodes := []
	for x in range(-World.GRID, World.GRID + 1):
		for y in range(-World.GRID, World.GRID + 1):
			if Vector3(x * World.CELL, 0, y * World.CELL).distance_to(SPAWN) > 40.0:
				nodes.append(Vector2i(x, y))
	nodes.shuffle()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in range(mini(30, nodes.size())):
		var a: Vector2i = nodes[i]
		dirs.shuffle()
		var to := a
		for d in dirs:
			var n: Vector2i = a + d
			if absi(n.x) <= World.GRID and absi(n.y) <= World.GRID:
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
	# yayalar
	var yaya_slots := []
	for k in Game.SLOTS.keys():
		if String(k).begins_with("yaya"):
			yaya_slots.append(k)
	for i in range(72):
		var r: Rect2 = world.blocks[(i * 7) % world.blocks.size()]
		var loop := world.sidewalk_loop(r)
		var n := Pedestrian.new()
		n.slot = "polis" if i % 11 == 5 else yaya_slots[i % yaya_slots.size()]
		n.path = loop if i % 2 == 0 else [loop[0], loop[3], loop[2], loop[1]]
		n.idx = randi() % loop.size()
		world.add_child(n)
		n.global_position = loop[n.idx].lerp(loop[(n.idx + 1) % loop.size()], randf())
		if i % 12 == 11:
			ld.step(0.65 + i * 0.003, "Sokaklar doluyor")
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
	if Game.shots_dir == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().create_timer(2.0).timeout.connect(func(): dialog.play_scene("intro"))


func _unhandled_input(e: InputEvent) -> void:
	if playing and e.is_action_pressed("pause") and not get_tree().paused:
		_pause()
		get_viewport().set_input_as_handled()
	if playing and e is InputEventMouseButton and e.pressed and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	_free_cam(Vector3(-163, 2.2, 76), Vector3(-158, 8.0, 10))
	await _wait(16)
	await Game.shot("10_eski_carsi")
	_free_cam(Vector3(-6, 2.4, -58), Vector3(-6, 6.0, 10))
	await _wait(16)
	await Game.shot("11_gece_cadde")
	_set_time(18.1)
	_free_cam(Vector3(60, 3.0, 336), Vector3(-40, 4.0, 348))
	await _wait(18)
	await Game.shot("12_sahil_gunbatimi")
	_set_time(15.0)
	_free_cam(Vector3(175, 78, 175), Vector3(40, 15, 40))
	await _wait(16)
	await Game.shot("13_monoray")
	# ada: havadan, manastır, köprü, liman
	_free_cam(Vector3(0, 650, 1050), Vector3(0, 0, -180))
	await _wait(18)
	await Game.shot("18_ada_hava")
	var M := World.MON
	_set_time(9.5)
	_free_cam(M + Vector3(45, 20, 105), M + Vector3(0, 8, -20))
	await _wait(18)
	await Game.shot("19_manastir")
	_set_time(19.8)
	_free_cam(Vector3(World.BRIDGE_X0 - 30, 16, 40), Vector3((World.BRIDGE_X0 + World.BRIDGE_X1) * 0.5, 8, 0))
	await _wait(18)
	await Game.shot("20_kopru")
	_set_time(17.2)
	_free_cam(Vector3(-World.EDGE + 10, 14, 30), Vector3(-World.EDGE - 60, 2, 150))
	await _wait(18)
	await Game.shot("21_liman")
	# arazi çarpışması: oyuncu tepede yürüyebiliyor mu
	_set_time(13.0)
	var tp := Vector3(60, world.terrain_h(60, -430) + 1.5, -430)
	player.global_position = tp
	player.velocity = Vector3.ZERO
	_player_cam()
	await _wait(20)
	print("ARAZI oyuncu_y=", player.global_position.y, " arazi_y=", world.terrain_h(player.global_position.x, player.global_position.z))
	await Game.shot("25_arazi")
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
	# iskeletsiz tek parça "minifig" testi (Element Arenası parçalama sistemi)
	var mf := "user://test_minifig.glb"
	if _make_test_minifig(mf):
		Game.admin.slots["yaya2"] = {"type": "glb", "path": mf}
		ap.list.select(4)
		ap._select("yaya2")
		await _wait(20)
		print("MINIFIG mod=", ap.preview.mode, " not=", ap.preview.note)
		await Game.shot("26_minifig_yuru")
		ap.preview.play_once("punch_cross", 0.1)
		await _wait(10)
		await Game.shot("27_minifig_yumruk")
		Game.admin.slots.erase("yaya2")
	ap.queue_free()
	await _wait(5)
	await Game.shot("15_duraklat")
	get_tree().quit()
