#!/usr/bin/env python3
"""Ücretsiz/açık lisanslı gerçekçi varlıkları indirir (CI'da derlemeden önce çalışır).
- Poly Haven (CC0): PBR dokular + sokak modelleri (API ile anahtar kelimeye göre seçilir)
- three.js örnek modelleri (MIT): iskeletli insan modeli (Idle/Walk/Run)
- Google Fonts (OFL): arayüz yazı tipleri
Bir kaynak inmezse oyun prosedürel yedeklerle çalışır; manifest.json neyin indiğini söyler.
"""
import json, os, sys, io, zipfile, colorsys, urllib.request, urllib.error

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets')
UA = {'User-Agent': 'NeonGolgeler-Build/1.0 (github.com/hllakbnr/neon-golgeler)'}
manifest = {'tex': {}, 'models': {}, 'chars': {}, 'fonts': {}, 'kenney': {}}


def get(url, binary=True):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    return data if binary else json.loads(data.decode('utf-8'))


def save(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data)


def try_dl(url, path):
    try:
        save(path, get(url))
        print('  ✓', os.path.relpath(path, ROOT))
        return True
    except Exception as e:
        print('  ✗', url, e)
        return False


def pick(assets, keywords, exclude=()):
    # anahtar kelimeler öncelik sırasıyla denenir; eşleşenler arasında en çok indirilen seçilir
    for k in keywords:
        best = None
        for aid, a in assets.items():
            text = (aid + ' ' + ' '.join(a.get('tags', [])) + ' ' + ' '.join(a.get('categories', []))).lower()
            if k in aid.lower() and not any(x in text for x in exclude):
                score = a.get('download_count', 0)
                if best is None or score > best[1]:
                    best = (aid, score)
        if best:
            return best[0]
    return None


def polyhaven():
    try:
        textures = get('https://api.polyhaven.com/assets?t=textures', False)
        models = get('https://api.polyhaven.com/assets?t=models', False)
    except Exception as e:
        print('Poly Haven erişilemedi:', e)
        return
    want_tex = {
        'asphalt': (['asphalt', 'road'], ()),
        'sidewalk': (['concrete_pavement', 'sidewalk', 'concrete_tiles', 'paving_tiles', 'pavement'], ()),
        'brick': (['brick_wall', 'red_brick', 'brick'], ('floor',)),
        'plaster': (['plaster', 'painted_plaster', 'stucco'], ()),
        'concrete': (['concrete_wall', 'concrete'], ('floor', 'tiles')),
        'grass': (['grass', 'lawn'], ()),
    }
    for key, (kw, ex) in want_tex.items():
        aid = pick(textures, kw, ex)
        if not aid:
            continue
        try:
            files = get('https://api.polyhaven.com/files/' + aid, False)
        except Exception as e:
            print('  ✗', aid, e)
            continue
        print('Doku', key, '→', aid)
        out = {}
        for slot, names in (('diff', ['Diffuse', 'diff']), ('nor', ['nor_gl']), ('rough', ['Rough', 'rough'])):
            for n in names:
                f = files.get(n, {}).get('1k', {}).get('jpg')
                if f and try_dl(f['url'], os.path.join(ROOT, 'tex', key, slot + '.jpg')):
                    out[slot] = 'res://assets/tex/%s/%s.jpg' % (key, slot)
                    break
        if 'diff' in out:
            manifest['tex'][key] = out
    want_models = {
        'lamp': ['street_lamp', 'streetlamp', 'lamp_post', 'street_light'],
        'bench': ['bench'],
        'bin': ['trash_can', 'trashcan', 'garbage', 'dumpster'],
        'hydrant': ['hydrant'],
        'plant': ['potted_plant', 'plant'],
        'barrier': ['barrier', 'bollard', 'cone'],
        'palm': ['palm'],
    }
    for key, kw in want_models.items():
        aid = pick(models, kw)
        if not aid:
            continue
        try:
            files = get('https://api.polyhaven.com/files/' + aid, False)
            g = files['gltf']['1k']['gltf']
        except Exception as e:
            print('  ✗ model', aid, e)
            continue
        print('Model', key, '→', aid)
        base = os.path.join(ROOT, 'models', key)
        ok = try_dl(g['url'], os.path.join(base, key + '.gltf'))
        for rel, inc in g.get('include', {}).items():
            ok = try_dl(inc['url'], os.path.join(base, rel)) and ok
        if ok:
            # gltf içindeki dosya adı farklı olabilir → aynı klasörde tutulur
            manifest['models'][key] = 'res://assets/models/%s/%s.gltf' % (key, key)


def characters():
    for base in ['https://raw.githubusercontent.com/mrdoob/three.js/r160/examples/models/gltf/',
                 'https://threejs.org/examples/models/gltf/']:
        if try_dl(base + 'Xbot.glb', os.path.join(ROOT, 'chars', 'human.glb')):
            manifest['chars']['human'] = 'res://assets/chars/human.glb'
            break


KENNEY = 'https://opengameart.org/sites/default/files/'


