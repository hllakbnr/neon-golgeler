extends CanvasLayer
class_name DialogBox
## Sesli diyalog + altyazı. Sesler derleme sırasında Türkçe metin-okuma (Piper, açık kaynak)
## ile üretilir: res://assets/voice/<id>.ogg. Ayarlardan altyazı açılıp kapatılabilir.

signal finished

const NAMES := {"kaan": ["KAAN", Color(1.0, 0.55, 0.15)], "ela": ["ELA", Color(0.3, 0.95, 0.95)], "polis": ["POLİS", Color(0.5, 0.65, 1.0)]}

var queue: Array = []
var player: AudioStreamPlayer
var panel: PanelContainer
var who_l: Label
var text_l: Label
var _t := 0.0
var _busy := false
var lines := {}


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player = AudioStreamPlayer.new()
	player.bus = "Voice"
	add_child(player)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.06, 0.62)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -210
	panel.offset_bottom = -150
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	who_l = Game.styled_label("", 22, Color.WHITE, true)
	v.add_child(who_l)
	text_l = Game.styled_label("", 24, Color.WHITE)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_l.custom_minimum_size = Vector2(980, 0)
	v.add_child(text_l)
	panel.visible = false
	if FileAccess.file_exists("res://data/dialogs.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogs.json"))
		if d is Dictionary:
			lines = d


func play_scene(key: String) -> void:
	for l in lines.get(key, []):
		queue.append(l)
	if not _busy:
		_next()


func say(who: String, text: String, id := "") -> void:
	queue.append({"who": who, "text": text, "id": id})
	if not _busy:
		_next()


func _next() -> void:
	if queue.is_empty():
		_busy = false
		panel.visible = false
		finished.emit()
		return
	_busy = true
	var l: Dictionary = queue.pop_front()
	var n = NAMES.get(l.get("who", ""), [String(l.get("who", "")).to_upper(), Color.WHITE])
	who_l.text = n[0]
	who_l.add_theme_color_override("font_color", n[1])
	text_l.text = l.get("text", "")
	panel.visible = Game.settings.get("subtitles", true)
	var dur := 1.6 + text_l.text.length() * 0.055
	var path := "res://assets/voice/%s.ogg" % l.get("id", "")
	if l.get("id", "") != "" and ResourceLoader.exists(path):
		var st: AudioStream = load(path)
		player.stream = st
		player.play()
		dur = maxf(st.get_length() + 0.45, 1.2)
	_t = dur


func _process(delta: float) -> void:
	if not _busy:
		return
	panel.visible = Game.settings.get("subtitles", true)
	_t -= delta
	if _t <= 0.0:
		_next()
