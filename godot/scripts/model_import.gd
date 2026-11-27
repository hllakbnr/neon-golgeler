extends RefCounted
class_name ModelImport
## Element Arenası'ndaki otomatik iskelet algoritmasının (eaSeg / namedSeg) Godot'a taşınmış hâli.
## İskeleti olmayan bir modelde kolları ve bacakları bulup ayırır, eklem (pivot) noktalarını hesaplar:
##  1) köşe kaynağı (weld) + komşuluk + köşe normalleri/alanları
##  2) eller: yatay dilimlerde en dıştaki iki nokta
##  3) kollar: gövde yan yüzeyine paralel kesme düzlemi taraması (açı −30…30°), yoksa kol yönünde
##     alan sıçraması (armJump); sarkan kollarda yön düzeltmesi
##  4) küçük artıklar komşu parçaya katılır
##  5) bacaklar: alttan yukarı birleşim (union-find) taramasıyla kasık; kıvrım halkası (ring) ile ince ayar
##  6) kalça bloğu, üçgen etiketleri, eklem noktaları
## Model uzayı: boy H, ayak y=0, yüz +Z, sağ taraf −X (Element Arenası ile aynı).
## Etiketler: 0 gövde · 1 sağ kol · 2 sol kol · 3 sağ bacak · 4 sol bacak · 5 kalça

const PART_RE := [[1, "(arm|kol)[^a-z]*(r|right|sag|sağ)([^a-z]|$)|(right|sag|sağ)[^a-z]*(arm|kol)"], [2, "(arm|kol)[^a-z]*(l|left|sol)([^a-z]|$)|(left|sol)[^a-z]*(arm|kol)"],
	[3, "(leg|bacak)[^a-z]*(r|right|sag|sağ)([^a-z]|$)|(right|sag|sağ)[^a-z]*(leg|bacak)"], [4, "(leg|bacak)[^a-z]*(l|left|sol)([^a-z]|$)|(left|sol)[^a-z]*(leg|bacak)"],
	[5, "(^|[^a-z])(hips?|pelvis|kalca|kalça)([^a-z]|$)"]]

var H := 2.7
var X := PackedFloat64Array()
var Y := PackedFloat64Array()
var Z := PackedFloat64Array()
var NX := PackedFloat64Array()
var NY := PackedFloat64Array()
var NZ := PackedFloat64Array()
var VA := PackedFloat64Array()
var TA := PackedInt32Array()
var AP := PackedInt32Array()
var ADJ := PackedInt32Array()
var lab := PackedByteArray()
var n := 0
var T := 0
var tot := 0.0
var info := {}


# ---------------------------------------------------------------- adlandırılmış parçalar
static func named_labels(names: Array) -> Array:
	var out := []
	var res := []
	for pr in PART_RE:
		var r := RegEx.new()
		r.compile("(?i)" + pr[1])
		res.append([pr[0], r])
	for nm in names:
		var l := 0
		for r in res:
			if (r[1] as RegEx).search(String(nm)):
				l = r[0]
				break
		out.append(l)
	if not ((out.has(1) and out.has(2)) or (out.has(3) and out.has(4))):
		return []
	return out


