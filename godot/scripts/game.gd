extends Node
## Küresel oyun durumu: ayarlar, giriş haritası, gün saati, varlık manifesti, ortak materyaller.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

var manifest := {"tex": {}, "models": {}, "chars": {}, "fonts": {}}
var settings := {
	"quality": 2,          # 0 düşük · 1 orta · 2 yüksek
	"sdfgi": true,
	"ssr": true,
	"fov": 70.0,
	"sens": 1.0,
	"invert_y": false,
	"fullscreen": true,
	"volume": 0.8,
	"time_speed": 1,       # 0 yavaş · 1 normal · 2 hızlı
	"move_speed": 2,       # 0 yürü · 1 hızlı yürü · 2 hafif koşu
	"render_scale": 1.0,
}
var time_of_day := 17.5    # saat (0..24)
var day := 1
var paused := false
var shots_dir := ""        # CI ekran görüntüsü modu
var keyart: Array = []     # yükleme ekranı görselleri
var font_display: Font
var font_ui: Font
var _mat_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	_load_manifest()
	_load_settings()
	_setup_input()
	_load_fonts()
	apply_settings()


func _load_manifest() -> void:
	if FileAccess.file_exists("res://assets/manifest.json"):
		var f := FileAccess.open("res://assets/manifest.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d.keys():
				manifest[k] = d[k]


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cfg.get_value("s", k, settings[k])
	if shots_dir != "":
		settings.fullscreen = false


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("s", k, settings[k])
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	if shots_dir == "":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	get_viewport().scaling_3d_scale = settings.render_scale
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001, settings.volume)))
	settings_changed.emit()


func _load_fonts() -> void:
	var fd = manifest.fonts.get("display", "")
	var fu = manifest.fonts.get("ui", "")
	if fd != "" and ResourceLoader.exists(fd):
		font_display = load(fd)
	if fu != "" and ResourceLoader.exists(fu):
		font_ui = load(fu)
	if font_ui:
		var th := Theme.new()
		th.default_font = font_ui
		th.default_font_size = 18
		get_tree().root.theme = th


func _key(action: String, keys: Array, buttons: Array = [], mouse: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	for m in mouse:
		var mb := InputEventMouseButton.new()
		mb.button_index = m
		InputMap.action_add_event(action, mb)


func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK])
	_key("jump", [KEY_SPACE], [JOY_BUTTON_A])
	_key("vehicle", [KEY_F], [JOY_BUTTON_Y])
	_key("interact", [KEY_E], [JOY_BUTTON_B])
	_key("attack", [], [JOY_BUTTON_X], [MOUSE_BUTTON_LEFT])
	_key("handbrake", [KEY_SPACE], [JOY_BUTTON_A])
	_key("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	_key("time_fast", [KEY_T])
	# gamepad eksenleri
	for pair in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0], ["throttle", JOY_AXIS_TRIGGER_RIGHT, 1.0], ["brake", JOY_AXIS_TRIGGER_LEFT, 1.0]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		InputMap.action_add_event(pair[0], m)


func _process(delta: float) -> void:
	if paused:
		return
	# 1 oyun saati = 60 sn (normal); yavaş 120 sn; hızlı 15 sn
	var hour_secs: float = [120.0, 60.0, 15.0][int(settings.time_speed)]
	if Input.is_action_pressed("time_fast"):
		hour_secs = 1.0
	time_of_day += delta / hour_secs
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		day += 1


func clock_text() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]


# ---------------------------------------------------------------- materyaller
func tex(key: String, slot: String) -> Texture2D:
	var t = manifest.tex.get(key, {})
	var p = t.get(slot, "")
	if p != "" and ResourceLoader.exists(p):
		return load(p)
	return null


func pbr(key: String, tint := Color.WHITE, uv := 0.25, rough := 0.8) -> StandardMaterial3D:
	var ck := "%s|%s|%s" % [key, tint.to_html(), uv]
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	var d := tex(key, "diff")
	if d:
		m.albedo_texture = d
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(uv, uv, uv)
		var n := tex(key, "nor")
		if n:
			m.normal_enabled = true
			m.normal_texture = n
			m.normal_scale = 1.0
		var r := tex(key, "rough")
		if r:
			m.roughness_texture = r
			m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[ck] = m
	return m


func paint(color: Color, metal := 0.0, rough := 0.35, clearcoat := 0.0) -> StandardMaterial3D:
	var ck := "p|%s|%s|%s|%s" % [color.to_html(), metal, rough, clearcoat]
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if clearcoat > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = clearcoat
		m.clearcoat_roughness = 0.1
	_mat_cache[ck] = m
	return m


func emissive(color: Color, energy := 4.0) -> StandardMaterial3D:
	var ck := "e|%s|%s" % [color.to_html(), energy]
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mat_cache[ck] = m
	return m


func model(key: String) -> PackedScene:
	var p = manifest.models.get(key, "")
	if p != "" and ResourceLoader.exists(p):
		return load(p)
	return null


func character_scene() -> PackedScene:
	var p = manifest.chars.get("human", "")
	if p != "" and ResourceLoader.exists(p):
		return load(p)
	return null


func styled_label(text: String, size: int, color := Color.WHITE, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display and font_display:
		l.add_theme_font_override("font", font_display)
	return l


func shot(name: String) -> void:
	## CI: ekran görüntüsü kaydet (--shots=/klasör)
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots_dir)
	img.save_png(shots_dir.path_join(name + ".png"))
	print("SHOT ", name)
