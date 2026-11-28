extends CanvasLayer
class_name Phone
## GTA tarzı cep telefonu (↑ ile açılır): ok tuşları ile gezin, Enter seç, Backspace geri, ↑ uzun kapat.
## Uygulamalar: Harita · Kişiler · Mesajlar · Yolculuk (hızlı seyahat) · Banka · Radyo · Kamera · NeonGram · Gardırop

const APPS := [
	["harita", "Harita", Color(0.2, 0.7, 0.4)], ["kisiler", "Kişiler", Color(0.25, 0.55, 1.0)], ["mesaj", "Mesajlar", Color(0.3, 0.85, 0.5)],
	["yolculuk", "Yolculuk", Color(1.0, 0.75, 0.15)], ["banka", "Banka", Color(0.15, 0.75, 0.7)], ["radyo", "Radyo", Color(1.0, 0.3, 0.6)],
	["kamera", "Kamera", Color(0.55, 0.55, 0.6)], ["neongram", "NeonGram", Color(0.85, 0.3, 1.0)], ["gardirop", "Gardırop", Color(1.0, 0.5, 0.25)],
]
const CONTACTS := [["ela", "Ela Poyraz"], ["tarik", "Turbo Tarık"], ["taksi", "Yolculuk Merkezi"], ["usta", "Bilge Usta"]]
const MESSAGES := [
	["Ela", "Şehre hoş geldin! Eski Çarşı'daki Noda Erişte Evi'nde buluşalım. Haritada işaret koymak için M'ye bas."],
	["Turbo Tarık", "Dojoya bekliyorum! Mankenlerde kombo çalış: sol tık hafif, Q ağır vuruş, V blok, sağ tık hedefe kilitlen."],
	["Bilge Usta", "Kasırga tekniği seninle: X ile dön, havada Boşluk ile süzül, Z ile metal şok dalgası, B ile ejderini çağır."],
	["Ada Bankası", "Hesabına ₺2.500 yatırıldı. Telefonundaki Banka uygulamasından para çekebilirsin."],
	["NeonGram", "Şehirde olan her şey burada! Kamera ile çektiğin fotoğrafları paylaş."],
	["Yolculuk", "Uzak bir yere mi gideceksin? Yolculuk uygulamasından şoför çağır, seni hemen götürsün."],
]
const DEST := [["sehir", "Neon Bulvar", Vector3(-88.5, 0.4, -36.0)], ["eski", "Eski Çarşı", Vector3(-248.5, 0.4, -100.0)], ["liman", "Liman", Vector3(-430.0, 0.6, -70.0)],
	["sahil", "Sahil", Vector3(-420.0, 0.6, 120.0)], ["lunapark", "Neon Lunapark", Vector3(88.5, 0.4, 200.0)], ["manastir", "Kasırga Manastırı", Vector3(180.0, -1.0, -930.0)],
	["gecit", "Atalar Geçidi", Vector3(2080.0, -1.0, 620.0)], ["sis", "Sis Kasabası", Vector3(2930.0, -1.0, 1660.0)], ["cay", "Bilge Çay Bahçesi", Vector3(880.0, -1.0, 3180.0)],
	["huslar", "Ak Huş Ormanı", Vector3(2660.0, -1.0, -330.0)]]

var player: Player
var screen := "home"
var sel := 0
var _items: Array = []
var _c: Control
var _t := 0.0
var _anim := 0.0
var _closing := false
var _info := ""
var _info_t := 0.0
var _hidden_for_photo := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw)
	add_child(_c)
	Sfx.ui("click", -8.0)
	player.visual.play("phone", 0.25)
	player.visual.lock_t = 0.3


func _process(delta: float) -> void:
	_t += delta
	if Game.paused and not _closing:
		_closing = true
		_anim = 0.0
		if player:
			player.phone = null
	_anim = move_toward(_anim, 0.0 if _closing else 1.0, delta * 5.0)
	_info_t -= delta
	if _closing and _anim <= 0.0:
		queue_free()
		return
	if not _closing and player.car == null and not player.combat.dead and player.velocity.length() < 0.5:
		player.visual.play("phone", 0.25)
		player.visual.lock_t = 0.15
	_c.queue_redraw()