# ---------------------------------------------------------------- ana giriş
func segment(geoms: Array) -> Dictionary:
	## geoms: [{pos: PackedVector3Array, idx: PackedInt32Array}] → {ok, tl:[PackedByteArray], piv, info}
	_weld(geoms)
	if n < 8:
		return {"ok": false}
	_normals_adjacency()
	var piv := {}
	var cut := {}
	_arms(piv, cut)
	_absorb(0.015 * tot)
	var ycut = _legs(cut)
	var waist = null
	if ycut != null and cut.has("leg") and not info.has("crotch_uf"):
		var r = _ring(ycut + 0.03 * H, ycut + 0.16 * H)
		if r != null:
			var a := 0.0
			for i in n:
				if lab[i] == 0 and Y[i] < r.y:
					a += VA[i]
			if a < 0.15 * tot:
				for i in n:
					if lab[i] == 0 and Y[i] < r.y:
						lab[i] = 5
				waist = r.y
	_absorb(0.008 * tot)
	# üçgen etiketleri (çoğunluk)
	var TL := PackedByteArray()
	TL.resize(T)
	for t in T:
		var a := lab[TA[3 * t]]
		var b := lab[TA[3 * t + 1]]
		var c := lab[TA[3 * t + 2]]
		TL[t] = a if (a == b or a == c) else (b if b == c else mini(a, mini(b, c)))
	# eklem noktaları
	for L in [1, 2]:
		if not cut.has(L):
			continue
		var cc: Dictionary = cut[L]
		var yt := -1e9
		for i in n:
			if lab[i] == L and Y[i] > yt:
				yt = Y[i]
		var bc = _boundary(TL, L, false)
		if bc == null:
			continue
		var iH: int = cc.iH
		var hand := Vector3(X[iH], Y[iH], Z[iH])
		var key := "armR" if L == 1 else "armL"
		if cc.has("u"):
			piv[key] = {"p": bc, "h": hand}
			continue
		var py: float = minf(yt - 0.02 * H, maxf(bc.y, yt - 0.05 * H))
		var t: float = deg_to_rad(cc.th)
		var nx: float = cc.side * cos(t)
		var ny: float = sin(t)
		var px: float = (cc.d - ny * py) / nx
		var sz := 0.0
		var k := 0
		for i in n:
			if lab[i] == L and abs(Y[i] - py) < 0.03 * H:
				sz += Z[i]
				k += 1
		piv[key] = {"p": Vector3(px, py, sz / k if k > 0 else bc.z), "h": hand}
	for L in [3, 4]:
		if not cut.has("leg"):
			continue
		var bc = _boundary(TL, L, true)
		if bc != null:
			piv["legR" if L == 3 else "legL"] = {"p": Vector3(bc.x, ycut - 0.02 * H, bc.z)}
	piv["waist"] = waist
	# geom başına üçgen etiketleri
	var tl := []
	var o := 0
	for g in geoms:
		var ix: PackedInt32Array = g.idx
		var nt := ix.size() / 3
		tl.append(TL.slice(o, o + nt))
		o += nt
	var lab_area := []
	for L in range(6):
		var a := 0.0
		for i in n:
			if lab[i] == L:
				a += VA[i]
		lab_area.append(snappedf(a / maxf(tot, 1e-9), 0.001))
	info["lab"] = lab_area
	var anim := {"arms": piv.has("armR") or piv.has("armL"), "legs": piv.has("legR") and piv.has("legL")}
	return {"ok": anim.arms or anim.legs, "anim": anim, "tl": tl, "piv": piv, "info": info}


# ---------------------------------------------------------------- 1) kaynak + komşuluk
func _weld(geoms: Array) -> void:
	var q := H * 1e-4
	var map := {}
	var tris := PackedInt32Array()
	for g in geoms:
		var pos: PackedVector3Array = g.pos
		var w := PackedInt32Array()
		w.resize(pos.size())
		for i in pos.size():
			var p: Vector3 = pos[i]
			var key := Vector3i(roundi(p.x / q), roundi(p.y / q), roundi(p.z / q))
			var id: int = map.get(key, -1)
			if id < 0:
				id = X.size()
				map[key] = id
				X.append(p.x)
				Y.append(p.y)
				Z.append(p.z)
			w[i] = id
		var ix: PackedInt32Array = g.idx
		for t in range(0, ix.size() - 2, 3):
			tris.append(w[ix[t]])
			tris.append(w[ix[t + 1]])
			tris.append(w[ix[t + 2]])
	TA = tris
	n = X.size()
	T = TA.size() / 3


