extends Node3D
class_name Pedestrian
## Kaldırımda dolaşan yaya / polis.
##  • Yürür, bazen durup telefonla konuşur ya da sohbet eder
##  • Saldırılınca: cesurlar karşılık verir (dövüşür), çoğu korkup kaçar, bazıları sinip kalır
##  • Suça tanık olursa polisi arar (GTA6'daki gibi: arama bitmeden durdurulursa ihbar olmaz)
##  • Polis rolü: aranıyorsan kovalar, cop / şok tabancası kullanır, tutuklamaya çalışır
##  • Araç çarparsa savrulur; yere düşer, sonra kalkar

enum S { WALK, FLEE, FIGHT, DOWN, DEAD, COWER, CALL, IDLE, FILM }

const RUN := 4.8

var path: Array = []
var idx := 0
var speed := 1.35
var slot := "yaya1"
var role := "civ"               # civ | police
var visual: CharacterVisual
var state := S.WALK
var health := 100.0
var max_health := 100.0
var brave := false
var hostile := false
var threat: Node3D = null
var world: World
var body: AnimatableBody3D      # oyuncunun içinden geçmemesi için çarpışma gövdesi
var body_shape: CollisionShape3D
var call_t := 0.0               # tanık: polisi arama süresi (HUD gösterir)
var call_sev := 0
var call_pos := Vector3.ZERO
var spawned := false            # aranma sistemiyle gelen polis (işi bitince silinir)
var _t := 0.0
var _atk_cd := 0.0
var _down := 0.0
var _vel := Vector3.ZERO
var _lod_t := 0.0
var _far := false
var _cars: Array = []
var _dir := 1
var _phone: Node3D
var _see_t := 0.0
var _taser_cd := 0.0
var _bark_cd := 0.0
var _idle_next := 0.0


func _ready() -> void:
	add_to_group("police" if role == "police" else "people")
	if world == null:
		world = get_parent() as World
	visual = CharacterVisual.new()
	add_child(visual)
	visual.setup(slot, Game.slot_default_skin(slot))
	speed = randf_range(1.1, 1.6)
	_lod_t = randf() * 0.5
	_idle_next = randf_range(20.0, 90.0)
	var r := randf()
	brave = role == "police" or r < 0.3
	if role == "police":
		max_health = 140.0
		health = max_health
		visual.hand_socket().add_child(Weapons.mesh("sok"))
	body = AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 8
	body.collision_mask = 0
	body_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	body_shape.shape = cap
	body_shape.position.y = 0.85
	body.add_child(body_shape)
	body.set_meta("ped", self)
	add_child(body)


func is_down() -> bool:
	return state == S.DEAD or state == S.DOWN


func is_dead() -> bool:
	return state == S.DEAD


func _floor(p: Vector3) -> float:
	return world.city_floor(p) if world else 0.18


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


