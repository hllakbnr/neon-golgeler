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


func _ready() -> void:
	layer = 5
	minimap = Control.new()
	minimap.position = Vector2(28, 0)
	minimap.size = Vector2(330, 210)
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_top = -256
	minimap.offset_bottom = -46
	minimap.offset_left = 28
	minimap.offset_right = 358
	minimap.clip_contents = true
	minimap.draw.connect(_draw_map)
	add_child(minimap)
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
	add_child(stars)
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


func _process(_d: float) -> void:
	if player == null:
		return
	_area_check -= _d
	if _area_check <= 0.0 and world:
		_area_check = 0.5
		var nm := world.district_name(player.global_position)
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
	MapPainter.draw_player(minimap, center, 0.0, 9.0)
	# kuzey işareti
	var north: Vector2 = center + Vector2(0, -1).rotated(player.yaw) * (minf(sz.x, sz.y) * 0.5 - 12.0)
	north = Vector2(clampf(north.x, 12, sz.x - 12), clampf(north.y, 12, sz.y - 12))
	minimap.draw_circle(north, 9.0, Color(0, 0, 0, 0.75))
	if Game.font_display:
		minimap.draw_string(Game.font_display, north + Vector2(-9, 5), "K", HORIZONTAL_ALIGNMENT_CENTER, 18, 14, Color.WHITE)
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.7), false, 3.0)
