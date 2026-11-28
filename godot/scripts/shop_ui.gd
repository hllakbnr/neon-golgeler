extends CanvasLayer
class_name ShopUI
## Dükkân menüsü: W/S ya da ok tuşları ile seç, E / Enter ile satın al, Esc ile çık. Fareyle de tıklanır.

const CATALOG := {
	"restoran": [
		{"id": "eriste", "name": "Erişte Kâsesi", "price": 25, "desc": "Sıcak et suyu, taze erişte. +40 can", "heal": 40},
		{"id": "acili", "name": "Acılı Ejder Eriştesi", "price": 35, "desc": "Yakıcı ama güç verir. +60 can, 30 sn bitmeyen dayanıklılık", "heal": 60, "boost": 30.0},
		{"id": "gyoza", "name": "Gyoza Tabağı", "price": 15, "desc": "Altı çıtır mantı. +20 can", "heal": 20},
		{"id": "cay", "name": "Yeşil Çay", "price": 6, "desc": "Sakinleştirir. +8 can, dayanıklılık dolar", "heal": 8, "stamina": 100.0},
	],
	"smoothie": [
		{"id": "ananas", "name": "Ananas Fırtınası", "price": 14, "desc": "Ananas + hindistan cevizi. +25 can", "heal": 25},
		{"id": "cilek", "name": "Çilek-Muz Karışımı", "price": 16, "desc": "Klasik. +30 can", "heal": 30},
		{"id": "neon", "name": "Neon Mavi Enerji", "price": 22, "desc": "Spirulina + yaban mersini. +30 can, 60 sn bitmeyen dayanıklılık", "heal": 30, "boost": 60.0},
		{"id": "yesil", "name": "Yeşil Güç", "price": 18, "desc": "Ispanak, elma, zencefil. +35 can", "heal": 35},
	],
	"market": [
		{"id": "su", "name": "Su", "price": 3, "desc": "+5 can", "heal": 5},
		{"id": "kraker", "name": "Pirinç Krakeri", "price": 6, "desc": "+12 can", "heal": 12},
		{"id": "kit", "name": "İlk Yardım Çantası", "price": 80, "desc": "Çantaya eklenir — silah çarkında 1 ile kullan: canı tamamen doldurur", "inv": "kit"},
		{"id": "icecek", "name": "Enerji İçeceği", "price": 25, "desc": "Çantaya eklenir — silah çarkında 2 ile kullan: 45 sn bitmeyen dayanıklılık", "inv": "icecek"},
		{"id": "sapka", "name": "Şapka ve Güneş Gözlüğü", "price": 45, "desc": "Görünüşünü değiştirir: polis aranırken tarifini bozar", "disguise": true},
	],
	"silah": [
		{"id": "shuriken20", "name": "Shuriken ×20", "price": 60, "desc": "Fırlatılan yıldız. Cephane +20", "ammo": 20},
		{"id": "shuriken50", "name": "Shuriken ×50", "price": 130, "desc": "Toplu paket. Cephane +50", "ammo": 50},
		{"id": "zirh1", "name": "Hafif Zırh Yeleği", "price": 250, "desc": "+50 zırh", "armor": 50.0},
		{"id": "zirh2", "name": "Ağır Zırh Yeleği", "price": 500, "desc": "+100 zırh", "armor": 100.0},
		{"id": "w_katana", "name": "Katana", "price": 1200, "desc": "Keskin, hızlı kombolar", "weapon": "katana"},
		{"id": "w_sopa", "name": "Bo Sopası", "price": 300, "desc": "Uzun menzil", "weapon": "sopa"},
		{"id": "w_nuncaku", "name": "Nunçaku", "price": 450, "desc": "En hızlı silah", "weapon": "nuncaku"},
		{"id": "w_sok", "name": "Şok Çubuğu", "price": 700, "desc": "Rakibi sersemletir", "weapon": "sok"},
	],
	"kulup": [
		{"id": "dans", "name": "Dans pistine çık", "price": 0, "desc": "Müziğe kendini bırak", "dance": true},
		{"id": "kokteyl", "name": "Neon Kokteyl (alkolsüz)", "price": 12, "desc": "+10 can", "heal": 10},
		{"id": "vip", "name": "VIP Bileklik", "price": 250, "desc": "Kulübün müdavimisin artık", "vip": true},
	],
	"dojo": [
		{"id": "ders_dayan", "name": "Dayanıklılık Antrenmanı", "price": 150, "desc": "+10 maksimum dayanıklılık (en fazla 160)", "stat": "stamina"},
		{"id": "ders_guc", "name": "Dövüş Dersi", "price": 300, "desc": "Tüm darbeler %10 daha güçlü (en fazla %50)", "stat": "dmg"},
		{"id": "manken", "name": "Mankende çalış", "price": 0, "desc": "Mankenlere vurarak kombo pratiği yap", "free": true},
	],
	"manastir": [
		{"id": "meditasyon", "name": "Meditasyon", "price": 0, "desc": "Can ve dayanıklılık tamamen dolar", "heal": 100, "stamina": 200.0},
		{"id": "kasirga", "name": "Kasırga Tekniği", "price": 0, "desc": "Öğrenildi — X tuşu ile kasırgaya dönüş", "free": true},
		{"id": "element", "name": "Element Gücü: Metal", "price": 0, "desc": "Öğrenildi — Z tuşu ile metal şok dalgası", "free": true},
	],
}