func close() -> void:
	_closing = true
	Sfx.ui("click", -10.0)
	if player:
		player.phone = null


func _unhandled_input(e: InputEvent) -> void:
	if _closing or not e.is_pressed() or e.is_echo():
		return
	if e is InputEventKey and (e as InputEventKey).keycode == KEY_ESCAPE:
		close()
		return
	var handled := true
	if e.is_action_pressed("phone"):
		_move(-3 if screen == "home" else -1)
	elif e.is_action_pressed("ui_phone_down"):
		_move(3 if screen == "home" else 1)
	elif e.is_action_pressed("ui_phone_left"):
		_move(-1)
	elif e.is_action_pressed("ui_phone_right"):
		_move(1)
	elif e is InputEventKey and ((e as InputEventKey).keycode == KEY_ENTER or (e as InputEventKey).keycode == KEY_KP_ENTER):
		_select()
	elif e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_select()
	elif (e is InputEventKey and (e as InputEventKey).keycode == KEY_BACKSPACE) or (e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_B) or (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT):
		_back()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _count() -> int:
	return APPS.size() if screen == "home" else _items.size()


func _move(d: int) -> void:
	var n := _count()
	if n == 0:
		return
	if screen == "home" and (d == -3 and sel < 3):
		close()
		return
	sel = clampi(sel + d, 0, n - 1) if screen == "home" else (sel + d + n) % n
	Sfx.ui("click", -16.0)


func _back() -> void:
	if screen == "home":
		close()
	else:
		screen = "home"
		sel = 0
		Sfx.ui("click", -12.0)


func _note(t: String) -> void:
	_info = t
	_info_t = 3.0


# ---------------------------------------------------------------- uygulamalar
func _open(app: String) -> void:
	screen = app
	sel = 0
	_items = []
	match app:
		"harita":
			close()
			var b := get_tree().current_scene
			if b and b.has_method("open_map"):
				b.open_map()
			return
		"kisiler":
			for c in CONTACTS:
				_items.append({"id": c[0], "t": c[1]})
		"mesaj":
			for m in MESSAGES:
				_items.append({"id": "", "t": m[0], "s": m[1]})
		"yolculuk":
			for d in DEST:
				var cost := _fare(d[2])
				_items.append({"id": d[0], "t": d[1], "s": "₺%d · %d m" % [cost, int(player.global_position.distance_to(d[2]))], "pos": d[2], "cost": cost})
		"banka":
			_items = [{"id": "yatir", "t": "Tüm nakdi yatır"}, {"id": "cek", "t": "₺500 çek"}, {"id": "cek2", "t": "₺2.000 çek"}]
		"radyo":
			var r := Radio.inst
			_items.append({"id": "", "t": "Kapalı"})
			for st in Radio.STATIONS:
				_items.append({"id": st.id, "t": st.name, "s": st.genre})
			if r:
				sel = r.index() + 1
		"kamera":
			_items = [{"id": "cek", "t": "Fotoğraf çek (Enter)"}]
		"neongram":
			_items = []
			for p in Game.feed:
				_items.append({"id": "", "t": p[0], "s": p[1]})
			for p in _city_posts():
				_items.append({"id": "", "t": p[0], "s": p[1]})
		"gardirop":
			for oid in Game.owned_outfits:
				var o := Outfits.info(oid)
				_items.append({"id": oid, "t": o.name, "s": "Giyili" if Game.outfit == oid else ""})


func _fare(p: Vector3) -> int:
	return 20 + int(player.global_position.distance_to(p) / 35.0)


func _select() -> void:
	Sfx.ui("select", -10.0)
	if screen == "home":
		_open(String(APPS[sel][0]))
		return
	if _items.is_empty():
		return
	var it: Dictionary = _items[sel]
	match screen:
		"kisiler":
			_call(String(it.id))
		"yolculuk":
			_ride(it)
		"banka":
			match String(it.id):
				"yatir":
					Game.bank += Game.money
					_note("₺%d yatırıldı." % Game.money)
					Game.money = 0
				"cek", "cek2":
					var v := 500 if it.id == "cek" else 2000
					if Game.bank >= v:
						Game.bank -= v
						Game.money += v
						Sfx.ui("cash", -8.0)
						_note("₺%d çekildi." % v)
					else:
						_note("Bakiye yetersiz.")
		"radyo":
			if Radio.inst:
				Radio.inst.select(String(it.id), true)
		"kamera":
			_photo()
		"gardirop":
			_change_outfit(String(it.id))


