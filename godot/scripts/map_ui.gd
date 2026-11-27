extends CanvasLayer
class_name MapScreen
## M ile açılan tam harita (GTA6 tarzı): uydu görünümlü kıta, yakınlaşınca şehir ayrıntısı,
## bölge adları, kategori filtreli simgeler, imleç altında yer bilgisi, sağ tık ile işaret + GPS rotası.

signal closed

var world: World
var player: Node3D
var canvas: Control
var legend: VBoxContainer
var info: Label
var _cam := Vector2.ZERO          # haritanın merkezindeki dünya noktası (x, z)
var _zoom := 0.18                 # piksel / metre
var _drag := false
var _hide := {}                   # gizlenen kategoriler
var _hover := {}


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw)
	canvas.gui_input.connect(_gui)
	add_child(canvas)
	# üst şerit
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.55)
	top.anchor_right = 1.0
	top.offset_bottom = 64
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var title := Game.styled_label("HARİTA", 40, Color.WHITE, true)
	title.position = Vector2(40, 10)
	add_child(title)
	info = Game.styled_label("", 20, Color(1, 1, 1, 0.9))
	info.anchor_left = 0.5
	info.anchor_right = 0.5
	info.offset_left = -400
	info.offset_right = 400
	info.offset_top = 18
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)
	# lejant (kategori filtreleri)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -300
	panel.offset_right = -24
	panel.offset_top = 84
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	legend = VBoxContainer.new()
	panel.add_child(legend)
	legend.add_child(Game.styled_label("YERLER", 22, Color(1, 1, 1, 0.8), true))
	var kinds := {}
	for p in world.pois:
		kinds[String(p.kind)] = true
	for k in kinds.keys():
		var st := MapPainter.style(k)
		var cb := CheckBox.new()
		cb.text = "%s  %s" % [st[0], st[2]]
		cb.button_pressed = true
		cb.add_theme_color_override("font_color", st[1])
		cb.add_theme_font_size_override("font_size", 16)
		cb.toggled.connect(func(on: bool): _hide[k] = not on; canvas.queue_redraw())
		legend.add_child(cb)
	var hint := Game.styled_label("Sağ tık / Enter: işaret koy · Tekerlek: yakınlaş · Sürükle: kaydır · Boşluk: konumuma dön · M / Esc: kapat", 17, Color(1, 1, 1, 0.75))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_top = -44
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	_cam = Vector2(player.global_position.x, player.global_position.z)


func _xf() -> Transform2D:
	var c := canvas.size * 0.5
	return Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, c) * Transform2D(0.0, -_cam)


func _draw() -> void:
	var xf := _xf()
	MapPainter.draw_world(canvas, world, xf, _zoom, Rect2(Vector2.ZERO, canvas.size))
	var f := Game.font_display
	# bölge adları
	if f and _zoom < 0.6:
		for rl in world.region_labels:
			var p: Vector2 = xf * (rl[1] as Vector2)
			var txt: String = String(rl[0]).to_upper()
			var fs := int(clampf(_zoom * 90.0, 13.0, 26.0))
			canvas.draw_string_outline(f, p + Vector2(-200, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 400, fs, 5, Color(0, 0, 0, 0.7))
			canvas.draw_string(f, p + Vector2(-200, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 400, fs, Color(1, 1, 1, 0.92))
	# şehir semt adları (yakınken)
	if f and _zoom >= 0.6:
		var done := {}
		for b in world.data.city.blocks:
			var nm: String = world.DISTRICT_NAMES.get(String(b.d), "")
			if nm == "" or done.has(nm):
				continue
			done[nm] = true
			var p: Vector2 = xf * Vector2(b.c[0], b.c[1])
			canvas.draw_string_outline(f, p + Vector2(-150, 0), nm.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 300, 18, 4, Color(0, 0, 0, 0.8))
			canvas.draw_string(f, p + Vector2(-150, 0), nm.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 300, 18, Color(1, 1, 0.9))
	# simgeler
	_hover = {}
	var mouse := canvas.get_local_mouse_position()
	for poi in world.pois:
		if _hide.get(String(poi.kind), false):
			continue
		var p: Vector2 = xf * Vector2(poi.pos.x, poi.pos.z)
		MapPainter.draw_icon(canvas, p, String(poi.kind), 11.0)
		if p.distance_to(mouse) < 14.0:
			_hover = poi
	if Game.has_waypoint:
		MapPainter.draw_waypoint(canvas, xf * Vector2(Game.waypoint.x, Game.waypoint.z))
	var pp: Vector2 = xf * Vector2(player.global_position.x, player.global_position.z)
	var yaw: float = player.get("yaw") if player.get("yaw") != null else 0.0
	MapPainter.draw_player(canvas, pp, -yaw, 11.0)
	# imleç artı işareti + yer bilgisi
	canvas.draw_line(mouse + Vector2(-12, 0), mouse + Vector2(12, 0), Color(1, 1, 1, 0.8), 1.5)
	canvas.draw_line(mouse + Vector2(0, -12), mouse + Vector2(0, 12), Color(1, 1, 1, 0.8), 1.5)
	var wpos: Vector2 = xf.affine_inverse() * mouse
	var nm := world.district_name(Vector3(wpos.x, 0, wpos.y))
	var dist := Vector2(player.global_position.x, player.global_position.z).distance_to(wpos)
	var txt := "%s · %s" % [nm if nm != "" else "Açık Deniz", _dist(dist)]
	if not _hover.is_empty():
		txt = "%s · %s" % [_hover.name, _dist(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(_hover.pos.x, _hover.pos.z)))]
	if Game.has_waypoint:
		txt += "   |   İşaret: %s" % _dist(_route_len())
	info.text = txt


func _route_len() -> float:
	var L := 0.0
	for k in range(1, Game.route.size()):
		L += Game.route[k].distance_to(Game.route[k - 1])
	return L


func _dist(m: float) -> String:
	return ("%.1f km" % (m / 1000.0)) if m >= 1000.0 else ("%d m" % int(m))


func _gui(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_toggle_waypoint(mb.position)
	elif e is InputEventMouseMotion:
		if _drag:
			_cam -= (e as InputEventMouseMotion).relative / _zoom
		canvas.queue_redraw()


func _zoom_at(screen: Vector2, k: float) -> void:
	var before: Vector2 = _xf().affine_inverse() * screen
	_zoom = clampf(_zoom * k, 0.06, 3.0)
	var after: Vector2 = _xf().affine_inverse() * screen
	_cam += before - after
	canvas.queue_redraw()


func _toggle_waypoint(screen: Vector2) -> void:
	var wp: Vector2 = _xf().affine_inverse() * screen
	if not _hover.is_empty():
		wp = Vector2(_hover.pos.x, _hover.pos.z)
	if Game.has_waypoint and Vector2(Game.waypoint.x, Game.waypoint.z).distance_to(wp) < 30.0 / _zoom:
		Game.has_waypoint = false
		Game.route = PackedVector3Array()
	else:
		Game.has_waypoint = true
		Game.waypoint = Vector3(wp.x, 0, wp.y)
		Game.route = world.route(player.global_position, Game.waypoint)
	canvas.queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("map") or e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
	elif e is InputEventKey and e.pressed:
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_toggle_waypoint(canvas.size * 0.5)
		elif k == KEY_SPACE:
			_cam = Vector2(player.global_position.x, player.global_position.z)
			canvas.queue_redraw()


func _process(delta: float) -> void:
	var mv := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_forward", "move_back"))
	if mv.length() > 0.1:
		_cam += mv * delta * 600.0 / maxf(_zoom, 0.1)
		canvas.queue_redraw()