func _normals_adjacency() -> void:
	NX.resize(n)
	NY.resize(n)
	NZ.resize(n)
	VA.resize(n)
	NX.fill(0)
	NY.fill(0)
	NZ.fill(0)
	VA.fill(0)
	var deg := PackedInt32Array()
	deg.resize(n + 1)
	deg.fill(0)
	for t in T:
		var a := TA[3 * t]
		var b := TA[3 * t + 1]
		var c := TA[3 * t + 2]
		if a == b or b == c or a == c:
			continue
		var ux := X[b] - X[a]
		var uy := Y[b] - Y[a]
		var uz := Z[b] - Z[a]
		var vx := X[c] - X[a]
		var vy := Y[c] - Y[a]
		var vz := Z[c] - Z[a]
		var cx := uy * vz - uz * vy
		var cy := uz * vx - ux * vz
		var cz := ux * vy - uy * vx
		var ar := sqrt(cx * cx + cy * cy + cz * cz) * 0.5
		for v in [a, b, c]:
			NX[v] += cx
			NY[v] += cy
			NZ[v] += cz
			VA[v] += ar / 3.0
		deg[a] += 2
		deg[b] += 2
		deg[c] += 2
	tot = 0.0
	for i in n:
		var l := sqrt(NX[i] * NX[i] + NY[i] * NY[i] + NZ[i] * NZ[i])
		if l < 1e-12:
			l = 1.0
		NX[i] /= l
		NY[i] /= l
		NZ[i] /= l
		tot += VA[i]
	var pt := PackedInt32Array()
	pt.resize(n + 1)
	pt[0] = 0
	for i in n:
		pt[i + 1] = pt[i] + deg[i]
	var tmp := PackedInt32Array()
	tmp.resize(pt[n])
	var fl := pt.slice(0, n)
	for t in T:
		var a := TA[3 * t]
		var b := TA[3 * t + 1]
		var c := TA[3 * t + 2]
		if a == b or b == c or a == c:
			continue
		tmp[fl[a]] = b
		tmp[fl[a] + 1] = c
		fl[a] += 2
		tmp[fl[b]] = a
		tmp[fl[b] + 1] = c
		fl[b] += 2
		tmp[fl[c]] = a
		tmp[fl[c] + 1] = b
		fl[c] += 2
	AP.resize(n + 1)
	AP[0] = 0
	var adj := PackedInt32Array()
	for i in n:
		var s := tmp.slice(pt[i], pt[i + 1])
		s.sort()
		var last := -1
		for v in s:
			if v != last:
				adj.append(v)
				last = v
		AP[i + 1] = adj.size()
	ADJ = adj
	lab.resize(n)
	lab.fill(0)
	info = {"n": n, "T": T, "tot": tot}


# ---------------------------------------------------------------- BFS yardımcıları
func _bfs_f(seed: int, f: PackedFloat64Array, d: float, lim: float) -> Array:
	## f[i] > d olan bağlı bölge; [maske, alan]
	var m := PackedByteArray()
	m.resize(n)
	m.fill(0)
	if not f[seed] > d:
		return [m, 0.0]
	var st := PackedInt32Array([seed])
	m[seed] = 1
	var a := 0.0
	while st.size() > 0:
		var v := st[st.size() - 1]
		st.remove_at(st.size() - 1)
		a += VA[v]
		if lim > 0.0 and a > lim:
			return [m, a]
		for k in range(AP[v], AP[v + 1]):
			var w := ADJ[k]
			if m[w] == 0 and f[w] > d:
				m[w] = 1
				st.append(w)
	return [m, a]


