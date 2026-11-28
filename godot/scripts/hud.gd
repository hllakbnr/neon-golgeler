extends CanvasLayer
class_name HUD
## Oyun içi arayüz: sol altta mini harita + can/zırh çubukları, sağ üstte saat, hız, ipucu.

var player: Player
var world: World
var minimap: Control
var clock: Label
var speed: Label
var prompt: Label
var fps: Label
var area: Label
var _area_name := ""
var _area_t := 0.0
var _area_check := 0.0
var _zoom := 1.0
var money: Label
var help_box: Label
var _help_t := 0.0
var _route_t := 0.0
var bars_box: HBoxContainer
var health_bar: ProgressBar
var armor_bar: ProgressBar
var stars: Control
var stamina_bar: ProgressBar
var weapon_l: Label
var big: Label
var _big_t := 0.0
var overlay: Control
var _bars_c: Control


func _ready() -> void:
	layer = 5
	Game.hud = self
	minimap = Control.new()
	minimap.position = Vector2(28, 0)
	minimap.size = Vector2(330, 210)
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_top = -256
	minimap.offset_bottom = -46
	minimap.offset_left = 28
	minimap.offset_right = 358
	minimap.draw.connect(_draw_map)
	# yuvarlak köşeli çerçeve: mini harita bu şeklin içine kırpılır
	var frame := Panel.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.08, 0.2, 0.3)
	fsb.set_corner_radius_all(16)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 28
	frame.offset_right = 358
	frame.offset_top = -262
	frame.offset_bottom = -52
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	minimap.anchor_top = 0.0
	minimap.anchor_bottom = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_top = 0
	minimap.offset_bottom = 0
	minimap.offset_left = 0
	minimap.offset_right = 0
	frame.add_child(minimap)
	var border := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.draw_center = false
	bsb.set_corner_radius_all(16)
	bsb.set_border_width_all(2)
	bsb.border_color = Color(1, 1, 1, 0.35)
	bsb.shadow_color = Color(0, 0, 0, 0.35)
	bsb.shadow_size = 8
	border.add_theme_stylebox_override("panel", bsb)
	border.anchor_top = 1.0
	border.anchor_bottom = 1.0
	border.offset_left = 28
	border.offset_right = 358
	border.offset_top = -262
	border.offset_bottom = -52
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	_bars_c = Control.new()
	_bars_c.anchor_top = 1.0
	_bars_c.anchor_bottom = 1.0
	_bars_c.offset_left = 28
	_bars_c.offset_right = 358
	_bars_c.offset_top = -46
	_bars_c.offset_bottom = -16
	_bars_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_c.draw.connect(_draw_bars)
	add_child(_bars_c)
	var bars := HBoxContainer.new()
	bars.anchor_top = 1.0
	bars.anchor_bottom = 1.0
	bars.offset_left = 28
	bars.offset_right = 358
	bars.offset_top = -40
	bars.offset_bottom = -32
	bars.add_theme_constant_override("separation", 4)
	add_child(bars)
	for c in [Color(0.35, 0.85, 0.4), Color(0.3, 0.6, 1.0)]:
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(163, 8)
		pb.value = 100
		var fg := StyleBoxFlat.new()
		fg.bg_color = c
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.45)
		pb.add_theme_stylebox_override("fill", fg)
		pb.add_theme_stylebox_override("background", bg)
		bars.add_child(pb)
		if health_bar == null:
			health_bar = pb
		else:
			armor_bar = pb
	bars_box = bars
	bars.visible = false
	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.anchor_top = 1.0
	stamina_bar.anchor_bottom = 1.0
	stamina_bar.offset_left = 28
	stamina_bar.offset_right = 358
	stamina_bar.offset_top = -29
	stamina_bar.offset_bottom = -25
	var sfg := StyleBoxFlat.new()
	sfg.bg_color = Color(1.0, 0.8, 0.25)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0.4)
	stamina_bar.add_theme_stylebox_override("fill", sfg)
	stamina_bar.add_theme_stylebox_override("background", sbg)
	add_child(stamina_bar)
	stamina_bar.visible = false
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	move_child(overlay, 0)
	clock = Game.styled_label("", 30, Color.WHITE, true)
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.offset_left = -220
	clock.offset_right = -30
	clock.offset_top = 22
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(clock)
	money = Game.styled_label("", 30, Color(0.55, 1.0, 0.55), true)
	money.anchor_left = 1.0
	money.anchor_right = 1.0
	money.offset_left = -320
	money.offset_right = -30
	money.offset_top = 58
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	money.add_theme_constant_override("shadow_offset_x", 2)
	money.add_theme_constant_override("shadow_offset_y", 2)
	add_child(money)
	stars = Control.new()
	stars.anchor_left = 1.0
	stars.anchor_right = 1.0
	stars.offset_left = -330
	stars.offset_right = -30
	stars.offset_top = 100
	stars.offset_bottom = 136
	stars.draw.connect(_draw_stars)
	add_child(stars)
	weapon_l = Game.styled_label("", 24, Color.WHITE, true)
	weapon_l.anchor_left = 1.0
	weapon_l.anchor_right = 1.0
	weapon_l.offset_left = -420
	weapon_l.offset_right = -30
	weapon_l.offset_top = 140
	weapon_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	weapon_l.add_theme_constant_override("shadow_offset_x", 2)
	weapon_l.add_theme_constant_override("shadow_offset_y", 2)
	add_child(weapon_l)
	big = Game.styled_label("", 120, Color.WHITE, true)
	big.set_anchors_preset(Control.PRESET_CENTER)
	big.offset_left = -700
	big.offset_right = 700
	big.offset_top = -90
	big.offset_bottom = 60
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	big.add_theme_constant_override("shadow_offset_x", 4)
	big.add_theme_constant_override("shadow_offset_y", 4)
	big.modulate.a = 0.0
	add_child(big)
	help_box = Label.new()
	help_box.position = Vector2(28, 28)
	help_box.size = Vector2(420, 0)
	help_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_box.add_theme_font_size_override("font_size", 18)
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0, 0, 0, 0.72)
	hb.content_margin_left = 14
	hb.content_margin_right = 14
	hb.content_margin_top = 10
	hb.content_margin_bottom = 10
	help_box.add_theme_stylebox_override("normal", hb)
	help_box.visible = false
	add_child(help_box)
	speed = Game.styled_label("", 44, Color.WHITE, true)
	speed.anchor_left = 1.0
	speed.anchor_right = 1.0
	speed.anchor_top = 1.0
	speed.anchor_bottom = 1.0
	speed.offset_left = -260
	speed.offset_right = -40
	speed.offset_top = -100
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(speed)
	prompt = Game.styled_label("", 20, Color.WHITE)
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_left = -300
	prompt.offset_right = 300
	prompt.offset_top = -130
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	add_child(prompt)
	fps = Game.styled_label("", 12, Color(1, 1, 1, 0.5))
	fps.anchor_left = 1.0
	fps.anchor_right = 1.0
	fps.anchor_top = 1.0
	fps.anchor_bottom = 1.0
	fps.offset_left = -160
	fps.offset_right = -12
	fps.offset_top = -22
	fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(fps)
	# bölge adı (GTA gibi: yeni bölgeye girince sağ altta belirir)
	area = Game.styled_label("", 40, Color.WHITE, true)
	area.anchor_left = 1.0
	area.anchor_right = 1.0
	area.anchor_top = 1.0
	area.anchor_bottom = 1.0
	area.offset_left = -700
	area.offset_right = -40
	area.offset_top = -170
	area.offset_bottom = -116
	area.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	area.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	area.add_theme_constant_override("shadow_offset_x", 3)
	area.add_theme_constant_override("shadow_offset_y", 3)
	area.modulate.a = 0.0
	add_child(area)