var kind := ""
var player: Player
var sel := 0
var _items: Array = []
var _rows: Array = []
var _desc: Label
var _money: Label
var _title: Label


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	if kind == "butik":
		for o in Outfits.LIST:
			_items.append({"id": "o_" + String(o.id), "name": String(o.name), "price": int(o.price), "desc": "Kıyafet", "outfit": String(o.id)})
	else:
		_items = CATALOG.get(kind, []).duplicate(true)
	player.controls = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.05, 0.88)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.border_width_top = 4
	sb.border_color = Interiors.STYLE.get(kind, {}).get("neon", Color(1, 0.3, 0.7))
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560
	panel.offset_right = -60
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_title = Game.styled_label(String(Interiors.STYLE.get(kind, {}).get("title", "DÜKKÂN")), 34, Color.WHITE, true)
	v.add_child(_title)
	_money = Game.styled_label("", 20, Color(0.55, 1.0, 0.55))
	v.add_child(_money)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(450, 360)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for i in _items.size():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(440, 40)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func(): sel = i; _buy())
		b.mouse_entered.connect(func(): sel = i; _refresh())
		list.add_child(b)
		_rows.append(b)
	_desc = Game.styled_label("", 17, Color(1, 1, 1, 0.8))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(450, 60)
	v.add_child(_desc)
	v.add_child(Game.styled_label("W/S seç · E satın al · Esc çık", 15, Color(1, 1, 1, 0.5)))
	_refresh()


func _label_for(it: Dictionary) -> String:
	var price := int(it.get("price", 0))
	var tag := ("₺%d" % price) if price > 0 else "Ücretsiz"
	if it.has("weapon") and player.combat.owned.has(String(it.weapon)):
		tag = "Sende var"
	if it.has("outfit"):
		if Game.outfit == String(it.outfit):
			tag = "Giyili"
		elif Game.owned_outfits.has(String(it.outfit)):
			tag = "Giy"
	return "%s    —    %s" % [String(it.name), tag]


func _refresh() -> void:
	for i in _rows.size():
		var b := _rows[i] as Button
		b.text = ("▸ " if i == sel else "   ") + _label_for(_items[i])
		b.modulate = Color.WHITE if i == sel else Color(1, 1, 1, 0.75)
	if sel < _items.size():
		_desc.text = String(_items[sel].get("desc", ""))
	_money.text = "Cüzdan: ₺%d" % Game.money


