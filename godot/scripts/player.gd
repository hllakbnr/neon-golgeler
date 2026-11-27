extends CharacterBody3D
class_name Player
## Kaan Demir: GTA tarzı omuz üstü kamera, yürü / hafif koş / koş, zıplama, araca binme.

signal entered_vehicle(car)
signal exited_vehicle

const WALK := 1.8
const FAST_WALK := 3.0
const JOG := 4.6
const SPRINT := 7.4
const JUMP := 4.8
const GRAVITY := 18.0

var visual: CharacterVisual
var rig: Node3D          # kamera kökü (dünya uzayında, gecikmeli takip)
var yaw_node: Node3D
var pitch_node: Node3D
var arm: SpringArm3D
var cam: Camera3D
var yaw := PI
var pitch := -0.18
var car: Car = null
var world: World
var controls := true
var _shake := 0.0
var _safe := Vector3.ZERO        # son güvenli kara noktası (denize düşünce geri dönülür)
var _safe_car := Transform3D()
var _safe_t := 0.0
var combat: Combat
var talk: TalkMenu = null
var phone: Phone = null
var powers: Powers
var mount: Dragon = null
var _was_floor := true
var _fall_v := 0.0
var _lean := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_mask = 1 | 8          # 8: yayalar (içlerinden geçilmez)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	visual = CharacterVisual.new()
	add_child(visual)
	visual.setup("kaan", Game.slot_default_skin("kaan"))
	combat = Combat.new(self)
	combat.name = "Dovus"
	add_child(combat)
	visual.rebuilt.connect(combat.refresh_model)
	powers = Powers.new(self)
	powers.name = "Gucler"
	add_child(powers)
	# kamera düzeni
	rig = Node3D.new()
	yaw_node = Node3D.new()
	pitch_node = Node3D.new()
	arm = SpringArm3D.new()
	arm.spring_length = 3.1
	arm.margin = 0.35
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	arm.shape = sphere
	arm.add_excluded_object(get_rid())
	cam = Camera3D.new()
	cam.near = 0.12
	cam.fov = Game.settings.fov
	cam.far = 1500.0
	cam.h_offset = 0.55
	get_parent().add_child.call_deferred(rig)
	rig.add_child(yaw_node)
	yaw_node.add_child(pitch_node)
	pitch_node.add_child(arm)
	arm.add_child(cam)
	await get_tree().process_frame
	rig.global_position = global_position + Vector3(0, 1.55, 0)
	cam.make_current()
	Game.settings_changed.connect(func(): cam.fov = Game.settings.fov)


func _unhandled_input(e: InputEvent) -> void:
	if not controls or Game.paused:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = 0.0025 * Game.settings.sens
		yaw -= e.relative.x * s
		pitch -= e.relative.y * s * (-1.0 if Game.settings.invert_y else 1.0)
		pitch = clamp(pitch, -1.1, 0.6)