func toast(text: String) -> void:
	_area_name = text
	area.text = text
	_area_t = 4.0


func notify(text: String, secs := 4.0) -> void:
	## GTA tarzı sol üst bilgi kutusu
	help_box.text = text
	help_box.visible = true
	_help_t = secs


func big_message(text: String, col: Color) -> void:
	big.text = text
	big.add_theme_color_override("font_color", col)
	_big_t = 4.2


func _process(_d: float) -> void:
	if player == null:
		return
	_big_t -= _d
	big.modulate.a = clampf(minf(4.2 - _big_t, _big_t) * 2.0, 0.0, 1.0) if _big_t > 0.0 else 0.0
	if player.combat:
		var cb := player.combat
		health_bar.value = cb.health
		armor_bar.value = cb.armor
		armor_bar.modulate.a = 1.0 if cb.armor > 0.0 else 0.35
		stamina_bar.value = cb.stamina
		stamina_bar.modulate.a = 1.0 if cb.stamina < 99.0 else 0.25
		var w := Weapons.info(cb.weapon)
		var am := ""
		if String(w.kind) == "throw":
			am = "  ×%d" % int(cb.ammo.get(cb.weapon, 0))
		weapon_l.text = ("%s%s" % [String(w.name).to_upper(), am]) if not player.car else ""
	stars.queue_redraw()
	overlay.queue_redraw()
	_bars_c.queue_redraw()
	_area_check -= _d
	if _area_check <= 0.0 and world:
		_area_check = 0.5
		var nm := world.district_name(player.global_position)
		if world.interiors and world.interiors.inside():
			nm = String(world.interiors.current_door.get("name", ""))
		if nm != "" and nm != _area_name:
			toast(nm.to_upper())
	_area_t -= _d
	area.modulate.a = clampf(minf(_area_t, 4.0 - _area_t) * 2.5, 0.0, 1.0) if _area_t > 0.0 else 0.0
	_help_t -= _d
	help_box.visible = _help_t > 0.0
	_route_t -= _d
	if Game.has_waypoint and _route_t <= 0.0:
		_route_t = 1.0
		if Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(Game.waypoint.x, Game.waypoint.z)) < 25.0:
			Game.has_waypoint = false
			Game.route = PackedVector3Array()
			notify("Hedefe vardın.", 3.0)
		else:
			Game.route = world.route(player.global_position, Game.waypoint)
	clock.text = Game.clock_text()
	money.text = "₺%s" % _fmt(Game.money)
	speed.text = ("%d km/s" % int(player.car.speed_kmh())) if player.car else ""
	prompt.text = player.prompt_text() if player.has_method("prompt_text") else ""
	fps.text = "%d FPS" % Engine.get_frames_per_second()
	minimap.queue_redraw()


