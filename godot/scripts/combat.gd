extends Node
class_name Combat
## Oyuncunun dövüş sistemi
##  • Sol tık: hafif saldırı (kombo zinciri) · Q: ağır saldırı · V: blok · sağ tık: hedefe kilitlen
##  • Dayanıklılık (stamina): her saldırı harcar, yorgunken darbeler zayıf ve yavaş
##  • Fare tekerleği / Tab: silah değiştir · shuriken fırlatılır (cephane)
##  • Can / zırh: can yarıya kadar kendiliğinden dolar; bayılınca hastanede uyanılır

signal weapon_changed(id: String)
signal died

var p: Player
var health := 100.0
var armor := 0.0
var stamina := 100.0
var max_stamina := 100.0
var dmg_mult := 1.0
var boost := 0.0                # enerji içeceği: süresince dayanıklılık bitmez
var weapon := "yumruk"
var owned: Array = []
var ammo := {"shuriken": 40}
var blocking := false
var target: Node3D = null
var dead := false
var stun := 0.0
var busy := 0.0
var lunge := Vector3.ZERO
var _lunge_t := 0.0
var _combo := 0
var _combo_t := 0.0
var _hits: Array = []
var _stam_wait := 0.0
var _regen_wait := 0.0
var _model: Node3D
var _queued := false
var _lock := false
var _wheel: Node = null


func _init(player: Player) -> void:
	p = player
	owned = Weapons.ORDER.duplicate()


func equip(id: String) -> void:
	if not owned.has(id):
		return
	weapon = id
	if _model and is_instance_valid(_model):
		_model.queue_free()
	_model = null
	if id != "yumruk" and p.visual:
		var sock := p.visual.hand_socket()
		if sock:
			_model = Weapons.mesh(id)
			sock.add_child(_model)
	var w := Weapons.info(id)
	if p.visual:
		p.visual.idle_anim = String(w.get("idle", "idle"))
	weapon_changed.emit(id)


func cycle(dir: int) -> void:
	var i := owned.find(weapon)
	equip(owned[(i + dir + owned.size()) % owned.size()])


func refresh_model() -> void:
	## karakter modeli değişince silah yeni ele takılır, aksesuarlar yeniden giyilir
	equip(weapon)
	if p.visual and not Game.accessories.is_empty():
		p.visual.set_accessories(Game.accessories)


# ---------------------------------------------------------------- her kare
func tick(delta: float, on_foot: bool) -> void:
	if dead:
		return
	stun = maxf(0.0, stun - delta)
	busy = maxf(0.0, busy - delta)
	_combo_t -= delta
	_lunge_t -= delta
	_stam_wait -= delta
	boost = maxf(0.0, boost - delta)
	if boost > 0.0:
		stamina = max_stamina
	if _stam_wait <= 0.0 and not blocking:
		stamina = minf(max_stamina, stamina + 24.0 * delta)
	_regen_wait -= delta
	if _regen_wait <= 0.0 and health < 50.0:
		health = minf(50.0, health + 3.0 * delta)
	var i := 0
	while i < _hits.size():
		var h: Dictionary = _hits[i]
		h.t -= delta
		if h.t <= 0.0:
			_hits.remove_at(i)
			if on_foot:
				_apply(h)
		else:
			i += 1
	if _model and is_instance_valid(_model) and Weapons.info(weapon).get("twirl", false):
		if busy <= 0.0 and not blocking:
			_model.rotation.x += delta * 16.0
		else:
			_model.rotation.x = 0.0
	if not on_foot:
		blocking = false
		target = null
		return
	if target and (not is_instance_valid(target) or not target.is_inside_tree() or _is_down(target) or target.global_position.distance_to(p.global_position) > 14.0):
		target = null
	var can := p.controls and not Game.paused and stun <= 0.0 and p.phone == null and p.talk == null and not (p.powers and p.powers.spinning())
	if not can:
		blocking = false
		return
	blocking = Input.is_action_pressed("block") and stamina > 3.0 and busy <= 0.05
	if blocking:
		_stam_wait = 0.4
		p.visual.play("block", 0.12)
		p.visual.lock_t = 0.12
	_lock = Input.is_action_pressed("aim")
	if _lock and target == null:
		target = _best_target(14.0, true)
	elif not _lock and busy <= 0.0 and _combo_t <= -1.5:
		target = null
	if Input.is_action_just_pressed("attack"):
		if busy > 0.18:
			_queued = true
		else:
			_attack(false)
	elif Input.is_action_just_pressed("heavy_attack") and busy <= 0.18:
		_attack(true)
	if _queued and busy <= 0.12:
		_queued = false
		_attack(false)
	if Input.is_action_just_pressed("weapon_wheel") and (_wheel == null or not is_instance_valid(_wheel)):
		_open_wheel()
	if busy <= 0.0:
		if Input.is_action_just_pressed("weapon_next"):
			cycle(1)
		elif Input.is_action_just_pressed("weapon_prev"):
			cycle(-1)