# ---------------------------------------------------------------- ana döngü
func _physics_process(delta: float) -> void:
	if path.is_empty() or Game.paused:
		return
	_atk_cd -= delta
	_taser_cd -= delta
	_bark_cd -= delta
	if state == S.DEAD:
		_t += delta
		if _t > 25.0 and _lod_check():
			_revive()
		return
	if state == S.DOWN:
		_down -= delta
		var np := global_position + _vel * delta
		global_position = world.walk_step(global_position, np) if world else np
		_vel.x = move_toward(_vel.x, 0.0, delta * 9.0)
		_vel.z = move_toward(_vel.z, 0.0, delta * 9.0)
		_vel.y -= 12.0 * delta
		var fl := _floor(global_position)
		if global_position.y <= fl:
			global_position.y = fl
			_vel.y = 0.0
		if _down <= 0.0:
			body_shape.set_deferred("disabled", false)
			global_position.y = fl
			visual.action("get_up", 1.0)
			state = S.FIGHT if (hostile and threat) else S.FLEE
			_t = randf_range(8.0, 14.0)
		return
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = 0.5
		_update_lod()
	if _far:
		if state != S.WALK:
			_set_walk()
		_path_step(delta, speed, _dir)
		return
	if _car_check():
		return
	match state:
		S.WALK:
			_walk(delta)
		S.IDLE:
			_t -= delta
			visual.set_motion(0.0)
			if _t <= 0.0:
				_set_walk()
		S.FLEE:
			_t -= delta
			if _t <= 0.0:
				_set_walk()
				return
			_path_step(delta, RUN * (0.8 if health < 40.0 else 1.0), _dir)
		S.COWER:
			_t -= delta
			visual.crouch = true
			visual.set_motion(0.0)
			if _t <= 0.0:
				visual.crouch = false
				state = S.FLEE
				_t = randf_range(8.0, 12.0)
		S.CALL:
			_calling(delta)
		S.FILM:
			_t -= delta
			_face(_player().global_position if _player() else global_position, delta)
			visual.play("phone", 0.3)
			if _t <= 0.0:
				_hide_phone()
				_set_walk()
		S.FIGHT:
			_fight(delta)


func _update_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	var far := cam != null and cam.global_position.distance_squared_to(global_position) > 120.0 * 120.0
	if far != _far:
		_far = far
		visual.visible = not far
		body_shape.set_deferred("disabled", far)
		if visual.anim:
			visual.anim.active = not far
	_cars = (get_tree().get_nodes_in_group("cars") + get_tree().get_nodes_in_group("traffic")) if not far else []
	if role == "police":
		_police_think()


func _lod_check() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam == null or cam.global_position.distance_to(global_position) > 70.0


func _set_walk() -> void:
	state = S.WALK
	threat = null
	hostile = false
	visual.crouch = false
	# en yakın yol noktasına dön
	var bd := 1e9
	for k in path.size():
		var d := (path[k] as Vector3).distance_to(global_position)
		if d < bd:
			bd = d
			idx = k


func _walk(delta: float) -> void:
	_idle_next -= delta
	if _idle_next <= 0.0 and role == "civ":
		_idle_next = randf_range(40.0, 120.0)
		state = S.IDLE
		_t = randf_range(6.0, 16.0)
		if randf() < 0.5:
			visual.play("phone" if randf() < 0.5 else "talk", 0.3)
			visual.lock_t = _t
		return
	# oyuncu yolu kapatıyorsa bekle
	var tgt: Vector3 = path[idx]
	var dir := tgt - global_position
	dir.y = 0.0
	var pl := _player()
	if pl and not pl.car:
		var rel: Vector3 = pl.global_position - global_position
		if rel.length() < 1.3 and dir.length() > 0.01 and rel.normalized().dot(dir.normalized()) > 0.5:
			visual.set_motion(0.0)
			return
	_path_step(delta, speed, 1)


func _path_step(delta: float, spd: float, dirsign: int) -> void:
	var target: Vector3 = path[idx]
	var to_t := target - global_position
	to_t.y = 0.0
	if to_t.length() < 0.6:
		idx = (idx + dirsign + path.size()) % path.size()
		return
	var dir := to_t.normalized()
	var np := global_position + dir * spd * delta
	global_position = world.walk_step(global_position, np) if world else np
	global_position.y = move_toward(global_position.y, _floor(global_position), delta * 2.0)
	if not _far:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 8.0))
		visual.set_motion(spd)


func _move_to(p: Vector3, spd: float, delta: float, stop := 0.0) -> float:
	var rel := p - global_position
	rel.y = 0.0
	var d := rel.length()
	if d > stop:
		var dir := rel / maxf(d, 0.001)
		var np := global_position + dir * minf(spd * delta, d - stop)
		global_position = world.walk_step(global_position, np) if world else np
		global_position.y = move_toward(global_position.y, _floor(global_position), delta * 2.0)
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 10.0))
		visual.set_motion(spd)
	else:
		visual.set_motion(0.0)
	return d


