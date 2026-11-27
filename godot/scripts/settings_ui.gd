extends Control
class_name SettingsUI
## Ayarlar: mor-pembe gradyan, üstte sekmeler, solda seçenek satırları (‹ değer ›),
## sağda açıklama paneli, sağ altta palmiye siluetleri.

signal closed

const TABS := ["OYNANIŞ", "GÖRÜNTÜ", "KAMERA", "SES", "KONTROLLER"]
var tab := 0
var tab_buttons: Array[Button] = []
var rows: VBoxContainer
var d_title: Label
var d_text: Label
var first_row: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/gradient.gdshader")
	bg.material = gm
	add_child(bg)
	_palms()
	var title := Game.styled_label("AYARLAR", 40, Color.WHITE, true)
	title.position = Vector2(48, 30)
	add_child(title)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(48, 90)
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	var lq := Game.styled_label("[Q]", 18, Color(1, 1, 1, 0.8), true)
	tabs.add_child(lq)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 22)
		if Game.font_display:
			b.add_theme_font_override("font", Game.font_display)
		var on := StyleBoxFlat.new()
		on.bg_color = Color(1, 1, 1, 0.95)
		on.content_margin_left = 14
		on.content_margin_right = 14
		var off := StyleBoxFlat.new()
		off.bg_color = Color(1, 1, 1, 0.08)
		off.content_margin_left = 14
		off.content_margin_right = 14
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", off)
		b.add_theme_stylebox_override("focus", off)
		b.add_theme_color_override("font_pressed_color", Color(0.25, 0.1, 0.3))
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func(): select_tab(idx))
		tabs.add_child(b)
		tab_buttons.append(b)
	tabs.add_child(Game.styled_label("[E]", 18, Color(1, 1, 1, 0.8), true))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(48, 150)
	scroll.size = Vector2(780, 640)
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.custom_minimum_size = Vector2(770, 0)
	rows.add_theme_constant_override("separation", 2)
	scroll.add_child(rows)
	d_title = Game.styled_label("", 30, Color.WHITE, true)
	d_title.anchor_left = 0.55
	d_title.anchor_right = 0.97
	d_title.offset_top = 165
	add_child(d_title)
	var line := ColorRect.new()
	line.color = Color(1, 0.6, 0.85, 0.8)
	line.anchor_left = 0.55
	line.anchor_right = 0.97
	line.offset_top = 210
	line.offset_bottom = 212
	add_child(line)
	d_text = Game.styled_label("", 20, Color(1, 1, 1, 0.9))
	d_text.anchor_left = 0.55
	d_text.anchor_right = 0.95
	d_text.offset_top = 228
	d_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(d_text)
	var hints := Game.styled_label("VARSAYILANA DÖN [R]     GERİ [Esc]", 22, Color.WHITE, true)
	hints.anchor_left = 1.0
	hints.anchor_right = 1.0
	hints.anchor_top = 1.0
	hints.anchor_bottom = 1.0
	hints.offset_left = -520
	hints.offset_right = -40
	hints.offset_top = -56
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hints)
	select_tab(0)


func _palms() -> void:
	var col := Color(0.25, 0.1, 0.32, 0.55)
	for p in [[Vector2(1250, 960), 1.0], [Vector2(1420, 990), 1.25], [Vector2(1560, 970), 0.9], [Vector2(1110, 1000), 0.8]]:
		var root := Node2D.new()
		root.position = p[0]
		root.scale = Vector2.ONE * p[1]
		add_child(root)
		var trunk := Polygon2D.new()
		trunk.color = col
		var pts := PackedVector2Array()
		for i in range(11):
			var t := i / 10.0
			pts.append(Vector2(-9 + sin(t * 2.0) * 30 * t, -t * 420))
		for i in range(10, -1, -1):
			var t := i / 10.0
			pts.append(Vector2(9 + sin(t * 2.0) * 30 * t - 4 * t, -t * 420))
		trunk.polygon = pts
		root.add_child(trunk)
		var top := Vector2(sin(2.0) * 30, -420)
		for k in range(9):
			var ang := -PI * 0.5 + (k - 4) * 0.42
			var fr := Polygon2D.new()
			fr.color = col
			var dirv := Vector2(cos(ang), sin(ang))
			var nrm := Vector2(-dirv.y, dirv.x)
			var fp := PackedVector2Array()
			for s in range(9):
				var t := s / 8.0
				var droop := Vector2(0, t * t * 120)
				fp.append(top + dirv * 200 * t + droop + nrm * 16 * sin(t * PI))
			for s in range(8, -1, -1):
				var t := s / 8.0
				var droop := Vector2(0, t * t * 120)
				fp.append(top + dirv * 200 * t + droop - nrm * 16 * sin(t * PI))
			fr.polygon = fp
			root.add_child(fr)


