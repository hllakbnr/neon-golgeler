extends Node3D
class_name Pickup
## Yerden alınabilen eşya: para, sağlık, zırh, shuriken. Üzerinden geçince toplanır.

var kind := "para"
var amount := 50
var life := 60.0
var _mesh: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("pickups")
	_mesh = Node3D.new()
	add_child(_mesh)
	match kind:
		"para":
			for k in range(3):
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.32, 0.02, 0.16)
				mi.mesh = bm
				mi.material_override = Game.paint(Color(0.35, 0.75, 0.4), 0.0, 0.6)
				mi.position = Vector3(randf_range(-0.05, 0.05), 0.02 * k, randf_range(-0.05, 0.05))
				mi.rotation.y = randf_range(-0.4, 0.4)
				_mesh.add_child(mi)
		"saglik":
			var c := Game.emissive(Color(1.0, 0.25, 0.3), 2.0)
			_box(Vector3(0.12, 0.36, 0.12), c)
			_box(Vector3(0.36, 0.12, 0.12), c)
		"zirh":
			_box(Vector3(0.36, 0.42, 0.12), Game.paint(Color(0.2, 0.35, 0.8), 0.3, 0.4))
		_:
			var s := Weapons.mesh("shuriken")
			s.scale = Vector3.ONE * 2.0
			_mesh.add_child(s)
	_mesh.position.y = 0.35


func _box(sz: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	_mesh.add_child(mi)


func _process(delta: float) -> void:
	if Game.paused:
		return
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_mesh.rotation.y += delta * 2.0
	_mesh.position.y = 0.35 + sin(_t * 3.0) * 0.06
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl == null or pl.car or pl.combat.dead:
		return
	if pl.global_position.distance_to(global_position) < 1.3:
		_collect(pl)


func _collect(pl: Player) -> void:
	match kind:
		"para":
			Game.money += amount
			Game.notify("+₺%d" % amount, 1.5)
			Sfx.ui("cash", -8.0)
		"saglik":
			pl.combat.heal(amount)
			Sfx.ui("select")
		"zirh":
			pl.combat.armor = minf(100.0, pl.combat.armor + amount)
			Sfx.ui("select")
		_:
			pl.combat.ammo["shuriken"] = int(pl.combat.ammo.get("shuriken", 0)) + amount
			Sfx.ui("select")
	queue_free()