func _fmt(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func _draw_map() -> void:
	var sz := minimap.size
	if player == null or world == null:
		return
	var center := sz * 0.5 + Vector2(0, sz.y * 0.18)
	var spd := player.car.linear_velocity.length() if player.car else 0.0
	_zoom = lerpf(_zoom, lerpf(1.1, 0.42, clampf(spd / 35.0, 0.0, 1.0)), 0.04)
	var sc := _zoom
	var p := player.global_position
	if world.interiors and world.interiors.inside():
		minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.05, 0.1))
		for k in 8:
			minimap.draw_line(Vector2(0, k * 30.0), Vector2(sz.x, k * 30.0), Color(1, 1, 1, 0.05), 1.0)
		var f: Font = Game.font_display if Game.font_display else ThemeDB.fallback_font
		minimap.draw_string(f, Vector2(0, sz.y * 0.5 + 10), "İÇ MEKÂN", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 30, Color(1, 1, 1, 0.5))
		minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.7), false, 3.0)
		return
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.1, 0.3, 0.44))
	var xf := Transform2D(player.yaw, Vector2(sc, sc), 0.0, center) * Transform2D(0.0, Vector2(-p.x, -p.z))
	MapPainter.draw_world(minimap, world, xf, sc, Rect2(Vector2.ZERO, sz))
	# simge noktalar (dik)
	for poi in world.pois:
		var mp: Vector2 = xf * Vector2(poi.pos.x, poi.pos.z)
		if Rect2(Vector2(-10, -10), sz + Vector2(20, 20)).has_point(mp):
			MapPainter.draw_icon(minimap, mp, String(poi.kind), 8.0)
	if Game.has_waypoint:
		var wp: Vector2 = xf * Vector2(Game.waypoint.x, Game.waypoint.z)
		wp = Vector2(clampf(wp.x, 10, sz.x - 10), clampf(wp.y, 24, sz.y - 6))
		MapPainter.draw_waypoint(minimap, wp)
	for car in get_tree().get_nodes_in_group("cars"):
		var cp: Vector2 = xf * Vector2((car as Node3D).global_position.x, (car as Node3D).global_position.z)
		if Rect2(Vector2.ZERO, sz).has_point(cp) and car != player.car:
			minimap.draw_circle(cp, 3.2, Color(0.3, 0.7, 1.0))
	# aranma: arama bölgesi, polisler, tanıklar
	var wt := Wanted.inst
	if wt and wt.stars > 0 and not wt.seen:
		var sc_c: Vector2 = xf * Vector2(wt.last_seen.x, wt.last_seen.z)
		var col := Color(0.3, 0.5, 1.0, 0.22) if int(wt.flash * 2.0) % 2 == 0 else Color(1.0, 0.25, 0.3, 0.22)
		minimap.draw_circle(sc_c, wt.search_r * sc, col)
		minimap.draw_arc(sc_c, wt.search_r * sc, 0, TAU, 64, Color(col, 0.7), 2.0)
	for o in get_tree().get_nodes_in_group("police"):
		var op: Vector2 = xf * Vector2((o as Node3D).global_position.x, (o as Node3D).global_position.z)
		if Rect2(Vector2.ZERO, sz).has_point(op) and not (o as Pedestrian).is_down():
			var blink := int(Time.get_ticks_msec() / 250) % 2 == 0
			minimap.draw_circle(op, 3.6, (Color(1, 0.2, 0.25) if blink else Color(0.3, 0.5, 1.0)) if (wt and wt.stars > 0) else Color(0.4, 0.55, 1.0, 0.8))
	for o in get_tree().get_nodes_in_group("traffic"):
		var tc := o as TrafficCar
		if tc and tc.pursuit:
			var op: Vector2 = xf * Vector2(tc.global_position.x, tc.global_position.z)
			if Rect2(Vector2.ZERO, sz).has_point(op):
				minimap.draw_rect(Rect2(op - Vector2(4, 4), Vector2(8, 8)), Color(1, 0.2, 0.25) if int(Time.get_ticks_msec() / 200) % 2 == 0 else Color(0.3, 0.5, 1.0))
	for o in get_tree().get_nodes_in_group("people"):
		var pd := o as Pedestrian
		if pd == null:
			continue
		if pd.state == Pedestrian.S.CALL or pd.hostile:
			var op: Vector2 = xf * Vector2(pd.global_position.x, pd.global_position.z)
			if Rect2(Vector2.ZERO, sz).has_point(op):
				minimap.draw_circle(op, 4.0, Color(1, 0.15, 0.2))
				if pd.state == Pedestrian.S.CALL:
					minimap.draw_arc(op, 7.0, 0, TAU, 16, Color(1, 0.9, 0.3), 1.5)
	MapPainter.draw_player(minimap, center, 0.0, 9.0)
	# kuzey işareti
	var north: Vector2 = center + Vector2(0, -1).rotated(player.yaw) * (minf(sz.x, sz.y) * 0.5 - 12.0)
	north = Vector2(clampf(north.x, 12, sz.x - 12), clampf(north.y, 12, sz.y - 12))
	minimap.draw_circle(north, 9.0, Color(0, 0, 0, 0.75))
	if Game.font_display:
		minimap.draw_string(Game.font_display, north + Vector2(-9, 5), "K", HORIZONTAL_ALIGNMENT_CENTER, 18, 14, Color.WHITE)
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.7), false, 3.0)