func _call(id: String) -> void:
	var d := get_tree().current_scene.get("dialog") as DialogBox
	Sfx.ui("ring", -8.0)
	if id == "taksi":
		_open("yolculuk")
		return
	if d == null:
		return
	await get_tree().create_timer(1.2).timeout
	match id:
		"ela":
			d.play_scene("tel_ela_%d" % (1 + randi() % 3))
		"tarik":
			d.play_scene("tel_tarik_%d" % (1 + randi() % 2))
		"usta":
			d.play_scene("tel_usta_%d" % (1 + randi() % 2))


func _ride(it: Dictionary) -> void:
	if Wanted.inst and Wanted.inst.stars > 0:
		_note("Aranırken şoför gelmez!")
		return
	if player.car:
		_note("Önce araçtan in.")
		return
	var cost := int(it.cost)
	if Game.money < cost:
		_note("Yeterli nakit yok.")
		return
	Game.money -= cost
	close()
	var w := player.world
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 60
	cl.add_child(fade)
	get_tree().current_scene.add_child(cl)
	var tw := cl.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	await tw.finished
	Game.notify("Yolculuk: %s (₺%d)" % [String(it.t), cost], 3.0)
	var p: Vector3 = it.pos
	if p.y < 0.0 and w:
		p.y = w.ground_y(p.x, p.z) + 0.6
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.rig.global_position = p + Vector3(0, 1.55, 0)
	Game.time_of_day = fmod(Game.time_of_day + 0.4, 24.0)
	await get_tree().create_timer(0.8).timeout
	var tw2 := cl.create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.6)
	await tw2.finished
	cl.queue_free()


func _photo() -> void:
	## NeonGram için fotoğraf: arayüz bir kare gizlenir, ekran kaydedilir
	_hidden_for_photo = true
	var hud := Game.hud as CanvasLayer
	if hud:
		hud.visible = false
	visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	visible = true
	if hud:
		hud.visible = true
	_hidden_for_photo = false
	Game.photos += 1
	DirAccess.make_dir_recursive_absolute("user://fotograflar")
	img.save_png("user://fotograflar/foto_%03d.png" % Game.photos)
	Sfx.ui("click", 0.0)
	var likes := randi_range(8, 240)
	Game.feed.push_front(["@kaan_demir", "Yeni fotoğraf #%d · %s · ❤ %d" % [Game.photos, player.world.district_name(player.global_position) if player.world else "", likes]])
	_note("Fotoğraf kaydedildi ve NeonGram'da paylaşıldı.")


func _change_outfit(id: String) -> void:
	if Wanted.inst and Wanted.inst.stars > 0 and Wanted.inst.seen:
		_note("Polis seni görürken üstünü değiştiremezsin!")
		return
	close()
	player.visual.action("interact", 0.8)
	await get_tree().create_timer(1.0).timeout
	Outfits.apply(player, id)
	if Wanted.inst:
		Wanted.inst.description_changed("kıyafet")
	Game.notify("Kıyafet değiştirildi: " + String(Outfits.info(id).name), 2.5)


func _city_posts() -> Array:
	return [["@sehirhaber", "Neon Lunapark bu hafta sonu gece yarısına kadar açık!"], ["@ayse.k", "Ananas Smoothie'nin yeni neon mavisi efsane 💙"],
		["@limanci_hakan", "Bugün limana üç gemi yanaştı, vinçler durmadı."], ["@bilge_cay", "Çay bahçemizde gün batımı ayrı güzel."],
		["@turbo_tarik", "DOJO'DA YENİ DÖNEM! Kayıtlar açık 🥋"], ["@sisli_gezgin", "Sis Kasabası'nın ayaklı evleri sabah sisinde masal gibi."]]


