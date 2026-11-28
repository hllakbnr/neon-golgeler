extends Node3D
class_name Interiors
## Girilebilen iç mekânlar: dükkânlar, restoran, smoothie barı, kulüp, dojo, manastır salonu.
## Her mekân dünyadan uzakta (x ≥ 6000) ilk girişte kurulur; kapıdan girince ekran kararır,
## oyuncu içeri ışınlanır, güneş kapanır. Tezgâhta [E] ile alışveriş, kapıda [E] ile çıkış.

const ORIGIN := Vector3(6000, 0, 6000)
const STYLE := {
	"restoran": {"w": 16.0, "d": 18.0, "h": 4.6, "floor": Color(0.32, 0.2, 0.12), "wall": Color(0.55, 0.16, 0.12), "trim": Color(0.12, 0.07, 0.05), "light": Color(1.0, 0.7, 0.45), "neon": Color(1.0, 0.35, 0.2), "keeper": "yaya5", "title": "NODA ERİŞTE EVİ"},
	"smoothie": {"w": 12.0, "d": 12.0, "h": 4.0, "floor": Color(0.9, 0.85, 0.7), "wall": Color(0.2, 0.75, 0.7), "trim": Color(1.0, 0.85, 0.3), "light": Color(1.0, 0.95, 0.85), "neon": Color(1.0, 0.8, 0.1), "keeper": "yaya8", "title": "ANANAS SMOOTHIE"},
	"market": {"w": 18.0, "d": 22.0, "h": 4.4, "floor": Color(0.82, 0.82, 0.8), "wall": Color(0.9, 0.9, 0.88), "trim": Color(0.8, 0.1, 0.12), "light": Color(0.95, 1.0, 1.0), "neon": Color(1.0, 0.2, 0.2), "keeper": "yaya2", "title": "KIZIL FENER MARKET"},
	"silah": {"w": 14.0, "d": 16.0, "h": 4.4, "floor": Color(0.12, 0.12, 0.13), "wall": Color(0.18, 0.17, 0.19), "trim": Color(0.6, 0.08, 0.1), "light": Color(1.0, 0.85, 0.75), "neon": Color(1.0, 0.1, 0.2), "keeper": "yaya9", "title": "KILIÇ & YILDIZ"},
	"butik": {"w": 16.0, "d": 18.0, "h": 4.6, "floor": Color(0.85, 0.82, 0.86), "wall": Color(0.16, 0.12, 0.2), "trim": Color(0.85, 0.7, 0.35), "light": Color(1.0, 0.92, 0.95), "neon": Color(0.85, 0.3, 1.0), "keeper": "yaya6", "title": "GÖLGE BUTİK"},
	"kulup": {"w": 24.0, "d": 26.0, "h": 7.0, "floor": Color(0.05, 0.05, 0.08), "wall": Color(0.06, 0.04, 0.1), "trim": Color(0.3, 0.1, 0.5), "light": Color(0.6, 0.3, 1.0), "neon": Color(1.0, 0.15, 0.75), "keeper": "yaya4", "title": "NEON KULÜP"},
	"dojo": {"w": 22.0, "d": 24.0, "h": 6.0, "floor": Color(0.75, 0.68, 0.45), "wall": Color(0.85, 0.8, 0.68), "trim": Color(0.35, 0.18, 0.1), "light": Color(1.0, 0.9, 0.75), "neon": Color(1.0, 0.5, 0.1), "keeper": "yaya7", "title": "TURBO TARIK'IN DOJOSU"},
	"manastir": {"w": 22.0, "d": 28.0, "h": 8.0, "floor": Color(0.45, 0.28, 0.15), "wall": Color(0.65, 0.14, 0.1), "trim": Color(0.2, 0.1, 0.06), "light": Color(1.0, 0.75, 0.45), "neon": Color(1.0, 0.6, 0.2), "keeper": "yaya11", "title": "KASIRGA MANASTIRI"},
}

var world: World
var built := {}           # tür → {root, spawn, door, counter, yaw}
var current := ""
var current_door := {}
var _fade: ColorRect
var _busy := false
var _sun_vis := true
var _amb := 1.0


func _ready() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)


func inside() -> bool:
	return current != ""