func _open_wheel() -> void:
	var wh := GearWheel.new()
	wh.player = p
	get_tree().current_scene.add_child(wh)
	_wheel = wh


func locked() -> bool:
	return _lock and target != null


func move_scale() -> float:
	## saldırı / blok sırasında yürüme yavaşlar
	if stun > 0.0 or dead:
		return 0.0
	if busy > 0.0:
		return 0.15
	if blocking:
		return 0.35
	return float(Weapons.info(weapon).get("move", 1.0))


func lunge_velocity() -> Vector3:
	return lunge if _lunge_t > 0.0 else Vector3.ZERO


# ---------------------------------------------------------------- saldırı
func _attack(heavy: bool) -> void:
	if busy > 0.18 or stun > 0.0:
		return
	var w := Weapons.info(weapon)
	if _wheel and is_instance_valid(_wheel):
		return
	var cost: float = float(w.cost) * (2.0 if heavy else 1.0)
	var weak := stamina < cost
	if not target:
		target = _best_target(4.5, false)
	var face := _face_dir()
	if target:
		var rel := target.global_position - p.global_position
		rel.y = 0.0
		if rel.length() > 0.1:
			face = rel.normalized()
	p.visual.rotation.y = atan2(face.x, face.z)
	if String(w.kind) == "throw":
		if int(ammo.get(weapon, 0)) <= 0:
			Game.notify("Shuriken kalmadı — Kılıç & Yıldız dükkânından alabilirsin.")
			cycle(-1)
			return
		ammo[weapon] = int(ammo[weapon]) - 1
		stamina = maxf(0.0, stamina - cost)
		_stam_wait = 0.6
		var L := clampf(p.visual.action("throw", 1.7), 0.3, 0.9)
		busy = L * 0.7
		var tgt := target
		get_tree().create_timer(L * 0.35).timeout.connect(func(): _throw(face, tgt, float(w.dmg)))
		if heavy and int(ammo.get(weapon, 0)) >= 2:
			ammo[weapon] = int(ammo[weapon]) - 2
			for sgn in [-1.0, 1.0]:
				var fd := face.rotated(Vector3.UP, sgn * 0.22)
				get_tree().create_timer(L * 0.35).timeout.connect(func(): _throw(fd, null, float(w.dmg)))
		Sfx.play("whoosh", p.global_position, 0.0, 1.4)
		return
	stamina = maxf(0.0, stamina - cost)
	_stam_wait = 0.9
	var anim_name: String
	if heavy:
		anim_name = String(w.heavy)
		_combo = 0
	else:
		if _combo_t <= 0.0:
			_combo = 0
		var combo: Array = w.combo
		anim_name = String(combo[_combo % combo.size()])
		_combo += 1
	var spd: float = float(w.speed) * (0.7 if weak else 1.0) * (0.85 if heavy else 1.0)
	var L := clampf(p.visual.action(anim_name, spd), 0.35, 1.7)
	p.visual.lock_t = L
	busy = L * (0.85 if heavy else 0.72)
	_combo_t = L + 0.5
	var dmg: float = float(w.dmg) * (1.9 if heavy else 1.0) * (0.5 if weak else 1.0) * dmg_mult
	var rng: float = float(w.range)
	var st: float = float(w.get("stun", 0.0))
	lunge = face * (3.2 if heavy else 2.0)
	_lunge_t = 0.16
	var fx := String(w.get("fx", "")) if heavy else ""
	match fx:
		"flurry":
			for k in range(4):
				_hits.append({"t": L * (0.18 + 0.17 * k), "dmg": dmg * 0.35, "range": rng, "heavy": k == 3, "stun": st})
		"dash":
			# ileri atılarak vuruş
			lunge = face * 9.0
			_lunge_t = 0.22
			_hits.append({"t": L * 0.3, "dmg": dmg, "range": rng + 1.2, "heavy": true, "stun": st})
		"smash":
			# iki elle yere vuruş: çevresindeki herkes savrulur
			_hits.append({"t": L * 0.5, "dmg": dmg, "range": rng + 0.8, "heavy": true, "stun": st, "arc": true, "fx": "smash"})
		"spin":
			# 360° dönerek savurma
			var tw := p.visual.create_tween()
			var r0 := p.visual.rotation.y
			tw.tween_property(p.visual, "rotation:y", r0 + TAU, L * 0.6).set_delay(L * 0.15)
			for k in range(2):
				_hits.append({"t": L * (0.35 + 0.25 * k), "dmg": dmg * 0.6, "range": rng + 0.4, "heavy": k == 1, "stun": st, "arc": true})
		"zap":
			_hits.append({"t": L * 0.4, "dmg": dmg, "range": rng + 2.0, "heavy": false, "stun": 2.8, "fx": "zap"})
		_:
			if anim_name == "sword_combo":
				for k in range(3):
					_hits.append({"t": L * (0.25 + 0.22 * k), "dmg": dmg * 0.45, "range": rng, "heavy": k == 2, "stun": st})
			else:
				_hits.append({"t": L * (0.42 if heavy else 0.36), "dmg": dmg, "range": rng, "heavy": heavy, "stun": st})
	Sfx.play("whoosh", p.global_position, -4.0, randf_range(0.9, 1.15) * (0.8 if heavy else 1.0))