func _unhandled_input(e: InputEvent) -> void:
	if not e.is_pressed() or e.is_echo():
		return
	if e is InputEventKey:
		var k: int = (e as InputEventKey).keycode
		if k == KEY_W or k == KEY_UP:
			sel = (sel - 1 + _items.size()) % _items.size()
			_refresh()
			Sfx.ui("click", -14.0)
		elif k == KEY_S or k == KEY_DOWN:
			sel = (sel + 1) % _items.size()
			_refresh()
			Sfx.ui("click", -14.0)
		elif k == KEY_E or k == KEY_ENTER or k == KEY_KP_ENTER:
			_buy()
		elif k == KEY_ESCAPE or k == KEY_BACKSPACE:
			_close()
		get_viewport().set_input_as_handled()
	elif e is InputEventJoypadButton:
		var jb: int = (e as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_DPAD_UP:
			sel = (sel - 1 + _items.size()) % _items.size()
		elif jb == JOY_BUTTON_DPAD_DOWN:
			sel = (sel + 1) % _items.size()
		elif jb == JOY_BUTTON_A:
			_buy()
		elif jb == JOY_BUTTON_B:
			_close()
		_refresh()
		get_viewport().set_input_as_handled()


func _buy() -> void:
	var it: Dictionary = _items[sel]
	var cb := player.combat
	var price := int(it.get("price", 0))
	if it.has("outfit") and Game.owned_outfits.has(String(it.outfit)):
		price = 0
	if it.has("weapon") and cb.owned.has(String(it.weapon)):
		cb.equip(String(it.weapon))
		Game.notify("%s kuşanıldı." % String(it.name), 2.0)
		return
	if it.get("stat", "") == "stamina" and cb.max_stamina >= 160.0:
		Game.notify("Dayanıklılığın zaten en üst seviyede.")
		return
	if it.get("stat", "") == "dmg" and cb.dmg_mult >= 1.5:
		Game.notify("Dövüş gücün zaten en üst seviyede.")
		return
	if Game.money < price:
		Game.notify("Yeterli paran yok.")
		Sfx.ui("click", -4.0)
		return
	Game.money -= price
	if price > 0:
		Sfx.ui("cash", -6.0)
	if it.has("heal"):
		cb.heal(float(it.heal))
		player.visual.action("consume", 1.0)
	if it.has("stamina"):
		cb.stamina = cb.max_stamina
	if it.has("boost"):
		cb.boost = maxf(cb.boost, float(it.boost))
	if it.has("armor"):
		cb.armor = minf(100.0, cb.armor + float(it.armor))
	if it.has("inv"):
		Game.items[String(it.inv)] = int(Game.items.get(String(it.inv), 0)) + 1
	if it.has("ammo"):
		cb.ammo["shuriken"] = int(cb.ammo.get("shuriken", 0)) + int(it.ammo)
	if it.has("weapon"):
		cb.owned.append(String(it.weapon))
		cb.equip(String(it.weapon))
	if it.has("disguise") and Wanted.inst:
		Wanted.inst.description_changed("kıyafet")
	if it.has("outfit"):
		var oid := String(it.outfit)
		if not Game.owned_outfits.has(oid):
			Game.owned_outfits.append(oid)
		Outfits.apply(player, oid)
		if Wanted.inst:
			Wanted.inst.description_changed("kıyafet")
	match String(it.get("stat", "")):
		"stamina":
			cb.max_stamina = minf(160.0, cb.max_stamina + 10.0)
			cb.stamina = cb.max_stamina
		"dmg":
			cb.dmg_mult = minf(1.5, cb.dmg_mult + 0.1)
	if it.has("dance"):
		_close()
		player.visual.play("dance", 0.3)
		player.visual.lock_t = 12.0
		return
	if it.get("free", false):
		_close()
		return
	Game.notify("Satın alındı: " + String(it.name), 2.0)
	_refresh()


func _close() -> void:
	player.controls = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Game.shots_dir == "" else Input.MOUSE_MODE_VISIBLE
	queue_free()