# ---------------------------------------------------------------- 2-3) eller ve kollar
func _arms(piv: Dictionary, cut: Dictionary) -> void:
	# her dilimde en dıştaki noktalar (eller)
	var slices := 35
	var mnx := PackedFloat64Array()
	var mxx := PackedFloat64Array()
	var iR := PackedInt32Array()
	var iL := PackedInt32Array()
	mnx.resize(slices)
	mxx.resize(slices)
	iR.resize(slices)
	iL.resize(slices)
	mnx.fill(0)
	mxx.fill(0)
	iR.fill(-1)
	iL.fill(-1)
	for i in n:
		var s := int(floor((Y[i] - 0.2 * H) / (0.02 * H)))
		if s < 0 or s >= slices:
			continue
		if X[i] < mnx[s]:
			mnx[s] = X[i]
			iR[s] = i
		if X[i] > mxx[s]:
			mxx[s] = X[i]
			iL[s] = i
	var best_s := -1.0
	var bR := -1
	var bL := -1
	for s in slices:
		if iR[s] < 0 or iL[s] < 0:
			continue
		var sp: float = minf(-mnx[s], mxx[s])
		if sp > best_s:
			best_s = sp
			bR = iR[s]
			bL = iL[s]
	if bR < 0 or best_s <= 0.12 * H:
		return
	var RS := {}
	var LS := {}
	for th in range(-30, 31, 4):
		RS[th] = _arm_try(-1, bR, th)
		LS[th] = _arm_try(1, bL, th)
	var bt = null
	var bs := -1.0
	for th in range(-30, 31, 4):
		if RS[th] != null and LS[th] != null and RS[th].sc + LS[th].sc > bs:
			bs = RS[th].sc + LS[th].sc
			bt = th
	for side_def in [[-1, bR, 1, RS], [1, bL, 2, LS]]:
		var side: int = side_def[0]
		var iH: int = side_def[1]
		var L: int = side_def[2]
		var S: Dictionary = side_def[3]
		var c = S[bt] if bt != null else null
		if c == null:
			for k in S.keys():
				if S[k] != null and (c == null or S[k].sc > c.sc):
					c = S[k]
		if c == null:
			c = _arm_jump(iH, Vector3(side, 0, 0))
		if c == null:
			continue
		var r: Array = _bfs_f(iH, c.f, c.d, 0.0)
		var m: PackedByteArray = r[0]
		# en uzak nokta → kol yönü; sarkan kolda kol yönünde sıçrama ile yeniden kes
		var q := -1
		var qd := -1.0
		for i in n:
			if m[i]:
				var dd := (X[i] - X[iH]) ** 2 + (Y[i] - Y[iH]) ** 2 + (Z[i] - Z[iH]) ** 2
				if dd > qd:
					qd = dd
					q = i
		if q >= 0 and not c.has("u"):
			var u := Vector3(X[iH] - X[q], Y[iH] - Y[q], Z[iH] - Z[q])
			if u.length() > 1e-6 and atan2(abs(u.x), -u.y) > 0.6:
				var cj = _arm_jump(iH, u.normalized())
				if cj != null:
					c = cj
					m = _bfs_f(iH, c.f, c.d, 0.0)[0]
		for i in n:
			if m[i]:
				lab[i] = L
		var cc := {"side": side, "th": c.th, "d": c.d, "iH": iH}
		if c.has("u"):
			cc["u"] = c.u
		cut[L] = cc


func _arm_try(side: int, iH: int, th: int):
	var t := deg_to_rad(th)
	var nx := side * cos(t)
	var ny := sin(t)
	var f := PackedFloat64Array()
	f.resize(n)
	for i in n:
		f[i] = X[i] * nx + Y[i] * ny
	var fh := f[iH]
	var bw := 0.004 * H
	var lo := 1e9
	var hi := -1e9
	var sel := PackedInt32Array()
	for i in n:
		if NX[i] * nx + NY[i] * ny > 0.85 and Y[i] > Y[iH] + 0.03 * H and f[i] < fh - 0.06 * H:
			sel.append(i)
			lo = minf(lo, f[i])
			hi = maxf(hi, f[i])
	if sel.size() < 3:
		return null
	var nb := int(floor((hi - lo) / bw)) + 2
	var h := PackedFloat64Array()
	h.resize(nb)
	h.fill(0)
	for i in sel:
		h[int(floor((f[i] - lo) / bw))] += VA[i]
	var h3 := PackedFloat64Array()
	h3.resize(nb)
	for k in nb:
		h3[k] = h[k] + (h[k - 1] if k > 0 else 0.0) + (h[k + 1] if k < nb - 1 else 0.0)
	for k in range(nb - 1, -1, -1):
		if h3[k] < 0.004 * tot:
			continue
		if k + 1 < nb and h3[k + 1] > h3[k]:
			continue
		if k > 0 and h3[k - 1] > h3[k]:
			continue
		var d := lo + (k + 1.5) * bw + 0.006 * H
		var r: Array = _bfs_f(iH, f, d, 0.15 * tot)
		if r[1] < 0.03 * tot:
			continue
		if r[1] > 0.14 * tot:
			break
		return {"sc": h3[k], "th": th, "d": d, "f": f}
	return null


