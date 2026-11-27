extends RefCounted
class_name PropBreaker
## Kırılabilir sokak eşyaları: lamba direkleri, çöp kutuları, banklar, yangın muslukları, saksılar.
## Araçla çarpınca ya da vurunca sabit eşya gizlenir, yerine gerçek fizikli bir kopya düşer
## (kütle, devrilme momenti, sekme). Gözden uzakken bir süre sonra yerine yenisi konur.

const G := 12.0
const MASS := {"lamp": 140.0, "bin": 14.0, "bench": 45.0, "hydrant": 90.0, "plant": 30.0}
var w: World
var grid := {}
var debris: Array = []
var _t := 0.0


func _init(world: World) -> void:
	w = world
	for i in w.breakables.size():
		var b: Dictionary = w.breakables[i]
		if not b.has("pos"):
			b["pos"] = (b.node as Node3D).position if b.has("node") else (b.xf as Transform3D).origin
		if b.has("node"):
			b["rot"] = (b.node as Node3D).rotation
		var p: Vector3 = b.pos
		var k := Vector2i(floori(p.x / G), floori(p.z / G))
		if not grid.has(k):
			grid[k] = []
		(grid[k] as Array).append(i)


func hit(center: Vector3, radius: float, impulse: Vector3) -> bool:
	var any := false
	var k0 := Vector2i(floori((center.x - radius - 1.0) / G), floori((center.z - radius - 1.0) / G))
	var k1 := Vector2i(floori((center.x + radius + 1.0) / G), floori((center.z + radius + 1.0) / G))
	for x in range(k0.x, k1.x + 1):
		for z in range(k0.y, k1.y + 1):
			for i in grid.get(Vector2i(x, z), []):
				var b: Dictionary = w.breakables[i]
				if b.get("broken", false):
					continue
				var p: Vector3 = b.pos
				if Vector2(p.x - center.x, p.z - center.z).length() < radius + float(b.get("r", 0.3)) and absf(center.y - p.y) < 2.5:
					_break(b, impulse)
					any = true
	return any


func _break(b: Dictionary, impulse: Vector3) -> void:
	b["broken"] = true
	var kind: String = b.kind
	var rb := RigidBody3D.new()
	rb.collision_layer = 16
	rb.collision_mask = 1 | 16
	rb.mass = MASS.get(kind, 30.0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.15
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	w.add_child(rb)
	if kind == "lamp":
		var mm: MultiMesh = b.mm
		var xf: Transform3D = b.xf
		mm.set_instance_transform(int(b.idx), Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin - Vector3(0, 50, 0)))
		var mi := MeshInstance3D.new()
		mi.mesh = mm.mesh
		mi.position = Vector3(0, -3.5, 0)
		rb.add_child(mi)
		shape.size = Vector3(0.24, 7.0, 0.24)
		rb.global_transform = Transform3D(xf.basis, xf.origin + Vector3(0, 3.5, 0))
		if b.get("cs"):
			(b.cs as CollisionShape3D).set_deferred("disabled", true)
		var l: OmniLight3D = b.get("light")
		if l:
			l.set_meta("broken", true)
			l.visible = false
		var dir := Vector3(impulse.x, 0, impulse.z)
		rb.apply_impulse(dir * rb.mass * 0.45, Vector3(0, 2.8, 0))
		Sfx.play("metal", b.pos + Vector3(0, 1, 0), 0.0, 0.7)
		Sfx.play("glass", b.pos + Vector3(0, 6, 0), -6.0)
		Fx.sparks(b.pos + Vector3(0, 0.3, 0), Color(1.0, 0.8, 0.4))
	else:
		var n: Node3D = b.node
		var gxf := n.global_transform
		var sb: StaticBody3D = b.get("body")
		if sb:
			for c in sb.get_children():
				if c is CollisionShape3D:
					(c as CollisionShape3D).set_deferred("disabled", true)
		n.get_parent().remove_child(n)
		rb.add_child(n)
		var hgt := 1.0
		match kind:
			"bench":
				shape.size = Vector3(1.6, 0.9, 0.6)
				hgt = 0.9
			"hydrant":
				shape.size = Vector3(0.4, 0.9, 0.4)
				hgt = 0.9
			_:
				shape.size = Vector3(0.6, 1.0, 0.6)
		n.transform = Transform3D(Basis(), Vector3(0, -hgt * 0.5, 0))
		rb.global_transform = Transform3D(gxf.basis, gxf.origin + Vector3(0, hgt * 0.5 + 0.02, 0))
		rb.apply_impulse(impulse * rb.mass * 0.55 + Vector3(0, 2.5, 0) * rb.mass, Vector3(0, hgt * 0.3, 0))
		rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-3, 3), randf_range(-4, 4))
		Sfx.play("metal" if kind != "plant" else "thud", b.pos + Vector3(0, 0.5, 0), -3.0, randf_range(0.8, 1.2))
		if kind == "hydrant":
			Fx.fountain(b.pos + Vector3(0, 0.2, 0), 14.0)
		elif kind == "bin":
			Fx.debris(b.pos + Vector3(0, 0.6, 0), Color(0.75, 0.72, 0.6), 10)
	cs.shape = shape
	rb.add_child(cs)
	debris.append({"b": b, "rb": rb, "t": 0.0})


func tick(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	var cam := w.get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	var i := 0
	while i < debris.size():
		var e: Dictionary = debris[i]
		e.t += 1.0
		var b: Dictionary = e.b
		var rb: RigidBody3D = e.rb
		var far := cp.distance_to(b.pos) > 70.0 and (not is_instance_valid(rb) or cp.distance_to(rb.global_position) > 70.0)
		if e.t > 40.0 and far:
			_restore(b, rb)
			debris.remove_at(i)
			continue
		i += 1


func _restore(b: Dictionary, rb: RigidBody3D) -> void:
	b["broken"] = false
	if b.kind == "lamp":
		(b.mm as MultiMesh).set_instance_transform(int(b.idx), b.xf)
		if b.get("cs"):
			(b.cs as CollisionShape3D).set_deferred("disabled", false)
		var l: OmniLight3D = b.get("light")
		if l:
			l.set_meta("broken", false)
			l.visible = w.night > 0.3
		if is_instance_valid(rb):
			rb.queue_free()
		return
	var n: Node3D = b.node
	if is_instance_valid(n):
		n.get_parent().remove_child(n)
		w.add_child(n)
		n.position = b.pos
		n.rotation = b.get("rot", Vector3.ZERO)
	var sb: StaticBody3D = b.get("body")
	if sb:
		for c in sb.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).set_deferred("disabled", false)
	if is_instance_valid(rb):
		rb.queue_free()
