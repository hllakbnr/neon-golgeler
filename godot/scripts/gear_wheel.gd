extends CanvasLayer
class_name GearWheel
## Silah ve eşya çarkı (GTA6'daki düzenden esinlenme): Tab basılı tutulur, arka plan bulanıklaşır ve
## zaman yavaşlar. Fare ya da sağ çubukla bir kutu seçilir, Tab bırakılınca kuşanılır.
##  • Q / E: SİLAHLAR ↔ EŞYALAR sekmesi
##  • Eşyalar: maske, güneş gözlüğü, şapka (aç/kapa) ve kıyafet askısı (sıradaki kıyafet)
##  • Sol altta sarf malzemeleri: 1 = ilk yardım çantası, 2 = enerji içeceği

var player: Player
var tab := 0
var sel := -1
var _dir := Vector2.ZERO
var _c: Control
var _t := 0.0
var _slots: Array = []


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var blur := ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 3.5).rgb;
	vec3 r = textureLod(screen, SCREEN_UV + vec2(0.004, 0.0), 3.5).rgb;
	vec3 b = textureLod(screen, SCREEN_UV - vec2(0.004, 0.0), 3.5).rgb;
	COLOR = vec4(vec3(r.r, c.g, b.b) * 0.55, 1.0);
}
"""
	sm.shader = sh
	blur.material = sm
	add_child(blur)
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw)
	add_child(_c)
	Game.set_slowmo(0.2)
	_build()
	Sfx.ui("click", -10.0)


func _build() -> void:
	_slots = []
	var cb := player.combat
	if tab == 0:
		for id in Weapons.ORDER:
			var w := Weapons.info(id)
			var owned := cb.owned.has(id)
			var sub := ""
			if String(w.kind) == "throw":
				sub = "%d" % int(cb.ammo.get(id, 0))
			_slots.append({"id": id, "label": String(w.name), "cat": "FIRLATMA" if String(w.kind) == "throw" else ("YAKIN DÖVÜŞ" if id != "yumruk" else "ÇIPLAK EL"), "sub": sub, "weapon": id, "on": owned})
		sel = Weapons.ORDER.find(cb.weapon)
	else:
		for acc in ["maske", "gozluk", "sapka"]:
			var on: bool = Game.accessories.get(acc, false)
			_slots.append({"id": acc, "label": {"maske": "Ninja Maskesi", "gozluk": "Güneş Gözlüğü", "sapka": "Şapka"}[acc], "cat": "AKSESUAR", "sub": "AÇIK" if on else "KAPALI", "on": true, "acc": acc})
		_slots.append({"id": "kiyafet", "label": "Kıyafet değiştir", "cat": "GARDIROP", "sub": String(Outfits.info(Game.outfit).name), "on": true})
		sel = 0


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_dir += e.relative
		if _dir.length() > 160.0:
			_dir = _dir.normalized() * 160.0
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.is_echo():
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_Q or k == KEY_E:
			tab = 1 - tab
			_dir = Vector2.ZERO
			_build()
			Sfx.ui("click", -12.0)
			get_viewport().set_input_as_handled()
		elif k == KEY_1 or k == KEY_2:
			_use(k == KEY_1)
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_finish()
		get_viewport().set_input_as_handled()


func _use(kit: bool) -> void:
	var key := "kit" if kit else "icecek"
	var n := int(Game.items.get(key, 0))
	if n <= 0:
		Sfx.ui("click", -4.0)
		return
	Game.items[key] = n - 1
	if kit:
		player.combat.heal(100.0)
	else:
		player.combat.boost = maxf(player.combat.boost, 45.0)
		player.combat.stamina = player.combat.max_stamina
	Sfx.ui("select", -6.0)


func _process(delta: float) -> void:
	_t += delta
	var j := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if j.length() > 0.4:
		_dir = j * 160.0
	if _dir.length() > 40.0 and _slots.size() > 0:
		var n := _slots.size()
		var a := fposmod(atan2(_dir.x, -_dir.y), TAU)
		var seg := TAU / n
		var ns := int(fposmod(a + seg * 0.5, TAU) / seg) % n
		if ns != sel:
			sel = ns
			Sfx.ui("click", -16.0)
	_c.queue_redraw()
	if not Input.is_action_pressed("weapon_wheel"):
		_finish()


func _finish() -> void:
	if is_queued_for_deletion():
		return
	Game.set_slowmo(1.0)
	if sel >= 0 and sel < _slots.size():
		var s: Dictionary = _slots[sel]
		if tab == 0:
			if s.on:
				player.combat.equip(String(s.id))
		elif s.has("acc"):
			var acc := String(s.acc)
			Game.accessories[acc] = not Game.accessories.get(acc, false)
			player.visual.set_accessories(Game.accessories)
			if Wanted.inst:
				Wanted.inst.description_changed("kıyafet")
		elif s.id == "kiyafet" and Game.owned_outfits.size() > 1:
			var i := Game.owned_outfits.find(Game.outfit)
			var nid := String(Game.owned_outfits[(i + 1) % Game.owned_outfits.size()])
			Outfits.apply(player, nid)
			if Wanted.inst:
				Wanted.inst.description_changed("kıyafet")
		Sfx.ui("select", -8.0)
	queue_free()


func _draw() -> void:
	var vs := _c.size
	var c := vs * 0.5 + Vector2(0, 10)
	var fd: Font = Game.font_display if Game.font_display else ThemeDB.fallback_font
	var fu: Font = Game.font_ui if Game.font_ui else fd
	var k := clampf(_t * 8.0, 0.0, 1.0)
	# sekmeler
	var tabs := ["SİLAHLAR", "EŞYALAR"]
	var tx := c.x - 130.0
	_chip(Vector2(tx - 50, 54), "Q")
	for i in 2:
		var on := i == tab
		var w := fd.get_string_size(tabs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		if on:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 0.9)
			sb.set_corner_radius_all(3)
			_c.draw_style_box(sb, Rect2(tx - 8, 48, w + 16, 38))
		_c.draw_string(fd, Vector2(tx, 79), tabs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.06, 0.06, 0.1) if on else Color(1, 1, 1, 0.8))
		tx += w + 34.0
	_chip(Vector2(tx - 10, 54), "E")
	# kutular çember üzerinde
	var n := _slots.size()
	var R := 230.0 * k
	for i in n:
		var s: Dictionary = _slots[i]
		var a := -PI * 0.5 + i * TAU / n
		var p := c + Vector2(cos(a), sin(a)) * R
		var on := i == sel
		var box := Rect2(p - Vector2(66, 48), Vector2(132, 96))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.22) if on else Color(0.1, 0.1, 0.14, 0.6)
		sb.set_border_width_all(3 if on else 1)
		sb.border_color = Color(1, 1, 1, 0.95) if on else Color(1, 1, 1, 0.12)
		_c.draw_style_box(sb, box)
		var ic := Color.WHITE if s.on else Color(1, 1, 1, 0.25)
		if s.has("weapon"):
			Weapons.draw_icon(_c, p + Vector2(0, -8), String(s.weapon), 30.0, ic)
		else:
			_item_icon(String(s.id), p + Vector2(0, -8), ic, bool(Game.accessories.get(String(s.id), false)))
		if String(s.sub) != "" or (s.has("weapon") and not s.on):
			var strip := Rect2(box.position + Vector2(0, box.size.y - 24), Vector2(box.size.x, 24))
			_c.draw_rect(strip, Color(0, 0, 0, 0.55))
			var txt := String(s.sub) if s.on else "YOK"
			_c.draw_string(fd, strip.position + Vector2(0, 19), txt.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, strip.size.x, 18, Color.WHITE)
		if on and s.has("weapon"):
			_c.draw_rect(Rect2(box.position + Vector2(10, box.size.y - 4), Vector2(box.size.x - 20, 3)), Color(0.3, 0.9, 0.9))
	# ortada seçilen
	if sel >= 0 and sel < n:
		var s2: Dictionary = _slots[sel]
		_c.draw_string(fd, c + Vector2(-160, -4), String(s2.label).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 320, 30, Color.WHITE)
		_c.draw_string(fu, c + Vector2(-160, 22), String(s2.cat), HORIZONTAL_ALIGNMENT_CENTER, 320, 15, Color(1, 1, 1, 0.65))
	# sol üst çubuklar ve sağ üst para
	var cb := player.combat
	_mini_bar(Vector2(40, 40), cb.health / 100.0, Color(1.0, 0.55, 0.65))
	_mini_bar(Vector2(40, 62), cb.armor / 100.0, Color(0.35, 0.9, 0.85))
	_mini_bar(Vector2(40, 84), cb.stamina / maxf(cb.max_stamina, 1.0), Color(0.6, 0.5, 1.0))
	_c.draw_string(fd, Vector2(vs.x - 300, 64), "₺%d" % Game.money, HORIZONTAL_ALIGNMENT_RIGHT, 250, 30, Color.WHITE)
	# sol alt: sarf malzemeleri
	var items := [["kit", "1", Color(0.9, 0.2, 0.25)], ["icecek", "2", Color(1.0, 0.6, 0.15)]]
	for i in items.size():
		var it: Array = items[i]
		var bx := Rect2(Vector2(40 + i * 90, vs.y - 150), Vector2(78, 92))
		var sb3 := StyleBoxFlat.new()
		sb3.bg_color = Color(0.1, 0.1, 0.14, 0.75)
		_c.draw_style_box(sb3, bx)
		var ip := bx.get_center() + Vector2(0, -12)
		if it[0] == "kit":
			_c.draw_rect(Rect2(ip - Vector2(14, 16), Vector2(28, 32)), it[2])
			_c.draw_rect(Rect2(ip - Vector2(3, 9), Vector2(6, 18)), Color.WHITE)
			_c.draw_rect(Rect2(ip - Vector2(9, 3), Vector2(18, 6)), Color.WHITE)
		else:
			_c.draw_rect(Rect2(ip - Vector2(8, 18), Vector2(16, 36)), it[2])
			_c.draw_rect(Rect2(ip - Vector2(8, 4), Vector2(16, 8)), Color(1, 1, 1, 0.85))
		_c.draw_string(fd, bx.position + Vector2(0, 86), "%d" % int(Game.items.get(it[0], 0)), HORIZONTAL_ALIGNMENT_CENTER, bx.size.x, 20, Color.WHITE)
		_chip(Vector2(bx.position.x + 22, bx.end.y + 8), String(it[1]))


func _chip(p: Vector2, k: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.15)
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.7)
	_c.draw_style_box(sb, Rect2(p, Vector2(32, 26)))
	_c.draw_string(Game.font_ui if Game.font_ui else ThemeDB.fallback_font, p + Vector2(0, 19), k, HORIZONTAL_ALIGNMENT_CENTER, 32, 15, Color.WHITE)


func _mini_bar(p: Vector2, v: float, col: Color) -> void:
	_c.draw_rect(Rect2(p, Vector2(150, 8)), Color(0, 0, 0, 0.5))
	_c.draw_rect(Rect2(p, Vector2(150 * clampf(v, 0.0, 1.0), 8)), col)


func _item_icon(id: String, c: Vector2, col: Color, on: bool) -> void:
	var cc := col if on else Color(col, 0.55)
	match id:
		"maske":
			_c.draw_circle(c, 22.0, Color(0.15, 0.15, 0.18))
			_c.draw_rect(Rect2(c + Vector2(-20, -6), Vector2(40, 9)), cc)
			_c.draw_rect(Rect2(c + Vector2(-12, -4), Vector2(8, 4)), Color(1, 1, 1, 0.9))
			_c.draw_rect(Rect2(c + Vector2(4, -4), Vector2(8, 4)), Color(1, 1, 1, 0.9))
		"gozluk":
			_c.draw_circle(c + Vector2(-13, 0), 10.0, cc)
			_c.draw_circle(c + Vector2(13, 0), 10.0, cc)
			_c.draw_line(c + Vector2(-4, -3), c + Vector2(4, -3), cc, 3.0)
		"sapka":
			_c.draw_arc(c + Vector2(0, 6), 18.0, PI, TAU, 16, cc, 12.0)
			_c.draw_rect(Rect2(c + Vector2(0, 2), Vector2(30, 6)), cc)
		"kiyafet":
			_c.draw_arc(c + Vector2(0, -14), 5.0, PI, TAU * 0.9, 8, cc, 3.0)
			_c.draw_polyline(PackedVector2Array([c + Vector2(0, -9), c + Vector2(-26, 10), c + Vector2(26, 10), c + Vector2(0, -9)]), cc, 3.0)
