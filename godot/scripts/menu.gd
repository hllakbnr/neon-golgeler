extends CanvasLayer
class_name MainMenu
## Ana / duraklatma menüsü: solda dikey liste, arkada bulanık oyun sahnesi, sol üstte "NG" amblemi.

signal play_pressed
signal resume_pressed

var pause_mode := false
var list: VBoxContainer
var desc: Label
var settings_ui: SettingsUI
var buttons: Array[Button] = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var blur := ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/blur.gdshader")
	blur.material = bm
	add_child(blur)
	# sol koyu panel
	var panel := ColorRect.new()
	panel.color = Color(0.09, 0.08, 0.13, 0.86)
	panel.anchor_bottom = 1.0
	panel.offset_right = 560
	add_child(panel)
	# amblem
	var logo := Game.styled_label("NG", 150, Color(0, 0, 0, 0), true)
	logo.add_theme_color_override("font_outline_color", Color(0.92, 0.45, 0.7))
	logo.add_theme_constant_override("outline_size", 6)
	logo.position = Vector2(56, 20)
	add_child(logo)
	var sub := Game.styled_label("NEON GÖLGELER", 26, Color(0.92, 0.45, 0.7), true)
	sub.position = Vector2(62, 190)
	add_child(sub)
	list = VBoxContainer.new()
	list.position = Vector2(40, 270)
	list.custom_minimum_size = Vector2(480, 0)
	list.add_theme_constant_override("separation", 8)
	add_child(list)
	desc = Game.styled_label("", 16, Color(1, 1, 1, 0.6))
	desc.anchor_top = 1.0
	desc.anchor_bottom = 1.0
	desc.offset_left = 56
	desc.offset_right = 520
	desc.offset_top = -90
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(desc)
	var ver := Game.styled_label("Godot deneme sürümü · Klavye/Fare veya Gamepad", 13, Color(1, 1, 1, 0.35))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 56
	ver.offset_top = -34
	add_child(ver)
	var cred := Game.styled_label("Emeği geçenler: dokular Poly Haven (CC0) · karakter/araç modelleri ve animasyonlar Kenney, Quaternius (CC0) · yazı tipleri Google Fonts (OFL) · kasırga efekti modeli 'Spinjitzu (green)', AAV's 3D Models (Sketchfab), CC BY 4.0; renkleri oyunda değiştirildi · müzikler oyun için prosedürel bestelendi", 12, Color(1, 1, 1, 0.3))
	cred.anchor_top = 1.0
	cred.anchor_bottom = 1.0
	cred.anchor_right = 1.0
	cred.offset_left = 600
	cred.offset_right = -30
	cred.offset_top = -52
	cred.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(cred)
	settings_ui = SettingsUI.new()
	settings_ui.visible = false
	settings_ui.closed.connect(func(): settings_ui.visible = false; _focus_first())
	add_child(settings_ui)
	build()


func build() -> void:
	for c in list.get_children():
		c.queue_free()
	buttons.clear()
	var items := []
	if pause_mode:
		items.append(["Devam Et", "Şehre geri dön.", func(): resume_pressed.emit()])
	else:
		items.append(["Hikâye Modu", "Kaan Demir'in hikâyesine başla.", func(): play_pressed.emit()])
	items.append(["Harita", "Şehir haritası (yakında: görev ve yol noktaları).", func(): pass])
	items.append(["Fotoğraf Stüdyosu", "Kamerayı serbest bırak, kareyi yakala (yakında).", func(): pass])
	items.append(["Ayarlar", "Oynanış, görüntü, kamera ve ses ayarları.", func(): settings_ui.visible = true; settings_ui.grab()])
	items.append(["Yardım", "WASD hareket · Shift koş · Boşluk zıpla · F araç · Fare kamera · T zamanı hızlandır · Esc menü", func(): pass])
	items.append(["Çıkış", "Oyundan çık.", func(): get_tree().quit()])
	for it in items:
		var b := Button.new()
		b.text = "    " + it[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(470, 52)
		b.add_theme_font_size_override("font_size", 24)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0, 0, 0, 0)
		var hl := StyleBoxTexture.new()
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 0.95))
		gr.set_color(1, Color(0.75, 0.72, 0.85, 0.25))
		gt.gradient = gr
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(1, 0)
		hl.texture = gt
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hl)
		b.add_theme_stylebox_override("focus", hl)
		b.add_theme_stylebox_override("pressed", hl)
		b.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		b.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.15))
		b.add_theme_color_override("font_focus_color", Color(0.1, 0.08, 0.15))
		b.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.15))
		if Game.font_ui:
			b.add_theme_font_override("font", Game.font_ui)
		var d: String = it[1]
		b.focus_entered.connect(func(): desc.text = d)
		b.mouse_entered.connect(func(): b.grab_focus())
		b.pressed.connect(it[2])
		list.add_child(b)
		buttons.append(b)
	_focus_first.call_deferred()


func _focus_first() -> void:
	if buttons.size() > 0 and visible:
		buttons[0].grab_focus()


func open(as_pause: bool) -> void:
	pause_mode = as_pause
	visible = true
	build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(e: InputEvent) -> void:
	# F10: gizli yönetici bölümü (PIN korumalı)
	if visible and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F10:
		var ap := AdminPanel.new()
		get_parent().add_child(ap)
		get_viewport().set_input_as_handled()
		return
	if visible and pause_mode and e.is_action_pressed("pause") and not settings_ui.visible:
		resume_pressed.emit()
		get_viewport().set_input_as_handled()
