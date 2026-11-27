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
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.build()
	menu_cam = Camera3D.new()
	menu_cam.fov = 55
	menu_cam.far = 1500
	world.add_child(menu_cam)
	menu_cam.make_current()
	await _capture_keyart()
	Game.time_of_day = 18.2
	menu = MainMenu.new()
	add_child(menu)
	menu.play_pressed.connect(_start_game)
	menu.resume_pressed.connect(_resume)
	menu.open(false)
	if Game.shots_dir != "":
		_run_shots()


func _capture_keyart() -> void:
	var shots := [[Vector3(-86, 2.0, 30), Vector3(-80, 9, -40), 17.7], [Vector3(-20, 1.8, 236), Vector3(60, 5, 244), 11.0], [Vector3(-118, 34, -118), Vector3(0, 12, 0), 21.5]]
	for s in shots:
		Game.time_of_day = s[2]
		world.update_time(s[2], true)
		menu_cam.look_at_from_position(s[0], s[1], Vector3.UP)
		for i in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		Game.keyart.append(ImageTexture.create_from_image(img))


func _process(delta: float) -> void:
	if not playing:
		_orbit += delta * 0.04
		var c := Vector3(0, 25, 0)
		menu_cam.look_at_from_position(c + Vector3(cos(_orbit) * 160, 55 + sin(_orbit * 0.7) * 10, sin(_orbit) * 160), c, Vector3.UP)


const SPAWN := Vector3(-88.5, 0.4, -36.0)
var dialog: DialogBox


func _start_game() -> void:
	menu.visible = false
	var ld := LoadingScreen.new()
	add_child(ld)
	ld.set_progress(0.05)
	await get_tree().process_frame
	# oyuncu: Kaan, merkezin batısındaki caddede kaldırımda
	player = Player.new()
	player.world = world
	world.add_child(player)
	player.global_position = SPAWN
	player.yaw = PI
	ld.set_progress(0.25)
	await get_tree().process_frame
	# park hâlindeki araçlar (yol kenarında)
	var parked := [["sedan-sports", Vector3(-84.6, 0.5, -46.0), 0.0], ["taxi", Vector3(-84.6, 0.5, -24.0), 0.0], ["suv", Vector3(-75.4, 0.5, -12.0), PI],
		["police", Vector3(-4.6, 0.5, -120.0), 0.0], ["hatchback-sports", Vector3(84.6, 0.5, 30.0), 0.0], ["van", Vector3(-164.6, 0.5, 60.0), 0.0],
		["suv-luxury", Vector3(20.0, 0.5, 235.4), -PI * 0.5], ["sedan", Vector3(124.0, 0.5, -155.4), PI * 0.5]]
	for p in parked:
		var c := Car.new()
		c.model = p[0]
		world.add_child(c)
		c.global_position = p[1]
		c.rotation.y = p[2]
	ld.set_progress(0.5)
	await get_tree().process_frame
	# trafik
	for i in range(18):
		var t := TrafficCar.new()
		t.world = world
		t.model = CarModel.TRAFFIC[i % CarModel.TRAFFIC.size()]
		var a := Vector2i(randi_range(-World.GRID, World.GRID - 1), randi_range(-World.GRID, World.GRID))
		t.from = a
		t.to = a + Vector2i(1, 0)
		world.add_child(t)
	ld.set_progress(0.7)
	await get_tree().process_frame
	# yayalar
	var yaya_slots := []
	for k in Game.SLOTS.keys():
		if String(k).begins_with("yaya"):
			yaya_slots.append(k)
	for i in range(46):
		var r: Rect2 = world.blocks[i % world.blocks.size()]
		var loop := world.sidewalk_loop(r)
		var n := Pedestrian.new()
		n.slot = "polis" if i % 11 == 5 else yaya_slots[i % yaya_slots.size()]
		n.path = loop if i % 2 == 0 else [loop[0], loop[3], loop[2], loop[1]]
		n.idx = randi() % loop.size()
		world.add_child(n)
		n.global_position = loop[n.idx].lerp(loop[(n.idx + 1) % loop.size()], randf())
	ld.set_progress(0.85)
	hud = HUD.new()
	hud.player = player
	hud.world = world
	add_child(hud)
	dialog = DialogBox.new()
	add_child(dialog)
	Game.time_of_day = 16.5
	for i in range(20):
		await get_tree().process_frame
		ld.set_progress(0.85 + i * 0.0075)
	ld.set_progress(1.0)
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
	ld.set_progress(0.6)
	await _wait(10)
	await Game.shot("03_yukleme")
	ld.queue_free()
	await _start_game()
	_set_time(11.0)
	await _wait(45)
	await Game.shot("04_gunduz")
	dialog.play_scene("intro")
	_set_time(18.4)
	await _wait(40)
	await Game.shot("05_gunbatimi_diyalog")
	_set_time(22.5)
	await _wait(40)
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
	_player_cam()
	player.exit_car()
	# yakın plan karakter (önden)
	player.global_position = SPAWN + Vector3(0, 0, 4)
	player.visual.rotation.y = PI
	await _wait(20)
	var pp := player.global_position
	_free_cam(pp + Vector3(0.6, 1.6, -3.4), pp + Vector3(0, 1.1, 0))
	await _wait(10)
	await Game.shot("08_karakter")
	# gece şehir manzaraları
	_set_time(22.0)
	_free_cam(Vector3(-118, 34, -118), Vector3(0, 12, 0))
	await _wait(40)
	await Game.shot("09_gece_merkez")
	_free_cam(Vector3(-60, 3.5, -240), Vector3(20, 6.0, -238))
	await _wait(30)
	await Game.shot("10_eski_carsi")
	_free_cam(Vector3(-6, 2.4, -58), Vector3(-6, 6.0, 10))
	await _wait(30)
	await Game.shot("11_gece_cadde")
	_set_time(18.1)
	_free_cam(Vector3(-30, 3.5, 262), Vector3(30, 6.0, 230))
	await _wait(40)
	await Game.shot("12_sahil_gunbatimi")
	_set_time(15.0)
	_free_cam(Vector3(175, 78, 175), Vector3(40, 15, 40))
	await _wait(30)
	await Game.shot("13_monoray")
	_player_cam()
	_pause()
	await _wait(10)
	var ap := AdminPanel.new()
	add_child(ap)
	await _wait(25)
	await Game.shot("14_yonetici")
	ap.queue_free()
	await _wait(5)
	await Game.shot("15_duraklat")
	get_tree().quit()
