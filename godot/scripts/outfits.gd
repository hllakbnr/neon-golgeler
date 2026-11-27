extends RefCounted
class_name Outfits
## Kıyafetler: varsayılan karakterde kostüm dokusu değişir; yönetici panelinden özel 3B model
## yüklenmişse modelin kumaş renkleri (ten/yüz rengi korunarak) yeniden boyanır.

const LIST := [
	{"id": "varsayilan", "name": "Kaan'ın Metal Gi'si", "skin": "kaan.png", "tint": Color(0, 0, 0, 0), "price": 0},
	{"id": "ates", "name": "Ateş Gi'si", "skin": "kaan_ates.png", "tint": Color(0.85, 0.16, 0.1), "price": 300},
	{"id": "simsek", "name": "Şimşek Gi'si", "skin": "kaan_simsek.png", "tint": Color(0.18, 0.42, 1.0), "price": 300},
	{"id": "buz", "name": "Buz Gi'si", "skin": "kaan_buz.png", "tint": Color(0.88, 0.92, 0.98), "price": 300},
	{"id": "toprak", "name": "Toprak Gi'si", "skin": "kaan_toprak.png", "tint": Color(0.42, 0.28, 0.16), "price": 300},
	{"id": "yesil", "name": "Yeşil Enerji Gi'si", "skin": "kaan_yesil.png", "tint": Color(0.18, 0.78, 0.3), "price": 500},
	{"id": "golge", "name": "Gölge Ninja", "skin": "kaan_golge.png", "tint": Color(0.1, 0.1, 0.12), "price": 450},
	{"id": "sokak1", "name": "Sokak Stili · Mavi", "skin": "texture-c.png", "tint": Color(0.25, 0.4, 0.7), "price": 120},
	{"id": "sokak2", "name": "Sokak Stili · Yeşil", "skin": "texture-g.png", "tint": Color(0.3, 0.55, 0.3), "price": 150},
	{"id": "sokak3", "name": "Sokak Stili · Kırmızı", "skin": "texture-l.png", "tint": Color(0.7, 0.2, 0.2), "price": 150},
	{"id": "takim", "name": "Gece Takımı", "skin": "texture-m.png", "tint": Color(0.15, 0.15, 0.2), "price": 400},
]


static func info(id: String) -> Dictionary:
	for o in LIST:
		if o.id == id:
			return o
	return LIST[0]


static func apply(pl: Player, id: String) -> void:
	var o := info(id)
	Game.outfit = id
	var cfg: Dictionary = Game.slot_cfg("kaan")
	if cfg.get("type", "") == "glb":
		var t: Color = o.tint
		if t.a <= 0.0:
			pl.visual.setup("kaan", Game.slot_default_skin("kaan"))
		else:
			pl.visual.tint(t)
		return
	var skin := String(o.skin)
	if not ResourceLoader.exists(Game.skin_path(skin)):
		skin = Game.slot_default_skin("kaan")
	pl.visual.setup("kaan", skin)
