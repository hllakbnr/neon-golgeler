extends CanvasLayer
class_name Intro
## Oyun başında hikâyeyi anlatan sinematik giriş (GTA girişleri gibi): sinema şeritleri, ağır kamera
## kaydırmaları, anlatıcı (Bilge Usta) ve Kaan'ın sesi, sonda oyun adı. Enter / Esc / Boşluk ile geçilir.

signal finished

var world: World
var player: Player
var _cam: Camera3D
var _sub: Label
var _title: Label
var _fade: ColorRect
var _music: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _skip := false
var _lines: Array = []


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = 0.12
		else:
			bar.anchor_top = 0.88
			bar.anchor_bottom = 1.0
		add_child(bar)
	_sub = Game.styled_label("", 30, Color.WHITE)
	_sub.anchor_top = 0.88
	_sub.anchor_bottom = 1.0
	_sub.anchor_right = 1.0
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_sub)
	_title = Game.styled_label("NEON GÖLGELER", 150, Color(1.0, 0.35, 0.8), true)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	add_child(_title)
	var skip := Game.styled_label("Geçmek için Enter", 16, Color(1, 1, 1, 0.5))
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -260
	skip.offset_right = -30
	skip.offset_top = 30
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(skip)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_cam = Camera3D.new()
	_cam.fov = 52.0
	world.add_child(_cam)
	_cam.make_current()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -10.0
	if ResourceLoader.exists("res://assets/music/dalga.ogg"):
		_music.stream = load("res://assets/music/dalga.ogg")
		add_child(_music)
		_music.play()
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	var dlg := get_tree().current_scene.get("dialog") as DialogBox
	if dlg:
		_lines = dlg.lines.get("intro_story", [])
	if Game.hud:
		(Game.hud as CanvasLayer).visible = false
	player.controls = false
	_run()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e as InputEventKey).keycode in [KEY_ENTER, KEY_ESCAPE, KEY_SPACE, KEY_KP_ENTER]:
		_skip = true
		get_viewport().set_input_as_handled()


func _line(i: int) -> Dictionary:
	return _lines[i] if i < _lines.size() else {"text": "", "id": ""}


func _shot(a: Vector3, b: Vector3, look_a: Vector3, look_b: Vector3, line: Dictionary) -> void:
	if _skip:
		return
	var dur := 6.5
	_voice.stop()
	var vp := "res://assets/voice/%s.ogg" % String(line.get("id", ""))
	if ResourceLoader.exists(vp):
		_voice.stream = load(vp)
		_voice.play()
		dur = maxf(dur, _voice.stream.get_length() + 1.4)
	_sub.text = String(line.get("text", ""))
	if not Game.settings.get("subtitles", true):
		_sub.text = ""
	var t := 0.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	while t < dur and not _skip:
		var k := t / dur
		var e := k * k * (3.0 - 2.0 * k)
		_cam.global_position = a.lerp(b, e)
		var lk := look_a.lerp(look_b, e)
		if lk.distance_to(_cam.global_position) > 0.1:
			_cam.look_at(lk, Vector3.UP)
		if t > dur - 0.8 and _fade.color.a < 0.01:
			var tw2 := create_tween()
			tw2.tween_property(_fade, "color:a", 1.0, 0.7)
		await get_tree().process_frame
		t += get_process_delta_time()


func _run() -> void:
	Game.time_of_day = 19.2
	var M := World.MON
	var pp := player.global_position
	var head := pp + Vector3(0, 1.6, 0)
	await _shot(Vector3(-780, 70, 360), Vector3(-620, 55, 220), Vector3(-300, 10, 0), Vector3(-150, 20, -40), _line(0))
	await _shot(M + Vector3(170, 60, 210), M + Vector3(120, 30, 150), M + Vector3(0, 10, 0), M + Vector3(0, 14, 0), _line(1))
	await _shot(Vector3(-560, 95, 520), Vector3(-430, 70, 380), Vector3(100, 40, -150), Vector3(60, 50, -120), _line(2))
	await _shot(Vector3(-163, 3.5, -2), Vector3(-161, 2.6, -40), Vector3(-158, 8, -80), Vector3(-157, 6, -100), _line(3))
	await _shot(head + Vector3(2.2, 0.4, 4.5), head + Vector3(1.0, 0.1, 2.2), head, head, _line(4))
	_voice.stop()
	_sub.text = ""
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	tw.tween_property(_title, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6 if not _skip else 0.3)
	await tw.finished
	player.cam.make_current()
	_cam.queue_free()
	player.controls = true
	if Game.hud:
		(Game.hud as CanvasLayer).visible = true
	var tw3 := create_tween()
	tw3.tween_property(_title, "modulate:a", 0.0, 0.5)
	tw3.parallel().tween_property(_fade, "color:a", 0.0, 0.9)
	tw3.parallel().tween_property(_music, "volume_db", -60.0, 1.2)
	await tw3.finished
	finished.emit()
	queue_free()