# ---------------------------------------------------------------- çizim
func _draw() -> void:
	if _hidden_for_photo:
		return
	var vs := _c.size
	var W := 300.0
	var H := 560.0
	var k := ease(_anim, -2.0)
	var o := Vector2(vs.x - W - 60.0, vs.y - H * k + 10.0 * (1.0 - k) - 40.0)
	var f: Font = Game.font_ui if Game.font_ui else ThemeDB.fallback_font
	var fd: Font = Game.font_display if Game.font_display else f
	# gövde
	_rrect(Rect2(o - Vector2(10, 10), Vector2(W + 20, H + 20)), 34.0, Color(0.05, 0.05, 0.07))
	_rrect(Rect2(o, Vector2(W, H)), 26.0, Color(0.08, 0.06, 0.14))
	# duvar kâğıdı (neon gradyan)
	for i in 28:
		var t := float(i) / 27.0
		var col := Color(0.35, 0.05, 0.45).lerp(Color(0.02, 0.35, 0.5), t)
		_c.draw_rect(Rect2(o + Vector2(6, 40 + i * (H - 50) / 28.0), Vector2(W - 12, (H - 50) / 28.0 + 1)), Color(col, 0.55))
	# durum çubuğu
	_c.draw_string(f, o + Vector2(20, 28), Game.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	_c.draw_string(f, o + Vector2(W - 90, 28), "NeonTel ▮▮▮", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	_c.draw_rect(Rect2(o + Vector2(W * 0.5 - 30, 10), Vector2(60, 12)), Color(0, 0, 0))
	if screen == "home":
		for i in APPS.size():
			var a: Array = APPS[i]
			var cx := o.x + 50.0 + (i % 3) * 100.0
			var cy := o.y + 110.0 + (i / 3) * 130.0
			var on := i == sel
			var s := 62.0 * (1.12 if on else 1.0)
			_rrect(Rect2(Vector2(cx - s * 0.5 + 0.0, cy - s * 0.5), Vector2(s, s)), 16.0, (a[2] as Color).lightened(0.15) if on else a[2])
			_glyph(String(a[0]), Vector2(cx, cy), s * 0.32)
			_c.draw_string(f, Vector2(cx - 50, cy + s * 0.5 + 20), String(a[1]), HORIZONTAL_ALIGNMENT_CENTER, 100, 14, Color.WHITE if on else Color(1, 1, 1, 0.8))
			if on:
				_c.draw_rect(Rect2(Vector2(cx - s * 0.5 - 4, cy - s * 0.5 - 4), Vector2(s + 8, s + 8)), Color(1, 1, 1, 0.9), false, 2.0)
	else:
		var title := ""
		var acol := Color.WHITE
		for a in APPS:
			if a[0] == screen:
				title = a[1]
				acol = a[2]
		_c.draw_rect(Rect2(o + Vector2(6, 40), Vector2(W - 12, 52)), Color(acol, 0.9))
		_c.draw_string(fd, o + Vector2(20, 78), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		var y := o.y + 110.0
		if screen == "banka":
			_c.draw_string(f, Vector2(o.x + 20, y), "Nakit: ₺%d" % Game.money, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 1.0, 0.6))
			_c.draw_string(f, Vector2(o.x + 20, y + 24), "Hesap: ₺%d" % Game.bank, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.9, 1.0))
			y += 50.0
		if screen == "kamera":
			_c.draw_string(f, Vector2(o.x + 20, y), "Çekilen: %d fotoğraf" % Game.photos, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
			y += 30.0
		var row_h := 52.0 if screen in ["mesaj", "neongram", "yolculuk", "radyo"] else 40.0
		var first := maxi(0, sel - int((H - 140.0 - (y - o.y - 110.0)) / row_h) + 1)
		for i in range(first, _items.size()):
			if y > o.y + H - 40.0:
				break
			var it: Dictionary = _items[i]
			var on := i == sel
			if on:
				_c.draw_rect(Rect2(Vector2(o.x + 10, y - 4), Vector2(W - 20, row_h - 6)), Color(1, 1, 1, 0.16))
			_c.draw_string(f, Vector2(o.x + 20, y + 16), String(it.t), HORIZONTAL_ALIGNMENT_LEFT, W - 40, 17, Color.WHITE)
			if it.has("s") and String(it.s) != "":
				_c.draw_string(f, Vector2(o.x + 20, y + 36), String(it.s), HORIZONTAL_ALIGNMENT_LEFT, W - 40, 13, Color(1, 1, 1, 0.65))
			y += row_h
		if _items.is_empty():
			_c.draw_string(f, Vector2(o.x + 20, y + 16), "Henüz bir şey yok.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
	if _info_t > 0.0:
		_rrect(Rect2(o + Vector2(16, H - 96), Vector2(W - 32, 46)), 10.0, Color(0, 0, 0, 0.8))
		_c.draw_string(f, o + Vector2(26, H - 66), _info, HORIZONTAL_ALIGNMENT_LEFT, W - 52, 14, Color.WHITE)
	_c.draw_string(f, o + Vector2(0, H - 14), "↑↓←→ gez · Enter seç · Backspace geri", HORIZONTAL_ALIGNMENT_CENTER, W, 11, Color(1, 1, 1, 0.5))


func _rrect(r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	_c.draw_style_box(sb, r)


func _glyph(id: String, c: Vector2, s: float) -> void:
	## basit çizilmiş uygulama simgeleri
	var w := Color.WHITE
	match id:
		"harita":
			_c.draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.7), c + Vector2(-s * 0.3, -s), c + Vector2(s * 0.3, -s * 0.7), c + Vector2(s, -s), c + Vector2(s, s * 0.7), c + Vector2(s * 0.3, s), c + Vector2(-s * 0.3, s * 0.7), c + Vector2(-s, s), c + Vector2(-s, -s * 0.7)]), w, 3.0)
		"kisiler":
			_c.draw_circle(c + Vector2(0, -s * 0.35), s * 0.4, w)
			_c.draw_arc(c + Vector2(0, s * 0.9), s * 0.85, PI, TAU, 16, w, 5.0)
		"mesaj":
			_c.draw_rect(Rect2(c - Vector2(s, s * 0.7), Vector2(s * 2, s * 1.3)), w)
			_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, s * 0.6), c + Vector2(-s * 0.8, s * 1.1), c + Vector2(0, s * 0.6)]), w)
		"yolculuk":
			_c.draw_rect(Rect2(c - Vector2(s, s * 0.2), Vector2(s * 2, s * 0.7)), w)
			_c.draw_rect(Rect2(c - Vector2(s * 0.55, s * 0.65), Vector2(s * 1.1, s * 0.5)), w)
			_c.draw_circle(c + Vector2(-s * 0.55, s * 0.55), s * 0.22, Color(0.1, 0.1, 0.1))
			_c.draw_circle(c + Vector2(s * 0.55, s * 0.55), s * 0.22, Color(0.1, 0.1, 0.1))
		"banka":
			_c.draw_string(Game.font_display if Game.font_display else ThemeDB.fallback_font, c + Vector2(-s, s * 0.6), "₺", HORIZONTAL_ALIGNMENT_CENTER, s * 2, int(s * 1.8), w)
		"radyo":
			_c.draw_circle(c, s * 0.25, w)
			for r in [0.55, 0.9]:
				_c.draw_arc(c, s * r, -0.7, 0.7, 10, w, 3.0)
				_c.draw_arc(c, s * r, PI - 0.7, PI + 0.7, 10, w, 3.0)
		"kamera":
			_c.draw_rect(Rect2(c - Vector2(s, s * 0.6), Vector2(s * 2, s * 1.3)), w)
			_c.draw_circle(c + Vector2(0, s * 0.05), s * 0.45, Color(0.2, 0.2, 0.25))
		"neongram":
			_c.draw_rect(Rect2(c - Vector2(s * 0.9, s * 0.9), Vector2(s * 1.8, s * 1.8)), w, false, 3.0)
			_c.draw_arc(c, s * 0.45, 0, TAU, 20, w, 3.0)
			_c.draw_circle(c + Vector2(s * 0.55, -s * 0.55), s * 0.12, w)
		"gardirop":
			_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.5), c + Vector2(-s * 0.35, -s * 0.9), c + Vector2(s * 0.35, -s * 0.9), c + Vector2(s, -s * 0.5), c + Vector2(s * 0.7, -s * 0.1), c + Vector2(s * 0.5, -s * 0.3), c + Vector2(s * 0.5, s), c + Vector2(-s * 0.5, s), c + Vector2(-s * 0.5, -s * 0.3), c + Vector2(-s * 0.7, -s * 0.1)]), w)