# ---------------------------------------------------------------- giriş / çıkış
func prompt(p: Vector3, in_car: bool) -> String:
	if _busy:
		return ""
	if current != "":
		var b: Dictionary = built[current]
		if p.distance_to(b.door) < 1.8:
			return "[E] Dışarı çık"
		if p.distance_to(b.counter) < 2.6:
			return "[E] " + ("Antrenman / dersler" if current == "dojo" else ("Meditasyon" if current == "manastir" else "Alışveriş"))
		return ""
	var d := world.nearest_door(p, 7.0 if in_car else 2.6)
	if d.is_empty():
		return ""
	if String(d.interior) == "atolye":
		return "[E] Aracı boyat (₺150)" if in_car else ""
	if in_car:
		return ""
	return "[E] Gir: " + String(d.name)


func try_use(pl: Player) -> bool:
	if _busy:
		return false
	var p := pl.global_position
	if current != "":
		var b: Dictionary = built[current]
		if p.distance_to(b.door) < 1.8:
			_exit(pl)
			return true
		if p.distance_to(b.counter) < 2.6:
			_open_shop(pl)
			return true
		return false
	var d := world.nearest_door(p, 7.0 if pl.car else 2.6)
	if d.is_empty():
		return false
	if String(d.interior) == "atolye":
		if pl.car:
			_respray(pl)
			return true
		return false
	if pl.car:
		return false
	_enter(pl, d)
	return true


func _enter(pl: Player, d: Dictionary) -> void:
	var kind := String(d.interior)
	if not STYLE.has(kind):
		Game.notify("Burası şu an kapalı.")
		return
	if Wanted.inst and Wanted.inst.stars > 0 and Wanted.inst.seen:
		Game.notify("Polis peşindeyken içeri giremezsin!")
		return
	_busy = true
	await _fade_to(1.0)
	if not built.has(kind):
		_build(kind)
	current = kind
	current_door = d
	var b: Dictionary = built[kind]
	pl.global_position = b.spawn
	pl.velocity = Vector3.ZERO
	pl.visual.rotation.y = 0.0
	pl.yaw = PI
	pl.rig.global_position = pl.global_position + Vector3(0, 1.55, 0)
	_lights(false)
	(b.root as Node3D).visible = true
	if kind == "kulup" and Radio.inst:
		Radio.inst.set_club(true)
	await get_tree().create_timer(0.25).timeout
	await _fade_to(0.0)
	Game.notify(String(d.name), 2.0)
	_busy = false


func _exit(pl: Player) -> void:
	_busy = true
	await _fade_to(1.0)
	var d := current_door
	var yaw: float = float(d.get("yaw", 0.0))
	var out := Vector3(sin(yaw), 0, cos(yaw))
	var pos: Vector3 = d.pos
	pl.global_position = pos + out * 2.2 + Vector3(0, 0.3, 0)
	pl.velocity = Vector3.ZERO
	pl.visual.rotation.y = yaw
	pl.yaw = yaw + PI
	pl.rig.global_position = pl.global_position + Vector3(0, 1.55, 0)
	(built[current].root as Node3D).visible = false
	if current == "kulup" and Radio.inst:
		Radio.inst.set_club(false)
	current = ""
	_lights(true)
	await get_tree().create_timer(0.2).timeout
	await _fade_to(0.0)
	_busy = false


func _lights(on: bool) -> void:
	if world.sun:
		if not on:
			_sun_vis = world.sun.visible
		world.sun.visible = on and _sun_vis
	if world.moon:
		world.moon.visible = on
	if world.env:
		if not on:
			_amb = world.env.ambient_light_energy
			world.env.ambient_light_energy = 0.25
			world.env.volumetric_fog_enabled = false
		else:
			world.env.ambient_light_energy = _amb
			world.apply_quality()


func _fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, 0.35)
	await tw.finished


func _respray(pl: Player) -> void:
	if Game.money < 150:
		Game.notify("Boya için ₺150 gerekiyor.")
		return
	Game.money -= 150
	_busy = true
	await _fade_to(1.0)
	var c := Color.from_hsv(randf(), randf_range(0.5, 0.9), randf_range(0.45, 0.9))
	if pl.car and pl.car.has_method("repaint"):
		pl.car.repaint(c)
	if Wanted.inst and Wanted.inst.stars > 0 and not Wanted.inst.seen:
		Wanted.inst.clear("Araç boyandı — polis artık seni tanımıyor.")
	await get_tree().create_timer(0.6).timeout
	Sfx.ui("cash", -6.0)
	await _fade_to(0.0)
	Game.notify("Aracın yeni rengiyle hazır (-₺150).")
	_busy = false


func _open_shop(pl: Player) -> void:
	var ui := ShopUI.new()
	ui.kind = current
	ui.player = pl
	get_tree().current_scene.add_child(ui)


