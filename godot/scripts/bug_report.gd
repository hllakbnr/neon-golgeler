extends CanvasLayer
class_name BugReport
## F9: hata bildirimi. Oyun durur, kısa bir not yazılır (isteğe bağlı), Kaydet'e basılınca ekranın
## altına sürüm / konum / bölge / saat / araç / aranma bilgisi ve not basılarak ekran görüntüsü alınır.
## Dosya Belgeler/NeonGolgeler_Hatalar klasörüne kaydedilir ve klasör açılır: resmi sohbete atman yeterli.

var player: Player
var world: World
var _panel: PanelContainer
var _note: LineEdit
var _strip: Label
var _was_paused := false
var _mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.06, 0.92)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	sb.border_width_top = 4
	sb.border_color = Color(1, 0.3, 0.4)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_top = -110
	_panel.offset_bottom = 110
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	v.add_child(Game.styled_label("HATA BİLDİR", 32, Color(1, 0.45, 0.55), true))
	v.add_child(Game.styled_label("Ne oldu? (boş bırakabilirsin) — Enter: kaydet · Esc: vazgeç", 17, Color(1, 1, 1, 0.75)))
	_note = LineEdit.new()
	_note.placeholder_text = "Örn: arabaya çarpınca yaya duvarın içine girdi"
	_note.add_theme_font_size_override("font_size", 20)
	_note.custom_minimum_size = Vector2(700, 44)
	_note.text_submitted.connect(func(_t: String): _save())
	v.add_child(_note)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var b1 := Button.new()
	b1.text = "  Kaydet  "
	b1.add_theme_font_size_override("font_size", 20)
	b1.pressed.connect(_save)
	h.add_child(b1)
	var b2 := Button.new()
	b2.text = "  Vazgeç  "
	b2.add_theme_font_size_override("font_size", 20)
	b2.pressed.connect(_close)
	h.add_child(b2)
	_note.grab_focus()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _info() -> String:
	var p := player.global_position
	var parts := PackedStringArray()
	parts.append("Sürüm %d" % Game.version)
	parts.append("Konum (%.1f, %.1f, %.1f)" % [p.x, p.y, p.z])
	if world:
		var dn := world.district_name(p)
		if world.interiors and world.interiors.inside():
			dn = "İç mekân: " + String(world.interiors.current)
		parts.append(dn)
	parts.append("Saat " + Game.clock_text())
	if player.car:
		parts.append("Araçta: %s %.0f km/s" % [player.car.model, player.car.linear_velocity.length() * 3.6])
	if player.mount:
		parts.append("Ejderhada")
	if Wanted.inst and Wanted.inst.stars > 0:
		parts.append("Aranma %d★" % Wanted.inst.stars)
	parts.append("Silah: " + String(player.combat.weapon))
	parts.append("FPS %d" % Engine.get_frames_per_second())
	return " · ".join(parts)


func _save() -> void:
	var note := _note.text.strip_edges()
	_panel.visible = false
	_strip = Game.styled_label("HATA: " + (note if note != "" else "(not yok)") + "\n" + _info(), 20, Color.WHITE)
	_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_strip.anchor_top = 1.0
	_strip.anchor_bottom = 1.0
	_strip.anchor_right = 1.0
	_strip.offset_top = -86
	var bg := ColorRect.new()
	bg.color = Color(0.6, 0.05, 0.12, 0.85)
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.anchor_right = 1.0
	bg.offset_top = -92
	add_child(bg)
	_strip.offset_left = 16
	add_child(_strip)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("NeonGolgeler_Hatalar")
	DirAccess.make_dir_recursive_absolute(dir)
	var t := Time.get_datetime_dict_from_system()
	var name := "hata_%04d%02d%02d_%02d%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	var path := dir.path_join(name + ".png")
	img.save_png(path)
	var f := FileAccess.open(dir.path_join(name + ".txt"), FileAccess.WRITE)
	if f:
		f.store_string(note + "\n" + _info() + "\n")
	OS.shell_open(dir)
	Game.notify("Hata kaydedildi: Belgeler/NeonGolgeler_Hatalar/%s.png — resmi sohbete at." % name, 6.0)
	_close()


func _close() -> void:
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse
	queue_free()