func _face(p: Vector3, delta: float) -> void:
	var rel := p - global_position
	if Vector2(rel.x, rel.z).length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(rel.x, rel.z), minf(1.0, delta * 10.0))


# ---------------------------------------------------------------- araçlar
func _car_check() -> bool:
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
			if c is TrafficCar and (c as TrafficCar).freeze:
				cv = cn.global_transform.basis.z * (c as TrafficCar).speed
		cv.y = 0.0
		var sp := cv.length()
		var lx: float = absf(rel.dot(cn.global_transform.basis.x))
		var lz: float = absf(rel.dot(cn.global_transform.basis.z))
		if lx < 1.4 and lz < 2.3 and sp > 2.5:
			var driver := c is Car and (c as Car).driven
			take_hit(sp * 4.5, cn.global_position, true, _player() if driver else null, 0.0, cv)
			if driver and Wanted.inst:
				Wanted.inst.crime("ezme", global_position, 2 if state == S.DEAD else 1, self)
			return true
		if sp > 3.0 and d < 7.0 and cv.normalized().dot(-rel.normalized()) > 0.6 and state != S.DOWN:
			var side := cn.global_transform.basis.x * (1.0 if rel.dot(cn.global_transform.basis.x) > 0 else -1.0)
			global_position = world.walk_step(global_position, global_position + side * 4.5 * get_physics_process_delta_time()) if world else global_position + side * 4.5 * get_physics_process_delta_time()
			visual.rotation.y = atan2(side.x, side.z)
			visual.set_motion(4.5)
			return true
	return false


# ---------------------------------------------------------------- hasar
func take_hit(dmg: float, from: Vector3, heavy: bool, attacker: Node = null, stun_t := 0.0, push := Vector3.ZERO) -> void:
	if state == S.DEAD:
		return
	health -= dmg
	_hide_phone()
	call_t = 0.0
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var att := attacker as Node3D
	if att and Wanted.inst and att.is_in_group("player"):
		Wanted.inst.crime("saldırı" if role == "civ" else "polise saldırı", global_position, 1 if role == "civ" else 2, self)
	_alarm_others(att)
	if health <= 0.0:
		_die(away * (6.0 if heavy else 3.0) + push * 0.6 + Vector3(0, 3.0 if heavy or push != Vector3.ZERO else 1.0, 0))
		return
	if heavy or stun_t > 0.0 or push != Vector3.ZERO:
		_knock(away * (5.0 if heavy else 2.0) + push * 0.6 + Vector3(0, 3.0, 0), 2.2 + stun_t)
	else:
		visual.action("hit", 1.1)
		global_position = world.walk_step(global_position, global_position + away * 0.35) if world else global_position + away * 0.35
	threat = att
	if att == null:
		return
	if role == "police" or (brave and health > max_health * 0.3):
		hostile = true
		if state != S.DOWN:
			state = S.FIGHT
		_bark("tehdit")
	elif state != S.DOWN:
		_start_flee(att)
		_bark("korku")


func _knock(v: Vector3, t: float) -> void:
	state = S.DOWN
	_down = t
	_vel = v
	body_shape.set_deferred("disabled", true)
	visual.action("knockback", 1.0, 0.05, t + 1.0)


func _die(v: Vector3) -> void:
	state = S.DEAD
	_t = 0.0
	_vel = v
	health = 0.0
	hostile = false
	body_shape.set_deferred("disabled", true)
	visual.action("die", 1.0, 0.05, 999.0)
	var tw := create_tween()
	var dest := Vector3(global_position.x + v.x * 0.35, 0.0, global_position.z + v.z * 0.35)
	if world:
		dest = world.walk_step(global_position, dest)
	dest.y = _floor(dest)
	tw.tween_property(self, "global_position", dest, 0.5).set_ease(Tween.EASE_OUT)
	# yere düşen para (GTA'daki gibi toplanabilir)
	if randf() < 0.75:
		var pk := Pickup.new()
		pk.kind = "para"
		pk.amount = randi_range(10, 120) if role == "civ" else randi_range(40, 160)
		get_parent().add_child(pk)
		pk.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6))
	if Wanted.inst and threat and threat.is_in_group("player"):
		Wanted.inst.crime("cinayet" if role == "civ" else "polis öldürme", global_position, 2 if role == "civ" else 4, self)


