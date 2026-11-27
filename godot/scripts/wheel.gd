extends CanvasLayer
class_name RadialWheel
## GTA tarzı daire menü (silah çarkı / radyo çarkı): tuş basılı tutulurken açık kalır,
## fare ya da sağ çubukla dilim seçilir, tuş bırakılınca seçim yapılır. Açıkken zaman yavaşlar.

signal chosen(id: String)
signal hovered(id: String)

var items: Array = []           # [{id, label, icon, sub, col}]
var sel := -1
var title := ""
var action := "weapon_wheel"
var slowmo := 0.25
var _dir := Vector2.ZERO
var _c: Control
var _t := 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw)
	add_child(_c)
	if slowmo < 1.0:
		Game.set_slowmo(slowmo)
	Sfx.ui("click", -10.0)


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_dir += e.relative
		if _dir.length() > 140.0:
			_dir = _dir.normalized() * 140.0
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT):
		_finish()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	var j := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if j.length() > 0.4:
		_dir = j * 140.0
	if _dir.length() > 30.0 and items.size() > 0:
		var a := fposmod(atan2(_dir.x, -_dir.y), TAU)
		var seg := TAU / items.size()
		var ns := int(fposmod(a + seg * 0.5, TAU) / seg) % items.size()
		if ns != sel:
			sel = ns
			Sfx.ui("click", -14.0)
			hovered.emit(String(items[sel].id))
	_c.queue_redraw()
	if not Input.is_action_pressed(action):
		_finish()


func _finish() -> void:
	if is_queued_for_deletion():
		return
	if slowmo < 1.0:
		Game.set_slowmo(1.0)
	if sel >= 0 and sel < items.size():
		Sfx.ui("select", -8.0)
		chosen.emit(String(items[sel].id))
	queue_free()


func _draw() -> void:
	var c := _c.size * 0.5
	var n := maxi(1, items.size())
	var R := 250.0
	var r0 := 95.0
	var k := clampf(_t * 6.0, 0.0, 1.0)
	_c.draw_circle(c, R + 14.0, Color(0, 0, 0, 0.55 * k))
	var seg := TAU / n
	for i in n:
		var a0 := -PI * 0.5 + (i - 0.5) * seg + 0.02
		var a1 := a0 + seg - 0.04
		var pts := PackedVector2Array()
		for s in 13:
			var a := lerpf(a0, a1, s / 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * R * k)
		for s in 13:
			var a := lerpf(a1, a0, s / 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r0 * k)
		var it: Dictionary = items[i]
		var col: Color = it.get("col", Color(0.35, 0.8, 1.0))
		var on := i == sel
		_c.draw_colored_polygon(pts, Color(col, 0.55) if on else Color(0.08, 0.08, 0.12, 0.78))
		var mid := -PI * 0.5 + i * seg
		var ip := c + Vector2(cos(mid), sin(mid)) * (r0 + R) * 0.5 * k
		var f: Font = Game.font_display if Game.font_display else ThemeDB.fallback_font
		var icon := String(it.get("icon", ""))
		var ic := Color.WHITE if on else Color(1, 1, 1, 0.75)
		if it.has("weapon"):
			Weapons.draw_icon(_c, ip + Vector2(0, -12), String(it.weapon), 26.0, ic)
		else:
			_c.draw_string(f, ip + Vector2(-60, -2), icon, HORIZONTAL_ALIGNMENT_CENTER, 120, 32, ic)
		var lab := String(it.get("short", it.get("label", "")))
		_c.draw_string(Game.font_ui if Game.font_ui else f, ip + Vector2(-70, 26), lab, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color(1, 1, 1, 0.9 if on else 0.6))
	# ortadaki açıklama
	var f2: Font = Game.font_display if Game.font_display else ThemeDB.fallback_font
	_c.draw_string(f2, c + Vector2(-90, -36), title, HORIZONTAL_ALIGNMENT_CENTER, 180, 22, Color(1, 1, 1, 0.6))
	if sel >= 0:
		var it2: Dictionary = items[sel]
		_c.draw_string(f2, c + Vector2(-90, 4), String(it2.get("label", "")), HORIZONTAL_ALIGNMENT_CENTER, 180, 26, Color.WHITE)
		_c.draw_string(Game.font_ui if Game.font_ui else f2, c + Vector2(-90, 30), String(it2.get("sub", "")), HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color(1, 1, 1, 0.7))