func _star_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	return pts


func _draw_stars() -> void:
	var wt := Wanted.inst
	if wt == null:
		return
	var n := 6
	var w := stars.size.x
	for i in n:
		var c := Vector2(w - 18.0 - (n - 1 - i) * 40.0, 18.0)
		var pts := _star_pts(c, 16.0)
		var on := i < wt.stars
		if on:
			var a := 1.0 if wt.seen else (0.35 + 0.65 * absf(sin(wt.flash * 4.0)))
			stars.draw_colored_polygon(pts, Color(1, 1, 1, a))
		elif wt.stars > 0:
			var closed := pts.duplicate()
			closed.append(pts[0])
			stars.draw_polyline(closed, Color(1, 1, 1, 0.35), 1.5)
	if wt.stars > 0 and not wt.seen:
		var ep := wt.evade_progress()
		stars.draw_rect(Rect2(Vector2(w - 238.0, 40.0), Vector2(220.0, 3.0)), Color(0, 0, 0, 0.4))
		stars.draw_rect(Rect2(Vector2(w - 238.0, 40.0), Vector2(220.0 * ep, 3.0)), Color(0.4, 0.8, 1.0))


func _draw_overlay() -> void:
	## 3B noktalara bağlı ekran işaretleri (havada yazı değil, arayüz simgeleri)
	var cam := get_viewport().get_camera_3d()
	if cam == null or player == null:
		return
	var cb := player.combat
	if cb and cb.target and is_instance_valid(cb.target):
		var tp := cb.target.global_position + Vector3(0, 2.15, 0)
		if not cam.is_position_behind(tp):
			var sp := cam.unproject_position(tp)
			var col := Color(1, 0.25, 0.3) if cb.locked() else Color(1, 1, 1, 0.55)
			overlay.draw_colored_polygon(PackedVector2Array([sp + Vector2(-9, -12), sp + Vector2(9, -12), sp + Vector2(0, 0)]), col)
			var ped := cb.target as Pedestrian
			if ped and cb.locked():
				var hp := clampf(ped.health / ped.max_health, 0.0, 1.0)
				overlay.draw_rect(Rect2(sp + Vector2(-30, -24), Vector2(60, 5)), Color(0, 0, 0, 0.6))
				overlay.draw_rect(Rect2(sp + Vector2(-30, -24), Vector2(60 * hp, 5)), Color(0.9, 0.25, 0.25))
	for o in get_tree().get_nodes_in_group("people"):
		var pd := o as Pedestrian
		if pd == null or pd.state != Pedestrian.S.CALL:
			continue
		var tp := pd.global_position + Vector3(0, 2.3, 0)
		if cam.is_position_behind(tp) or cam.global_position.distance_to(tp) > 60.0:
			continue
		var sp := cam.unproject_position(tp)
		overlay.draw_circle(sp, 13.0, Color(0.9, 0.15, 0.2, 0.9))
		overlay.draw_rect(Rect2(sp + Vector2(-4, -7), Vector2(8, 14)), Color.WHITE)
		overlay.draw_arc(sp, 16.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - clampf(pd.call_t / 7.0, 0.0, 1.0)), 24, Color(1, 0.9, 0.3), 3.0)
	var wt := Wanted.inst
	if wt and wt.arrest_progress() > 0.01:
		var c := overlay.size * 0.5 + Vector2(0, 80)
		overlay.draw_arc(c, 26.0, -PI * 0.5, -PI * 0.5 + TAU * wt.arrest_progress(), 32, Color(0.4, 0.6, 1.0), 5.0)
		if Game.font_ui:
			overlay.draw_string(Game.font_ui, c + Vector2(-260, 52), "Tutuklanıyorsun — kaç ya da karşı koy!", HORIZONTAL_ALIGNMENT_CENTER, 520, 18, Color.WHITE)


