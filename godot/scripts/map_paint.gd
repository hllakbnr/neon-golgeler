extends RefCounted
class_name MapPainter
## Mini harita ve tam harita için ortak çizim: kıta görseli + yakınlaşınca şehrin keskin vektör
## çizimi (bloklar, binalar, yollar) + rota + simge noktalar.

const POI_STYLE := {"food": ["Y", Color(1.0, 0.6, 0.2), "Yeme-içme"], "dojo": ["D", Color(1.0, 0.25, 0.8), "Dojo"],
	"weapons": ["S", Color(0.4, 0.9, 1.0), "Silah"], "clothes": ["K", Color(0.7, 0.45, 1.0), "Kıyafet"],
	"club": ["N", Color(0.2, 1.0, 1.0), "Kulüp"], "police": ["P", Color(0.35, 0.55, 1.0), "Polis"],
	"hospital": ["H", Color(1.0, 0.3, 0.3), "Hastane"], "spray": ["B", Color(0.3, 1.0, 0.5), "Boya"],
	"tower": ["T", Color(1.0, 0.3, 0.85), "Kule"], "monastery": ["M", Color(1.0, 0.8, 0.4), "Manastır"],
	"secure": ["A", Color(1.0, 0.2, 0.25), "Güvenlikli Ada"], "harbor": ["L", Color(1.0, 0.85, 0.2), "Liman"],
	"station": ["İ", Color(0.2, 0.9, 1.0), "İstasyon"], "beach": ["P", Color(1.0, 0.9, 0.4), "Sahil"],
	"fun": ["E", Color(1.0, 0.4, 0.9), "Eğlence"], "bank": ["B", Color(1.0, 0.85, 0.3), "Banka"],
	"arcade": ["O", Color(0.4, 1.0, 0.3), "Oyun salonu"], "ruins": ["R", Color(0.9, 0.75, 0.45), "Harabe"],
	"statues": ["G", Color(0.75, 0.75, 0.8), "Geçit"], "town": ["S", Color(0.6, 0.9, 1.0), "Kasaba"],
	"village": ["K", Color(0.6, 1.0, 0.5), "Köy"], "tea": ["Ç", Color(0.5, 0.9, 0.4), "Çay bahçesi"],
	"temple": ["T", Color(0.6, 0.85, 1.0), "Tapınak"], "volcano": ["V", Color(1.0, 0.4, 0.1), "Volkan"],
	"cabin": ["Ku", Color(0.9, 0.9, 1.0), "Kulübe"], "coves": ["Ko", Color(0.5, 0.8, 1.0), "Koylar"],
	"island": ["A", Color(0.4, 0.9, 0.5), "Ada"], "bridge": ["Kö", Color(1.0, 0.3, 0.3), "Köprü"],
	"lighthouse": ["F", Color(1.0, 0.95, 0.6), "Fener"], "shop": ["$", Color(1, 1, 1), "Dükkân"]}
const BLD_COL := {"eski": Color(0.66, 0.36, 0.27), "tekno": Color(0.59, 0.67, 0.77), "merkez": Color(0.63, 0.66, 0.73),
	"liman": Color(0.55, 0.53, 0.47), "konut": Color(0.89, 0.84, 0.77), "sahil": Color(0.91, 0.78, 0.81)}


static func style(kind: String) -> Array:
	return POI_STYLE.get(kind, ["?", Color.WHITE, kind])