def kenney():
    """Kenney (CC0) oyuncak tarzı paketler: bloklu karakterler + araç kiti."""
    packs = {
        'blocky': (['kenney_blocky-characters_2.0.zip'], 'Models/GLB format/'),
        'cars': (['kenney_car-kit_3.0.zip', 'kenney_car-kit.zip'], 'Models/GLB format/'),
    }
    for key, (names, prefix) in packs.items():
        data = None
        for n in names:
            try:
                data = get(KENNEY + n)
                print('Kenney', key, '←', n, len(data))
                break
            except Exception as e:
                print('  ✗', n, e)
        if not data:
            continue
        z = zipfile.ZipFile(io.BytesIO(data))
        out_dir = os.path.join(ROOT, 'kenney', key)
        for info in z.infolist():
            if not info.filename.startswith(prefix) or info.is_dir():
                continue
            rel = info.filename[len(prefix):]
            if key == 'cars' and rel.endswith('.glb') and (rel.startswith('debris') or rel.startswith('kart') or rel.startswith('tractor') or rel.startswith('race')):
                continue
            save(os.path.join(out_dir, rel), z.read(info))
        files = sorted(f for f in os.listdir(out_dir) if f.endswith('.glb'))
        manifest.setdefault('kenney', {})[key] = ['res://assets/kenney/%s/%s' % (key, f) for f in files]
        print('  ', key, files)
    _make_skins()


def animations():
    """Quaternius Universal Animation Library 1 + 2 (CC0): gerçekçi insan hareketleri."""
    packs = [
        ('ual1', 'universal_animation_librarystandard.zip', 'AnimationLibrary_Godot_Standard.glb'),
        ('ual2', 'universal_animation_library_2standard.zip', 'UAL2_Standard.glb'),
    ]
    for key, zname, inner in packs:
        try:
            data = get(KENNEY + zname)
        except Exception as e:
            print('  ✗ animasyon', zname, e)
            continue
        z = zipfile.ZipFile(io.BytesIO(data))
        hit = [i for i in z.infolist() if i.filename.endswith('/' + inner) or i.filename == inner]
        if not hit:
            print('  ✗', inner, 'zip içinde yok')
            continue
        save(os.path.join(ROOT, 'anim', key + '.glb'), z.read(hit[0]))
        manifest.setdefault('anim', {})[key] = 'res://assets/anim/%s.glb' % key
        print('Animasyon', key, '←', zname, hit[0].file_size)


def _recolor(src, dst, mapping, extra=None):
    from PIL import Image, ImageDraw
    im = Image.open(src).convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            out = mapping(x, y, r, g, b)
            if out:
                px[x, y] = out + (a,)
    if extra:
        extra(ImageDraw.Draw(im), im)
    im.save(dst)


def _make_skins():
    """Kaan ve Ela için özgün kostümler (ninja şablonundan yeniden renklendirme)."""
    try:
        from PIL import Image  # noqa
    except Exception:
        print('PIL yok, özel kostüm atlandı')
        return
    tdir = os.path.join(ROOT, 'kenney', 'blocky', 'Textures')
    src = os.path.join(tdir, 'texture-r.png')
    if not os.path.exists(src):
        return
    def shade(r, g, b):
        return (r + g + b) / 3.0
    def is_skin(r, g, b):
        return r > 200 and g > 150 and b > 110 and r > b + 40
    def is_belt(r, g, b):
        return r > 180 and g < 120 and b < 130
    # Kaan: grafit siyahı kıyafet, turuncu kuşak ve kol şeritleri (Metal)
    def kaan(x, y, r, g, b):
        if is_skin(r, g, b):
            return None
        if is_belt(r, g, b):
            return (255, 128, 20)
        v = shade(r, g, b)
        if 40 < v < 130:
            k = (v - 40) / 90.0
            c = (int(22 + 40 * k), int(22 + 40 * k), int(26 + 44 * k))
            # kollarda turuncu şerit
            if 480 <= x < 1024 and 700 <= y < 724:
                return (240, 110, 15)
            return c
        return None
    def kaan_extra(d, im):
        # sırtta metal amblemi (iç içe altıgen)
        cx, cy = 384, 850
        for rr, col in ((40, (255, 128, 20)), (30, (30, 30, 36)), (18, (200, 200, 210))):
            pts = [(cx + rr * __import__('math').cos(a * 1.0472), cy + rr * __import__('math').sin(a * 1.0472)) for a in range(6)]
            d.polygon(pts, fill=col + (255,))
    _recolor(src, os.path.join(tdir, 'kaan.png'), kaan, kaan_extra)
    # Ela: camgöbeği / beyaz kıyafet, beyaz kuşak (Rüzgâr)
    def ela(x, y, r, g, b):
        if is_skin(r, g, b):
            return None
        if is_belt(r, g, b):
            return (240, 250, 255)
        v = shade(r, g, b)
        if 40 < v < 130:
            k = (v - 40) / 90.0
            return (int(20 + 60 * k), int(120 + 80 * k), int(130 + 80 * k))
        return None
    def ela_extra(d, im):
        cx, cy = 384, 850
        for i in range(3):
            d.arc((cx - 34 + i * 6, cy - 30 + i * 10, cx + 34 - i * 6, cy + 10 + i * 10), 200, 340, fill=(240, 250, 255, 255), width=6)
    _recolor(src, os.path.join(tdir, 'ela.png'), ela, ela_extra)
    manifest.setdefault('kenney', {})['skins'] = sorted('res://assets/kenney/blocky/Textures/' + f for f in os.listdir(tdir) if f.endswith('.png'))
    print('Özel kostümler: kaan.png, ela.png')


def fonts():
    for key, url in {
        'display': 'https://github.com/google/fonts/raw/main/ofl/bebasneue/BebasNeue-Regular.ttf',
        'ui': 'https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf',
    }.items():
        if try_dl(url, os.path.join(ROOT, 'fonts', key + '.ttf')):
            manifest['fonts'][key] = 'res://assets/fonts/%s.ttf' % key


if __name__ == '__main__':
    polyhaven()
    kenney()
    animations()
    characters()   # yalnızca CI testinde iskeletli özel model denemesi için
    fonts()
    with open(os.path.join(ROOT, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