# ---------------------------------------------------------------- kurulum
func _build(kind: String) -> void:
	var st: Dictionary = STYLE[kind]
	var k := built.size()
	var root := Node3D.new()
	root.name = "ic_" + kind
	add_child(root)
	root.position = ORIGIN + Vector3(k * 120.0, 0, 0)
	var W: float = st.w
	var D: float = st.d
	var H: float = st.h
	var fl := Game.paint(st.floor, 0.0, 0.55)
	var wl := Game.paint(st.wall, 0.0, 0.8)
	var tr := Game.paint(st.trim, 0.2, 0.5)
	var body := StaticBody3D.new()
	root.add_child(body)
	# zemin, tavan, duvarlar
	_box(root, body, Vector3(0, -0.1, 0), Vector3(W, 0.2, D), fl)
	_box(root, body, Vector3(0, H + 0.1, 0), Vector3(W, 0.2, D), Game.paint(Color(st.wall).darkened(0.5), 0.0, 0.9))
	_box(root, body, Vector3(-W * 0.5, H * 0.5, 0), Vector3(0.3, H, D), wl)
	_box(root, body, Vector3(W * 0.5, H * 0.5, 0), Vector3(0.3, H, D), wl)
	_box(root, body, Vector3(0, H * 0.5, D * 0.5), Vector3(W, H, 0.3), wl)
	var sw := W * 0.5 - 0.9
	_box(root, body, Vector3(-(0.9 + sw * 0.5), H * 0.5, -D * 0.5), Vector3(sw + 0.02, H, 0.3), wl)
	_box(root, body, Vector3(0.9 + sw * 0.5, H * 0.5, -D * 0.5), Vector3(sw + 0.02, H, 0.3), wl)
	_box(root, body, Vector3(0, H * 0.5 + 1.3, -D * 0.5), Vector3(1.8, H - 2.6, 0.3), wl)
	# kapı (cam, ışıklı çerçeve)
	_box(root, null, Vector3(0, 1.3, -D * 0.5 - 0.02), Vector3(1.8, 2.6, 0.05), Game.emissive(Color(0.5, 0.7, 0.9), 0.6))
	_box(root, body, Vector3(0, 1.3, -D * 0.5 - 0.1), Vector3(1.8, 2.6, 0.1), null)
	_neon(root, Vector3(0, 2.75, -D * 0.5 + 0.2), Vector3(2.2, 0.06, 0.06), st.neon)
	# süpürgelik ve tavan şeridi
	for s in [-1.0, 1.0]:
		_box(root, null, Vector3(s * (W * 0.5 - 0.17), 0.15, 0), Vector3(0.05, 0.3, D), tr)
		_neon(root, Vector3(s * (W * 0.5 - 0.2), H - 0.15, 0), Vector3(0.05, 0.05, D - 0.6), st.neon)
	# ışıklar
	for i in range(2):
		for j in range(3):
			var l := OmniLight3D.new()
			l.light_color = st.light
			l.light_energy = 1.6
			l.omni_range = maxf(W, D) * 0.55
			l.shadow_enabled = i == 0 and j == 1
			l.position = Vector3((i - 0.5) * W * 0.5, H - 0.4, (j - 1) * D * 0.3)
			root.add_child(l)
			_box(root, null, l.position + Vector3(0, 0.3, 0), Vector3(0.8, 0.06, 0.8), Game.emissive(st.light, 2.0))
	# tezgâh (arka duvar önünde)
	var cz := D * 0.5 - 3.2
	_box(root, body, Vector3(0, 0.55, cz), Vector3(minf(W * 0.5, 7.0), 1.1, 0.9), tr)
	_box(root, null, Vector3(0, 1.12, cz), Vector3(minf(W * 0.5, 7.0) + 0.1, 0.06, 1.0), Game.paint(Color(0.9, 0.9, 0.92), 0.3, 0.2))
	_neon(root, Vector3(0, 0.3, cz - 0.47), Vector3(minf(W * 0.5, 7.0), 0.05, 0.05), st.neon)
	# arka duvarda ışıklı tabela (duvara asılı)
	_wall_sign(root, Vector3(0, H - 1.0, D * 0.5 - 0.17), String(st.title), st.neon)
	# tezgâhtar
	var keeper := CharacterVisual.new()
	root.add_child(keeper)
	keeper.setup(String(st.keeper), Game.slot_default_skin(String(st.keeper)))
	keeper.position = Vector3(0, 0, cz + 1.3)
	keeper.rotation.y = PI
	_decor(root, body, W, D, H, st, kind, cz)
	match kind:
		"restoran":
			_restaurant(root, body, W, D, tr)
		"smoothie":
			_smoothie(root, body, W, D, cz)
		"market":
			_market(root, body, W, D)
		"silah":
			_weapons(root, body, W, D)
		"butik":
			_boutique(root, body, W, D)
		"kulup":
			_club(root, body, W, D, H)
		"dojo":
			_dojo(root, body, W, D, keeper)
		"manastir":
			_temple(root, body, W, D, H)
	built[kind] = {"root": root, "spawn": root.position + Vector3(0, 0.2, -D * 0.5 + 1.6), "door": root.position + Vector3(0, 0.2, -D * 0.5 + 0.9),
		"counter": root.position + Vector3(0, 0.2, cz - 1.0)}


