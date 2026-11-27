extends Node3D
class_name Shuriken
## Fırlatılan shuriken: ışın taramasıyla isabet, yayaya hasar verir, duvara saplanır.

var vel := Vector3.ZERO
var dmg := 18.0
var owner_node: Node = null
var _life := 3.0
var _stuck := false
var _mesh: Node3D


func _ready() -> void:
	_mesh = Weapons.mesh("shuriken")
	_mesh.scale = Vector3.ONE * 1.4
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _stuck:
		return
	_mesh.rotate_object_local(Vector3.FORWARD, delta * 40.0)
	vel.y -= 2.0 * delta
	var to := global_position + vel * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, to, 1 | 8)
	if owner_node is CollisionObject3D:
		q.exclude = [(owner_node as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	global_position = hit.position
	var col: Object = hit.collider
	if col and col.has_meta("ped"):
		var ped = col.get_meta("ped")
		if is_instance_valid(ped) and ped.has_method("take_hit"):
			ped.take_hit(dmg, global_position - vel.normalized() * 3.0, false, owner_node, 0.0)
			Sfx.play("punch", global_position, -6.0, 1.6)
		queue_free()
		return
	Sfx.play("metal", global_position, -10.0, 2.2)
	_stuck = true
	_life = 6.0