func _revive() -> void:
	## gözden uzakta: yeni bir yaya olarak yolun başında belirir
	if spawned:
		queue_free()
		return
	health = max_health
	state = S.WALK
	threat = null
	hostile = false
	idx = randi() % path.size()
	global_position = path[idx]
	body_shape.set_deferred("disabled", false)
	visual.lock_t = 0.0
	visual.play("idle", 0.0)


func _alarm_others(att: Node3D) -> void:
	## yakındakiler tepki verir: çoğu kaçar, bazıları telefonla çeker ya da polisi arar
	if att == null or not att.is_in_group("player"):
		return
	for n in get_tree().get_nodes_in_group("people"):
		var o := n as Pedestrian
		if o == null or o == self or o.is_down() or o.state == S.FIGHT or o.state == S.CALL:
			continue
		var d := o.global_position.distance_to(global_position)
		if d > 18.0:
			continue
		o.react(att, d)


func react(att: Node3D, d: float) -> void:
	if state == S.FLEE or state == S.COWER or state == S.FILM:
		return
	var r := randf()
	if r < 0.12 and d > 6.0:
		state = S.FILM
		_t = randf_range(5.0, 9.0)
		_show_phone()
	elif r < 0.28 and d < 8.0:
		state = S.COWER
		_t = randf_range(2.5, 5.0)
		_bark("korku")
	else:
		_start_flee(att)


func _start_flee(att: Node3D) -> void:
	state = S.FLEE
	visual.crouch = false
	_t = randf_range(9.0, 15.0)
	threat = att
	# yol boyunca tehditten uzaklaşan yönü seç
	var a: Vector3 = path[(idx + 1) % path.size()]
	var b: Vector3 = path[(idx - 1 + path.size()) % path.size()]
	var tp := att.global_position if att else global_position
	_dir = 1 if a.distance_to(tp) > b.distance_to(tp) else -1
	idx = (idx + (1 if _dir > 0 else 0)) % path.size()
	if _dir < 0:
		idx = (idx - 1 + path.size()) % path.size()


# ---------------------------------------------------------------- dövüş
func _fight(delta: float) -> void:
	var pl := _player()
	if threat == null or not is_instance_valid(threat) or (threat.has_method("is_down") and threat.is_down()):
		_set_walk()
		return
	if threat == pl and (pl.car or pl.combat.dead):
		if role == "police" and pl.car:
			visual.set_motion(0.0)
			return
		_set_walk()
		return
	var d := global_position.distance_to(threat.global_position)
	if d > (60.0 if role == "police" else 25.0):
		_set_walk()
		return
	if role == "civ" and health < max_health * 0.25:
		_start_flee(threat)
		return
	# şok tabancası (3+ yıldız)
	if role == "police" and Wanted.inst and Wanted.inst.stars >= 3 and d > 4.0 and d < 11.0 and _taser_cd <= 0.0:
		_taser_cd = 5.0
		_face(threat.global_position, 1.0)
		visual.action("spell", 1.2)
		var tgt := threat
		get_tree().create_timer(0.35).timeout.connect(func():
			if is_instance_valid(tgt) and not is_down() and tgt.global_position.distance_to(global_position) < 12.0:
				Sfx.play("zap", tgt.global_position, -2.0)
				Fx.bolt(global_position + Vector3(0, 1.3, 0), tgt.global_position + Vector3(0, 1.0, 0), Color(0.5, 0.8, 1.0))
				if tgt.has_method("take_hit"):
					tgt.take_hit(4.0, global_position, false, self, 2.2))
		return
	if visual.lock_t > 0.0:
		return
	if d > 1.35:
		_move_to(threat.global_position, RUN * (1.05 if role == "police" else 0.95), delta, 1.1)
		return
	_face(threat.global_position, delta)
	visual.set_motion(0.0)
	if _atk_cd <= 0.0:
		_atk_cd = randf_range(1.0, 1.7) if role == "civ" else randf_range(0.9, 1.3)
		var an: String = (["punch_jab", "punch_cross", "hook"] as Array)[randi() % 3] if role == "civ" else (["sword_a", "sword_b"] as Array)[randi() % 2]
		var L := clampf(visual.action(an, 1.0), 0.3, 1.2)
		var tgt := threat
		get_tree().create_timer(L * 0.4).timeout.connect(func():
			if is_instance_valid(tgt) and not is_down() and tgt.global_position.distance_to(global_position) < 1.8 and tgt.has_method("take_hit"):
				tgt.take_hit(randf_range(5.0, 9.0) if role == "civ" else randf_range(7.0, 11.0), global_position, false, self, 0.0))


