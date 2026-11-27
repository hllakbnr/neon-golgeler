extends CanvasLayer
class_name AdminPanel
## Gizli yönetici bölümü (menüde F10, PIN korumalı).
## Her karakter yuvası (Kaan, Ela, polis, yayalar) için:
##  • 3B model yükle (.glb/.gltf) → otomatik olarak oyunun iskeletine bağlanır ve
##    tüm animasyonları oynar (parçalı, iskeletli veya tek parça modeller)
##  • kostüm dokusu yükle (.png, bloklu karakter şablonu)
##  • şablonu kaydet (kendi kostümünü boyamak için) · varsayılana dön
## Önizlemede model döner, animasyon düğmeleriyle test edilir.

var slot_ids: Array = []
var list: ItemList
var preview: CharacterVisual
var vp: SubViewport
var info: Label
var mode_l: Label
var pin_box: Control
var main: Control
var dlg: FileDialog
var _pending := ""          # "glb" | "png" | "save"
var _spin := 0.0
var _cur := "kaan"
var skip_pin := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	slot_ids = Game.SLOTS.keys()
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if skip_pin or Game.shots_dir != "":
		_build_main()
	else:
		_build_pin()


func _btn(text: String, cb: Callable, w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	if w > 0:
		b.custom_minimum_size = Vector2(w, 42)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(1, 1, 1, 0.08)
	n.set_corner_radius_all(4)
	n.content_margin_left = 12
	n.content_margin_right = 12
	var h := StyleBoxFlat.new()
	h.bg_color = Color(1, 0.4, 0.8, 0.85)
	h.set_corner_radius_all(4)
	h.content_margin_left = 12
	h.content_margin_right = 12
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- PIN
func _build_pin() -> void:
	pin_box = VBoxContainer.new()
	pin_box.set_anchors_preset(Control.PRESET_CENTER)
	pin_box.offset_left = -220
	pin_box.offset_right = 220
	pin_box.offset_top = -120
	pin_box.add_theme_constant_override("separation", 14)
	add_child(pin_box)
	var first: bool = String(Game.admin.get("pin", "")) == ""
	pin_box.add_child(Game.styled_label("YÖNETİCİ", 48, Color(1, 0.45, 0.85), true))
	var msg := Game.styled_label("İlk giriş: kendine bir PIN belirle (en az 4 hane)." if first else "PIN gir:", 20)
	pin_box.add_child(msg)
	var le := LineEdit.new()
	le.secret = true
	le.custom_minimum_size = Vector2(440, 48)
	le.add_theme_font_size_override("font_size", 24)
	pin_box.add_child(le)
	le.grab_focus.call_deferred()
	var go := func():
		var t := le.text.strip_edges()
		if first:
			if t.length() < 4:
				msg.text = "PIN en az 4 haneli olmalı."
				return
			Game.admin.pin = t.sha256_text()
			Game.save_admin()
		elif t.sha256_text() != String(Game.admin.pin):
			msg.text = "PIN yanlış."
			le.text = ""
			return
		pin_box.queue_free()
		_build_main()
	le.text_submitted.connect(func(_t): go.call())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pin_box.add_child(row)
	row.add_child(_btn("Giriş", go, 200))
	row.add_child(_btn("Kapat", func(): queue_free(), 200))


# ---------------------------------------------------------------- ana ekran
func _build_main() -> void:
	main = Control.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	var title := Game.styled_label("YÖNETİCİ · KARAKTER MODELLERİ", 40, Color(1, 0.45, 0.85), true)
	title.position = Vector2(48, 28)
	main.add_child(title)
	var sub := Game.styled_label("Bir yuva seç → model ya da kostüm yükle. Yüklenen modeller otomatik olarak iskelete bağlanır ve oyundaki tüm animasyonları kullanır.", 17, Color(1, 1, 1, 0.75))
	sub.position = Vector2(50, 82)
	main.add_child(sub)
	list = ItemList.new()
	list.position = Vector2(48, 130)
	list.size = Vector2(300, 820)
	list.add_theme_font_size_override("font_size", 20)
	for id in slot_ids:
		list.add_item(Game.SLOTS[id][0])
	list.item_selected.connect(func(i): _select(slot_ids[i]))
	main.add_child(list)
	# önizleme
	var svc := SubViewportContainer.new()
	svc.position = Vector2(380, 130)
	svc.size = Vector2(760, 820)
	svc.stretch = true
	main.add_child(svc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	svc.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.08, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.55, 0.75)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2, 2.5, -2)
	rim.light_color = Color(1, 0.3, 0.8)
	rim.light_energy = 3.0
	rim.omni_range = 6
	vp.add_child(rim)
	var floor_m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.3
	cyl.bottom_radius = 1.4
	cyl.height = 0.12
	floor_m.mesh = cyl
	floor_m.position.y = -0.06
	floor_m.material_override = Game.paint(Color(0.2, 0.18, 0.26), 0.6, 0.3)
	vp.add_child(floor_m)
	var cam := Camera3D.new()
	cam.fov = 40
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.4, 4.6), Vector3(0, 0.95, 0), Vector3.UP)
	preview = CharacterVisual.new()
	vp.add_child(preview)
	# animasyon düğmeleri
	var anims := HBoxContainer.new()
	anims.position = Vector2(390, 900)
	anims.add_theme_constant_override("separation", 6)
	main.add_child(anims)
	for a in [["Dur", "idle"], ["Yürü", "walk"], ["Koş", "sprint"], ["Sür", "drive"], ["Yumruk", "attack-melee-right"], ["Tekme", "attack-kick-right"], ["Düş", "die"], ["Selam", "emote-yes"]]:
		var an: String = a[1]
		anims.add_child(_btn(a[0], func(): preview.play_once(an, 0.15)))
	# sağ panel
	var side := VBoxContainer.new()
	side.position = Vector2(1170, 130)
	side.custom_minimum_size = Vector2(700, 0)
	side.add_theme_constant_override("separation", 12)
	main.add_child(side)
	info = Game.styled_label("", 20)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(700, 0)
	side.add_child(info)
	mode_l = Game.styled_label("", 18, Color(0.6, 1, 0.8))
	mode_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	mode_l.custom_minimum_size = Vector2(700, 0)
	side.add_child(mode_l)
	side.add_child(_btn("3B model yükle (.glb / .gltf)", func(): _open("glb"), 420))
	side.add_child(_btn("Kostüm dokusu yükle (.png)", func(): _open("png"), 420))
	side.add_child(_btn("Kostüm şablonunu kaydet (boyamak için)", func(): _open("save"), 420))
	side.add_child(_btn("Varsayılana dön", _reset, 420))
	side.add_child(_btn("Kapat", func(): queue_free(), 420))
	var help := Game.styled_label("İpuçları:\n• İskeletli insansı modeller (ör. Mixamo'dan .glb) en iyi sonucu verir.\n• Parça adları head / torso / arm-left / arm-right / leg-left / leg-right olan modeller doğrudan takılır.\n• Tek parça modeller boy oranlarına göre otomatik bölünür.\n• Model +Z yönüne bakmalı (glTF standardı).", 16, Color(1, 1, 1, 0.65))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.custom_minimum_size = Vector2(700, 0)
	side.add_child(help)
	dlg = FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.size = Vector2i(1000, 640)
	dlg.file_selected.connect(_on_file)
	add_child(dlg)
	list.select(0)
	_select(slot_ids[0])