func _box(root: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = null
	if mat:
		mi = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.position = pos
		root.add_child(mi)
	if body:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		body.add_child(cs)
	return mi


func _neon(root: Node3D, pos: Vector3, size: Vector3, c: Color) -> void:
	_box(root, null, pos, size, Game.emissive(c, 4.0))


func _wall_sign(root: Node3D, pos: Vector3, text: String, c: Color) -> void:
	var w := clampf(text.length() * 0.42, 3.0, 9.0)
	_box(root, null, pos + Vector3(0, 0, -0.03), Vector3(w + 0.4, 1.1, 0.06), Game.paint(Color(0.05, 0.05, 0.07), 0.2, 0.5))
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = minf(0.009, (w - 0.2) / maxf(1.0, text.length() * 0.6 * 96.0))
	l.modulate = c
	l.outline_size = 0
	l.position = pos + Vector3(0, 0, -0.08)
	l.rotation.y = PI
	if Game.font_display:
		l.font = Game.font_display
	root.add_child(l)


func _table(root: Node3D, body: StaticBody3D, p: Vector3, wood: Material, chairs := 4) -> void:
	_box(root, body, p + Vector3(0, 0.75, 0), Vector3(1.3, 0.06, 1.3), wood)
	_box(root, body, p + Vector3(0, 0.37, 0), Vector3(0.12, 0.74, 0.12), wood)
	for k in chairs:
		var a := k * TAU / chairs
		var cp := p + Vector3(cos(a), 0, sin(a)) * 1.05
		_box(root, body, cp + Vector3(0, 0.45, 0), Vector3(0.45, 0.06, 0.45), wood)
		_box(root, null, cp + Vector3(0, 0.22, 0), Vector3(0.08, 0.44, 0.08), wood)


func _restaurant(root: Node3D, body: StaticBody3D, W: float, D: float, wood: Material) -> void:
	for i in range(2):
		for j in range(2):
			var p := Vector3((i - 0.5) * W * 0.5, 0, -D * 0.15 + j * 4.2)
			_table(root, body, p, wood)
			var bowl := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.18
			sm.bottom_radius = 0.1
			sm.height = 0.12
			bowl.mesh = sm
			bowl.material_override = Game.paint(Color(0.9, 0.85, 0.75), 0.0, 0.3)
			bowl.position = p + Vector3(0.2, 0.84, 0.1)
			root.add_child(bowl)
	# kağıt fenerler
	for k in range(6):
		var lp := Vector3((k % 3 - 1) * W * 0.3, 3.6, (k / 3 - 0.5) * 6.0)
		var lm := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.35
		sp.height = 0.8
		lm.mesh = sp
		lm.material_override = Game.emissive(Color(1.0, 0.25, 0.15), 1.6)
		lm.position = lp
		root.add_child(lm)


func _smoothie(root: Node3D, body: StaticBody3D, W: float, D: float, cz: float) -> void:
	var fruit := [Color(1.0, 0.85, 0.1), Color(1.0, 0.3, 0.3), Color(0.5, 0.9, 0.3), Color(1.0, 0.55, 0.1), Color(0.7, 0.3, 0.9)]
	for k in 5:
		var bl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.09
		cm.height = 0.38
		bl.mesh = cm
		bl.material_override = Game.paint(fruit[k], 0.0, 0.2)
		bl.position = Vector3(-2.0 + k, 1.35, cz)
		root.add_child(bl)
	for k in 6:
		var p := Vector3(-W * 0.5 + 1.0, 0.25, -D * 0.3 + k * 1.0)
		_box(root, body, p, Vector3(0.8, 0.5, 0.8), Game.paint(Color(0.6, 0.45, 0.25), 0.0, 0.8))
		for f in 4:
			var fm := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.12
			sp.height = 0.24
			fm.mesh = sp
			fm.material_override = Game.paint(fruit[(k + f) % 5], 0.0, 0.4)
			fm.position = p + Vector3((f % 2 - 0.5) * 0.3, 0.32, (f / 2 - 0.5) * 0.3)
			root.add_child(fm)
	# bar tabureleri
	for k in 4:
		var sp := Vector3(-1.8 + k * 1.2, 0, cz - 1.0)
		_box(root, body, sp + Vector3(0, 0.75, 0), Vector3(0.45, 0.08, 0.45), Game.paint(Color(1.0, 0.85, 0.3), 0.3, 0.3))
		_box(root, null, sp + Vector3(0, 0.37, 0), Vector3(0.08, 0.74, 0.08), Game.paint(Color(0.8, 0.8, 0.82), 0.9, 0.2))


func _market(root: Node3D, body: StaticBody3D, W: float, D: float) -> void:
	var shelf := Game.paint(Color(0.85, 0.85, 0.87), 0.6, 0.35)
	var cols := [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.8, 0.2), Color(0.3, 0.8, 0.4), Color(0.9, 0.5, 0.1), Color(0.7, 0.3, 0.8)]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.3, 0.18)
	mm.mesh = bm
	var xf := []
	for row in range(3):
		var x := (row - 1) * 4.0
		_box(root, body, Vector3(x, 0.9, -1.0), Vector3(1.0, 1.8, 7.0), shelf)
		for lvl in range(3):
			for side in [-1.0, 1.0]:
				for s in range(26):
					xf.append([Transform3D(Basis(), Vector3(x + side * 0.38, 0.35 + lvl * 0.55, -4.2 + s * 0.25)), cols[(row * 7 + lvl * 3 + s / 3) % cols.size()]])
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i][0])
		mm.set_instance_color(i, xf[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.5
	mmi.material_override = m
	root.add_child(mmi)
	# ışıklı dolaplar
	for k in range(4):
		var p := Vector3(W * 0.5 - 0.6, 1.1, -D * 0.3 + k * 2.2)
		_box(root, body, p, Vector3(0.9, 2.2, 2.0), Game.paint(Color(0.2, 0.2, 0.22), 0.5, 0.4))
		_box(root, null, p + Vector3(-0.46, 0, 0), Vector3(0.02, 2.0, 1.8), Game.emissive(Color(0.75, 0.9, 1.0), 1.2))


func _weapons(root: Node3D, body: StaticBody3D, W: float, D: float) -> void:
	var board := Game.paint(Color(0.25, 0.12, 0.08), 0.0, 0.8)
	for s in [-1.0, 1.0]:
		_box(root, null, Vector3(s * (W * 0.5 - 0.2), 2.2, 0), Vector3(0.06, 2.4, D * 0.7), board)
		var ids := ["katana", "sopa", "boru", "nuncaku", "zincir", "sok", "katana", "sopa"]
		for k in ids.size():
			var wm := Weapons.mesh(ids[k])
			wm.position = Vector3(s * (W * 0.5 - 0.3), 2.2, -D * 0.3 + k * (D * 0.6 / ids.size()))
			wm.rotation = Vector3(0, 0, PI * 0.5)
			wm.rotation.y = s * PI * 0.5
			root.add_child(wm)
	# vitrin masası: shurikenler
	_box(root, body, Vector3(0, 0.5, -1.5), Vector3(3.0, 1.0, 1.2), Game.paint(Color(0.15, 0.15, 0.17), 0.4, 0.4))
	_box(root, null, Vector3(0, 1.02, -1.5), Vector3(3.0, 0.04, 1.2), Game.emissive(Color(0.6, 0.1, 0.15), 0.6))
	for k in 6:
		var sh := Weapons.mesh("shuriken")
		sh.position = Vector3(-1.2 + k * 0.48, 1.06, -1.5)
		root.add_child(sh)


func _boutique(root: Node3D, body: StaticBody3D, W: float, D: float) -> void:
	var cols := [Color(0.85, 0.15, 0.1), Color(0.15, 0.35, 0.9), Color(0.92, 0.92, 0.95), Color(0.1, 0.1, 0.12), Color(0.2, 0.75, 0.35), Color(0.95, 0.6, 0.1)]
	for r in 2:
		var x := (r - 0.5) * W * 0.5
		_box(root, null, Vector3(x, 1.7, -1.0), Vector3(0.05, 0.05, 5.0), Game.paint(Color(0.8, 0.7, 0.4), 1.0, 0.25))
		for k in 10:
			var c: Color = cols[(k + r * 3) % cols.size()]
			_box(root, null, Vector3(x, 1.2, -3.2 + k * 0.48), Vector3(0.5, 0.85, 0.06), Game.paint(c, 0.0, 0.7))
	# aynalar
	for s in [-1.0, 1.0]:
		var mr := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 2.6, 1.6)
		mr.mesh = bm
		mr.material_override = Game.paint(Color(0.85, 0.9, 0.95), 1.0, 0.02)
		mr.position = Vector3(s * (W * 0.5 - 0.2), 1.6, D * 0.2)
		root.add_child(mr)


func _club(root: Node3D, body: StaticBody3D, W: float, D: float, H: float) -> void:
	# ışıklı dans pisti
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(1.15, 0.04, 1.15)
	tiles.mesh = bm
	tiles.instance_count = 64
	var neon := [Color(1, 0.15, 0.75), Color(0.1, 0.9, 1.0), Color(0.6, 0.2, 1.0), Color(1.0, 0.6, 0.1)]
	for i in 8:
		for j in 8:
			var n := i * 8 + j
			tiles.set_instance_transform(n, Transform3D(Basis(), Vector3(-4.2 + i * 1.2, 0.02, -5.0 + j * 1.2)))
			tiles.set_instance_color(n, neon[(i + j) % 4])
	var tmi := MultiMeshInstance3D.new()
	tmi.multimesh = tiles
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.emission_enabled = true
	tm.emission_energy_multiplier = 1.5
	tmi.material_override = tm
	root.add_child(tmi)
	var anim_t := Timer.new()
	anim_t.wait_time = 0.45
	anim_t.autostart = true
	root.add_child(anim_t)
	anim_t.timeout.connect(func():
		for n in 64:
			tiles.set_instance_color(n, neon[randi() % 4] * randf_range(0.3, 1.0)))
	# renkli ortam ışıkları (kulüp karanlık ama görünür olsun)
	for k in 6:
		var ol := OmniLight3D.new()
		ol.light_color = neon[k % 4]
		ol.light_energy = 2.2
		ol.omni_range = 9.0
		ol.position = Vector3((k % 3 - 1) * W * 0.32, H - 1.5, (k / 3 - 0.5) * D * 0.45)
		root.add_child(ol)
	# DJ kabini
	_box(root, body, Vector3(0, 0.6, D * 0.5 - 6.5), Vector3(4.0, 1.2, 1.4), Game.paint(Color(0.1, 0.1, 0.12), 0.6, 0.3))
	_neon(root, Vector3(0, 1.22, D * 0.5 - 7.21), Vector3(4.0, 0.06, 0.04), Color(0.1, 0.9, 1.0))
	# hareketli spot ışıklar
	for k in 6:
		var sp := SpotLight3D.new()
		sp.light_color = neon[k % 4]
		sp.light_energy = 8.0
		sp.spot_range = 14.0
		sp.spot_angle = 18.0
		sp.position = Vector3(-5.0 + k * 2.0, H - 0.3, -1.0)
		sp.rotation.x = -PI * 0.5
		root.add_child(sp)
		var tw := sp.create_tween().set_loops()
		tw.tween_property(sp, "rotation:z", 0.5, 1.2 + k * 0.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(sp, "rotation:z", -0.5, 1.2 + k * 0.2).set_trans(Tween.TRANS_SINE)
	# dans edenler
	for k in 8:
		var dv := CharacterVisual.new()
		root.add_child(dv)
		var slot := "yaya%d" % (1 + (k * 5) % 12)
		dv.setup(slot, Game.slot_default_skin(slot))
		dv.position = Vector3(-3.5 + (k % 4) * 2.3 + randf_range(-0.3, 0.3), 0.04, -4.0 + (k / 4) * 2.6)
		dv.rotation.y = randf() * TAU
		dv.play("dance", 0.0, randf_range(0.9, 1.1))
	# bar
	_box(root, body, Vector3(-W * 0.5 + 1.2, 0.55, 2.0), Vector3(1.0, 1.1, 8.0), Game.paint(Color(0.15, 0.08, 0.2), 0.3, 0.3))
	_neon(root, Vector3(-W * 0.5 + 1.72, 1.0, 2.0), Vector3(0.04, 0.06, 8.0), Color(1, 0.15, 0.75))


func _dojo(root: Node3D, body: StaticBody3D, W: float, D: float, keeper: CharacterVisual) -> void:
	var mat := Game.paint(Color(0.55, 0.7, 0.4), 0.0, 0.9)
	for i in 4:
		for j in 4:
			_box(root, null, Vector3(-5.4 + i * 3.6, 0.02, -6.0 + j * 2.0), Vector3(3.5, 0.05, 1.9), mat)
	# antrenman mankenleri (vurulabilir)
	for k in 3:
		var dm := Dummy.new()
		root.add_child(dm)
		dm.position = Vector3(-4.0 + k * 4.0, 0, -2.0)
	# silah rafları
	var wood := Game.paint(Color(0.4, 0.22, 0.12), 0.0, 0.7)
	for s in [-1.0, 1.0]:
		_box(root, body, Vector3(s * (W * 0.5 - 0.5), 1.0, 2.0), Vector3(0.4, 2.0, 4.0), wood)
		for k in 4:
			var wm := Weapons.mesh("sopa" if k % 2 == 0 else "katana")
			wm.position = Vector3(s * (W * 0.5 - 0.75), 1.0, 0.6 + k * 0.9)
			wm.rotation.x = -PI * 0.5
			root.add_child(wm)
	keeper.play("fold_arms", 0.0)


func _temple(root: Node3D, body: StaticBody3D, W: float, D: float, H: float) -> void:
	var col := Game.paint(Color(0.6, 0.1, 0.08), 0.0, 0.6)
	for s in [-1.0, 1.0]:
		for k in 5:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.32
			cm.bottom_radius = 0.36
			cm.height = H
			mi.mesh = cm
			mi.material_override = col
			mi.position = Vector3(s * W * 0.32, H * 0.5, -D * 0.35 + k * D * 0.16)
			root.add_child(mi)
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 0.36
			sh.height = H
			cs.shape = sh
			cs.position = mi.position
			body.add_child(cs)
	# sunak ve dört element taşı
	var el := [Color(1.0, 0.35, 0.1), Color(0.3, 0.6, 1.0), Color(0.55, 0.4, 0.25), Color(0.75, 0.95, 1.0)]
	for k in 4:
		var p := Vector3(-3.0 + k * 2.0, 0, D * 0.5 - 6.0)
		_box(root, body, p + Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.9), Game.paint(Color(0.3, 0.28, 0.26), 0.0, 0.9))
		var gem := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.28
		sp.height = 0.56
		gem.mesh = sp
		gem.material_override = Game.emissive(el[k], 3.0)
		gem.position = p + Vector3(0, 1.35, 0)
		root.add_child(gem)
		var l := OmniLight3D.new()
		l.light_color = el[k]
		l.light_energy = 1.2
		l.omni_range = 4.0
		l.position = gem.position
		root.add_child(l)
	# meditasyon minderleri
	for k in 6:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.4
		cm.bottom_radius = 0.42
		cm.height = 0.12
		mi.mesh = cm
		mi.material_override = Game.paint(Color(0.85, 0.65, 0.2), 0.0, 0.8)
		mi.position = Vector3(-3.0 + (k % 3) * 3.0, 0.06, -2.0 + (k / 3) * 3.0)
		root.add_child(mi)



func _decor(root: Node3D, body: StaticBody3D, W: float, D: float, H: float, st: Dictionary, kind: String, cz: float) -> void:
	## her mekâna ortak süsleme: saksı bitkileri, duvar tabloları, raflar, kasa, menü panosu, halı, saat, hoparlör
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var neon: Color = st.neon
	var pot := Game.paint(Color(0.55, 0.32, 0.2), 0.0, 0.8)
	var leaf := Game.paint(Color(0.18, 0.5, 0.22), 0.0, 0.7)
	# köşelerde saksı bitkileri
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			if kind == "dojo" and sz > 0:
				continue
			var p := Vector3(sx * (W * 0.5 - 0.8), 0, sz * (D * 0.5 - 0.8))
			if sz < 0 and absf(p.x) < 2.0:
				continue
			_box(root, body, p + Vector3(0, 0.3, 0), Vector3(0.55, 0.6, 0.55), pot)
			for k in 5:
				var lf := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.28
				sp.height = 0.9
				lf.mesh = sp
				lf.material_override = leaf
				lf.position = p + Vector3(rng.randf_range(-0.2, 0.2), 0.95 + k * 0.12, rng.randf_range(-0.2, 0.2))
				lf.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
				root.add_child(lf)
	# yan duvarlarda çerçeveli tablolar / afişler
	var art := [Color(0.9, 0.3, 0.4), Color(0.2, 0.6, 0.9), Color(1.0, 0.75, 0.2), Color(0.4, 0.85, 0.5), neon]
	for sx in [-1.0, 1.0]:
		for k in 3:
			var z := -D * 0.3 + k * D * 0.25
			var fp := Vector3(sx * (W * 0.5 - 0.17), 2.1, z)
			_box(root, null, fp, Vector3(0.05, 1.1, 0.9), Game.paint(Color(0.12, 0.1, 0.08), 0.2, 0.6))
			var a: Color = art[(k + (1 if sx > 0 else 0)) % art.size()]
			_box(root, null, fp + Vector3(-sx * 0.03, 0, 0), Vector3(0.03, 0.95, 0.75), Game.paint(a, 0.0, 0.5))
			_box(root, null, fp + Vector3(-sx * 0.04, rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)), Vector3(0.02, 0.3, 0.3), Game.paint(a.lightened(0.4), 0.0, 0.5))
	# arka duvarda raflar ve şişeler / kutular
	var shelf := Game.paint(Color(0.3, 0.2, 0.12), 0.0, 0.7)
	for lvl in 3:
		var y := 1.5 + lvl * 0.55
		for sx in [-1.0, 1.0]:
			var sp2 := Vector3(sx * W * 0.28, y, D * 0.5 - 0.35)
			_box(root, null, sp2, Vector3(2.4, 0.05, 0.35), shelf)
			for k in 7:
				var bc := Color.from_hsv(rng.randf(), 0.6, 0.85)
				var bh := rng.randf_range(0.15, 0.35)
				_box(root, null, sp2 + Vector3(-1.0 + k * 0.33, 0.03 + bh * 0.5, 0), Vector3(0.12, bh, 0.12), Game.paint(bc, 0.2, 0.3))
	# kasa ve menü panosu
	_box(root, null, Vector3(1.6, 1.3, cz), Vector3(0.45, 0.3, 0.35), Game.paint(Color(0.15, 0.15, 0.17), 0.6, 0.3))
	_box(root, null, Vector3(1.6, 1.5, cz - 0.1), Vector3(0.35, 0.18, 0.02), Game.emissive(Color(0.3, 1.0, 0.6), 1.5))
	if kind in ["restoran", "smoothie", "kulup"]:
		var mb := Vector3(-W * 0.28, H - 1.0, D * 0.5 - 0.2)
		_box(root, null, mb, Vector3(3.0, 1.2, 0.05), Game.paint(Color(0.05, 0.05, 0.06), 0.0, 0.6))
		for k in 5:
			_box(root, null, mb + Vector3(-0.6, 0.4 - k * 0.2, -0.04), Vector3(1.4, 0.05, 0.01), Game.emissive(Color(1, 1, 1), 0.9))
			_box(root, null, mb + Vector3(1.0, 0.4 - k * 0.2, -0.04), Vector3(0.4, 0.05, 0.01), Game.emissive(neon, 1.2))
	# ortada halı
	if kind != "dojo" and kind != "kulup":
		_box(root, null, Vector3(0, 0.012, -D * 0.1), Vector3(W * 0.45, 0.02, D * 0.3), Game.paint(neon.darkened(0.55), 0.0, 0.95))
		_box(root, null, Vector3(0, 0.016, -D * 0.1), Vector3(W * 0.4, 0.02, D * 0.25), Game.paint(neon.darkened(0.35), 0.0, 0.95))
	# duvar saati ve hoparlörler
	var clk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 0.06
	clk.mesh = cyl
	clk.material_override = Game.paint(Color(0.95, 0.95, 0.92), 0.0, 0.4)
	clk.rotation.x = PI * 0.5
	clk.position = Vector3(W * 0.3, H - 0.8, -D * 0.5 + 0.2)
	root.add_child(clk)
	for sx in [-1.0, 1.0]:
		_box(root, null, Vector3(sx * (W * 0.5 - 0.35), H - 0.6, D * 0.5 - 0.35), Vector3(0.35, 0.5, 0.3), Game.paint(Color(0.08, 0.08, 0.09), 0.3, 0.5))
	# tavandan sarkan lambalar
	for k in 4:
		var lp := Vector3((k % 2 - 0.5) * W * 0.4, H - 0.9, (k / 2 - 0.5) * D * 0.35)
		_box(root, null, lp + Vector3(0, 0.45, 0), Vector3(0.02, 0.9, 0.02), Game.paint(Color(0.1, 0.1, 0.1), 0.5, 0.5))
		var sh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.38
		cm.height = 0.3
		sh.mesh = cm
		sh.material_override = Game.paint(neon.darkened(0.3), 0.4, 0.4)
		sh.position = lp
		root.add_child(sh)
		_box(root, null, lp - Vector3(0, 0.16, 0), Vector3(0.2, 0.05, 0.2), Game.emissive(st.light, 3.0))