func _arm_jump(iH: int, u: Vector3):
	var f := PackedFloat64Array()
	f.resize(n)
	for i in n:
		f[i] = X[i] * u.x + Y[i] * u.y + Z[i] * u.z
	var pa := 0.0
	var pd = null
	var gs := []
	var d := f[iH] - 0.02 * H
	while d > f[iH] - 1.2 * H:
		var r: Array = _bfs_f(iH, f, d, 0.2 * tot)
		if pd != null:
			var g: float = r[1] - pa
			if gs.size() >= 5:
				var srt := gs.duplicate()
				srt.sort()
				var md: float = srt[srt.size() >> 1]
				if g > maxf(3.0 * md, 0.012 * tot) or r[1] > 0.14 * tot:
					if pa > 0.025 * tot and pa < 0.14 * tot:
						return {"sc": 0.0, "th": 0, "d": pd, "f": f, "u": u}
					return null
			gs.append(g)
		pa = r[1]
		pd = d
		d -= 0.005 * H
	return null


# ---------------------------------------------------------------- 4) küçük artıklar
func _absorb(min_a: float) -> void:
	var seen := PackedByteArray()
	seen.resize(n)
	seen.fill(0)
	for s in n:
		if seen[s]:
			continue
		var L := lab[s]
		var comp := PackedInt32Array()
		var a := 0.0
		var st := PackedInt32Array([s])
		seen[s] = 1
		while st.size() > 0:
			var v := st[st.size() - 1]
			st.remove_at(st.size() - 1)
			comp.append(v)
			a += VA[v]
			for k in range(AP[v], AP[v + 1]):
				var w := ADJ[k]
				if seen[w] == 0 and lab[w] == L:
					seen[w] = 1
					st.append(w)
		if a >= min_a:
			continue
		var cnt := {}
		for v in comp:
			for k in range(AP[v], AP[v + 1]):
				var w := ADJ[k]
				if lab[w] != L:
					cnt[lab[w]] = cnt.get(lab[w], 0) + 1
		var bl := -1
		var bc := 0
		for k in cnt.keys():
			if cnt[k] > bc:
				bc = cnt[k]
				bl = k
		if bl >= 0:
			for v in comp:
				lab[v] = bl


# ---------------------------------------------------------------- 5) bacaklar
func _ring(y0: float, y1: float):
	## bant içindeki çevresel kıvrım (kemer, paça) çizgisi
	var bw := 0.005 * H
	var nb := int(ceil((y1 - y0) / bw))
	if nb < 2:
		return null
	var sc := PackedFloat64Array()
	sc.resize(nb)
	sc.fill(0)
	var cov := PackedInt32Array()      # 16 bitlik açısal kapsama maskesi
	cov.resize(nb)
	cov.fill(0)
	var zc := 0.0
	var zn := 0
	for i in n:
		if Y[i] > y0 and Y[i] < y1 and lab[i] == 0:
			zc += Z[i]
			zn += 1
	zc = zc / zn if zn > 0 else 0.0
	for a in n:
		if lab[a] != 0:
			continue
		for k in range(AP[a], AP[a + 1]):
			var b := ADJ[k]
			if b <= a or lab[b] != 0:
				continue
			var dx := X[b] - X[a]
			var dy := Y[b] - Y[a]
			var dz := Z[b] - Z[a]
			var L := sqrt(dx * dx + dy * dy + dz * dz)
			if L < 1e-9 or abs(dy) > 0.35 * L:
				continue
			var cv := ((NX[a] - NX[b]) * dx + (NY[a] - NY[b]) * dy + (NZ[a] - NZ[b]) * dz) / L
			if cv < 0.15:
				continue
			var my := (Y[a] + Y[b]) * 0.5
			if my < y0 or my >= y1:
				continue
			var bi := int(floor((my - y0) / bw))
			sc[bi] += L * cv
			var an := atan2((Z[a] + Z[b]) * 0.5 - zc, (X[a] + X[b]) * 0.5)
			cov[bi] |= 1 << (int(floor((an + PI) / TAU * 16.0)) & 15)
	var best = null
	for k in range(nb - 1):
		var m := cov[k] | cov[k + 1]
		var c := 0
		for s in 16:
			if m & (1 << s):
				c += 1
		if c < 12:
			continue
		var s2 := sc[k] + sc[k + 1]
		if best == null or s2 > best.s:
			best = {"s": s2, "y": y0 + (k + 1) * bw}
	if best != null and best.s > 0.12:
		return best
	return null