func _select(id: String) -> void:
	_cur = id
	preview.setup(id, Game.slot_default_skin(id))
	var cfg := Game.slot_cfg(id)
	var src := "Varsayılan kostüm (%s)" % Game.slot_default_skin(id)
	if cfg.get("type", "") == "glb":
		src = "Özel model: " + String(cfg.path).get_file()
	elif cfg.get("type", "") == "skin":
		src = "Özel kostüm: " + String(cfg.path).get_file()
	info.text = "%s\nKaynak: %s" % [Game.SLOTS[id][0], src]
	var m := {"blocky": "Bloklu karakter + kostüm", "parts": "Parça adlarıyla bağlandı", "skinned": "İskelet algılandı → kemikler oyunun iskeletine bağlandı", "split": "İskelet yok → model otomatik parçalara bölündü", "fallback": "Model bulunamadı (yedek gövde)"}
	mode_l.text = "Bağlantı: " + String(m.get(preview.mode, preview.mode))
	preview.play("walk")


func _open(kind: String) -> void:
	_pending = kind
	if kind == "glb":
		dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dlg.filters = PackedStringArray(["*.glb, *.gltf ; 3B model"])
	elif kind == "png":
		dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dlg.filters = PackedStringArray(["*.png ; Kostüm dokusu"])
	else:
		dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dlg.filters = PackedStringArray(["*.png ; PNG"])
		dlg.current_file = "kostum_sablonu.png"
	dlg.popup_centered()


func _on_file(path: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://admin/files")
	if _pending == "save":
		var tex := Game.load_texture(Game.slot_default_skin(_cur))
		if tex:
			tex.get_image().save_png(path)
			info.text += "\nŞablon kaydedildi: " + path
		return
	var ext := path.get_extension().to_lower()
	var stored := path
	if ext == "glb" or ext == "png":
		stored = "user://admin/files/%s_%d.%s" % [_cur, Time.get_unix_time_from_system(), ext]
		DirAccess.copy_absolute(path, ProjectSettings.globalize_path(stored))
	Game.admin.slots[_cur] = {"type": "glb" if ext in ["glb", "gltf"] else "skin", "path": stored}
	Game.save_admin()
	_apply_live()
	_select(_cur)


func _reset() -> void:
	Game.admin.slots.erase(_cur)
	Game.save_admin()
	_apply_live()
	_select(_cur)


func _apply_live() -> void:
	## oyundaki karakterleri hemen güncelle
	for n in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("people"):
		var v = n.get("visual")
		if v is CharacterVisual and (v as CharacterVisual).slot == _cur:
			(v as CharacterVisual).setup(_cur, Game.slot_default_skin(_cur))


func _process(delta: float) -> void:
	if preview:
		_spin += delta * 0.6
		preview.rotation.y = _spin


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_F10):
		queue_free()
		get_viewport().set_input_as_handled()
