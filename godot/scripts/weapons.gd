extends RefCounted
class_name Weapons
## Silah verileri ve elde tutulan prosedürel modeller (ilk sürümlerdeki silahlar + nunçaku).
## kind: melee | throw. combo: hafif saldırı animasyon zinciri; heavy: ağır saldırı.

const LIST := {
	"yumruk": {"name": "Yumruk", "kind": "melee", "dmg": 9.0, "range": 1.5, "speed": 1.15, "cost": 7.0,
		"combo": ["punch_jab", "punch_cross", "hook"], "heavy": "kick", "icon": "✊", "price": 0},
	"boru": {"name": "Demir Boru", "kind": "melee", "dmg": 17.0, "range": 1.9, "speed": 1.0, "cost": 10.0,
		"combo": ["sword_a", "sword_b"], "heavy": "sword_c", "icon": "▬", "price": 150},
	"sopa": {"name": "Bo Sopası", "kind": "melee", "dmg": 15.0, "range": 2.3, "speed": 1.05, "cost": 9.0,
		"combo": ["sword_a", "sword_b", "sword_c"], "heavy": "sword_combo", "icon": "│", "price": 300},
	"nuncaku": {"name": "Nunçaku", "kind": "melee", "dmg": 12.0, "range": 1.8, "speed": 1.35, "cost": 7.0,
		"combo": ["sword_a", "sword_b", "sword_c", "sword_a"], "heavy": "sword_combo", "icon": "⫶", "price": 450},
	"katana": {"name": "Katana", "kind": "melee", "dmg": 26.0, "range": 2.1, "speed": 1.1, "cost": 11.0,
		"combo": ["sword_a", "sword_b", "sword_c"], "heavy": "sword_combo", "icon": "⚔", "price": 1200},
	"zincir": {"name": "Zincir", "kind": "melee", "dmg": 14.0, "range": 2.6, "speed": 0.95, "cost": 10.0,
		"combo": ["sword_a", "sword_b"], "heavy": "sword_combo", "icon": "∞", "price": 400},
	"shuriken": {"name": "Shuriken", "kind": "throw", "dmg": 18.0, "range": 30.0, "speed": 1.6, "cost": 5.0,
		"combo": ["throw"], "heavy": "throw", "icon": "✦", "price": 20},
	"sok": {"name": "Şok Çubuğu", "kind": "melee", "dmg": 6.0, "range": 1.7, "speed": 1.2, "cost": 8.0,
		"combo": ["sword_a", "sword_b"], "heavy": "sword_c", "icon": "ϟ", "price": 700, "stun": 2.5},
}
const ORDER := ["yumruk", "boru", "sopa", "nuncaku", "katana", "zincir", "shuriken", "sok"]


static func info(id: String) -> Dictionary:
	return LIST.get(id, LIST.yumruk)


static func mesh(id: String) -> Node3D:
	## eldeki model: tutma noktası orijinde, namlu/bıçak +Z yönünde
	var root := Node3D.new()
	var steel := Game.paint(Color(0.85, 0.87, 0.9), 1.0, 0.18)
	var dark := Game.paint(Color(0.1, 0.1, 0.11), 0.4, 0.5)
	var wood := Game.paint(Color(0.5, 0.33, 0.18), 0.0, 0.7)
	match id:
		"boru":
			_cyl(root, Vector3(0, 0, 0.35), 0.035, 1.0, Game.paint(Color(0.45, 0.45, 0.47), 0.9, 0.4))
		"sopa":
			_cyl(root, Vector3(0, 0, 0.15), 0.03, 1.8, wood)
		"nuncaku":
			_cyl(root, Vector3(0, 0, 0.12), 0.03, 0.34, dark)
			_cyl(root, Vector3(0.05, -0.05, 0.42), 0.03, 0.34, dark).rotation = Vector3(0.6, 0, 0.4)
			_box(root, Vector3(0.02, -0.02, 0.29), Vector3(0.015, 0.015, 0.1), steel)
		"katana":
			_box(root, Vector3(0, 0, -0.05), Vector3(0.04, 0.04, 0.26), dark)
			_box(root, Vector3(0, 0, 0.1), Vector3(0.12, 0.03, 0.04), Game.paint(Color(0.8, 0.65, 0.2), 1.0, 0.3))
			_box(root, Vector3(0, 0, 0.55), Vector3(0.012, 0.045, 0.85), steel)
		"zincir":
			for k in range(8):
				var l := _box(root, Vector3(0, -k * 0.02, 0.08 + k * 0.1), Vector3(0.03, 0.05, 0.09), Game.paint(Color(0.6, 0.6, 0.62), 1.0, 0.3))
				l.rotation.z = (k % 2) * PI * 0.5
		"shuriken":
			var pts := PackedVector2Array()
			for k in range(8):
				var a := k * TAU / 8.0
				var r := 0.11 if k % 2 == 0 else 0.03
				pts.append(Vector2(cos(a), sin(a)) * r)
			var poly := CSGPolygon3D.new()
			poly.polygon = pts
			poly.depth = 0.01
			poly.material = steel
			poly.rotation.x = PI * 0.5
			poly.position = Vector3(0, 0, 0.05)
			root.add_child(poly)
		"sok":
			_cyl(root, Vector3(0, 0, 0.25), 0.03, 0.7, dark)
			_box(root, Vector3(0, 0, 0.62), Vector3(0.05, 0.05, 0.06), Game.emissive(Color(0.4, 0.8, 1.0), 4.0))
	return root