func _bar(x: float, w: float, v: float, col: Color, icon: String) -> void:
	## yuvarlak uçlu, koyu zeminli çubuk + küçük simge
	var y := 10.0
	var h := 9.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(5)
	_bars_c.draw_style_box(sb, Rect2(x, y, w, h))
	if v > 0.001:
		var fb := StyleBoxFlat.new()
		fb.bg_color = col
		fb.set_corner_radius_all(5)
		_bars_c.draw_style_box(fb, Rect2(x + 1, y + 1, maxf(6.0, (w - 2) * clampf(v, 0.0, 1.0)), h - 2))
	var c := Vector2(x - 2, y + h * 0.5)
	match icon:
		"can":
			_bars_c.draw_circle(c + Vector2(-9, -1.5), 3.2, col)
			_bars_c.draw_circle(c + Vector2(-4.5, -1.5), 3.2, col)
			_bars_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-12.2, -0.5), c + Vector2(-1.3, -0.5), c + Vector2(-6.75, 5.5)]), col)
		"zirh":
			_bars_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -5), c + Vector2(-2, -5), c + Vector2(-2, 0), c + Vector2(-7, 5), c + Vector2(-12, 0)]), col)
		"guc":
			_bars_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(-11, 1), c + Vector2(-7, 1), c + Vector2(-9, 6), c + Vector2(-2, -1), c + Vector2(-6, -1)]), col)


func _draw_bars() -> void:
	if player == null or player.combat == null:
		return
	var cb := player.combat
	var low := cb.health < 30.0 and int(Time.get_ticks_msec() / 300) % 2 == 0
	_bar(16.0, 140.0, cb.health / 100.0, Color(1.0, 0.3, 0.35) if low else Color(0.35, 0.9, 0.5), "can")
	_bar(178.0, 72.0, cb.armor / 100.0, Color(0.35, 0.65, 1.0), "zirh")
	_bar(272.0, 58.0, cb.stamina / maxf(cb.max_stamina, 1.0), Color(1.0, 0.82, 0.3), "guc")
