#!/usr/bin/env python3
"""Neon Gölgeler dünya üreticisi.

Ninjago'nun genel coğrafyasından ilham alan ama tamamen özgün adlarla bir kıta üretir:
kuzeybatı kıyısında başkent (Neon Şehir), kuzeyinde dağ tepesinde Kasırga Manastırı,
doğusunda Kum Denizi çölü, ortada kuzey-güney uzanan sıradağlar, kuzeydoğuda karlı huş ormanı
ve buzullar, doğu kıyısında kazıklar üstünde Sis Kasabası, güneyde çay köyü, batıda volkan adaları.

Çıktılar (godot/data/):
  world_h.bin  float32 yükseklik (satır = z, sütun = x)
  world_c.bin  uint8 RGBA zemin rengi (a = kaya oranı)
  world_r.bin  uint8 bölge kimliği
  world.json   yollar, şehir blokları/binalar, önemli yerler, ağaçlar, adalar
  map.png      harita görseli (uydu/çizim karışımı, yollar ve binalar dahil)
Hepsi deterministik (sabit tohum). numpy + scipy + pillow gerekir.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'data')
X0, X1 = -1700.0, 3500.0
Z0, Z1 = -1900.0, 4700.0
STEP = 8.0
W = int((X1 - X0) / STEP) + 1
H = int((Z1 - Z0) / STEP) + 1
SEA = -1.2
xs = X0 + np.arange(W) * STEP
zs = Z0 + np.arange(H) * STEP
XX, ZZ = np.meshgrid(xs, zs)

# şehir ızgarası (Godot ile aynı sabitler)
CELL, ROAD_W, WALK = 80.0, 12.0, 5.0
GX, GZ = 5, 4                     # bloklar: i = -GX..GX-1, j = -GZ..GZ-1
BLOCK = CELL - ROAD_W - WALK * 2
CITY_X, CITY_Z = GX * CELL, GZ * CELL
EDGE_X, EDGE_Z = CITY_X + 6, CITY_Z + 6

rng = np.random.default_rng(20261128)


def px(x):
    return (x - X0) / STEP


def pz(z):
    return (z - Z0) / STEP


def fbm(seed, cells, octaves=5, pers=0.5):
    r = np.random.default_rng(seed)
    out = np.zeros((H, W))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = int(cells * 2 ** o) + 3
        g = r.standard_normal((n, int(n * W / H) + 3))
        up = ndimage.zoom(g, (H / g.shape[0] * 1.02, W / g.shape[1] * 1.02), order=3)[:H, :W]
        out += up * amp
        tot += amp
        amp *= pers
    return out / tot


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


_warp = None


def ell(cx, cz, rx, rz):
    global _warp
    if _warp is None:
        _warp = fbm(11, 6, 4)
    return np.sqrt(((XX - cx) / rx) ** 2 + ((ZZ - cz) / rz) ** 2) * (1 + _warp * 0.35)


def seg_dist(ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz + 1e-9
    t = np.clip(((XX - ax) * dx + (ZZ - az) * dz) / L2, 0, 1)
    return np.hypot(XX - (ax + t * dx), ZZ - (az + t * dz)), t


def poly_dist(pts):
    d = np.full((H, W), 1e9)
    for a, b in zip(pts[:-1], pts[1:]):
        dd, _ = seg_dist(a[0], a[1], b[0], b[1])
        d = np.minimum(d, dd)
    return d


# ------------------------------------------------------------------ kıta şekli
COAST = [(-520, -560), (-430, -900), (-260, -1290), (80, -1640), (520, -1830), (660, -1560), (760, -1600), (820, -1850),
         (1200, -1880), (1800, -1760), (2150, -1700), (2230, -1500), (2330, -1560), (2400, -1560), (2950, -1210),
         (3200, -760), (3050, -560), (3250, -380), (3300, 80), (3200, 800), (3080, 1400), (2960, 1720),
         (2760, 1880), (2700, 2140), (2940, 2320), (3000, 2800), (2780, 3350), (2480, 3880), (2060, 4330),
         (1520, 4520), (1000, 4470), (640, 4250), (520, 3900), (700, 3520), (560, 3150), (380, 2800),
         (120, 2520), (-120, 2250), (-160, 2050), (150, 1900), (360, 1600), (320, 1250), (80, 1000),
         (-250, 820), (-450, 660), (-560, 440), (-500, 0), (-500, -300)]
ISLANDS = [  # ad, merkez x, z, yarıçap
    ('ada', -1050, -950, 150),          # Güvenlikli Ada
    ('orumcek', -760, 2330, 190),       # Örümcek Adası (orman)
    ('atesA', -1300, 1250, 270),        # Ateş Adaları
    ('atesB', -1470, 1850, 160),
    ('atesC', -1080, 620, 95),
    ('kucuk1', 3200, 3500, 70), ('kucuk2', -300, 3400, 90), ('kucuk3', 1900, -1950, 60)]


def land_mask():
    img = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(img)
    d.polygon([(px(x), pz(z)) for x, z in COAST], fill=255)
    for _, cx, cz, r in ISLANDS:
        d.ellipse([px(cx - r), pz(cz - r), px(cx + r), pz(cz + r)], fill=255)
    return np.array(img) > 127


def signed_dist(mask):
    inside = ndimage.distance_transform_edt(mask) * STEP
    outside = ndimage.distance_transform_edt(~mask) * STEP
    return inside - outside


print('kıta…')
m0 = land_mask()
sd = signed_dist(m0)
city_box = (np.abs(XX) < EDGE_X + 110) & (np.abs(ZZ) < EDGE_Z + 110)
coast_noise = fbm(1, 7, 5) * 120 + fbm(2, 26, 3) * 30
sd = sd + np.where(city_box, 0, coast_noise)
land = sd > 0
border = (XX < X0 + 120) | (XX > X1 - 120) | (ZZ < Z0 + 120) | (ZZ > Z1 - 120)
land &= ~border
# şehrin batı kıyısı (liman + sahil) düz bir hatta kalsın
land |= (XX > -EDGE_X - 70) & (XX < EDGE_X + 300) & (np.abs(ZZ) < EDGE_Z + 60)
land &= ~((XX < -EDGE_X - 95) & (np.abs(ZZ) < EDGE_Z + 40))
din = ndimage.distance_transform_edt(land) * STEP          # kıyıdan içeri uzaklık
dout = ndimage.distance_transform_edt(~land) * STEP

# ------------------------------------------------------------------ yükseklik
print('yükseklik…')
n_lo = fbm(3, 5, 6)
n_mid = fbm(4, 18, 4)
n_ridge = 1 - np.abs(fbm(5, 10, 5) * 2.2)
h = 1.2 + np.minimum(din * 0.03, 22) + n_lo * 14 + n_mid * 4
h = np.maximum(h, 0.6)

REG = {}  # bölge maskeleri (ağırlık 0..1)


def ridge(pts, Hm, w):
    d = poly_dist(pts)
    return Hm * np.exp(-(d / w) ** 2) * (0.75 + 0.45 * n_ridge)


def cone(cx, cz, Hm, w):
    d = np.hypot(XX - cx, ZZ - cz)
    return Hm * np.exp(-(d / w) ** 2)


mtn = np.zeros((H, W))
north = ridge([(-330, -1180), (250, -1470), (900, -1600), (1400, -1500)], 250, 210)
golden = cone(1320, -1300, 310, 170) + cone(1560, -1120, 240, 130) + cone(1120, -1130, 200, 120)
central = ridge([(2080, -900), (2180, -250), (2080, 560), (2220, 1400), (2060, 2300), (2150, 2900)], 330, 260)
glacier = ridge([(2480, -1380), (2880, -980), (3120, -520)], 420, 250)
south = ridge([(700, 3200), (1100, 3600), (1600, 3800)], 110, 260)
mon_peak = cone(180, -1000, 205, 190) + cone(330, -1120, 120, 110)
mtn = np.maximum.reduce([north, golden, central, glacier, south, mon_peak])
mtn *= smoothstep(0, 160, din)          # kıyıda dik düşmesin
mtn += cone(-1300, 1250, 170, 120) - cone(-1300, 1250, 60, 30) * 1.6     # volkan + krater
mtn += cone(-1470, 1850, 110, 80)
h = h + mtn
REG['golden'] = np.clip(golden / 140, 0, 1)

# Kum Denizi (çöl): kumul dalgaları, alçak
desert = smoothstep(1.1, 0.75, ell(1150, 520, 640, 900))
dunes = (np.sin((XX * 0.8 + ZZ * 0.6) / 38 + fbm(6, 14, 3) * 3) * 0.5 + 0.5) * 7 + fbm(7, 30, 3) * 3
h = h * (1 - desert) + (10 + dunes + n_lo * 6) * desert
REG['desert'] = desert
# Çorak Topraklar (şehirle çöl arası)
bad = smoothstep(1.1, 0.7, ell(600, 250, 260, 650)) * (1 - desert)
REG['bad'] = bad
# Kızıl Kanyon: kırmızı yayla + derin kanyon
canyon_reg = smoothstep(1.25, 0.6, ell(1350, 1950, 520, 480))
canyon_line = [(880, 1480), (1150, 1700), (1330, 1960), (1520, 2250), (1720, 2480)]
cd = poly_dist(canyon_line)
plateau = 70 + n_mid * 6
cut = smoothstep(70, 28, cd)
h = h * (1 - canyon_reg) + (plateau * (1 - cut) + (8 + n_mid * 2) * cut) * canyon_reg
REG['canyon'] = canyon_reg
# Ak Huş Ormanı (karlı)
birch = smoothstep(1.1, 0.7, ell(2660, -330, 430, 520))
h = h * (1 - birch * 0.4) + (38 + n_mid * 8) * birch * 0.4
REG['birch'] = birch
# Atalar Geçidi: orta sıradağı kesen geçit (dik duvarlar)
pass_line = [(1850, 640), (2080, 620), (2330, 700)]
pd = poly_dist(pass_line)
h = np.where(pd < 160, h * smoothstep(40, 150, pd) + (55 + n_mid * 2) * (1 - smoothstep(40, 150, pd)), h)
REG['pass'] = smoothstep(220, 60, pd)
# Sakin Orman, çay köyü, sahil yamaçları
REG['forest'] = smoothstep(1.1, 0.7, ell(500, 2450, 330, 420))
REG['tea'] = smoothstep(1.1, 0.7, ell(1050, 3300, 360, 300))
tea_terr = REG['tea']
h = h * (1 - tea_terr * 0.5) + (45 + np.round(n_mid * 3) * 2) * tea_terr * 0.5

# şehir düzlüğü
cbox = np.maximum(np.abs(XX) - EDGE_X, 0), np.maximum(np.abs(ZZ) - EDGE_Z, 0)
cd_city = np.hypot(*cbox)
city_w = smoothstep(140, 30, cd_city)
h = h * (1 - city_w) + 0.0 * city_w
# liman rıhtımı ve sahil bandı düz
coastal_city = (XX < -EDGE_X + 1) & (XX > -EDGE_X - 72) & (np.abs(ZZ) < EDGE_Z + 50)
h = np.where(coastal_city, np.where(ZZ < 0, -0.6, np.clip(0.4 - (-EDGE_X - XX) * 0.022, -2, 0.4)), h)
# rıhtım betonunun altı: arazi rıhtım yüzeyinin altında kalsın (iç içe titreme olmasın)
quay_box = (XX < -EDGE_X + 1) & (XX > -EDGE_X - 90) & (ZZ < 4) & (ZZ > -EDGE_Z - 10)
h = np.where(quay_box, np.minimum(h, -0.6), h)
# manastır platosu + merdiven rampası
MON = (180.0, -1000.0, 190.0)
dm = np.hypot(XX - MON[0], ZZ - MON[1])
h = np.where(dm < 95, h * smoothstep(55, 95, dm) + MON[2] * (1 - smoothstep(55, 95, dm)), h)
STAIR = [(180.0, -EDGE_Z - 8.0), (180.0, MON[1] + 62.0)]

# deniz tabanı
sea_floor = SEA - 1.0 - np.clip(dout * 0.05, 0, 34)
beach = smoothstep(40, 0, din) * (1 - smoothstep(60, 140, mtn))
h = np.where(land, h * (1 - beach) + np.clip(h, 0.2, 1.4) * beach, sea_floor)
h = np.where(land & (din < 10), np.minimum(h, 0.3), h)

# ------------------------------------------------------------------ yollar
print('yollar…')


def sample_h(x, z):
    fx, fz = px(x), pz(z)
    return float(ndimage.map_coordinates(h, [[fz], [fx]], order=1)[0])


def densify(pts, step=8.0):
    out = []
    for a, b in zip(pts[:-1], pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(L / step))
        for k in range(n):
            t = k / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    out.append(pts[-1])
    # Catmull-Rom yumuşatma (köşeler yuvarlansın)
    sm = [out[0]]
    for i in range(1, len(out) - 1):
        sm.append(((out[i - 1][0] + 2 * out[i][0] + out[i + 1][0]) / 4, (out[i - 1][1] + 2 * out[i][1] + out[i + 1][1]) / 4))
    sm.append(out[-1])
    for _ in range(3):
        sm = [sm[0]] + [((sm[i - 1][0] + 2 * sm[i][0] + sm[i + 1][0]) / 4, (sm[i - 1][1] + 2 * sm[i][1] + sm[i + 1][1]) / 4) for i in range(1, len(sm) - 1)] + [sm[-1]]
    return sm


def profile(pts, grade=0.09, fixed=None, bridge=False):
    ys = np.array([sample_h(x, z) for x, z in pts])
    ys = np.maximum(ys, 1.0)
    if fixed:
        for i, y in fixed.items():
            ys[i if i >= 0 else len(ys) + i] = y
    k = 9
    ys2 = np.convolve(np.pad(ys, k, mode='edge'), np.ones(2 * k + 1) / (2 * k + 1), mode='same')[k:-k]
    if fixed:
        for i, y in fixed.items():
            ys2[i if i >= 0 else len(ys2) + i] = y
    L = [0.0]
    for a, b in zip(pts[:-1], pts[1:]):
        L.append(L[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    for _ in range(3):  # eğim sınırı
        for i in range(1, len(ys2)):
            ys2[i] = np.clip(ys2[i], ys2[i - 1] - grade * (L[i] - L[i - 1]), ys2[i - 1] + grade * (L[i] - L[i - 1]))
        for i in range(len(ys2) - 2, -1, -1):
            ys2[i] = np.clip(ys2[i], ys2[i + 1] - grade * (L[i + 1] - L[i]), ys2[i + 1] + grade * (L[i + 1] - L[i]))
    if fixed:
        for i, y in fixed.items():
            ys2[i if i >= 0 else len(ys2) + i] = y
    return ys2


ROADS = []


def road(name, pts, width=11.0, kind='yol', grade=0.09, fixed=None, start_city=True):
    p = densify(pts)
    fx = {0: 0.0} if start_city else {}
    if fixed:
        fx.update(fixed)
    ys = profile(p, grade, fx)
    ROADS.append({'name': name, 'kind': kind, 'width': width, 'pts': [[round(x, 2), round(float(y), 2), round(z, 2)] for (x, z), y in zip(p, ys)]})


road('Manastır Yolu', [(400, -EDGE_Z), (520, -500), (720, -640), (800, -860), (700, -1080), (500, -1200), (330, -1200), (230, -1110),
                       (195, -1068)], 10.0, 'dag', 0.135, {-1: MON[2]})
road('Çöl Otoyolu', [(EDGE_X, 0), (650, 40), (1000, 180), (1400, 380), (1820, 630), (2080, 620), (2330, 700), (2650, 950),
                     (2880, 1300), (2930, 1680)], 14.0, 'otoyol', 0.07)
road('Güney Yolu', [(0, EDGE_Z), (150, 650), (480, 1050), (640, 1550), (640, 2100), (760, 2700), (1000, 3250), (1280, 3800),
                    (1450, 4300)], 12.0, 'yol', 0.08)
road('Kanyon Yolu', [(1400, 380), (1320, 900), (1150, 1500), (1330, 1960), (1520, 2250), (1720, 2480), (2200, 2650), (2780, 2330)],
     11.0, 'yol', 0.08, start_city=False)
road('Kuzey Yolu', [(1000, 180), (1120, -300), (1260, -760), (1700, -1060), (2300, -1080), (2620, -600), (2860, 80), (2950, 700),
                    (2880, 1300)], 11.0, 'yol', 0.1, start_city=False)
road('Lunapark Yolu', [(-200, EDGE_Z), (-230, 470)], 9.0, 'yol', 0.08)
# köprü: şehrin kuzeybatısından Güvenlikli Ada'ya
BRIDGE = [(-400, -EDGE_Z), (-400, -400), (-470, -520), (-640, -690), (-900, -840), (-960, -885)]  # kuzeybatı caddesinin ucundan, limanın dışından
bp = densify(BRIDGE, 8)
by = []
Lb = [0.0]
for a, b in zip(bp[:-1], bp[1:]):
    Lb.append(Lb[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
tot = Lb[-1]
for L in Lb:
    t = L / tot
    by.append(min(14.0, 0.0 + 14.0 * min(1, t / 0.15)) if t < 0.5 else min(14.0, 3.0 + 11.0 * min(1, (1 - t) / 0.12)))
ROADS.append({'name': 'Kızıl Köprü', 'kind': 'kopru', 'width': 13.0, 'pts': [[round(x, 2), round(y, 2), round(z, 2)] for (x, z), y in zip(bp, by)]})

# yolları araziye oy (yarma/dolgu)
best_w = np.zeros((H, W))
best_h = np.zeros((H, W))
for r in ROADS:
    if r['kind'] == 'kopru':
        continue
    pts = r['pts']
    half = r['width'] * 0.5
    for a, b in zip(pts[:-1], pts[1:]):
        x0i = int(max(0, px(min(a[0], b[0]) - 40)))
        x1i = int(min(W - 1, px(max(a[0], b[0]) + 40))) + 1
        z0i = int(max(0, pz(min(a[2], b[2]) - 40)))
        z1i = int(min(H - 1, pz(max(a[2], b[2]) + 40))) + 1
        sx, sz = XX[z0i:z1i, x0i:x1i], ZZ[z0i:z1i, x0i:x1i]
        dx, dz = b[0] - a[0], b[2] - a[2]
        L2 = dx * dx + dz * dz + 1e-9
        t = np.clip(((sx - a[0]) * dx + (sz - a[2]) * dz) / L2, 0, 1)
        d = np.hypot(sx - (a[0] + t * dx), sz - (a[2] + t * dz))
        yy = a[1] + (b[1] - a[1]) * t
        w = 1 - smoothstep(half + 2, half + 22, d)
        sel = w > best_w[z0i:z1i, x0i:x1i]
        best_w[z0i:z1i, x0i:x1i] = np.where(sel, w, best_w[z0i:z1i, x0i:x1i])
        best_h[z0i:z1i, x0i:x1i] = np.where(sel, yy - 0.3, best_h[z0i:z1i, x0i:x1i])
h = h * (1 - best_w) + best_h * best_w
# merdiven rampası
sdist, st = seg_dist(STAIR[0][0], STAIR[0][1], STAIR[1][0], STAIR[1][1])
sw = 1 - smoothstep(6, 20, sdist)
h = h * (1 - sw) + (st * MON[2] - 0.2) * sw
road_mask = best_w > 0.85

# ------------------------------------------------------------------ bölgeler
REGIONS = [  # kimlik, ad, etiket konumu
    (1, 'Neon Şehir', (0, 0)), (2, 'Kasırga Dağı', (180, -1000)), (3, 'Kuzey Sıradağları', (700, -1500)),
    (4, 'Altın Doruklar', (1320, -1250)), (5, 'Çorak Topraklar', (600, 300)), (6, 'Kum Denizi', (1150, 600)),
    (7, 'Kızıl Kanyon', (1350, 1950)), (8, 'Orta Sıradağlar', (2150, 0)), (9, 'Atalar Geçidi', (2080, 640)),
    (10, 'Ak Huş Ormanı', (2650, -330)), (11, 'Buzul Doruklar', (2850, -1000)), (12, 'Sis Kasabası', (2900, 1950)),
    (13, 'Sakin Orman', (500, 2450)), (14, 'Yasemin Köyü', (1050, 3300)), (15, 'Ruhlar Koyu', (1400, 4450)),
    (16, 'Güvenlikli Ada', (-1050, -950)), (17, 'Örümcek Adası', (-760, 2330)), (18, 'Ateş Adaları', (-1300, 1400)),
    (19, 'Güney Tepeleri', (1200, 3700)), (20, 'Doğu Kıyısı', (3100, 400)), (21, 'Batı Kıyısı', (-200, 1500)), (0, 'Açık Deniz', (0, 0))]
reg = np.zeros((H, W), np.uint8)
reg[land] = 21
reg[land & (XX > 2600)] = 20
reg[land & (ZZ > 3400) & (XX > 600)] = 19
reg[(REG['forest'] > 0.5) & land] = 13
reg[(REG['tea'] > 0.5) & land] = 14
reg[land & (ZZ > 4150)] = 15
reg[(central > 120) & land] = 8
reg[(north > 90) & land] = 3
reg[(REG['golden'] > 0.35) & land] = 4
reg[(glacier > 120) & land] = 11
reg[(REG['birch'] > 0.5) & land] = 10
reg[(REG['bad'] > 0.5) & land] = 5
reg[(REG['desert'] > 0.5) & land] = 6
reg[(REG['canyon'] > 0.5) & land] = 7
reg[(REG['pass'] > 0.5) & land & (np.abs(XX - 2080) < 300)] = 9
reg[(np.hypot(XX - 2900, ZZ - 1950) < 260)] = 12
reg[(mon_peak > 60) & land] = 2
for nm, cx, cz, r in ISLANDS:
    idx = {'ada': 16, 'orumcek': 17, 'atesA': 18, 'atesB': 18, 'atesC': 18}.get(nm, 0)
    if idx:
        reg[(np.hypot(XX - cx, ZZ - cz) < r + 60) & land] = idx
reg[(np.abs(XX) < EDGE_X + 75) & (np.abs(ZZ) < EDGE_Z + 60)] = 1

# ------------------------------------------------------------------ zemin rengi
print('renkler…')
gy, gx = np.gradient(h, STEP)
slope = np.hypot(gx, gy)
C = np.zeros((H, W, 3))
grass = np.stack([0.34 + n_mid * 0.04, 0.53 + n_mid * 0.06, 0.24 + n_mid * 0.03], -1)
dry = np.array([0.62, 0.56, 0.32])
sand = np.array([0.88, 0.8, 0.6])
dsand = np.array([0.83, 0.66, 0.42])
rock = np.array([0.42, 0.4, 0.37])
red = np.array([0.66, 0.36, 0.22])
gold = np.array([0.82, 0.66, 0.32])
snow = np.array([0.94, 0.95, 0.98])
forest = np.array([0.24, 0.37, 0.17])
C[:] = grass
C = C * (1 - REG['bad'][..., None]) + dry * REG['bad'][..., None]
f = np.clip(REG['forest'] + REG['tea'] * 0.5, 0, 1)[..., None]
C = C * (1 - f) + forest * f
C = C * (1 - REG['desert'][..., None]) + dsand * REG['desert'][..., None]
cr = np.clip(REG['canyon'] * smoothstep(0.1, 0.4, slope) + REG['canyon'] * 0.6, 0, 1)[..., None]
C = C * (1 - cr) + red * cr
mon_d = np.hypot(XX - MON[0], ZZ - MON[1])
mon_g = 1.0 - smoothstep(260, 480, mon_d)          # manastır dağı: yeşil yamaçlar, az kaya
rk = np.clip(smoothstep(0.45, 0.9, slope) + smoothstep(120, 200, h) * 0.6 * (1 - mon_g), 0, 1) * (1 - 0.45 * mon_g)
gk = np.clip(REG['golden'] * 0.9, 0, 1)[..., None]
rockcol = rock * (1 - gk) + gold * gk
rockcol = rockcol * (1 - cr) + red * cr
C = C * (1 - rk[..., None]) + rockcol * rk[..., None]
sn = np.clip(smoothstep(250, 300, h + n_mid * 20) + REG['birch'] * 0.85 + smoothstep(180, 240, h) * (glacier > 100), 0, 1)
sn = sn * (1 - smoothstep(0.9, 1.3, slope) * 0.5) * (1 - np.clip(REG['golden'] * 1.5, 0, 1))
C = C * (1 - sn[..., None]) + snow * sn[..., None]
bch = (land & (din < 45) & (h < 2.2) & (reg != 1))[..., None] * 1.0
C = C * (1 - bch) + sand * bch
C = np.where(land[..., None], C, np.array([0.55, 0.5, 0.4]))
dirt = np.array([0.42, 0.36, 0.28])
rs = smoothstep(0.85, 0.55, best_w)[..., None] * (best_w > 0.3)[..., None]
C = C * (1 - rs * 0.6) + dirt * rs * 0.6
A = np.clip(rk + (REG['canyon'] * 0.3), 0, 1)

# ------------------------------------------------------------------ şehir: bloklar, parseller, binalar
print('şehir…')
srng = np.random.default_rng(77)


def district(i, j):
    if i == -GX and j <= -1:
        return 'liman'
    if i == -GX:
        return 'sahil'
    if -4 <= i <= -3 and j <= -1:
        return 'eski'
    if j == -GZ and i <= 0:
        return 'eski'
    if i >= 2 and j <= -2:
        return 'tekno'
    if i >= 3 and j >= 0:
        return 'konut'
    if 1 <= i <= 2 and j >= 2:
        return 'lunapark'
    if -1 <= i <= 1 and -1 <= j <= 0:
        return 'merkez'
    return 'cadde'


DNAMES = {'merkez': 'Neon Bulvar', 'cadde': 'Neon Bulvar', 'eski': 'Eski Çarşı', 'liman': 'Liman', 'tekno': 'Teknoloji Merkezi',
          'konut': 'Doğu Konutları', 'sahil': 'Sahil', 'lunapark': 'Neon Lunapark'}
SIGNS = ['ERİŞTE', 'KAFE', 'OTEL', 'ÇAY', 'SUSHİ', 'ARCADE', 'BUTİK', 'ECZANE', 'RAMEN', 'KARAOKE', 'TEKNO', 'MANGA', 'BAR',
         'LOKUM', 'DÖNER', 'SİNEMA', 'PİDE', 'FIRIN', 'MARKET', 'OYUNCAK', 'KİTAP', 'SİMİT']
# önemli mekânlar: blok → (kimlik, ad, tür, iç mekân türü)
LANDMARKS = {(-3, -2): ('noodle', 'Noda Erişte Evi', 'food', 'restoran'), (-4, -1): ('weapons', 'Kılıç & Yıldız', 'weapons', 'silah'),
             (0, 1): ('boutique', 'Gölge Butik', 'clothes', 'butik'), (-1, 2): ('club', 'Neon Kulüp', 'club', 'kulup'),
             (-2, 0): ('police', 'Polis Merkezi', 'police', None), (3, -1): ('hospital', 'Hastane', 'hospital', None),
             (-2, 3): ('spray', 'Boya Atölyesi', 'spray', 'atolye'), (2, 1): ('dojo', "Turbo Tarık'ın Dojosu", 'dojo', 'dojo'),
             (3, -3): ('tower', 'Teknoloji Kulesi', 'tower', None), (1, -2): ('market', 'Kızıl Fener Market', 'food', 'market'),
             (-3, 1): ('bank', 'Ada Bankası', 'bank', None), (4, -2): ('arcade', 'Piksel Salonu', 'arcade', None)}
blocks = []
buildings = []
for i in range(-GX, GX):
    for j in range(-GZ, GZ):
        d = district(i, j)
        cx, cz = (i + 0.5) * CELL, (j + 0.5) * CELL
        b = {'i': i, 'j': j, 'd': d, 'c': [cx, cz]}
        blocks.append(b)
        if d == 'lunapark':
            continue
        lm = LANDMARKS.get((i, j))
        hh = BLOCK * 0.5
        if d == 'konut':
            for gx_ in (-1, 1):
                for gz_ in (-1, 1):
                    w_, d_ = float(srng.uniform(10, 14)), float(srng.uniform(9, 12))
                    buildings.append({'c': [cx + gx_ * BLOCK * 0.25, cz + gz_ * BLOCK * 0.25], 's': [w_, d_], 'k': 'ev', 'd': d,
                                      'h': round(float(srng.uniform(5, 7.5)), 1), 'roof': int(srng.integers(0, 2))})
            continue
        if lm:
            if lm[0] == 'tower':
                lots = [(-hh + 6, -hh + 6, BLOCK - 12, BLOCK - 12)]
            else:
                lots = [(-hh, -hh, BLOCK, BLOCK * 0.55), (-hh, BLOCK * 0.55 - hh + 3, BLOCK * 0.5 - 1.5, BLOCK * 0.45 - 3),
                        (1.5, BLOCK * 0.55 - hh + 3, BLOCK * 0.5 - 1.5, BLOCK * 0.45 - 3)]
        else:
            lay = int(srng.integers(0, 3))
            if d in ('merkez', 'tekno'):
                lay = int(srng.choice([0, 3]))
            if d == 'liman':
                lay = 1
            if lay == 0:
                q = BLOCK * 0.5 - 2
                lots = [(-hh, -hh, q, q), (2, -hh, q, q), (-hh, 2, q, q), (2, 2, q, q)]
            elif lay == 1:
                lots = [(-hh, -hh, BLOCK, BLOCK * 0.42), (-hh, BLOCK * 0.42 - hh + 3, BLOCK * 0.45, BLOCK * 0.58 - 3),
                        (BLOCK * 0.45 - hh + 3, BLOCK * 0.42 - hh + 3, BLOCK * 0.55 - 3, BLOCK * 0.58 - 3)]
            elif lay == 2:
                lots = [(-hh, -hh, BLOCK * 0.62, BLOCK), (BLOCK * 0.62 - hh + 3, -hh, BLOCK * 0.38 - 3, BLOCK * 0.5 - 1.5),
                        (BLOCK * 0.62 - hh + 3, 1.5, BLOCK * 0.38 - 3, BLOCK * 0.5 - 1.5)]
            else:
                lots = [(-hh + 6, -hh + 6, BLOCK * 0.55, BLOCK * 0.55)]
                b['plaza'] = True
        tall_p = {'merkez': 0.9, 'cadde': 0.3, 'eski': 0.0, 'sahil': 0.15, 'liman': 0.0, 'tekno': 0.95}.get(d, 0.2)
        for k, (lx, lz, lw, ld) in enumerate(lots):
            tall = srng.random() < tall_p
            if d in ('merkez', 'tekno') and tall:
                floors = int(srng.integers(16, 40))
            elif tall:
                floors = int(srng.integers(8, 16))
            elif d == 'eski':
                floors = int(srng.integers(1, 3))
            elif d == 'liman':
                floors = int(srng.integers(1, 3))
            else:
                floors = int(srng.integers(1, 6))
            kind = 'kule' if tall else ('pagoda' if d == 'eski' else ('depo' if d == 'liman' else 'bina'))
            bb = {'c': [round(cx + lx + lw * 0.5, 2), round(cz + lz + ld * 0.5, 2)], 's': [round(lw, 2), round(ld, 2)], 'k': kind, 'd': d,
                  'f': floors, 'h': round(4.6 + floors * 3.4, 1), 'glass': bool(tall and srng.random() < (0.8 if d == 'tekno' else 0.55)),
                  'seed': int(srng.integers(0, 1 << 30))}
            # vitrin: hangi cephe sokağa bakıyor → tabela ve kapı
            sides = []
            if lz <= -hh + 0.1:
                sides.append(1)   # -z
            if lz + ld >= hh - 0.1:
                sides.append(0)   # +z
            if lx <= -hh + 0.1:
                sides.append(3)   # -x
            if lx + lw >= hh - 0.1:
                sides.append(2)   # +x
            if sides and d != 'liman':
                bb['side'] = int(srng.choice(sides))
                bb['sign'] = SIGNS[int(srng.integers(0, len(SIGNS)))]
            if lm and k == 0:
                bb['lm'] = lm[0]
                bb['name'] = lm[1]
                bb['kind2'] = lm[2]
                if lm[3]:
                    bb['interior'] = lm[3]
                if lm[0] == 'tower':
                    bb['k'] = 'kule'
                    bb['h'] = 190.0
                    bb['f'] = 52
                    bb['glass'] = True
                else:
                    bb['h'] = max(bb['h'], 12.0) if bb['k'] != 'pagoda' else 9.0
                    bb['side'] = 0 if 0 in sides else (sides[0] if sides else 0)
                    bb.pop('sign', None)
            buildings.append(bb)

# ------------------------------------------------------------------ önemli yerler (şehir dışı)
POIS = [
    {'id': 'manastir', 'name': 'Kasırga Manastırı', 'kind': 'monastery', 'pos': [MON[0], MON[2], MON[1]]},
    {'id': 'smoothie', 'name': 'Ananas Smoothie', 'kind': 'food', 'pos': [-EDGE_X - 30, 0.4, 150], 'interior': 'smoothie'},
    {'id': 'liman', 'name': 'Liman', 'kind': 'harbor', 'pos': [-EDGE_X - 40, 0, -170]},
    {'id': 'sahil', 'name': 'Sahil', 'kind': 'beach', 'pos': [-EDGE_X - 40, 0, 120]},
    {'id': 'ada', 'name': 'Güvenlikli Ada', 'kind': 'secure', 'pos': [-1050, 4, -950]},
    {'id': 'harabe', 'name': 'Kum Altı Harabeleri', 'kind': 'ruins', 'pos': [1180, 0, 760]},
    {'id': 'gecit', 'name': 'Atalar Geçidi', 'kind': 'statues', 'pos': [2080, 0, 630]},
    {'id': 'sis', 'name': 'Sis Kasabası', 'kind': 'town', 'pos': [2950, 0, 1950]},
    {'id': 'koy', 'name': 'Yasemin Köyü', 'kind': 'village', 'pos': [1050, 0, 3300]},
    {'id': 'cay', 'name': 'Bilge Çay Bahçesi', 'kind': 'tea', 'pos': [880, 0, 3180]},
    {'id': 'hava', 'name': 'Hava Tapınağı', 'kind': 'temple', 'pos': [2160, 0, 1450]},
    {'id': 'volkan', 'name': 'Ateş Dağı', 'kind': 'volcano', 'pos': [-1300, 0, 1250]},
    {'id': 'huskulube', 'name': 'Mucit Kulübesi', 'kind': 'cabin', 'pos': [2700, 0, -260]},
    {'id': 'koylar', 'name': 'Ruhlar Koyu', 'kind': 'coves', 'pos': [1450, 0, 4480]},
    {'id': 'orumcek', 'name': 'Örümcek Adası', 'kind': 'island', 'pos': [-760, 0, 2330]},
    {'id': 'kopru', 'name': 'Kızıl Köprü', 'kind': 'bridge', 'pos': [-700, 14, -730]},
]
for p in POIS:
    p['pos'][1] = round(float(max(sample_h(p['pos'][0], p['pos'][2]), p['pos'][1])), 2) if p['kind'] not in ('monastery', 'secure') else p['pos'][1]

# ------------------------------------------------------------------ ağaçlar ve kayalar
print('ağaçlar…')
trees = {'cam': [], 'yuvarlak': [], 'hus': [], 'palmiye': [], 'kaktus': [], 'kuru': [], 'sakura': []}
rocks = []
tr = np.random.default_rng(99)
N = 240000
cand_x = tr.uniform(X0, X1, N)
cand_z = tr.uniform(Z0, Z1, N)
fi = np.clip(((cand_x - X0) / STEP).astype(int), 0, W - 1)
fj = np.clip(((cand_z - Z0) / STEP).astype(int), 0, H - 1)
for x, z, i_, j_ in zip(cand_x, cand_z, fi, fj):
    if not land[j_, i_] or h[j_, i_] < 1.0 or best_w[j_, i_] > 0.2 or reg[j_, i_] == 1:
        continue
    if slope[j_, i_] > 0.8 or abs(x - STAIR[0][0]) < 14 and STAIR[1][1] < z < STAIR[0][1]:
        continue
    if math.hypot(x - MON[0], z - MON[1]) < 70:
        continue
    y = float(h[j_, i_])
    r_ = reg[j_, i_]
    u = tr.random()
    s = float(tr.uniform(0.8, 1.45))
    kind = None
    if r_ == 6:
        if u < 0.035:
            kind = 'kaktus'
        elif u < 0.06:
            rocks.append([x, y, z, s * 1.4])
    elif r_ == 7:
        if u < 0.06:
            rocks.append([x, y, z, s * 2.2])
        elif u < 0.08:
            kind = 'kuru'
    elif r_ == 5:
        if u < 0.04:
            kind = 'kuru'
        elif u < 0.06:
            rocks.append([x, y, z, s])
    elif r_ == 10:
        if u < 0.55:
            kind = 'hus'
        elif u < 0.7:
            kind = 'cam'
    elif r_ in (3, 8, 11):
        if y < 230 and u < 0.35:
            kind = 'cam'
        elif u < 0.4:
            rocks.append([x, y, z, s * 2.0])
    elif r_ == 2:
        if u < 0.35:
            kind = 'sakura' if tr.random() < 0.5 else 'cam'
    elif r_ == 4:
        if u < 0.12:
            rocks.append([x, y, z, s * 2.5])
    elif r_ == 13:
        if u < 0.7:
            kind = 'yuvarlak' if tr.random() < 0.75 else 'cam'
    elif r_ == 14:
        if u < 0.15:
            kind = 'sakura'
    elif r_ in (17,):
        if u < 0.8:
            kind = 'palmiye' if tr.random() < 0.5 else 'yuvarlak'
    elif r_ == 18:
        if u < 0.05:
            kind = 'kuru'
        elif u < 0.12:
            rocks.append([x, y, z, s * 1.8])
    else:
        if din[j_, i_] < 60 and y < 6 and u < 0.12:
            kind = 'palmiye'
        elif u < 0.16:
            kind = 'yuvarlak' if tr.random() < 0.6 else 'cam'
    if kind:
        trees[kind].append([round(float(x), 1), round(y - 0.2, 2), round(float(z), 1), round(s, 2)])
print({k: len(v) for k, v in trees.items()}, 'kaya', len(rocks))

# ------------------------------------------------------------------ dosyalar
os.makedirs(OUT, exist_ok=True)
h32 = h.astype(np.float32)
h32.tofile(os.path.join(OUT, 'world_h.bin'))
col = np.concatenate([np.clip(C, 0, 1) * 255, A[..., None] * 255], -1).astype(np.uint8)
col.tofile(os.path.join(OUT, 'world_c.bin'))
reg.astype(np.uint8).tofile(os.path.join(OUT, 'world_r.bin'))
data = {
    'x0': X0, 'z0': Z0, 'step': STEP, 'w': W, 'h': H, 'sea': SEA,
    'city': {'cell': CELL, 'road_w': ROAD_W, 'walk': WALK, 'gx': GX, 'gz': GZ, 'blocks': blocks, 'buildings': buildings,
             'dnames': DNAMES},
    'roads': ROADS, 'stair': [[STAIR[0][0], 0.0, STAIR[0][1]], [STAIR[1][0], MON[2], STAIR[1][1]]],
    'monastery': [MON[0], MON[2], MON[1]], 'islands': [[n, cx, cz, r] for n, cx, cz, r in ISLANDS],
    'pois': POIS, 'regions': [[i, n, list(p)] for i, n, p in REGIONS],
    'trees': {k: [c for t in v for c in t] for k, v in trees.items()},
    'rocks': [c for r in rocks for c in [round(float(v), 2) for v in r]],
    'canyon': canyon_line, 'pass': pass_line,
}
with open(os.path.join(OUT, 'world.json'), 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

# ------------------------------------------------------------------ harita görseli
print('harita…')
MS = 2  # harita: 4 m/piksel
mw, mh = W * MS, H * MS
ls = np.array([-1.0, -1.2, 0.8])
ls /= np.linalg.norm(ls)
nx, nz = -gx, -gy
nl = (nx * ls[0] + nz * ls[1] + 1.0 * ls[2]) / np.sqrt(nx * nx + nz * nz + 1)
shade = np.clip(0.88 + nl * 0.22, 0.7, 1.1)       # yumuşak gölgeleme (GTA6 haritası gibi sade)
# arazi renklerini harita paletine çevir: yeşiller → yumuşak deniz yeşili, kuru alanlar → kum, kar → açık gri
lum = C[..., 0] * 0.3 + C[..., 1] * 0.59 + C[..., 2] * 0.11
greenish = (C[..., 1] > C[..., 0] * 1.02) & (C[..., 1] > C[..., 2] * 0.95)
teal = np.array([0.44, 0.67, 0.56])
forest = np.array([0.36, 0.58, 0.47])
sand = np.array([0.86, 0.8, 0.62])
snow = np.array([0.9, 0.93, 0.95])
rockc = np.array([0.62, 0.66, 0.6])
gcol = forest[None, None, :] + (teal - forest)[None, None, :] * np.clip((lum[..., None] - 0.18) / 0.25, 0, 1)
dry = sand[None, None, :] * (0.88 + 0.12 * np.clip(lum[..., None] / 0.6, 0, 1))
mc = np.where(greenish[..., None], gcol, dry)
mc = np.where((lum > 0.72)[..., None], snow[None, None, :], mc)
mc = mc * (1 - C[..., 3:4] * 0.5) + rockc[None, None, :] * C[..., 3:4] * 0.5 if C.shape[-1] > 3 else mc
shallow = smoothstep(140, 0, dout)[..., None]
deep = np.clip(dout / 900.0, 0, 1)[..., None]
water = np.array([0.33, 0.68, 0.84]) * shallow + (np.array([0.2, 0.47, 0.67]) * (1 - deep) + np.array([0.11, 0.27, 0.45]) * deep) * (1 - shallow)
mc = np.where(land[..., None], mc * shade[..., None], water)
img = Image.fromarray((np.clip(mc, 0, 1) * 255).astype(np.uint8)).resize((mw, mh), Image.BICUBIC)
dr = ImageDraw.Draw(img, 'RGBA')


def m(x, z):
    return ((x - X0) / STEP * MS, (z - Z0) / STEP * MS)


# şehir: açık gri zemin, beyaz yollar, gri binalar (GTA6 haritası tarzı)
dr.rectangle([m(-EDGE_X - 4, -EDGE_Z - 4), m(EDGE_X + 4, EDGE_Z + 4)], fill=(186, 190, 196, 255))
for b in blocks:
    o = (BLOCK + WALK * 2) * 0.5
    cx, cz = b['c']
    col_b = {'lunapark': (150, 196, 170, 255), 'konut': (196, 204, 200, 255)}.get(b['d'], (205, 208, 214, 255))
    dr.rectangle([m(cx - o, cz - o), m(cx + o, cz + o)], fill=col_b)
for bb in buildings:
    cx, cz = bb['c']
    sw_, sd_ = bb['s']
    shade_b = 178 - min(bb['h'], 150) * 0.25
    dr.rectangle([m(cx - sw_ / 2, cz - sd_ / 2), m(cx + sw_ / 2, cz + sd_ / 2)], fill=(int(shade_b), int(shade_b + 4), int(shade_b + 12), 255))
for i in range(-GX, GX + 1):
    dr.line([m(i * CELL, -CITY_Z - 6), m(i * CELL, CITY_Z + 6)], fill=(250, 251, 252, 255), width=max(2, int(ROAD_W / STEP * MS * 1.2)))
for j in range(-GZ, GZ + 1):
    dr.line([m(-CITY_X - 6, j * CELL), m(CITY_X + 6, j * CELL)], fill=(250, 251, 252, 255), width=max(2, int(ROAD_W / STEP * MS * 1.2)))
# yollar: ince gri kenarlı beyaz çizgiler; otoyol daha kalın
for r in ROADS:
    pts = [m(p[0], p[2]) for p in r['pts']]
    wdt = max(2, int(r['width'] / STEP * MS * (1.3 if r['kind'] == 'otoyol' else 1.0)))
    dr.line(pts, fill=(120, 128, 130, 200), width=wdt + 2, joint='curve')
    fillc = {'otoyol': (255, 250, 226, 255), 'kopru': (236, 238, 242, 255)}.get(r['kind'], (248, 249, 250, 255))
    dr.line(pts, fill=fillc, width=wdt, joint='curve')
dr.line([m(*STAIR[0]), m(*STAIR[1])], fill=(200, 180, 150, 255), width=3)
img = img.filter(ImageFilter.UnsharpMask(radius=1.0, percent=40))
img.save(os.path.join(OUT, 'map.png'), optimize=True)
print('tamam', W, H, 'yol', len(ROADS), 'bina', len(buildings))
