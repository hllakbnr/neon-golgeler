extends RefCounted
class_name Barks
## Yaya / polis tepki sesleri (derlemede metin-okuma ile üretilir: assets/voice/bark_<tür>_<ses>_<n>.ogg)

static var _cache := {}


static func _list(kind: String, voice: String) -> Array:
	var key := kind + "_" + voice
	if _cache.has(key):
		return _cache[key]
	var out := []
	for n in range(1, 7):
		var p := "res://assets/voice/bark_%s_%s_%d.ogg" % [kind, voice, n]
		if ResourceLoader.exists(p):
			out.append(p)
	_cache[key] = out
	return out


static func say(kind: String, pos: Vector3, male := true, police := false) -> void:
	var voice := "polis" if police else ("erkek" if male else "kadin")
	var l := _list(kind, voice)
	if l.is_empty() and voice == "polis":
		l = _list(kind, "erkek")
	if l.is_empty():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = load(l[randi() % l.size()])
	a.bus = "Voice"
	a.unit_size = 5.0
	a.max_distance = 45.0
	a.pitch_scale = randf_range(0.93, 1.08)
	tree.current_scene.add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)