func _legs(cut: Dictionary):
	# kasık: alttan yukarı eklerken iki büyük parçanın tek parçaya birleştiği yükseklik
	var ord := []
	for i in n:
		if lab[i] == 0:
			ord.append(Vector2(Y[i], i))
	ord.sort()
	var par := PackedInt32Array()
	par.resize(n)
	for i in n:
		par[i] = i
	var ar := VA.duplicate()
	var ad := PackedByteArray()
	ad.resize(n)
	ad.fill(0)
	var thr := 0.02 * tot
	var big := 0
	var had2 := false
	var ycut = null
	for e in ord:
		var v := int(e.y)
		ad[v] = 1
		for k in range(AP[v], AP[v + 1]):
			var w := ADJ[k]
			if ad[w] == 0:
				continue
			var a := _find(par, v)
			var b := _find(par, w)
			if a == b:
				continue
			var ba := 1 if ar[a] > thr else 0
			var bb := 1 if ar[b] > thr else 0
			par[b] = a
			ar[a] += ar[b]
			big += (1 if ar[a] > thr else 0) - ba - bb
		if Y[v] < 0.2 * H and big >= 2:
			had2 = true
		if had2 and big == 1 and Y[v] > 0.12 * H and Y[v] < 0.6 * H:
			ycut = Y[v]
			info["crotch_uf"] = snappedf(Y[v] / H, 0.001)
			break
		if Y[v] > 0.6 * H:
			break
	if ycut != null and ycut < 0.4 * H:
		var r = _ring(ycut + 0.01 * H, minf(0.45 * H, ycut + 0.16 * H))
		if r != null and r.s > 0.3:
			ycut = r.y
			info.erase("crotch_uf")
	if ycut == null:
		var r = _ring(0.12 * H, 0.5 * H)
		if r != null:
			ycut = r.y
	if ycut == null:
		return null
	var lm := PackedByteArray()
	lm.resize(n)
	lm.fill(0)
	for i in n:
		if lab[i] == 0 and Y[i] < ycut and Y[i] < 0.04 * H and lm[i] == 0:
			var st := PackedInt32Array([i])
			lm[i] = 1
			while st.size() > 0:
				var v := st[st.size() - 1]
				st.remove_at(st.size() - 1)
				for k in range(AP[v], AP[v + 1]):
					var w := ADJ[k]
					if lm[w] == 0 and lab[w] == 0 and Y[w] < ycut:
						lm[w] = 1
						st.append(w)
	var aR := 0.0
	var aL := 0.0
	for i in n:
		if lm[i]:
			if X[i] < 0:
				aR += VA[i]
			else:
				aL += VA[i]
	if aR > 0.02 * tot and aL > 0.02 * tot and aR < 0.3 * tot and aL < 0.3 * tot:
		for i in n:
			if lm[i]:
				lab[i] = 3 if X[i] < 0 else 4
		cut["leg"] = {"y": ycut}
	else:
		info["legFail"] = [aR / tot, aL / tot]
	return ycut


func _find(par: PackedInt32Array, i: int) -> int:
	var r := i
	while par[r] != r:
		r = par[r]
	while par[i] != r:
		var nx := par[i]
		par[i] = r
		i = nx
	return r


func _boundary(TL: PackedByteArray, L: int, legs_only_other: bool):
	## L etiketli üçgenlerin, başka parçaya komşu köşelerinin ortalaması (eklem yeri)
	var sx := 0.0
	var sy := 0.0
	var sz := 0.0
	var k := 0
	for t in T:
		if TL[t] != L:
			continue
		for e in 3:
			var v := TA[3 * t + e]
			for j in range(AP[v], AP[v + 1]):
				var o := lab[ADJ[j]]
				if o != L and (not legs_only_other or (o != 3 and o != 4)):
					sx += X[v]
					sy += Y[v]
					sz += Z[v]
					k += 1
					break
	if k == 0:
		return null
	return Vector3(sx / k, sy / k, sz / k)
