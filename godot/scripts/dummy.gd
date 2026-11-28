extends Node3D
class_name Dummy
## Dojo antrenman mankeni: vurulunca sallanır, isabetleri sayar.

var hits := 0
var _post: Node3D


func _ready() -> void:
	add_to_group("dummies")
	_post = Node3D.new()
	add_child(_post)
	var wood := Game.paint(Color(0.55, 0.36, 0.2), 0.0, 0.8)
	var straw := Game.paint(Color(0.85, 0.72, 0.4), 0.0, 0.95)
	_part(Vector3(0, 0.7, 0), Vector3(0.14, 1.4, 0.14), wood)
	_part(Vector3(0, 1.2, 0), Vector3(0.5, 0.75, 0.32), straw)
	_part(Vector3(0, 1.72, 0), Vector3(0.3, 0.3, 0.3), straw)
	_part(Vector3(0, 1.35, 0), Vector3(1.1, 0.1, 0.1), wood)
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.4
	cm.height = 0.12
	base.mesh = cm
	base.material_override = wood
	base.position.y = 0.06
	add_child(base)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.38
	cap.height = 1.9
	cs.shape = cap
	cs.position.y = 0.95
	sb.add_child(cs)
	add_child(sb)


func _part(p: Vector3, s: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	_post.add_child(mi)


func is_down() -> bool:
	return false


func take_hit(dmg: float, from: Vector3, heavy: bool, _attacker: Node = null, _stun := 0.0) -> void:
	hits += 1
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var ax := away.cross(Vector3.UP).normalized()
	var amt := clampf(dmg / 60.0, 0.08, 0.45) * (1.5 if heavy else 1.0)
	var tw := create_tween()
	tw.tween_property(_post, "basis", Basis(ax, -amt), 0.08)
	tw.tween_property(_post, "basis", Basis(ax, amt * 0.5), 0.18)
	tw.tween_property(_post, "basis", Basis(), 0.3).set_trans(Tween.TRANS_ELASTIC)
	Sfx.play("thud", global_position + Vector3(0, 1.2, 0), -2.0, randf_range(0.9, 1.2))
	Fx.debris(global_position + Vector3(0, 1.3, 0), Color(0.85, 0.72, 0.4), 6)
