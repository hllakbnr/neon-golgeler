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


func _ready() -> void:
	add_to_group("player")
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
	# kamera düzeni
	rig = Node3D.new()
	yaw_node = Node3D.new()
	pitch_node = Node3D.new()
	arm = SpringArm3D.new()
	arm.spring_length = 3.1
	arm.margin = 0.25
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	arm.shape = sphere
	arm.add_excluded_object(get_rid())
	cam = Camera3D.new()
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
	if car:
		global_position = car.global_position + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO
		var spd_k: float = clamp(car.linear_velocity.length() / 40.0, 0.0, 1.0)
		_follow_cam(delta, car.global_position + Vector3(0, 1.7, 0), lerp(6.8, 8.2, spd_k), 0.0)
		cam.fov = lerp(cam.fov, Game.settings.fov + 8.0 * spd_k, delta * 2.0)
		if controls and Input.is_action_just_pressed("vehicle"):
			exit_car()
		return
	var input := Vector2.ZERO
	if controls and not Game.paused:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := Basis(Vector3.UP, yaw)
	var dir := (basis * Vector3(input.x, 0, input.y))
	var mode: int = Game.settings.move_speed
	var top: float = [WALK, FAST_WALK, JOG][mode]
	if controls and Input.is_action_pressed("sprint"):
		top = SPRINT
	var want: Vector3 = dir * top * minf(1.0, input.length())
	var acc := 14.0 if is_on_floor() else 4.0
	velocity.x = move_toward(velocity.x, want.x, acc * delta * max(top, 4.0))
	velocity.z = move_toward(velocity.z, want.z, acc * delta * max(top, 4.0))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif controls and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.2:
		var target := atan2(velocity.x, velocity.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target, min(1.0, delta * 10.0))
	visual.set_motion(hs, is_on_floor())
	# koşarken kamera biraz geri çekilir, FOV açılır
	var sprinting := hs > 6.0
	_follow_cam(delta, global_position + Vector3(0, 1.55, 0), 3.6 if sprinting else 3.1, 0.55)
	cam.fov = lerp(cam.fov, Game.settings.fov + (6.0 if sprinting else 0.0), delta * 4.0)
	if controls and Input.is_action_just_pressed("vehicle"):
		_try_enter()


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
		# sürücü koltuğuna otur
		remove_child(visual)
		car.add_child(visual)
		visual.position = car.seat
		visual.rotation = Vector3.ZERO
		visual.scale = Vector3.ONE * 0.82
		visual.play("drive", 0.15)
		car.set_driver(true)
		entered_vehicle.emit(car)


func exit_car() -> void:
	if car == null:
		return
	var side := car.global_transform.basis.x * -1.8
	global_position = car.global_position + side + Vector3(0, 0.3, 0)
	car.set_driver(false)
	car.remove_child(visual)
	add_child(visual)
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.rotation.y = car.global_rotation.y
	car = null
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = false
	velocity = Vector3.ZERO
	exited_vehicle.emit()


func shake(t := 0.3) -> void:
	_shake = max(_shake, t)
