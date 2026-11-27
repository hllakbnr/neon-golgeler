extends CanvasLayer
class_name TalkMenu
## Yayalarla etkileşim (GTA6'daki selamlama / kışkırtma / yatıştırma fikrinden esinlenme):
## [E] ile açılır; 1-4 ya da W/S + E ile seçilir. Yaya durur, sana döner ve tepki verir.

const OPTIONS := [["selam", "Selamla"], ["sohbet", "Sohbet et"], ["kiskirt", "Kışkırt"], ["sakin", "Sakinleştir"], ["para", "₺20 bahşiş ver"]]
const LINES := {
	"selam_cevap": ["Selam! İyi akşamlar.", "Merhaba, kolay gelsin.", "Hey, selam!", "Oo, selamlar.", "İyi günler."],
	"sohbet": [
		["Lunapark gece açılınca bütün şehir pembeye boyanıyor.", "Dönme dolaba bir kere bin, manzara inanılmaz."],
		["Dağdaki manastırı gördün mü? Yüzlerce basamak varmış.", "Diyorlar ki tepede hâlâ eski ustalar antrenman yapıyor."],
		["Limana yeni gemiler geldi, konteynerler tepeleme dolu.", "Gece orada dolaşma, garip tipler oluyor."],
		["Kızıl Köprü'den adaya geçen yol çok güzel.", "Ama ada kapalı, girişe izin yokmuş."],
		["Eski Çarşı'daki erişteciyi denedin mi?", "Noda Erişte Evi. Acılısını söyle, pişman olmazsın."],
		["Turbo Tarık'ın dojosu çok popüler oldu.", "Herkes oraya dövüş öğrenmeye gidiyor."],
		["Çölün ortasında taş heykeller varmış.", "Atalar Geçidi diyorlar oraya, gidenler hep anlatıyor."],
		["Bu akşam radyoda Neon FM çok iyi çalıyor.", "Arabaya binince bir aç derim."],
	],
	"kizgin": ["Ne bakıyorsun be?", "Yoluna devam et!", "Bana mı dedin sen?", "Git başımdan!", "Sen kimsin ya?"],
	"korkak": ["Tamam tamam, sorun istemiyorum!", "Lütfen, rahat bırak beni!", "Ben gidiyorum…"],
	"sakin_cevap": ["Peki, tamam. Sakinim.", "Haklısın, abarttım.", "Neyse, boş ver."],
	"zaten": ["Ben zaten sakinim?", "Bir sorun mu var?"],
	"para_cevap": ["Vay, sağ ol! Çok naziksin.", "Gerçekten mi? Teşekkürler!", "Bugün şanslı günümmüş."],
}

var player: Player
var ped: Pedestrian
var sel := 0
var _box: VBoxContainer
var _labels: Array = []


func _ready() -> void:
	layer = 9
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.05, 0.82)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.border_width_left = 3
	sb.border_color = Color(1.0, 0.3, 0.75)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = 120
	panel.offset_top = -40
	add_child(panel)
	_box = VBoxContainer.new()
	panel.add_child(_box)
	var t := Game.styled_label("YAYA", 22, Color(1.0, 0.5, 0.85), true)
	_box.add_child(t)
	for i in OPTIONS.size():
		var l := Game.styled_label("", 19, Color.WHITE)
		_box.add_child(l)
		_labels.append(l)
	_refresh()
	ped.state = Pedestrian.S.IDLE
	ped._t = 30.0
	ped.visual.set_motion(0.0)


func _refresh() -> void:
	for i in _labels.size():
		(_labels[i] as Label).text = ("▸ " if i == sel else "   ") + "%d  %s" % [i + 1, OPTIONS[i][1]]
		(_labels[i] as Label).modulate = Color.WHITE if i == sel else Color(1, 1, 1, 0.7)


func _process(delta: float) -> void:
	if not is_instance_valid(ped) or ped.is_down() or player.car or player.global_position.distance_to(ped.global_position) > 4.0:
		_close()
		return
	ped._face(player.global_position, delta)
	var rel := ped.global_position - player.global_position
	player.visual.rotation.y = lerp_angle(player.visual.rotation.y, atan2(rel.x, rel.z), minf(1.0, delta * 8.0))


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey or e is InputEventJoypadButton) or not e.is_pressed() or e.is_echo():
		return
	var pick := -1
	if e is InputEventKey:
		var k: int = (e as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_5:
			pick = k - KEY_1
		elif k == KEY_W or k == KEY_UP:
			sel = (sel - 1 + OPTIONS.size()) % OPTIONS.size()
			_refresh()
		elif k == KEY_S or k == KEY_DOWN:
			sel = (sel + 1) % OPTIONS.size()
			_refresh()
		elif k == KEY_ESCAPE or k == KEY_BACKSPACE:
			_close()
	if e.is_action_pressed("interact"):
		pick = sel
	if pick >= 0:
		get_viewport().set_input_as_handled()
		_do(String(OPTIONS[pick][0]))
		_close()


func _say(who: String, text: String) -> void:
	var d := get_tree().current_scene.get("dialog") as DialogBox
	if d:
		d.say(who, text)


func _pick(key: String) -> String:
	var a: Array = LINES[key]
	return String(a[randi() % a.size()])


func _do(opt: String) -> void:
	Sfx.ui("click", -10.0)
	match opt:
		"selam":
			player.visual.action("interact", 1.2)
			_say("kaan", (["Selam!", "Merhaba, nasılsın?", "İyi akşamlar."] as Array)[randi() % 3])
			ped._bark("selam")
			_say("yaya", _pick("selam_cevap"))
			ped.visual.action("yes", 1.0)
			_release(4.0)
		"sohbet":
			var pair: Array = (LINES.sohbet as Array)[randi() % (LINES.sohbet as Array).size()]
			_say("kaan", (["Bu şehirde neler oluyor?", "Ne var ne yok?", "Buralarda ilginç bir şey var mı?"] as Array)[randi() % 3])
			_say("yaya", String(pair[0]))
			_say("yaya", String(pair[1]))
			ped.visual.play("talk", 0.3)
			ped.visual.lock_t = 9.0
			_release(10.0)
		"kiskirt":
			player.visual.action("no", 1.0)
			_say("kaan", (["Ne bakıyorsun?", "Çekil yolumdan.", "Bir sorun mu var?"] as Array)[randi() % 3])
			if ped.brave or ped.role == "police":
				_say("yaya", _pick("kizgin"))
				ped._bark("tehdit")
				ped.threat = player
				ped.hostile = true
				ped.state = Pedestrian.S.FIGHT
			else:
				_say("yaya", _pick("korkak"))
				ped._start_flee(player)
		"sakin":
			if ped.hostile:
				if randf() < 0.7:
					_say("yaya", _pick("sakin_cevap"))
					ped._set_walk()
				else:
					_say("yaya", _pick("kizgin"))
					ped.state = Pedestrian.S.FIGHT
			else:
				_say("yaya", _pick("zaten"))
				_release(3.0)
		"para":
			if Game.money >= 20:
				Game.money -= 20
				Sfx.ui("cash", -8.0)
				_say("yaya", _pick("para_cevap"))
				ped.visual.action("yes", 1.0)
				_release(4.0)
			else:
				Game.notify("Yeterli paran yok.")


func _release(t: float) -> void:
	if is_instance_valid(ped) and ped.state == Pedestrian.S.IDLE:
		ped._t = t


func _close() -> void:
	if is_instance_valid(ped) and ped.state == Pedestrian.S.IDLE and ped._t > 20.0:
		ped._t = 0.5
	if player:
		player.talk = null
	queue_free()