func _opts() -> Array:
	## [ad, açıklama, anahtar, seçenekler(etiket listesi) | "bool", değerler]
	match tab:
		0:
			return [["Hareket Hızı", "Sol çubuk tam itildiğinde ulaşılan en yüksek hız. Hafif koşu: çubuğu bıraktıkça yavaşlarsın.", "move_speed", ["Yürü", "Hızlı Yürü", "Hafif Koşu"], [0, 1, 2]],
				["Zaman Hızı", "Gün/gece döngüsünün hızı. Normal: 1 oyun saati = 1 dakika.", "time_speed", ["Yavaş", "Normal", "Hızlı"], [0, 1, 2]]]
		1:
			return [["Grafik Kalitesi", "Gölge mesafesi, hacimsel sis ve ekran-uzayı efektleri.", "quality", ["Düşük", "Orta", "Yüksek"], [0, 1, 2]],
				["Küresel Aydınlatma (SDFGI)", "Işığın yüzeylerden sekmesi. Daha gerçekçi ama daha ağır.", "sdfgi", "bool", []],
				["Yansımalar (SSR)", "Islak zemin ve camlarda ekran-uzayı yansımaları.", "ssr", "bool", []],
				["Çözünürlük Ölçeği", "3B sahnenin çizim çözünürlüğü. Düşük değer FPS'i artırır.", "render_scale", ["%50", "%67", "%77", "%100"], [0.5, 0.67, 0.77, 1.0]],
				["Tam Ekran", "Pencereli veya tam ekran. Oyun içinde F11 ile de değiştirilebilir.", "fullscreen", "bool", []],
				["Otomatik Güncelleme", "Oyun açılırken yeni sürüm varsa indirip kurar ve oyunu yeniden başlatır.", "auto_update", "bool", []]]
		2:
			return [["Görüş Alanı (FOV)", "Kamera açısı.", "fov", ["60", "65", "70", "75", "80", "90"], [60.0, 65.0, 70.0, 75.0, 80.0, 90.0]],
				["Fare Hassasiyeti", "Kamera dönüş hızı.", "sens", ["0.5", "0.75", "1.0", "1.25", "1.5", "2.0"], [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]],
				["Dikeyi Ters Çevir", "Fareyi yukarı itince kamera aşağı bakar.", "invert_y", "bool", []]]
		3:
			return [["Ana Ses", "Genel ses seviyesi.", "volume", ["Kapalı", "%25", "%50", "%75", "%100"], [0.0, 0.25, 0.5, 0.75, 1.0]],
				["Diyalog Sesi", "Karakterlerin konuşma sesi.", "voice_volume", ["Kapalı", "%25", "%50", "%75", "%100"], [0.0, 0.25, 0.5, 0.75, 1.0]],
				["Altyazılar", "Konuşmaların yazısı ekranın altında görünür.", "subtitles", "bool", []]]
		_:
			return [["Klavye / Fare", "WASD hareket · Shift koş · C eğil · Boşluk zıpla · F araca bin/in · Boşluk el freni · T zamanı hızlandır · F11 tam ekran · Esc menü", "", "info", []],
				["Gamepad", "Sol çubuk hareket · Sağ çubuk kamera · Ⓐ zıpla · Ⓨ araç · RT/LT gaz/fren · Start menü", "", "info", []]]


func select_tab(i: int) -> void:
	tab = (i + TABS.size()) % TABS.size()
	for k in tab_buttons.size():
		tab_buttons[k].button_pressed = k == tab
	for c in rows.get_children():
		c.queue_free()
	first_row = null
	for o in _opts():
		rows.add_child(_row(o))
	if first_row:
		first_row.grab_focus.call_deferred()


