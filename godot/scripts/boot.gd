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
	var shots := [[Vector3(-30, 2.2, 52), Vector3(10, 6, 0), 17.6], [Vector3(46, 1.6, -36), Vector3(0, 3, -40), 11.0], [Vector3(-10, 30, -110), Vector3(30, 0, -10), 21.5]]
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
		var c := Vector3(0, 8, 0)
		menu_cam.look_at_from_position(c + Vector3(cos(_orbit) * 70, 22 + sin(_orbit * 0.7) * 6, sin(_orbit) * 70), c, Vector3.UP)


func _start_game() -> void:
	menu.visible = false
	var ld := LoadingScreen.new()
	add_child(ld)
	ld.set_progress(0.05)
	await get_tree().process_frame
	# oyuncu
	player = Player.new()
	player.world = world
	world.add_child(player)
	player.global_position = Vector3(-40 + 8.0, 0.4, 40 - 1.0)
	player.yaw = PI * 0.75
	ld.set_progress(0.25)
	await get_tree().process_frame
	# park hâlindeki araçlar
	var colors := [Color(0.75, 0.05, 0.08), Color(0.95, 0.95, 0.95), Color(0.05, 0.05, 0.06), Color(0.1, 0.35, 0.75), Color(0.85, 0.6, 0.1)]
	var spots := [Vector3(-40 + 4.2, 0.6, 46), Vector3(-40 + 4.2, 0.6, 58), Vector3(4.2, 0.6, -20), Vector3(-4.2, 0.6, 20), Vector3(36, 0.6, -4.2)]
	for i in spots.size():
		var c := Car.new()
		c.body_color = colors[i % colors.size()]
		world.add_child(c)
		c.global_position = spots[i]
		c.rotation.y = 0.0 if i < 4 else PI * 0.5
	ld.set_progress(0.5)
	await get_tree().process_frame
	# trafik
	for i in range(8):
		var t := TrafficCar.new()
		t.world = world
		t.color = colors[(i + 2) % colors.size()].lerp(Color(randf(), randf(), randf()), 0.3)
		var a := Vector2i(randi_range(-1, 1), randi_range(-2, 2))
		t.from = a
		t.to = a + Vector2i(1, 0)
		world.add_child(t)
	ld.set_progress(0.7)
	await get_tree().process_frame
	# yayalar
	for i in range(18):
		var r: Rect2 = world.blocks[i % world.blocks.size()]
		var loop := world.sidewalk_loop(r)
		var n := Pedestrian.new()
		n.path = loop
		n.idx = randi() % loop.size()
		world.add_child(n)
		n.global_position = loop[n.idx].lerp(loop[(n.idx + 1) % loop.size()], randf())
	ld.set_progress(0.85)
	hud = HUD.new()
	hud.player = player
	hud.world = world
	add_child(hud)
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


func _run_shots() -> void:
	await _wait(30)
	await Game.shot("01_menu")
	menu.settings_ui.visible = true
	menu.settings_ui.select_tab(1)
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
	for t in [[11.0, "04_gunduz"], [18.3, "05_gunbatimi"], [22.5, "06_gece"]]:
		Game.time_of_day = t[0]
		world.update_time(t[0], true)
		await _wait(45)
		await Game.shot(t[1])
	# araç
	Game.time_of_day = 12.0
	var car: Car = get_tree().get_nodes_in_group("cars")[0]
	player.global_position = car.global_position + Vector3(2, 0, 0)
	await _wait(5)
	player._try_enter()
	await _wait(40)
	await Game.shot("07_arac")
	# yakın plan karakter
	player.exit_car()
	player.yaw = 0.0
	player.pitch = -0.05
	player.arm.spring_length = 1.8
	await _wait(40)
	await Game.shot("08_karakter")
	_pause()
	await _wait(15)
	await Game.shot("09_duraklat")
	get_tree().quit()
