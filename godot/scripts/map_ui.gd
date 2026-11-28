extends CanvasLayer
class_name MapScreen
## Duraklatma haritası (GTA6 menüsünden esinlenen düzen):
##  • Üstte sekmeler: KAAN · HARİTA · GÖREVLER · İLERLEME (Q / E ile geçiş)
##  • Solda kategori şeridi (tümü, dükkânlar, yeme-içme, eğlence, dövüş, hizmetler, gezilecek yerler);
##    kategori seçilince yer listesi açılır, listeden seçilen yere harita kayar ve rota çizilir
##  • Sağ üstte nakit ve banka, sağ altta tuş ipuçları
##  • Yumuşak renkli kıta, beyaz yollar, açık gri şehir; bölge adları büyük ve kalın

signal closed

const TABS := ["KAAN", "HARİTA", "GÖREVLER", "İLERLEME"]
const CATS := [
	["tum", "Tüm yerler", []],
	["dukkan", "Dükkânlar", ["weapons", "clothes", "shop", "spray", "bank", "arcade"]],
	["yemek", "Yeme-içme", ["food"]],
	["eglence", "Eğlence", ["club", "fun", "beach", "arcade"]],
	["dovus", "Dövüş ve eğitim", ["dojo", "monastery"]],
	["hizmet", "Hizmetler", ["hospital", "police", "station", "harbor"]],
	["gezi", "Gezilecek yerler", ["ruins", "statues", "town", "village", "tea", "temple", "volcano", "cabin", "coves", "island", "bridge", "lighthouse", "tower", "secure"]],
]

var world: World
var player: Node3D
var canvas: Control
var _cam := Vector2.ZERO
var _zoom := 0.16
var _drag := false
var _hover := {}
var _tab := 1
var _cat := 0
var _list_open := false
var _list: Array = []
var _sel := 0
var _t := 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.25, 0.42)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw)
	canvas.gui_input.connect(_gui)
	add_child(canvas)
	_cam = Vector2(player.global_position.x, player.global_position.z)
	Sfx.ui("select", -10.0)


func _xf() -> Transform2D:
	var c := canvas.size * 0.5
	return Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, c) * Transform2D(0.0, -_cam)


func _cat_kinds(ci: int) -> Array:
	return CATS[ci][2]


func _visible_poi(poi: Dictionary) -> bool:
	if _cat == 0:
		return true
	return (_cat_kinds(_cat) as Array).has(String(poi.kind))


func _build_list() -> void:
	_list = []
	for poi in world.pois:
		if _visible_poi(poi):
			_list.append(poi)
	var pp := Vector2(player.global_position.x, player.global_position.z)
	_list.sort_custom(func(a, b): return pp.distance_to(Vector2(a.pos.x, a.pos.z)) < pp.distance_to(Vector2(b.pos.x, b.pos.z)))
	_sel = 0


# ---------------------------------------------------------------- çizim
func _draw() -> void:
	var vs := canvas.size
	var fd: Font = Game.font_display if Game.font_display else ThemeDB.fallback_font
	var fu: Font = Game.font_ui if Game.font_ui else fd
	if _tab == 1:
		_draw_map(fd)
	else:
		_draw_page(fd, fu)
	# üst şerit
	canvas.draw_rect(Rect2(0, 0, vs.x, 84), Color(0.03, 0.04, 0.08, 0.86))
	canvas.draw_string(fu, Vector2(36, 54), Game.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.85))
	var tx := vs.x * 0.5 - 330.0
	_key_chip(Vector2(tx - 56, 38), "Q")
	for i in TABS.size():
		var on := i == _tab
		var w := fd.get_string_size(TABS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		canvas.draw_string(fd, Vector2(tx, 56), TABS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1.0, 0.4, 0.75) if on else Color(1, 1, 1, 0.85))
		if on:
			canvas.draw_rect(Rect2(tx, 64, w, 3), Color(1.0, 0.4, 0.75))
		tx += w + 46.0
	_key_chip(Vector2(tx - 10, 38), "E")
	# sağ üst: para
	canvas.draw_string(fd, Vector2(vs.x - 330, 130), "₺%s" % _fmt(Game.money), HORIZONTAL_ALIGNMENT_RIGHT, 260, 34, Color.WHITE)
	canvas.draw_circle(Vector2(vs.x - 46, 119), 14.0, Color(0.55, 0.9, 0.55))
	canvas.draw_string(fd, Vector2(vs.x - 330, 172), "₺%s" % _fmt(Game.bank), HORIZONTAL_ALIGNMENT_RIGHT, 260, 30, Color(1, 1, 1, 0.85))
	canvas.draw_circle(Vector2(vs.x - 46, 161), 14.0, Color(0.6, 0.45, 1.0))
	canvas.draw_string(fd, Vector2(vs.x - 59, 168), "B", HORIZONTAL_ALIGNMENT_CENTER, 26, 18, Color(0.1, 0.05, 0.2))
	canvas.draw_string(fd, Vector2(vs.x - 59, 127), "N", HORIZONTAL_ALIGNMENT_CENTER, 26, 18, Color(0.05, 0.2, 0.05))


