extends Node3D
class_name Pedestrian
## Kaldırımda dolaşan yaya: blok çevresinde döngü, oyuncuya yol verir,
## yaklaşan araçtan kaçar, çarpılırsa yere düşer ve sonra kalkar.

var path: Array = []
var idx := 0
var speed := 1.35
var slot := "yaya1"
var visual: CharacterVisual
var _down := 0.0          # yerde kalma süresi
var _flee := 0.0
var _flee_dir := Vector3.ZERO
var _vel := Vector3.ZERO  # savrulma hızı
var _lod_t := 0.0
var _far := false         # kameradan uzaksa görünmez, animasyonu durur (FPS)
var _cars: Array = []


func _ready() -> void:
	add_to_group("people")
	visual = CharacterVisual.new()
	add_child(visual)
	visual.setup(slot, Game.slot_default_skin(slot))
	speed = randf_range(1.1, 1.6)
	_lod_t = randf() * 0.5


func _physics_process(delta: float) -> void:
	if path.is_empty() or Game.paused:
		return
	# savrulma / yerde yatma
	if _down > 0.0:
		_down -= delta
		global_position += _vel * delta
		_vel = _vel.move_toward(Vector3.ZERO, delta * 9.0)
		global_position.y = maxf(0.18, global_position.y + _vel.y * delta)
		_vel.y -= 12.0 * delta
		if _down <= 0.0:
			global_position.y = 0.18
			visual.play("idle", 0.4)
		return
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = 0.5
		var cam := get_viewport().get_camera_3d()
		var far := cam != null and cam.global_position.distance_squared_to(global_position) > 120.0 * 120.0
		if far != _far:
			_far = far
			visual.visible = not far
			if visual.anim:
				visual.anim.active = not far
		_cars = get_tree().get_nodes_in_group("cars") + get_tree().get_nodes_in_group("traffic") if not far else []
	if _far:
		var tgt: Vector3 = path[idx]
		var tv := tgt - global_position
		tv.y = 0.0
		if tv.length() < 0.6:
			idx = (idx + 1) % path.size()
		else:
			global_position += tv.normalized() * speed * delta
		return
	for c in _cars:
		if not is_instance_valid(c):
			continue
		var cn := c as Node3D
		var rel := global_position - cn.global_position
		rel.y = 0.0
		var d := rel.length()
		if d > 9.0:
			continue
		var cv := Vector3.ZERO
		if c is RigidBody3D:
			cv = (c as RigidBody3D).linear_velocity
		elif c.get("speed") != null:
			cv = cn.global_transform.basis.z * float(c.speed)
		cv.y = 0.0
		var sp := cv.length()
		# çarpışma: aracın gövdesi içinde ve hızlı
		var lx: float = abs(rel.dot(cn.global_transform.basis.x))
		var lz: float = abs(rel.dot(cn.global_transform.basis.z))
		if lx < 1.4 and lz < 2.3 and sp > 2.5:
			_knock(cv)
			return
		# kaçış: araç bana doğru geliyor
		if sp > 3.0 and d < 7.0 and cv.normalized().dot(-rel.normalized()) > 0.6:
			_flee = 1.2
			_flee_dir = cn.global_transform.basis.x * (1.0 if rel.dot(cn.global_transform.basis.x) > 0 else -1.0)
	if _flee > 0.0:
		_flee -= delta
		global_position += _flee_dir * 4.5 * delta
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(_flee_dir.x, _flee_dir.z), min(1.0, delta * 10.0))
		visual.set_motion(4.5)
		return
	var target: Vector3 = path[idx]
	var to_t := target - global_position
	to_t.y = 0.0
	if to_t.length() < 0.6:
		idx = (idx + 1) % path.size()
		return
	var dir := to_t.normalized()
	var blocked := false
	for p in get_tree().get_nodes_in_group("player"):
		var rel2: Vector3 = (p as Node3D).global_position - global_position
		if rel2.length() < 1.3 and rel2.normalized().dot(dir) > 0.5:
			blocked = true
	if blocked:
		visual.set_motion(0.0)
		return
	global_position += dir * speed * delta
	global_position.y = move_toward(global_position.y, 0.18, delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), min(1.0, delta * 6.0))
	visual.set_motion(speed)


func _knock(car_vel: Vector3) -> void:
	_down = 5.0
	_vel = car_vel * 0.7 + Vector3(0, 3.5, 0)
	visual.play_once("die", 0.05)