static func _cyl(root: Node3D, pos: Vector3, r: float, length: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = mat
	mi.rotation.x = PI * 0.5
	mi.position = pos
	root.add_child(mi)
	return mi


static func _box(root: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi


static func draw_icon(ci: CanvasItem, c: Vector2, id: String, s: float, col: Color) -> void:
	## arayüz için çizilmiş silah simgesi (yazı tipine bağlı değil)
	match id:
		"yumruk":
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.3) * s, Vector2(0.9, 0.6) * s), col)
			for k in 4:
				ci.draw_rect(Rect2(c + Vector2(-0.45 + k * 0.23, -0.5) * s, Vector2(0.2, 0.22) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.15) * s, Vector2(0.18, 0.4) * s), col)
		"boru":
			ci.draw_line(c + Vector2(-0.7, 0.5) * s, c + Vector2(0.7, -0.5) * s, col, 0.16 * s)
		"sopa":
			ci.draw_line(c + Vector2(-0.8, 0.6) * s, c + Vector2(0.8, -0.6) * s, col, 0.1 * s)
		"nuncaku":
			ci.draw_line(c + Vector2(-0.7, 0.4) * s, c + Vector2(-0.15, -0.2) * s, col, 0.14 * s)
			ci.draw_line(c + Vector2(0.15, -0.2) * s, c + Vector2(0.7, 0.4) * s, col, 0.14 * s)
			ci.draw_arc(c + Vector2(0, -0.25) * s, 0.15 * s, PI, TAU, 8, col, 0.04 * s)
		"katana":
			ci.draw_line(c + Vector2(-0.75, 0.55) * s, c + Vector2(-0.4, 0.3) * s, col.darkened(0.3), 0.14 * s)
			ci.draw_line(c + Vector2(-0.48, 0.18) * s, c + Vector2(-0.3, 0.42) * s, col, 0.08 * s)
			ci.draw_line(c + Vector2(-0.4, 0.3) * s, c + Vector2(0.8, -0.6) * s, col, 0.08 * s)
		"zincir":
			for k in 5:
				ci.draw_arc(c + Vector2(-0.6 + k * 0.3, sin(k) * 0.15) * s, 0.14 * s, 0, TAU, 10, col, 0.05 * s)
		"shuriken":
			var pts := PackedVector2Array()
			for k in 8:
				var a := k * TAU / 8.0
				pts.append(c + Vector2(cos(a), sin(a)) * (0.6 if k % 2 == 0 else 0.18) * s)
			ci.draw_colored_polygon(pts, col)
		"sok":
			ci.draw_line(c + Vector2(-0.7, 0.5) * s, c + Vector2(0.3, -0.2) * s, col.darkened(0.3), 0.14 * s)
			var b := PackedVector2Array([c + Vector2(0.35, -0.75) * s, c + Vector2(0.1, -0.2) * s, c + Vector2(0.35, -0.25) * s, c + Vector2(0.15, 0.25) * s, c + Vector2(0.6, -0.4) * s, c + Vector2(0.35, -0.35) * s])
			ci.draw_polyline(b, Color(0.5, 0.85, 1.0), 0.06 * s)
		_:
			ci.draw_circle(c, 0.4 * s, col)