func _fmt(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func _key_chip(p: Vector2, k: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.12)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.6)
	canvas.draw_style_box(sb, Rect2(p, Vector2(34, 26)))
	canvas.draw_string(Game.font_ui if Game.font_ui else ThemeDB.fallback_font, p + Vector2(0, 19), k, HORIZONTAL_ALIGNMENT_CENTER, 34, 15, Color.WHITE)


func _draw_map(fd: Font) -> void:
	var vs := canvas.size
	var xf := _xf()
	MapPainter.draw_world(canvas, world, xf, _zoom, Rect2(Vector2.ZERO, vs))
	# bölge adları (GTA6'daki gibi büyük, kalın, gölgeli)
	if _zoom < 0.55:
		for rl in world.region_labels:
			var p: Vector2 = xf * (rl[1] as Vector2)
			var txt: String = String(rl[0]).to_upper()
			var fs := int(clampf(_zoom * 220.0, 22.0, 54.0))
			canvas.draw_string(fd, p + Vector2(-300, 3), txt, HORIZONTAL_ALIGNMENT_CENTER, 600, fs, Color(0, 0, 0, 0.35))
			canvas.draw_string(fd, p + Vector2(-300, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 600, fs, Color(1, 1, 1, 0.95))
	else:
		var done := {}
		for b in world.data.city.blocks:
			var nm: String = world.DISTRICT_NAMES.get(String(b.d), "")
			if nm == "" or done.has(nm):
				continue
			done[nm] = true
			var p: Vector2 = xf * Vector2(b.c[0], b.c[1])
			canvas.draw_string(fd, p + Vector2(-200, 2), nm.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 400, 30, Color(0, 0, 0, 0.35))
			canvas.draw_string(fd, p + Vector2(-200, 0), nm.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 400, 30, Color(1, 1, 1, 0.95))
	# simgeler
	_hover = {}
	var mouse := canvas.get_local_mouse_position()
	var rad := clampf(_zoom * 60.0, 10.0, 15.0)
	for poi in world.pois:
		if not _visible_poi(poi):
			continue
		var p: Vector2 = xf * Vector2(poi.pos.x, poi.pos.z)
		var hl: bool = _list_open and _sel < _list.size() and _list[_sel] == poi
		MapPainter.draw_icon(canvas, p, String(poi.kind), rad * (1.35 if hl else 1.0))
		if p.distance_to(mouse) < rad + 4.0:
			_hover = poi
	if Game.has_waypoint:
		MapPainter.draw_waypoint(canvas, xf * Vector2(Game.waypoint.x, Game.waypoint.z))
	# oyuncu: koyu daire içinde beyaz ok + nabız halkası
	var pp: Vector2 = xf * Vector2(player.global_position.x, player.global_position.z)
	var pulse := fmod(_t, 1.6) / 1.6
	canvas.draw_arc(pp, 16.0 + pulse * 18.0, 0, TAU, 32, Color(1, 1, 1, 0.5 * (1.0 - pulse)), 2.0)
	canvas.draw_circle(pp, 15.0, Color(0.08, 0.08, 0.12, 0.92))
	canvas.draw_arc(pp, 15.0, 0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
	var yaw: float = player.get("yaw") if player.get("yaw") != null else 0.0
	MapPainter.draw_player(canvas, pp, -yaw, 8.0)
	# imleç
	canvas.draw_arc(mouse, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)
	canvas.draw_circle(mouse, 2.0, Color.WHITE)
	# imleç bilgi kutusu
	var wpos: Vector2 = xf.affine_inverse() * mouse
	var info := ""
	var dist := 0.0
	if not _hover.is_empty():
		info = String(_hover.name)
		dist = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(_hover.pos.x, _hover.pos.z))
	else:
		info = world.district_name(Vector3(wpos.x, 0, wpos.y))
		if info == "":
			info = "Açık Deniz"
		dist = Vector2(player.global_position.x, player.global_position.z).distance_to(wpos)
	var fu: Font = Game.font_ui if Game.font_ui else fd
	var box := Rect2(mouse + Vector2(22, -14), Vector2(maxf(170.0, fu.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 24), 50))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.08, 0.85)
	sb.set_corner_radius_all(6)
	canvas.draw_style_box(sb, box)
	canvas.draw_string(fu, box.position + Vector2(12, 21), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	canvas.draw_string(fu, box.position + Vector2(12, 41), _dist(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.65))
	_draw_sidebar(fd, fu)
	# sağ alt ipuçları
	var hints := [["Boşluk", "MERKEZLE"], ["Sağ tık", "İŞARET KOY"], ["Enter", "ROTA ÇİZ"], ["Tekerlek", "YAKINLAŞ"], ["M / Esc", "ÇIKIŞ"]]
	var y := vs.y - 46.0 * hints.size() - 20.0
	for h in hints:
		canvas.draw_string(fd, Vector2(vs.x - 470, y + 30), String(h[1]), HORIZONTAL_ALIGNMENT_RIGHT, 300, 26, Color.WHITE)
		var kw := fu.get_string_size(String(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(1, 1, 1, 0.14)
		sb2.set_corner_radius_all(6)
		sb2.set_border_width_all(2)
		sb2.border_color = Color(1, 1, 1, 0.7)
		canvas.draw_style_box(sb2, Rect2(Vector2(vs.x - 160, y + 9), Vector2(kw, 28)))
		canvas.draw_string(fu, Vector2(vs.x - 160, y + 29), String(h[0]), HORIZONTAL_ALIGNMENT_CENTER, kw, 15, Color.WHITE)
		y += 46.0
	if Game.has_waypoint:
		canvas.draw_string(fd, Vector2(36, vs.y - 34), "İŞARET · %s" % _dist(_route_len()), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.8, 0.6, 1.0))


func _draw_sidebar(fd: Font, fu: Font) -> void:
	var x := 22.0
	var y := 110.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.08, 0.82)
	sb.set_corner_radius_all(8)
	canvas.draw_style_box(sb, Rect2(x, y, 64, 18 + CATS.size() * 58))
	for i in CATS.size():
		var c := Vector2(x + 32, y + 38 + i * 58)
		var on := i == _cat
		if on:
			canvas.draw_rect(Rect2(x, c.y - 26, 64, 52), Color(1, 1, 1, 0.92))
			canvas.draw_rect(Rect2(x - 6, c.y - 26, 4, 52), Color(1.0, 0.4, 0.75))
		_cat_icon(String(CATS[i][0]), c, Color(0.08, 0.08, 0.12) if on else Color(1, 1, 1, 0.9))
	# kategori listesi (GTA6'daki yer listesi gibi)
	if _list_open:
		var lx := x + 76.0
		var lw := 420.0
		var vs := canvas.size
		var lh := minf(vs.y - 220.0, 70.0 + _list.size() * 52.0)
		canvas.draw_style_box(sb, Rect2(lx, y, lw, lh))
		canvas.draw_string(fd, Vector2(lx + 24, y + 48), String(CATS[_cat][1]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
		var rows := int((lh - 80.0) / 52.0)
		var first := clampi(_sel - rows + 1, 0, maxi(0, _list.size() - rows))
		var ry := y + 70.0
		for k in range(first, mini(_list.size(), first + rows)):
			var poi: Dictionary = _list[k]
			var on := k == _sel
			if on:
				canvas.draw_rect(Rect2(lx + 12, ry, lw - 24, 46), Color(1, 1, 1, 0.92))
			MapPainter.draw_icon(canvas, Vector2(lx + 38, ry + 23), String(poi.kind), 11.0)
			var d := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(poi.pos.x, poi.pos.z))
			canvas.draw_string(fu, Vector2(lx + 62, ry + 30), String(poi.name), HORIZONTAL_ALIGNMENT_LEFT, 250, 19, Color(0.08, 0.08, 0.12) if on else Color.WHITE)
			canvas.draw_string(fu, Vector2(lx + lw - 112, ry + 30), _dist(d), HORIZONTAL_ALIGNMENT_RIGHT, 90, 15, Color(0.2, 0.2, 0.25) if on else Color(1, 1, 1, 0.6))
			ry += 52.0
		canvas.draw_string(fu, Vector2(lx + 24, y + lh - 14), "%d / %d" % [_sel + 1 if _list.size() > 0 else 0, _list.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))


func _cat_icon(id: String, c: Vector2, col: Color) -> void:
	match id:
		"tum":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(11, 12), c + Vector2(0, 6), c + Vector2(-11, 12)]), col)
		"dukkan":
			canvas.draw_rect(Rect2(c + Vector2(-12, -6), Vector2(24, 18)), col)
			canvas.draw_arc(c + Vector2(0, -6), 7.0, PI, TAU, 10, col, 3.0)
		"yemek":
			canvas.draw_line(c + Vector2(-7, -13), c + Vector2(-7, 13), col, 3.0)
			for k in 3:
				canvas.draw_line(c + Vector2(-11 + k * 4, -13), c + Vector2(-11 + k * 4, -4), col, 2.0)
			canvas.draw_rect(Rect2(c + Vector2(4, -13), Vector2(6, 26)), col)
		"eglence":
			canvas.draw_arc(c, 12.0, 0, TAU, 20, col, 3.0)
			for k in 6:
				var a := k * TAU / 6.0
				canvas.draw_line(c, c + Vector2(cos(a), sin(a)) * 12.0, col, 2.0)
		"dovus":
			canvas.draw_rect(Rect2(c + Vector2(-10, -8), Vector2(20, 14)), col)
			canvas.draw_rect(Rect2(c + Vector2(-13, -3), Vector2(5, 12)), col)
			for k in 4:
				canvas.draw_rect(Rect2(c + Vector2(-10 + k * 5.2, -13), Vector2(4, 6)), col)
		"hizmet":
			canvas.draw_rect(Rect2(c + Vector2(-4, -12), Vector2(8, 24)), col)
			canvas.draw_rect(Rect2(c + Vector2(-12, -4), Vector2(24, 8)), col)
		"gezi":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 11), c + Vector2(-3, -9), c + Vector2(3, 0), c + Vector2(7, -5), c + Vector2(13, 11)]), col)


