extends Node
class_name Wanted
## Aranma sistemi (GTA6'daki mantıktan esinlenen özgün uyarlama)
##  • Suç işlenince polis hemen gelmez: polis görürse anında, yoksa bir tanık telefonla ihbar eder.
##    Tanık aramayı bitirmeden durdurulursa (korkutulur / yere serilirse) ihbar gitmez.
##  • 6 yıldız. Polis seni görüyorsa yıldızlar sabit, görmüyorsa yanıp söner ve haritada arama bölgesi çıkar.
##  • Arama bölgesinin dışına çıkıp gözden kaybolunca aranma düşer; kıyafet ya da araç değiştirmek
##    polisin elindeki tarifi bozar ve kaçışı hızlandırır.
##  • 1–2 yıldızda yakındaki polis tutuklamaya çalışır (YAKALANDIN), 3+ yıldızda şok tabancası,
##    2+ yıldızda devriye arabaları sirenle kovalar.

static var inst: Wanted

signal changed(stars: int)

var player: Player
var world: World
var stars := 0
var heat := 0.0
var seen := false
var last_seen := Vector3.ZERO
var search_r := 0.0
var flash := 0.0
var _seen_t := 99.0
var _unseen_t := 0.0
var _spawn_t := 0.0
var _arrest_t := 0.0
var cars: Array = []


func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _exit_tree() -> void:
	if inst == self:
		inst = null


# ---------------------------------------------------------------- suç
func crime(kind: String, pos: Vector3, sev: int, victim: Node = null) -> void:
	if player == null or player.combat.dead:
		return
	# polis gördü mü?
	for n in get_tree().get_nodes_in_group("police"):
		var o := n as Pedestrian
		if o == null or o == victim or o.is_down():
			continue
		var d := o.global_position.distance_to(pos)
		if d < 40.0 and o._line_of_sight(player):
			_raise(sev, player.global_position)
			Game.notify("Polis gördü: " + kind)
			return
	if stars > 0 and seen:
		_raise(sev, player.global_position)
		return
	# sivil tanık
	var best: Pedestrian = null
	var bd := 30.0 if not player.visual.crouch else 16.0
	for n in get_tree().get_nodes_in_group("people"):
		var o := n as Pedestrian
		if o == null or o == victim or o.is_down() or o.state == Pedestrian.S.FIGHT:
			continue
		if o.state == Pedestrian.S.CALL:
			o.call_sev = maxi(o.call_sev, sev)
			return
		var d := o.global_position.distance_to(pos)
		if d < bd and d > 1.5:
			bd = d
			best = o
	if best:
		best.start_call(sev, pos)
		Game.notify("Bir tanık polisi arıyor! Durdurursan ihbar gitmez.", 3.5)


func report(sev: int, pos: Vector3) -> void:
	Game.notify("Tanık ihbar etti — polis seni arıyor.", 3.0)
	_raise(sev, pos)
	_seen_t = 2.0


func _raise(sev: int, pos: Vector3) -> void:
	var before := stars
	heat = maxf(heat, float(sev)) if stars == 0 else heat + float(sev) * 0.6
	heat = minf(heat, 6.0)
	stars = clampi(ceili(heat - 0.001), 1, 6)
	last_seen = pos
	search_r = 70.0 + stars * 35.0
	_unseen_t = 0.0
	if stars != before:
		Sfx.ui("star", -4.0)
		changed.emit(stars)
		_spawn_t = 0.5


func spotted(pos: Vector3) -> void:
	last_seen = pos
	_seen_t = 0.0


func clear(msg := "") -> void:
	stars = 0
	heat = 0.0
	_unseen_t = 0.0
	_arrest_t = 0.0
	changed.emit(0)
	for c in cars:
		if is_instance_valid(c):
			(c as TrafficCar).end_pursuit()
	cars.clear()
	if msg != "":
		Game.notify(msg)


func description_changed(what: String) -> void:
	## kıyafet / araç değişimi: görülmüyorsan polis yanlış kişiyi arar
	if stars <= 0 or seen:
		return
	_unseen_t += 12.0 if what == "kıyafet" else 7.0
	search_r *= 0.8
	Game.notify("Polisin tarifi artık sana uymuyor (%s değişti)." % what, 3.0)


# ---------------------------------------------------------------- her kare
func _process(delta: float) -> void:
	if Game.paused or player == null:
		return
	flash += delta
	if stars <= 0:
		seen = false
		return
	if player.combat.dead:
		clear()
		return
	_seen_t += delta
	seen = _seen_t < 1.2
	var pp := player.global_position
	if seen:
		_unseen_t = 0.0
		last_seen = pp
	else:
		var outside := pp.distance_to(last_seen) > search_r
		_unseen_t += delta * (1.8 if outside else 0.5) * (1.3 if player.visual.crouch else 1.0)
		if _unseen_t > 10.0 + stars * 6.0:
			clear("Polisten kurtuldun.")
			return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 3.0
		_maintain()
	_arrest_check(delta)