func _physics_process(delta: float) -> void:
	# sağ çubuk ile kamera
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(rx) > 0.15:
		yaw -= rx * 2.6 * delta * Game.settings.sens
	if abs(ry) > 0.15:
		pitch = clamp(pitch - ry * 2.0 * delta * Game.settings.sens, -1.1, 0.6)
	_safe_t -= delta
	if controls and not Game.paused and phone == null and not combat.dead and Input.is_action_just_pressed("phone"):
		phone = Phone.new()
		phone.player = self
		get_parent().add_child(phone)
	if mount and is_instance_valid(mount):
		combat.tick(delta, false)
		powers.tick(delta)
		global_position = mount.seat()
		velocity = Vector3.ZERO
		visual.global_rotation = Vector3(0, mount.yaw, 0)
		visual.play("sit", 0.2)
		visual.lock_t = 0.1
		var dk: float = clampf(mount.speed / 40.0, 0.0, 1.0)
		_follow_cam(delta, mount.global_position + Vector3(0, 2.2, 0), lerpf(9.0, 12.0, dk), 0.0)
		cam.fov = lerp(cam.fov, Game.settings.fov + 12.0 * dk, delta * 2.0)
		return
	if car:
		combat.tick(delta, false)
		if car.global_position.y < World.SEA - 1.0:
			_rescue_car()
		elif _safe_t <= 0.0 and car.global_position.y > World.SEA + 0.6 and car.global_transform.basis.y.y > 0.85:
			_safe_t = 1.0
			_safe_car = car.global_transform
		global_position = car.global_position + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO
		var spd_k: float = clamp(car.linear_velocity.length() / 40.0, 0.0, 1.0)
		_follow_cam(delta, car.global_position + Vector3(0, 1.7, 0), lerp(6.8, 8.2, spd_k), 0.0)
		cam.fov = lerp(cam.fov, Game.settings.fov + 8.0 * spd_k, delta * 2.0)
		if controls and Input.is_action_just_pressed("vehicle"):
			exit_car()
		elif controls and Input.is_action_just_pressed("interact") and world:
			world.try_door(self)
		return
	combat.tick(delta, true)
	powers.tick(delta)
	var input := Vector2.ZERO
	if controls and not Game.paused and not combat.dead:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := Basis(Vector3.UP, yaw)
	var dir := (basis * Vector3(input.x, 0, input.y))
	var mode: int = Game.settings.move_speed
	var top: float = [WALK, FAST_WALK, JOG][mode]
	if controls and Input.is_action_just_pressed("crouch") and is_on_floor():
		visual.crouch = not visual.crouch
	if visual.crouch:
		top = 1.6
	if controls and Input.is_action_pressed("sprint"):
		top = SPRINT
		visual.crouch = false
	if combat.locked() and not Input.is_action_pressed("sprint"):
		top = minf(top, JOG)
	if powers.spinning():
		top = 9.0
		visual.crouch = false
	var want: Vector3 = dir * top * minf(1.0, input.length()) * combat.move_scale() + combat.lunge_velocity()
	var acc := 14.0 if is_on_floor() else 4.0
	velocity.x = move_toward(velocity.x, want.x, acc * delta * max(top, 4.0))
	velocity.z = move_toward(velocity.z, want.z, acc * delta * max(top, 4.0))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif controls and not combat.dead and combat.busy <= 0.0 and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP
	move_and_slide()
	if global_position.y < World.SEA - 1.4 and _safe != Vector3.ZERO:
		global_position = _safe + Vector3(0, 0.3, 0)
		velocity = Vector3.ZERO
	elif _safe_t <= 0.0 and is_on_floor() and global_position.y > World.SEA + 0.4:
		_safe_t = 1.0
		_safe = global_position
	var hs := Vector2(velocity.x, velocity.z).length()
	if combat.locked():
		# hedefe kilitli: karakter hedefe bakar, kamera yavaşça hedefe döner
		var rel := combat.target.global_position - global_position
		var ta := atan2(rel.x, rel.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, ta, min(1.0, delta * 12.0))
		yaw = lerp_angle(yaw, ta + PI, min(1.0, delta * 3.0))
	elif hs > 0.2 and combat.busy <= 0.0 and not combat.blocking and not combat.dead:
		var target := atan2(velocity.x, velocity.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target, min(1.0, delta * 10.0))
	if not combat.dead:
		visual.set_motion(hs, is_on_floor())
	# iniş: yüksekten düşünce çöküp kalkar; koşarken dönüşlerde gövde içe yatar
	var fl := is_on_floor()
	if not fl:
		_fall_v = minf(_fall_v, velocity.y)
	elif not _was_floor:
		if _fall_v < -9.0 and not powers.spinning():
			visual.action("land", 1.2)
			shake(0.15)
			Fx.dust(global_position, 0.8)
		_fall_v = 0.0
	_was_floor = fl
	var turn := 0.0
	if hs > 4.0 and combat.busy <= 0.0:
		turn = clampf(angle_difference(visual.rotation.y, atan2(velocity.x, velocity.z)) * hs * 0.035, -0.16, 0.16)
	_lean = lerpf(_lean, turn, minf(1.0, delta * 6.0))
	visual.rotation.z = _lean
	# koşarken kamera biraz geri çekilir, FOV açılır
	var sprinting := hs > 6.0
	_follow_cam(delta, global_position + Vector3(0, 1.55, 0), 3.6 if sprinting else 3.1, 0.55)
	cam.fov = lerp(cam.fov, Game.settings.fov + (6.0 if sprinting else 0.0), delta * 4.0)
	if controls and not combat.dead and combat.busy <= 0.0 and Input.is_action_just_pressed("vehicle"):
		_try_enter()
	if controls and not combat.dead and talk == null and Input.is_action_just_pressed("interact"):
		_try_interact()