# ---------------------------------------------------------------- tanıklık / polis
func start_call(sev: int, pos: Vector3) -> void:
	state = S.CALL
	call_t = randf_range(4.5, 7.0)
	call_sev = sev
	call_pos = pos
	_show_phone()
	_bark("polis")


func _calling(delta: float) -> void:
	call_t -= delta
	var pl := _player()
	if pl:
		_face(pl.global_position, delta)
		# oyuncu çok yaklaşırsa telefonu bırakıp kaçabilir
		if pl.global_position.distance_to(global_position) < 2.0 and randf() < delta * 0.8:
			_hide_phone()
			call_t = 0.0
			_start_flee(pl)
			return
	visual.play("phone", 0.3)
	if call_t <= 0.0:
		_hide_phone()
		if Wanted.inst:
			Wanted.inst.report(call_sev, call_pos)
		_start_flee(pl)


func _show_phone() -> void:
	if _phone and is_instance_valid(_phone):
		return
	_phone = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.14, 0.012)
	(_phone as MeshInstance3D).mesh = bm
	(_phone as MeshInstance3D).material_override = Game.emissive(Color(0.6, 0.8, 1.0), 1.5)
	visual.hand_socket().add_child(_phone)


func _hide_phone() -> void:
	if _phone and is_instance_valid(_phone):
		_phone.queue_free()
	_phone = null


func _police_think() -> void:
	## polis: aranıyorsan ve seni görüyorsa kovalar
	if not Wanted.inst or is_down():
		return
	var pl := _player()
	if pl == null:
		return
	var d := pl.global_position.distance_to(global_position)
	if Wanted.inst.stars <= 0:
		if state == S.FIGHT and threat == pl:
			_set_walk()
		if spawned and d > 80.0:
			queue_free()
		return
	var sees := d < 42.0 and _line_of_sight(pl)
	if sees:
		Wanted.inst.spotted(pl.global_position)
		if state != S.FIGHT:
			state = S.FIGHT
			threat = pl
			hostile = true
			_bark("dur")
	elif state != S.FIGHT and spawned:
		# son görülen yere koş
		state = S.FIGHT
		threat = pl


func _line_of_sight(pl: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.6, 0), pl.global_position + Vector3(0, 1.2, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _bark(kind: String) -> void:
	if _bark_cd > 0.0 or _far:
		return
	_bark_cd = 4.0
	Barks.say(kind, global_position + Vector3(0, 1.6, 0), is_male(), role == "police")


func is_male() -> bool:
	return not (slot.trim_prefix("yaya").to_int() % 2 == 0 and slot.begins_with("yaya"))