func _face_dir() -> Vector3:
	var lw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if lw.length() > 0.2:
		return (Basis(Vector3.UP, p.yaw) * Vector3(lw.x, 0, lw.y)).normalized()
	var r := p.visual.rotation.y
	return Vector3(sin(r), 0, cos(r))


func _apply(h: Dictionary) -> void:
	var fwd := Vector3(sin(p.visual.rotation.y), 0, cos(p.visual.rotation.y))
	var hit := false
	for t in _targets():
		var tn := t as Node3D
		var rel := tn.global_position - p.global_position
		rel.y = 0.0
		var d := rel.length()
		if d > float(h.range) + 0.45 or absf(tn.global_position.y - p.global_position.y) > 1.6:
			continue
		if d > 0.35 and not h.get("arc", false) and fwd.dot(rel / d) < 0.2:
			continue
		t.take_hit(float(h.dmg), p.global_position, bool(h.heavy), p, float(h.stun))
		hit = true
	match String(h.get("fx", "")):
		"smash":
			Fx.ring(p.global_position + Vector3(0, 0.1, 0), Color(1, 0.9, 0.7), 4.0, 0.4)
			Fx.dust(p.global_position, 1.6)
			p.shake(0.3)
		"zap":
			Fx.bolt(p.global_position + Vector3(0, 1.3, 0), p.global_position + fwd * (float(h.range)) + Vector3(0, 1.1, 0), Color(0.5, 0.85, 1.0))
			Sfx.play("zap", p.global_position, -2.0)
	# kırılabilir eşyalar (çöp kutusu, lamba…)
	var w := p.world
	if w and w.has_method("hit_props"):
		if w.hit_props(p.global_position + fwd * 0.9 + Vector3(0, 0.9, 0), float(h.range) * 0.8, fwd * (7.0 if h.heavy else 4.5)):
			hit = true
	if hit:
		p.shake(0.14 if h.heavy else 0.08)
		Sfx.play("punch_heavy" if h.heavy else "punch", p.global_position, 0.0, randf_range(0.9, 1.1))
		Game.hitstop(0.07 if h.heavy else 0.04)