func _follow_cam(delta: float, target: Vector3, dist: float, offset: float) -> void:
	rig.global_position = rig.global_position.lerp(target, min(1.0, delta * 14.0))
	yaw_node.rotation.y = yaw
	pitch_node.rotation.x = pitch
	arm.spring_length = lerp(arm.spring_length, dist, delta * 5.0)
	cam.h_offset = lerp(cam.h_offset, offset, delta * 5.0)
	if _shake > 0.0:
		_shake -= delta
		cam.v_offset = randf_range(-1, 1) * _shake * 0.08
	else:
		cam.v_offset = 0.0
	# araçta kamera yavaşça arkaya hizalanır
	if car and car.linear_velocity.length() > 4.0 and not Input.get_last_mouse_velocity().length() > 1.0:
		var back := car.global_rotation.y + PI
		yaw = lerp_angle(yaw, back, delta * 1.8)


func _try_enter() -> void:
	var best: Car = null
	var bd := 3.8
	for c in get_tree().get_nodes_in_group("cars"):
		var cc := c as Car
		if cc == null:
			continue
		var d := global_position.distance_to(cc.global_position)
		if d < bd:
			bd = d
			best = cc
	if best:
		car = best
		for c in get_children():
			if c is CollisionShape3D:
				c.disabled = true
		# sürücü koltuğuna otur (camlar opak → görünmez, kol/baş dışarı taşmaz)
		add_collision_exception_with(car)
		remove_child(visual)
		car.add_child(visual)
		visual.position = car.seat
		visual.rotation = Vector3.ZERO
		visual.scale = Vector3.ONE * 0.72
		visual.visible = false
		visual.play("drive", 0.15)
		car.set_driver(true)
		entered_vehicle.emit(car)


func exit_car() -> void:
	if car == null:
		return
	var c0 := car
	var side := c0.global_transform.basis.x * (c0.size.x * 0.5 + 0.9)
	global_position = c0.global_position + side + Vector3(0, 0.4, 0)
	c0.set_driver(false)
	c0.remove_child(visual)
	add_child(visual)
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.visible = true
	visual.rotation.y = c0.global_rotation.y
	car = null
	# önce konum otursun, sonra çarpışma açılsın; araçla çarpışma bir süre kapalı kalır
	await get_tree().physics_frame
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = false
	get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(c0): remove_collision_exception_with(c0))
	velocity = Vector3.ZERO
	exited_vehicle.emit()


func _rescue_car() -> void:
	if _safe_car == Transform3D():
		return
	var b := Basis(Vector3.UP, _safe_car.basis.get_euler().y)
	car.global_transform = Transform3D(b, _safe_car.origin + Vector3(0, 0.6, 0))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO


func _talk_target() -> Pedestrian:
	var fwd := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	var best: Pedestrian = null
	var bd := 2.6
	for g in ["people", "police"]:
		for n in get_tree().get_nodes_in_group(g):
			var pd := n as Pedestrian
			if pd == null or pd.is_down() or pd.state == Pedestrian.S.FIGHT or pd.state == Pedestrian.S.FLEE:
				continue
			var rel := pd.global_position - global_position
			rel.y = 0.0
			var d := rel.length()
			if d < bd and (d < 1.0 or fwd.dot(rel / d) > 0.1):
				bd = d
				best = pd
	return best


func _try_interact() -> void:
	var w := world
	if w and w.has_method("try_door") and w.try_door(self):
		return
	var pd := _talk_target()
	if pd:
		talk = TalkMenu.new()
		talk.player = self
		talk.ped = pd
		get_parent().add_child(talk)


func prompt_text() -> String:
	if car:
		var cp: String = world.door_prompt(global_position, true) if world else ""
		return ("[F] İn   " + cp) if cp != "" else "[F] İn"
	if combat.dead:
		return ""
	if world and world.has_method("door_prompt"):
		var dp: String = world.door_prompt(global_position)
		if dp != "":
			return dp
	if talk == null and _talk_target():
		return "[E] Etkileşim"
	for c in get_tree().get_nodes_in_group("cars"):
		if (c as Node3D).global_position.distance_to(global_position) < 3.8:
			return "[F] Araca bin"
	return ""


func take_hit(dmg: float, from: Vector3, heavy: bool, attacker: Node = null, stun_t := 0.0) -> void:
	if car:
		return
	combat.take_hit(dmg, from, heavy, attacker, stun_t)


func is_down() -> bool:
	return combat.dead


func dismount() -> void:
	if mount == null:
		return
	var m := mount
	mount = null
	global_position = m.global_position + Vector3(0, -1.0, 0)
	velocity = m.vel * 0.3
	visual.rotation = Vector3(0, m.yaw, 0)
	visual.lock_t = 0.0
	powers.air_used = false


func shake(t := 0.3) -> void:
	_shake = max(_shake, t)
