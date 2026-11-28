extends Node
## Parçalı güncelleme yükleyicisi — diğer her şeyden önce çalışan ilk otomatik yüklemedir.
## Exe'nin kendi sürümüne (taban) ait bir yama paketi user://yama/ içinde varsa, oyunun dosyalarının
## üzerine yüklenir; böylece güncellemede yalnızca değişen dosyalar indirilir.
## Bu betik kasıtlı olarak küçük ve sabit tutulur (değişirse tam güncelleme gerekir).

static var exe_version := 0
static var patch_version := 0


func _init() -> void:
	if FileAccess.file_exists("res://version.txt"):
		exe_version = int(FileAccess.get_file_as_string("res://version.txt").strip_edges())
	if OS.has_feature("editor"):
		return
	var meta := "user://yama/yama.json"
	var pck := "user://yama/yama.pck"
	if not FileAccess.file_exists(meta) or not FileAccess.file_exists(pck):
		return
	var m = JSON.parse_string(FileAccess.get_file_as_string(meta))
	if m is Dictionary and int(m.get("base", -1)) == exe_version and exe_version > 0:
		if ProjectSettings.load_resource_pack(pck, true):
			patch_version = int(m.get("version", 0))
