extends RefCounted
class_name Sfx
## Prosedürel ses efektleri (dosya gerektirmez): ilk kullanımda sentezlenip önbelleğe alınır.
## Sfx.play("punch", konum) → 3B ses · Sfx.ui("click") → arayüz sesi

const RATE := 22050
static var _cache := {}
static var _rng := RandomNumberGenerator.new()


static func stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	_rng.seed = hash(name)
	var s: PackedFloat32Array
	match name:
		"whoosh":
			s = _noise_sweep(0.22, 900.0, 3200.0, 0.5)
		"punch":
			s = _mix([_thump(0.16, 110.0, 50.0), _noise_burst(0.06, 0.5)])
		"punch_heavy":
			s = _mix([_thump(0.28, 90.0, 38.0), _noise_burst(0.1, 0.7)])
		"block":
			s = _mix([_ring(0.25, [820.0, 1310.0, 2210.0], 18.0), _noise_burst(0.03, 0.4)])
		"metal":
			s = _mix([_ring(0.5, [430.0, 690.0, 1180.0, 1720.0], 9.0), _noise_burst(0.04, 0.6)])
		"glass":
			s = _mix([_ring(0.45, [2600.0, 3900.0, 5100.0], 12.0), _noise_burst(0.2, 0.5)])
		"crash":
			s = _mix([_thump(0.45, 70.0, 30.0), _noise_burst(0.35, 0.9), _ring(0.4, [310.0, 520.0, 870.0], 10.0)])
		"thud":
			s = _thump(0.2, 80.0, 40.0)
		"click":
			s = _ring(0.04, [2400.0], 120.0)
		"select":
			s = _ring(0.09, [1320.0, 1980.0], 40.0)
		"cash":
			s = _mix([_ring(0.5, [2093.0, 2637.0], 7.0), _noise_burst(0.05, 0.3)])
		"notify":
			s = _seq([[988.0, 0.09], [1319.0, 0.16]])
		"ring":
			s = _seq([[1300.0, 0.12], [1600.0, 0.12], [1300.0, 0.12], [1600.0, 0.12], [0.0, 0.5]])
		"star":
			s = _seq([[660.0, 0.07], [880.0, 0.07], [1100.0, 0.14]])
		"siren":
			s = _siren(2.0)
		"horn":
			s = _horn(0.5)
		"swoosh_big":
			s = _noise_sweep(0.9, 300.0, 2400.0, 0.7)
		"fire":
			s = _mix([_noise_sweep(0.8, 200.0, 900.0, 0.8), _thump(0.5, 60.0, 30.0)])
		"zap":
			s = _zap(0.35)
		"roar":
			s = _roar(1.4)
		"engine":
			s = _engine(1.0)
		"tyre":
			s = _noise_sweep(1.0, 1800.0, 2400.0, 0.4)
		"static":
			s = _noise_burst(0.35, 0.25)
		_:
			s = _noise_burst(0.05, 0.3)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	if name in ["siren", "engine", "tyre"]:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	_cache[name] = w
	return w


static func play(name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var a := AudioStreamPlayer3D.new()
	a.stream = stream(name)
	a.volume_db = vol_db
	a.pitch_scale = pitch
	a.unit_size = 6.0
	a.max_distance = 80.0
	a.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	tree.current_scene.add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)
	return a


static func ui(name: String, vol_db := -6.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = stream(name)
	a.volume_db = vol_db
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


# ---------------------------------------------------------------- sentez
static func _env(i: int, n: int, attack := 0.005, curve := 3.0) -> float:
	var t := float(i) / RATE
	var a := minf(1.0, t / attack)
	return a * pow(1.0 - float(i) / n, curve)


static func _noise_burst(dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	var lp := 0.0
	for i in n:
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.55)
		o[i] = lp * amp * _env(i, n, 0.002, 2.5)
	return o


static func _noise_sweep(dur: float, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	var lp := 0.0
	var bp := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, sin(k * PI) * 0.8 + k * 0.2)
		var c := clampf(f * TAU / RATE, 0.01, 0.95)
		var x := _rng.randf_range(-1.0, 1.0)
		lp += c * (x - lp)
		bp += c * (lp - bp)
		o[i] = (lp - bp) * 3.0 * amp * sin(k * PI)
	return o


static func _thump(dur: float, f0: float, f1: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(f0, f1, k) / RATE
		o[i] = sin(ph) * 0.9 * _env(i, n, 0.002, 2.0)
	return o


static func _ring(dur: float, freqs: Array, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in freqs.size():
			v += sin(TAU * float(freqs[j]) * t) / (1.0 + j * 0.6)
		o[i] = v * 0.35 * exp(-t * decay) * minf(1.0, t / 0.002)
	return o


static func _seq(notes: Array) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	for nt in notes:
		var n := int(float(nt[1]) * RATE)
		for i in n:
			var t := float(i) / RATE
			var v := 0.0
			if float(nt[0]) > 0.0:
				v = (sin(TAU * float(nt[0]) * t) + 0.3 * sin(TAU * float(nt[0]) * 2.0 * t)) * 0.3 * _env(i, n, 0.004, 1.2)
			o.append(v)
	return o


static func _siren(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		var f := 650.0 + 450.0 * (0.5 - 0.5 * cos(k * TAU))
		ph += TAU * f / RATE
		var sq := 1.0 if sin(ph) > 0.0 else -1.0
		o[i] = (sin(ph) * 0.6 + sq * 0.12) * 0.45
	return o


static func _horn(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in [349.0, 440.0]:
			var ph := fmod(t * f, 1.0)
			v += (ph * 2.0 - 1.0) * 0.5
		o[i] = v * 0.35 * minf(1.0, t / 0.01) * minf(1.0, (dur - t) / 0.03)
	return o


static func _zap(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * (1800.0 - 1400.0 * k + _rng.randf_range(-300.0, 300.0)) / RATE
		o[i] = signf(sin(ph)) * 0.25 * (1.0 - k)
	return o


static func _roar(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * (90.0 + 40.0 * sin(k * 9.0) - 30.0 * k) / RATE
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.2)
		o[i] = (sin(ph) * 0.5 + signf(sin(ph * 2.0)) * 0.15 + lp * 0.5) * sin(k * PI) * 0.8
	return o


static func _engine(dur: float) -> PackedFloat32Array:
	## döngülü motor uğultusu: 4 zamanlı ateşleme darbeleri + harmonikler (perde devirle değişir)
	var n := int(dur * RATE)
	var o := PackedFloat32Array()
	o.resize(n)
	var f := 55.0
	for i in n:
		var t := float(i) / RATE
		var ph := t * f
		var fire := pow(0.5 + 0.5 * sin(TAU * ph * 2.0), 6.0)
		var v := sin(TAU * ph) * 0.45 + sin(TAU * ph * 2.0) * 0.25 + sin(TAU * ph * 3.0) * 0.12 + fire * 0.35
		o[i] = v * 0.55 + _rng.randf_range(-0.04, 0.04)
	return o


static func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, (p as PackedFloat32Array).size())
	var o := PackedFloat32Array()
	o.resize(n)
	for p in parts:
		var a: PackedFloat32Array = p
		for i in a.size():
			o[i] += a[i]
	return o