func _draw_page(fd: Font, fu: Font) -> void:
	var vs := canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.05, 0.1, 0.96))
	var x := vs.x * 0.5 - 520.0
	var y := 170.0
	var pl := player as Player
	match _tab:
		0:
			canvas.draw_string(fd, Vector2(x, y), "KAAN DEMİR", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE)
			var cb := pl.combat if pl else null
			var rows := [
				["Kıyafet", String(Outfits.info(Game.outfit).name)],
				["Silah", String(Weapons.info(cb.weapon).name) if cb else "-"],
				["Can / Zırh", "%d / %d" % [int(cb.health), int(cb.armor)] if cb else "-"],
				["Dayanıklılık (en fazla)", "%d" % int(cb.max_stamina) if cb else "-"],
				["Dövüş gücü", "%%%d" % int(round(cb.dmg_mult * 100.0)) if cb else "-"],
				["Element", "Metal"],
				["Sahip olunan kıyafet", "%d" % Game.owned_outfits.size()],
			]
			for r in rows:
				y += 62.0
				canvas.draw_string(fu, Vector2(x, y), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.6))
				canvas.draw_string(fd, Vector2(x + 420, y), String(r[1]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
		2:
			canvas.draw_string(fd, Vector2(x, y), "GÖREVLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE)
			y += 70.0
			for line in ["Hikâye görevleri yakında geliyor.", "Şimdilik şehirde serbestçe dolaşabilir, dükkânlara girebilir,", "dojoda antrenman yapıp manastıra çıkabilirsin."]:
				y += 40.0
				canvas.draw_string(fu, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.8))
		3:
			canvas.draw_string(fd, Vector2(x, y), "İLERLEME", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE)
			var rows2 := [["Çekilen fotoğraf", str(Game.photos)], ["Nakit", "₺" + _fmt(Game.money)], ["Banka", "₺" + _fmt(Game.bank)],
				["Haritadaki yerler", str(world.pois.size())], ["Aranma", "%d yıldız" % (Wanted.inst.stars if Wanted.inst else 0)]]
			for r in rows2:
				y += 62.0
				canvas.draw_string(fu, Vector2(x, y), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.6))
				canvas.draw_string(fd, Vector2(x + 420, y), String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)


func _route_len() -> float:
	var L := 0.0
	for k in range(1, Game.route.size()):
		L += Game.route[k].distance_to(Game.route[k - 1])
	return L


func _dist(m: float) -> String:
	return ("%.1f km" % (m / 1000.0)) if m >= 1000.0 else ("%d m" % int(m))


# ---------------------------------------------------------------- giriş
func _gui(e: InputEvent) -> void:
	if _tab != 1:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# kenar çubuğu / liste tıklamaları
			if mb.position.x < 90.0 and mb.position.y > 110.0:
				var i := int((mb.position.y - 110.0 - 12.0) / 58.0)
				if i >= 0 and i < CATS.size():
					_pick_cat(i)
					return
			if _list_open and mb.position.x > 98.0 and mb.position.x < 518.0 and mb.position.y > 180.0:
				var k := int((mb.position.y - 180.0) / 52.0)
				var rows := int((minf(canvas.size.y - 220.0, 70.0 + _list.size() * 52.0) - 80.0) / 52.0)
				var first := clampi(_sel - rows + 1, 0, maxi(0, _list.size() - rows))
				if first + k < _list.size():
					_sel = first + k
					_focus_sel(true)
					return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_toggle_waypoint(mb.position)
	elif e is InputEventMouseMotion and _drag:
		_cam -= (e as InputEventMouseMotion).relative / _zoom


func _pick_cat(i: int) -> void:
	Sfx.ui("click", -12.0)
	if _cat == i and _list_open:
		_list_open = false
		return
	_cat = i
	_build_list()
	_list_open = true
	if not _list.is_empty():
		_focus_sel(false)


func _focus_sel(route: bool) -> void:
	if _sel >= _list.size():
		return
	var poi: Dictionary = _list[_sel]
	_cam = Vector2(poi.pos.x, poi.pos.z)
	_zoom = maxf(_zoom, 0.35)
	if route:
		_set_wp(Vector2(poi.pos.x, poi.pos.z))


func _zoom_at(screen: Vector2, k: float) -> void:
	var before: Vector2 = _xf().affine_inverse() * screen
	_zoom = clampf(_zoom * k, 0.05, 3.0)
	var after: Vector2 = _xf().affine_inverse() * screen
	_cam += before - after


func _set_wp(wp: Vector2) -> void:
	Game.has_waypoint = true
	Game.waypoint = Vector3(wp.x, 0, wp.y)
	Game.route = world.route(player.global_position, Game.waypoint)
	Sfx.ui("select", -8.0)


func _toggle_waypoint(screen: Vector2) -> void:
	var wp: Vector2 = _xf().affine_inverse() * screen
	if not _hover.is_empty():
		wp = Vector2(_hover.pos.x, _hover.pos.z)
	if Game.has_waypoint and Vector2(Game.waypoint.x, Game.waypoint.z).distance_to(wp) < 30.0 / _zoom:
		Game.has_waypoint = false
		Game.route = PackedVector3Array()
	else:
		_set_wp(wp)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("map") or e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _list_open:
			_list_open = false
			if e.is_action_pressed("pause"):
				return
		closed.emit()
		queue_free()
	elif e is InputEventKey and e.pressed and not e.is_echo():
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_Q:
			_tab = (_tab + TABS.size() - 1) % TABS.size()
		elif k == KEY_E:
			_tab = (_tab + 1) % TABS.size()
		elif _tab != 1:
			return
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			if _list_open and _list.size() > 0:
				_focus_sel(true)
			else:
				_toggle_waypoint(canvas.size * 0.5)
		elif k == KEY_SPACE:
			_cam = Vector2(player.global_position.x, player.global_position.z)
		elif _list_open and (k == KEY_UP or k == KEY_DOWN):
			_sel = clampi(_sel + (1 if k == KEY_DOWN else -1), 0, maxi(0, _list.size() - 1))
			_focus_sel(false)
		elif k >= KEY_1 and k <= KEY_7:
			_pick_cat(k - KEY_1)


func _process(delta: float) -> void:
	_t += delta
	if _tab == 1:
		var mv := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_forward", "move_back"))
		if mv.length() > 0.1:
			_cam += mv * delta * 600.0 / maxf(_zoom, 0.1)
	canvas.queue_redraw()
