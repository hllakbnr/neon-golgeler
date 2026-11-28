extends CanvasLayer
class_name Updater
## Oyun içi otomatik güncelleme (Windows .exe).
## Açılışta GitHub'daki "godot-guncel" sürümünün version.json dosyasına bakar; yeni sürüm varsa
## exe'yi indirir, çalışan exe'nin adını .old yapar, yenisini yerine koyar ve oyunu yeniden başlatır.
## Ağ yoksa ya da bir şey ters giderse oyun normal şekilde açılır.

signal finished

const BASE := "https://github.com/hllakbnr/neon-golgeler/releases/download/godot-guncel/"
const TEMP_NAME := "NeonGolgeler.indiriliyor"

var http: HTTPRequest
var title: Label
var info: Label
var bar: ProgressBar
var _downloading := false
var _new_path := ""


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/gradient.gdshader")
	bg.material = gm
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -110
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var logo := Game.styled_label("NEON GÖLGELER", 64, Color(1, 0.45, 0.85), true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(logo)
	title = Game.styled_label("Güncellemeler denetleniyor…", 26, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(720, 10)
	bar.show_percentage = false
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1, 0.35, 0.8)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.12)
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", bgs)
	box.add_child(bar)
	info = Game.styled_label("", 18, Color(1, 1, 1, 0.8))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(720, 0)
	box.add_child(info)
	var ver := Game.styled_label("Sürüm %d" % Game.version, 14, Color(1, 1, 1, 0.5))
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -200
	ver.offset_right = -20
	ver.offset_top = -36
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	http = HTTPRequest.new()
	http.max_redirects = 10
	http.timeout = 8.0
	add_child(http)


static func should_run() -> bool:
	if Game.shots_dir != "" or OS.has_feature("editor") or not OS.has_feature("windows"):
		return false
	if not Game.settings.get("auto_update", true):
		return false
	return Game.version > 0


static func cleanup_old() -> void:
	## önceki güncellemeden kalan .old dosyasını sil
	var exe := OS.get_executable_path()
	for p in [exe + ".old", exe.get_base_dir().path_join(TEMP_NAME)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func run() -> void:
	cleanup_old()
	bar.value = 0
	http.request(BASE + "version.json?t=%d" % Time.get_unix_time_from_system())
	var res: Array = await http.request_completed
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		_finish("Güncelleme sunucusuna ulaşılamadı, oyun açılıyor…", 1.0)
		return
	var d = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (d is Dictionary) or int(d.get("version", 0)) <= Game.version:
		_finish("Oyun güncel.", 0.4)
		return
	var nv := int(d.version)
	title.text = "Yeni sürüm bulundu: %d" % nv
	info.text = String(d.get("notes", "")).left(400)
	# parçalı güncelleme: exe aynı tabandansa yalnızca değişen dosyaların paketi indirilir
	if String(d.get("patch", "")) != "" and int(d.get("base", -1)) == Patcher.exe_version:
		await _patch(d)
		return
	var exe := OS.get_executable_path()
	_new_path = exe.get_base_dir().path_join(TEMP_NAME)
	http.timeout = 0.0
	http.download_file = _new_path
	http.download_chunk_size = 1 << 20
	_downloading = true
	http.request(BASE + String(d.get("file", "NeonGolgeler.exe")))
	res = await http.request_completed
	_downloading = false
	http.download_file = ""
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200 or not FileAccess.file_exists(_new_path):
		_finish("İndirme başarısız oldu, mevcut sürümle devam ediliyor.", 2.0)
		return
	var f := FileAccess.open(_new_path, FileAccess.READ)
	var size := f.get_length() if f else 0
	if f:
		f.close()
	if size < 20 * 1024 * 1024:
		DirAccess.remove_absolute(_new_path)
		_finish("İndirilen dosya eksik, mevcut sürümle devam ediliyor.", 2.0)
		return
	title.text = "Güncelleme kuruluyor…"
	# çalışan exe yeniden adlandırılabilir (Windows izin verir), sonra yenisi yerine konur
	if DirAccess.rename_absolute(exe, exe + ".old") != OK:
		_finish("Oyun klasörüne yazılamadı. Oyunu masaüstü gibi bir klasöre taşıyıp tekrar dene.", 3.0)
		return
	if DirAccess.rename_absolute(_new_path, exe) != OK:
		DirAccess.rename_absolute(exe + ".old", exe)
		_finish("Güncelleme kurulamadı, mevcut sürümle devam ediliyor.", 2.0)
		return
	for yp in ["user://yama/yama.pck", "user://yama/yama.json"]:
		if FileAccess.file_exists(yp):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(yp))
	title.text = "Oyun yeniden başlatılıyor…"
	await get_tree().create_timer(0.8).timeout
	OS.create_process(exe, OS.get_cmdline_args())
	get_tree().quit()


func _patch(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://yama")
	var tmp := ProjectSettings.globalize_path("user://yama/yama.indiriliyor")
	http.timeout = 0.0
	http.download_file = tmp
	http.download_chunk_size = 1 << 18
	_downloading = true
	title.text = "Güncelleme indiriliyor (yalnızca değişenler)…"
	http.request(BASE + String(d.patch) + "?v=%d" % int(d.version))
	var res: Array = await http.request_completed
	_downloading = false
	http.download_file = ""
	var want := int(d.get("patch_size", 0))
	var f := FileAccess.open(tmp, FileAccess.READ)
	var size := f.get_length() if f else 0
	if f:
		f.close()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200 or size < 64 or (want > 0 and size != want):
		DirAccess.remove_absolute(tmp)
		_finish("Güncelleme indirilemedi, mevcut sürümle devam ediliyor.", 2.0)
		return
	var dst := ProjectSettings.globalize_path("user://yama/yama.pck")
	if FileAccess.file_exists(dst):
		DirAccess.remove_absolute(dst)
	DirAccess.rename_absolute(tmp, dst)
	var mf := FileAccess.open("user://yama/yama.json", FileAccess.WRITE)
	mf.store_string(JSON.stringify({"base": Patcher.exe_version, "version": int(d.version)}))
	mf.close()
	title.text = "Oyun yeniden başlatılıyor…"
	await get_tree().create_timer(0.6).timeout
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	get_tree().quit()


func _process(_d: float) -> void:
	if _downloading:
		var total := http.get_body_size()
		var got := http.get_downloaded_bytes()
		if total > 0:
			bar.value = 100.0 * got / total
			info.text = "İndiriliyor: %.1f / %.1f MB" % [got / 1048576.0, total / 1048576.0]
		else:
			info.text = "İndiriliyor: %.1f MB" % (got / 1048576.0)


func _finish(msg: String, wait: float) -> void:
	title.text = msg
	bar.value = 100
	await get_tree().create_timer(wait).timeout
	finished.emit()
	queue_free()
