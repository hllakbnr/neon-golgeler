extends Node
class_name Radio
## Araç radyosu (GTA'daki gibi): araçtayken Q basılı tut → radyo çarkı, bırakınca istasyon değişir.
## İstasyonlar "canlı" çalar: hangi istasyona geçersen geç, şarkı o anki yerinden devam eder.
## Geçişte kısa parazit, ekranda istasyon adı, ara sıra DJ anonsu. Araçtan inince radyo susar.
## Müzikler derlemede prosedürel olarak bestelenir (tools/make_music.py) — telifsiz, oyuna özel.

static var inst: Radio

const STATIONS := [
	{"id": "neonfm", "name": "Neon FM", "genre": "Synthwave · gece sürüşü", "col": Color(1.0, 0.2, 0.75), "short": "NEON"},
	{"id": "ritim", "name": "Ritim 93", "genre": "Hip-hop · lo-fi", "col": Color(1.0, 0.75, 0.15), "short": "R93"},
	{"id": "kanyon", "name": "Kızıl Kanyon Rock", "genre": "Rock", "col": Color(0.95, 0.3, 0.2), "short": "ROCK"},
	{"id": "sakura", "name": "Sakura Radyo", "genre": "Doğu ezgileri · koto", "col": Color(1.0, 0.6, 0.8), "short": "SAKURA"},
	{"id": "cay", "name": "Çay Ocağı FM", "genre": "Anadolu esintisi · saz", "col": Color(0.85, 0.45, 0.15), "short": "ÇAY"},
	{"id": "dalga", "name": "Gece Dalgası", "genre": "Ambient · chill", "col": Color(0.3, 0.75, 1.0), "short": "DALGA"},
]

var player: Player
var station := ""
var last := ""
var user_off := false           # oyuncu radyoyu kapattıysa araca binince de kapalı kalır
var on_foot := false            # telefondan açıldıysa yürürken de çalar (kulaklık)
var _music: AudioStreamPlayer
var _dj: AudioStreamPlayer
var _streams := {}
var _toast: Label
var _toast_t := 0.0
var _was_in_car := false
var _wheel: RadialWheel
var _club := false


func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_music = AudioStreamPlayer.new()
	_music.bus = "Radio" if AudioServer.get_bus_index("Radio") >= 0 else "Music"
	add_child(_music)
	_dj = AudioStreamPlayer.new()
	_dj.bus = "Voice"
	add_child(_dj)
	var cl := CanvasLayer.new()
	cl.layer = 6
	add_child(cl)
	_toast = Game.styled_label("", 34, Color.WHITE, true)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 26
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("shadow_offset_x", 2)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_toast.modulate.a = 0.0
	cl.add_child(_toast)


func _exit_tree() -> void:
	if inst == self:
		inst = null


func index() -> int:
	for i in STATIONS.size():
		if STATIONS[i].id == station:
			return i
	return -1


func info(id: String) -> Dictionary:
	for s in STATIONS:
		if s.id == id:
			return s
	return {}


func _stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var st: AudioStream = null
	for ext in ["ogg", "wav"]:
		var p := "res://assets/music/%s.%s" % [id, ext]
		if ResourceLoader.exists(p):
			st = load(p)
			break
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(st as AudioStreamWAV).loop_end = int((st as AudioStreamWAV).get_length() * (st as AudioStreamWAV).mix_rate)
	_streams[id] = st
	return st


func select(id: String, from_phone := false, auto := false) -> void:
	if not auto:
		user_off = id == ""
	if id == station:
		return
	station = id
	if from_phone:
		on_foot = id != ""
	if id == "":
		_music.stop()
		_show("Radyo kapalı", Color(1, 1, 1, 0.8))
		return
	last = id
	Sfx.ui("static", -12.0)
	var st := _stream(id)
	var inf := info(id)
	_show(String(inf.get("name", id)), inf.get("col", Color.WHITE))
	if st == null:
		_music.stop()
		return
	_music.stream = st
	# canlı yayın: istasyonun "şu anki" yeri
	var L := st.get_length()
	var off := fmod(Time.get_ticks_msec() / 1000.0 + float(id.hash() % 1000), maxf(L, 1.0)) if L > 0.0 else 0.0
	_music.volume_db = -60.0
	_music.play(off)
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", 0.0, 0.6)
	if randf() < 0.45:
		get_tree().create_timer(1.5).timeout.connect(_dj_line.bind(id))


func _dj_line(id: String) -> void:
	if station != id:
		return
	var opts := []
	for n in range(1, 5):
		var p := "res://assets/voice/dj_%s_%d.ogg" % [id, n]
		if ResourceLoader.exists(p):
			opts.append(p)
	if opts.is_empty():
		return
	_dj.stream = load(opts[randi() % opts.size()])
	_dj.play()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -9.0, 0.3)
	tw.tween_interval(maxf(0.5, _dj.stream.get_length()))
	tw.tween_property(_music, "volume_db", 0.0, 0.6)


func _show(t: String, c: Color) -> void:
	_toast.text = t
	_toast.add_theme_color_override("font_color", c)
	_toast_t = 3.0


func set_club(on: bool) -> void:
	## kulüp içinde Neon FM yüksek sesle çalar
	_club = on
	if on:
		select("neonfm", false, true)
		_music.volume_db = 2.0
	elif player and player.car == null and not on_foot:
		select("", false, true)


func _process(delta: float) -> void:
	_toast_t -= delta
	_toast.modulate.a = clampf(minf(_toast_t, 3.0 - _toast_t) * 3.0, 0.0, 1.0) if _toast_t > 0.0 else 0.0
	if player == null:
		return
	var in_car := player.car != null
	if in_car and not _was_in_car and not _club:
		if last == "":
			last = String(STATIONS[randi() % STATIONS.size()].id)
		if not user_off:
			select(last, false, true)
	elif not in_car and _was_in_car and not on_foot and not _club:
		select("", false, true)
	_was_in_car = in_car
	# radyo çarkı (araçta Q basılı)
	if in_car and not Game.paused and Input.is_action_just_pressed("radio") and (_wheel == null or not is_instance_valid(_wheel)):
		_open_wheel()
	if in_car and not Game.paused and Input.is_action_just_pressed("weapon_next"):
		_cycle(1)
	elif in_car and not Game.paused and Input.is_action_just_pressed("weapon_prev"):
		_cycle(-1)


func _cycle(d: int) -> void:
	var i := index()
	var n := STATIONS.size() + 1
	var ni := (i + 1 + d + n) % n
	select("" if ni == 0 else String(STATIONS[ni - 1].id))


func _open_wheel() -> void:
	var wh := RadialWheel.new()
	wh.title = "RADYO"
	wh.action = "radio"
	wh.slowmo = 0.6
	wh.items.append({"id": "", "label": "Radyo Kapalı", "short": "Kapalı", "icon": "■", "sub": "", "col": Color(0.6, 0.6, 0.6)})
	for s in STATIONS:
		wh.items.append({"id": s.id, "label": s.name, "short": s.short, "icon": String(s.short).substr(0, 4), "sub": s.genre, "col": s.col})
	wh.sel = index() + 1
	wh.chosen.connect(func(id: String): select(id))
	get_tree().current_scene.add_child(wh)
	_wheel = wh