func evade_progress() -> float:
	return clampf(_unseen_t / (10.0 + stars * 6.0), 0.0, 1.0)


func _maintain() -> void:
	var pp := player.global_position
	# yaya polis
	var near := 0
	for n in get_tree().get_nodes_in_group("police"):
		var o := n as Pedestrian
		if o and not o.is_down() and o.global_position.distance_to(pp) < 70.0:
			near += 1
	# önce devriye arabaları gelir; yaya polis yalnızca 2+ yıldızda ve görüş dışından katılır
	var want := mini(stars * 2 - 1, 9) if stars >= 2 else 0
	var add := mini(want - near, 1)
	for k in add:
		_spawn_officer(pp)
	# devriye arabaları
	var i := 0
	while i < cars.size():
		if not is_instance_valid(cars[i]):
			cars.remove_at(i)
		else:
			i += 1
	if world and world.in_city(pp) and cars.size() < mini(stars, 4):
		_spawn_car(pp)


func _spawn_officer(pp: Vector3) -> void:
	if world == null:
		return
	# görüş alanının dışında, 70–95 m uzakta, aynı cadde üzerinde belirir ve koşarak gelir
	var cam := get_viewport().get_camera_3d()
	var cf := -cam.global_transform.basis.z if cam else Vector3.FORWARD
	var cands := []
	if world.in_city(pp):
		var dx := absf(pp.x - roundf(pp.x / world.CELL) * world.CELL)
		var dz := absf(pp.z - roundf(pp.z / world.CELL) * world.CELL)
		var axis := Vector3(0, 0, 1) if dx < dz else Vector3(1, 0, 0)
		for sgn in [1.0, -1.0]:
			cands.append(pp + axis * (70.0 + randf() * 25.0) * sgn)
	else:
		for k in 6:
			var a := randf() * TAU
			cands.append(pp + Vector3(cos(a), 0, sin(a)) * 80.0)
	var pos := Vector3.INF
	for c in cands:
		var cv: Vector3 = c
		var to := cv - (cam.global_position if cam else pp)
		to.y = 0.0
		if cf.dot(to.normalized()) < 0.25 and world.walk_ok(cv):
			pos = cv
			break
	if pos == Vector3.INF:
		return
	pos.y = world.city_floor(pos)
	var r := world.blocks[0]
	var bd := 1e9
	for b in world.blocks:
		var d := Vector2(pos.x, pos.z).distance_to(b.get_center())
		if d < bd:
			bd = d
			r = b
	var o := Pedestrian.new()
	o.role = "police"
	o.slot = "polis"
	o.spawned = true
	o.world = world
	o.path = world.sidewalk_loop(r)
	world.add_child(o)
	o.global_position = pos
	o.state = Pedestrian.S.FIGHT
	o.threat = player
	o.hostile = true


func _spawn_car(pp: Vector3) -> void:
	var nodes := []
	for x in range(-World.GX, World.GX + 1):
		for z in range(-World.GZ, World.GZ + 1):
			var np := Vector3(x * World.CELL, 0, z * World.CELL)
			var d := np.distance_to(pp)
			if d > 110.0 and d < 230.0:
				var cam := get_viewport().get_camera_3d()
				if cam:
					var to := np - cam.global_position
					to.y = 0.0
					if (-cam.global_transform.basis.z).dot(to.normalized()) > 0.35:
						continue
				nodes.append(Vector2i(x, z))
	if nodes.is_empty():
		return
	var a: Vector2i = nodes[randi() % nodes.size()]
	var t := TrafficCar.new()
	t.world = world
	t.model = "police"
	t.from = a
	var best := a
	var bd := 1e9
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = a + d
		if world.node_ok(n):
			var dd := Vector3(n.x * World.CELL, 0, n.y * World.CELL).distance_to(pp)
			if dd < bd:
				bd = dd
				best = n
	t.to = best
	t.pursuit = player
	t.police_unit = true
	world.add_child(t)
	cars.append(t)


func _arrest_check(delta: float) -> void:
	if player.car:
		_arrest_t = 0.0
		return
	var cop_near := false
	for n in get_tree().get_nodes_in_group("police"):
		var o := n as Pedestrian
		if o and not o.is_down() and o.global_position.distance_to(player.global_position) < 1.7:
			cop_near = true
			break
	var docile := player.combat.busy <= 0.0 and player.velocity.length() < 1.6
	if cop_near and (player.combat.stun > 0.0 or (stars <= 2 and docile)):
		_arrest_t += delta
		if _arrest_t > (0.8 if player.combat.stun > 0.0 else 2.2):
			_arrest_t = 0.0
			clear()
			player.combat.die("YAKALANDIN")
	else:
		_arrest_t = maxf(0.0, _arrest_t - delta * 2.0)


func arrest_progress() -> float:
	return clampf(_arrest_t / 2.2, 0.0, 1.0)