func _throw(dir: Vector3, tgt: Node3D, dmg: float) -> void:
	if not is_instance_valid(p):
		return
	var from := p.global_position + Vector3(0, 1.4, 0) + dir * 0.5
	var aim := dir
	if tgt and is_instance_valid(tgt):
		aim = (tgt.global_position + Vector3(0, 1.1, 0) - from).normalized()
	else:
		# kamera merkezine nişan
		var cam := p.cam
		var vp := p.get_viewport().get_visible_rect().size * 0.5
		var o := cam.project_ray_origin(vp)
		var n := cam.project_ray_normal(vp)
		var hitp := o + n * 40.0
		aim = (hitp - from).normalized()
	var s := Shuriken.new()
	s.dmg = dmg
	s.vel = aim * 32.0
	s.owner_node = p
	p.get_parent().add_child(s)
	s.global_position = from


func _targets() -> Array:
	var out := []
	for g in ["people", "police", "dummies"]:
		for n in get_tree().get_nodes_in_group(g):
			if n.has_method("take_hit") and not _is_down(n):
				out.append(n)
	return out


func _is_down(n: Node) -> bool:
	return n.has_method("is_down") and n.is_down()


func _best_target(max_d: float, camera_based: bool) -> Node3D:
	var best: Node3D = null
	var bs := -1e9
	var fwd := _face_dir()
	if camera_based:
		fwd = -p.cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
	for t in _targets():
		var tn := t as Node3D
		var rel := tn.global_position - p.global_position
		rel.y = 0.0
		var d := rel.length()
		if d > max_d or d < 0.01:
			continue
		var dot := fwd.dot(rel / d)
		if dot < (0.55 if camera_based else 0.1):
			continue
		var s := dot * 2.0 - d / max_d + (0.6 if t.get("hostile") else 0.0)
		if s > bs:
			bs = s
			best = tn
	return best


# ---------------------------------------------------------------- hasar alma
func take_hit(dmg: float, from: Vector3, heavy: bool, attacker: Node = null, stun_t := 0.0) -> void:
	if dead:
		return
	var rel := from - p.global_position
	rel.y = 0.0
	var facing := Vector3(sin(p.visual.rotation.y), 0, cos(p.visual.rotation.y))
	if blocking and rel.length() > 0.01 and facing.dot(rel.normalized()) > 0.2:
		stamina = maxf(0.0, stamina - dmg * (1.6 if heavy else 1.0))
		_stam_wait = 0.8
		dmg *= 0.15
		Sfx.play("block", p.global_position, -2.0)
		if stamina <= 0.0:
			blocking = false
			stun = 0.8
			p.visual.action("hit", 1.0)
	else:
		if stun_t > 0.0:
			stun = maxf(stun, stun_t)
		p.visual.action("knockback" if heavy else "hit", 1.15)
		busy = 0.0
		_hits.clear()
		if heavy and rel.length() > 0.01:
			p.velocity += -rel.normalized() * 5.0 + Vector3(0, 2.0, 0)
		Sfx.play("punch", p.global_position, -3.0, 0.8)
	var a := minf(armor, dmg * 0.7)
	armor -= a
	health -= dmg - a
	_regen_wait = 6.0
	p.shake(0.18 if heavy else 0.1)
	if attacker and attacker != p and (not target or not is_instance_valid(target)):
		target = attacker as Node3D
	if health <= 0.0:
		die("BAYILDIN")


func heal(v: float) -> void:
	health = minf(100.0, health + v)


func die(title: String) -> void:
	if dead:
		return
	dead = true
	health = 0.0
	blocking = false
	_hits.clear()
	if p.car:
		p.exit_car()
	if p.mount:
		p.mount.dismiss()
	p.visual.action("die", 1.0, 0.1, 99.0)
	died.emit()
	Game.big_message(title, Color(1.0, 0.25, 0.3) if title == "BAYILDIN" else Color(0.4, 0.6, 1.0))
	await get_tree().create_timer(4.5).timeout
	if not is_instance_valid(p):
		return
	var w := p.world
	var spot := Vector3.ZERO
	if w:
		spot = w.respawn_point("hospital" if title == "BAYILDIN" else "police")
	var fee := mini(Game.money, 250 if title == "BAYILDIN" else 400)
	Game.money -= fee
	p.global_position = spot
	p.velocity = Vector3.ZERO
	health = 100.0
	stamina = max_stamina
	stun = 0.0
	dead = false
	p.visual.lock_t = 0.0
	p.visual.play("idle", 0.0)
	Game.notify(("Hastane faturası" if title == "BAYILDIN" else "Kefalet") + ": ₺" + str(fee))
