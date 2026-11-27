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
var _zoom := 0.9
const POI_STYLE := {"food": ["Y", Color(1.0, 0.6, 0.2)], "dojo": ["D", Color(1.0, 0.25, 0.8)], "weapons": ["S", Color(0.4, 0.9, 1.0)],
	"clothes": ["K", Color(0.7, 0.45, 1.0)], "club": ["N", Color(0.2, 1.0, 1.0)], "police": ["P", Color(0.35, 0.55, 1.0)],
	"hospital": ["H", Color(1.0, 0.3, 0.3)], "spray": ["B", Color(0.3, 1.0, 0.5)], "tower": ["T", Color(1.0, 0.3, 0.85)],
	"monastery": ["M", Color(1.0, 0.8, 0.4)], "secure": ["A", Color(1.0, 0.2, 0.25)], "harbor": ["L", Color(1.0, 0.85, 0.2)],
	"station": ["İ", Color(0.2, 0.9, 1.0)], "beach": ["☀", Color(1.0, 0.9, 0.4)]}


func _ready() -> void:
	layer = 5
	minimap = Control.new()
	minimap.position = Vector2(28, 0)
	minimap.size = Vector2(300, 190)
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_top = -236
	minimap.offset_bottom = -46
	minimap.offset_left = 28
	minimap.offset_right = 328
	minimap.clip_contents = true
	minimap.draw.connect(_draw_map)
	add_child(minimap)
	var bars := HBoxContainer.new()
	bars.anchor_top = 1.0
	bars.anchor_bottom = 1.0
	bars.offset_left = 28
	bars.offset_right = 328
	bars.offset_top = -40
	bars.offset_bottom = -32
	bars.add_theme_constant_override("separation", 4)
	add_child(bars)
	for c in [Color(0.35, 0.85, 0.4), Color(0.3, 0.6, 1.0)]:
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(148, 8)
		pb.value = 100
		var fg := StyleBoxFlat.new()
		fg.bg_color = c
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.45)
		pb.add_theme_stylebox_override("fill", fg)
		pb.add_theme_stylebox_override("background", bg)
		bars.add_child(pb)
	clock = Game.styled_label("", 30, Color.WHITE, true)
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.offset_left = -220
	clock.offset_right = -30
	clock.offset_top = 22
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(clock)
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
	clock.text = Game.clock_text()
	speed.text = ("%d km/s" % int(player.car.speed_kmh())) if player.car else ""
	var near_car := false
	if player.car == null:
		for c in get_tree().get_nodes_in_group("cars"):
			if (c as Node3D).global_position.distance_to(player.global_position) < 3.8:
				near_car = true
	prompt.text = "[F] Araca bin" if near_car else ("[F] İn" if player.car else "")
	fps.text = "%d FPS" % Engine.get_frames_per_second()
	minimap.queue_redraw()


func _draw_map() -> void:
	var sz := minimap.size
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.1, 0.26, 0.4, 0.9))
	if player == null or world == null:
		return
	var center := sz * 0.5 + Vector2(0, 30)
	var spd := player.car.linear_velocity.length() if player.car else 0.0
	_zoom = lerpf(_zoom, lerpf(0.9, 0.45, clampf(spd / 35.0, 0.0, 1.0)), 0.05)
	var sc := _zoom
	var p := player.global_position
	# dünya → harita: merkez + dönüş(yaw) * ölçek * (nokta - oyuncu)
	minimap.draw_set_transform(center, player.yaw, Vector2(sc, sc))
	var off := Vector2(-p.x, -p.z)
	var tex := world.map_texture()
	if tex:
		minimap.draw_texture_rect(tex, Rect2(off + Vector2(-world.T_HALF, -world.T_HALF) - Vector2(world.T_STEP, world.T_STEP) * 0.5, Vector2(world.T_HALF, world.T_HALF) * 2.0 + Vector2(world.T_STEP, world.T_STEP)), false)
	for r in world.blocks:
		minimap.draw_rect(Rect2(r.position + off, r.size), Color(0.42, 0.43, 0.48))
	var road_col := Color(0.92, 0.92, 0.94)
	for e in world.extra_roads:
		minimap.draw_line(e[0] + off, e[1] + off, road_col, e[2])
	var g := world.GRID
	for i in range(-g, g + 1):
		var a := Vector2(i * world.CELL, -g * world.CELL - 6.0) + off
		var b := Vector2(i * world.CELL, g * world.CELL + 6.0) + off
		minimap.draw_line(a, b, road_col, world.ROAD_W)
		var c := Vector2(-g * world.CELL - 6.0, i * world.CELL) + off
		var d := Vector2(g * world.CELL + 6.0, i * world.CELL) + off
		minimap.draw_line(c, d, road_col, world.ROAD_W)
	minimap.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var xf := Transform2D(player.yaw, Vector2.ZERO)
	var to_map := func(w: Vector3) -> Vector2:
		return center + xf.basis_xform(Vector2(w.x - p.x, w.z - p.z) * sc)
	# simge noktalar (dik durur)
	var font := Game.font_display
	for poi in world.pois:
		var mp: Vector2 = to_map.call(poi.pos)
		if mp.x < -10 or mp.y < -10 or mp.x > sz.x + 10 or mp.y > sz.y + 10:
			continue
		var st: Array = POI_STYLE.get(poi.kind, ["•", Color.WHITE])
		minimap.draw_circle(mp, 8.0, Color(0.05, 0.05, 0.08, 0.9))
		minimap.draw_arc(mp, 8.0, 0, TAU, 20, st[1], 2.0)
		if font:
			minimap.draw_string(font, mp + Vector2(-4.5, 5.0), st[0], HORIZONTAL_ALIGNMENT_CENTER, 9, 13, st[1])
	# araçlar
	for car in get_tree().get_nodes_in_group("cars"):
		var cp: Vector2 = to_map.call((car as Node3D).global_position)
		if cp.distance_to(center) < 400:
			minimap.draw_circle(cp, 3.5, Color(0.3, 0.7, 1.0))
	# oyuncu oku
	var pts := PackedVector2Array([center + Vector2(0, -11), center + Vector2(8, 8), center + Vector2(0, 4), center + Vector2(-8, 8)])
	minimap.draw_colored_polygon(pts, Color.WHITE)
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.6), false, 3.0)