static func draw_world(ci: CanvasItem, w: World, xf: Transform2D, px_per_m: float, view: Rect2) -> void:
	ci.draw_set_transform_matrix(xf)
	var tex := w.map_texture()
	var wr := w.world_rect()
	if tex:
		ci.draw_texture_rect(tex, Rect2(wr.position - Vector2(w.step, w.step) * 0.5, wr.size + Vector2(w.step, w.step)), false)
	# şehir: yakınlaşınca keskin vektör çizim
	var cr := Rect2(-w.EDGE_X, -w.EDGE_Z, w.EDGE_X * 2.0, w.EDGE_Z * 2.0)
	var inv := xf.affine_inverse()
	var vis := inv * view
	if px_per_m > 0.25 and vis.intersects(cr):
		ci.draw_rect(cr.grow(4.0), Color(0.73, 0.75, 0.77))
		var outer := w.BLOCK + w.WALK * 2.0
		for b in w.data.city.blocks:
			var c := Vector2(b.c[0], b.c[1])
			var bc := Color(0.8, 0.82, 0.84)
			if b.d == "konut":
				bc = Color(0.77, 0.8, 0.78)
			elif b.d == "lunapark":
				bc = Color(0.59, 0.77, 0.67)
			ci.draw_rect(Rect2(c - Vector2(outer, outer) * 0.5, Vector2(outer, outer)), bc)
		for bb in w.data.city.buildings:
			var c := Vector2(bb.c[0], bb.c[1])
			var s := Vector2(bb.s[0], bb.s[1])
			var hgt: float = bb.h
			var g := 0.7 - minf(hgt, 150.0) / 1000.0
			var col := Color(g, g + 0.015, g + 0.045)
			ci.draw_rect(Rect2(c - s * 0.5, s), col)
			if bb.has("lm"):
				ci.draw_rect(Rect2(c - s * 0.5, s), Color(0.45, 0.5, 0.58), false, 1.4 / px_per_m)
		var road := Color(0.985, 0.988, 0.99)
		for i in range(-w.GX, w.GX + 1):
			ci.draw_line(Vector2(i * w.CELL, -w.EDGE_Z - 4.0), Vector2(i * w.CELL, w.EDGE_Z + 4.0), road, w.ROAD_W * 0.8)
		for j in range(-w.GZ, w.GZ + 1):
			ci.draw_line(Vector2(-w.EDGE_X - 4.0, j * w.CELL), Vector2(w.EDGE_X + 4.0, j * w.CELL), road, w.ROAD_W * 0.8)
	# rota (GPS)
	if Game.has_waypoint and Game.route.size() > 1:
		var pts := PackedVector2Array()
		for p in Game.route:
			pts.append(Vector2(p.x, p.z))
		ci.draw_polyline(pts, Color(0.62, 0.3, 1.0), maxf(7.0, 5.0 / px_per_m), true)
	ci.draw_set_transform_matrix(Transform2D())


static func draw_icon(ci: CanvasItem, p: Vector2, kind: String, r := 9.0) -> void:
	## GTA6 tarzı rozet: renkli dolu daire, beyaz kenar, koyu harf
	var st := style(kind)
	var col: Color = st[1]
	ci.draw_circle(p + Vector2(0, 1.5), r + 2.0, Color(0, 0, 0, 0.35))
	ci.draw_circle(p, r + 1.6, Color(1, 1, 1, 0.95))
	ci.draw_circle(p, r, col.darkened(0.15))
	if Game.font_display:
		ci.draw_string(Game.font_display, p + Vector2(-r, r * 0.5), st[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 1.4), Color(0.08, 0.08, 0.1))


static func draw_waypoint(ci: CanvasItem, p: Vector2) -> void:
	var c := Color(0.75, 0.2, 1.0)
	ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-7, -14), p + Vector2(7, -14)]), c)
	ci.draw_circle(p + Vector2(0, -16), 6.0, c)
	ci.draw_circle(p + Vector2(0, -16), 2.5, Color.WHITE)


static func draw_player(ci: CanvasItem, p: Vector2, ang: float, size := 10.0) -> void:
	var t := Transform2D(ang, p)
	var pts := PackedVector2Array([t * Vector2(0, -size * 1.1), t * Vector2(size * 0.8, size * 0.8), t * Vector2(0, size * 0.35), t * Vector2(-size * 0.8, size * 0.8)])
	ci.draw_colored_polygon(pts, Color.WHITE)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.7), 1.5, true)