func _row(o: Array) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(770, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "  " + o[0]
	b.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_width_bottom = 1
	normal.border_color = Color(1, 1, 1, 0.12)
	var hl := StyleBoxTexture.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0.95))
	gr.set_color(1, Color(0.85, 0.82, 0.9, 0.85))
	gt.gradient = gr
	gt.fill_to = Vector2(1, 0)
	hl.texture = gt
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hl)
	b.add_theme_stylebox_override("focus", hl)
	b.add_theme_color_override("font_hover_color", Color(0.2, 0.1, 0.25))
	b.add_theme_color_override("font_focus_color", Color(0.2, 0.1, 0.25))
	var val := Game.styled_label("", 22, Color.WHITE)
	val.anchor_left = 1.0
	val.anchor_right = 1.0
	val.offset_left = -380
	val.offset_right = -96
	val.offset_top = 14
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(val)
	var arrows := []
	if not (o[3] is String and o[3] == "info"):
		for spec in [["‹", -88, -1], ["›", -48, 1]]:
			var ab := Button.new()
			ab.text = spec[0]
			ab.flat = true
			ab.focus_mode = Control.FOCUS_NONE
			ab.add_theme_font_size_override("font_size", 30)
			ab.anchor_left = 1.0
			ab.anchor_right = 1.0
			ab.offset_left = spec[1]
			ab.offset_right = spec[1] + 36
			ab.offset_top = 6
			ab.offset_bottom = 52
			b.add_child(ab)
			arrows.append([ab, spec[2]])
	var key: String = o[2]
	var refresh := func():
		var dark := b.has_focus()
		val.add_theme_color_override("font_color", Color(0.2, 0.1, 0.25) if dark else Color.WHITE)
		if o[3] is String and o[3] == "bool":
			val.text = "Açık   ◉" if Game.settings[key] else "Kapalı   ○"
		elif o[3] is Array:
			var vals: Array = o[4]
			var cur = Game.settings[key]
			var idx := 0
			for k in vals.size():
				if is_equal_approx(float(vals[k]), float(cur)):
					idx = k
			val.text = "%s   %d / %d" % [o[3][idx], idx + 1, vals.size()]
		else:
			val.text = ""
	var change := func(dir: int):
		if key == "":
			return
		if o[3] is String and o[3] == "bool":
			Game.settings[key] = not Game.settings[key]
		else:
			var vals: Array = o[4]
			var idx := 0
			for k in vals.size():
				if is_equal_approx(float(vals[k]), float(Game.settings[key])):
					idx = k
			idx = clamp(idx + dir, 0, vals.size() - 1)
			Game.settings[key] = vals[idx]
		Game.save_settings()
		Game.apply_settings()
		refresh.call()
	for ar in arrows:
		var dir: int = ar[1]
		(ar[0] as Button).pressed.connect(func(): b.grab_focus(); change.call(dir))
		(ar[0] as Button).add_theme_color_override("font_color", Color.WHITE)
		(ar[0] as Button).add_theme_color_override("font_hover_color", Color(1, 0.5, 0.85))
	b.focus_entered.connect(func(): d_title.text = o[0].to_upper(); d_text.text = o[1]; refresh.call())
	b.focus_exited.connect(func(): refresh.call())
	b.mouse_entered.connect(func(): b.grab_focus())
	b.pressed.connect(func(): change.call(1))
	var on_input := func(e: InputEvent):
		var left: bool = e.is_action_pressed("ui_left") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_A)
		var right: bool = e.is_action_pressed("ui_right") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_D)
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP:
				right = true
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				left = true
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				left = true
		if left:
			change.call(-1)
			b.accept_event()
		elif right:
			change.call(1)
			b.accept_event()
	b.gui_input.connect(on_input)
	refresh.call()
	if first_row == null:
		first_row = b
	return b


func grab() -> void:
	select_tab(tab)


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_Q:
			select_tab(tab - 1)
		elif e.physical_keycode == KEY_E:
			select_tab(tab + 1)
		elif e.physical_keycode == KEY_R:
			Game.settings.quality = 2
			Game.save_settings()
			Game.apply_settings()
			select_tab(tab)
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_LEFT_SHOULDER:
			select_tab(tab - 1)
		elif e.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			select_tab(tab + 1)
