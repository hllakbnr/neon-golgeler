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


func _process(_d: float) -> void:
	if player == null:
		return
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
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.35, 0.45, 0.4, 0.82))
	if player == null or world == null:
		return
	var center := sz * 0.5 + Vector2(0, 30)
	var sc := 0.9
	var p := player.global_position
	var xf := Transform2D(player.yaw, Vector2.ZERO)
	var to_map := func(w: Vector3) -> Vector2:
		var v := Vector2(w.x - p.x, w.z - p.z) * sc
		return center + xf.basis_xform(v)
	# yollar
	var g := world.GRID
	for i in range(-g, g + 1):
		var a: Vector2 = to_map.call(Vector3(i * world.CELL, 0, -g * world.CELL))
		var b: Vector2 = to_map.call(Vector3(i * world.CELL, 0, g * world.CELL))
		minimap.draw_line(a, b, Color(0.9, 0.9, 0.92), world.ROAD_W * sc)
		var c: Vector2 = to_map.call(Vector3(-g * world.CELL, 0, i * world.CELL))
		var d: Vector2 = to_map.call(Vector3(g * world.CELL, 0, i * world.CELL))
		minimap.draw_line(c, d, Color(0.9, 0.9, 0.92), world.ROAD_W * sc)
	# araçlar
	for car in get_tree().get_nodes_in_group("cars"):
		minimap.draw_circle(to_map.call((car as Node3D).global_position), 4, Color(0.3, 0.7, 1.0))
	# oyuncu oku
	var pts := PackedVector2Array([center + Vector2(0, -11), center + Vector2(8, 8), center + Vector2(0, 4), center + Vector2(-8, 8)])
	minimap.draw_colored_polygon(pts, Color.WHITE)
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.6), false, 3.0)
