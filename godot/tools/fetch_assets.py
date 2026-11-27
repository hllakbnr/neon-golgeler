#!/usr/bin/env python3
"""Ücretsiz/açık lisanslı gerçekçi varlıkları indirir (CI'da derlemeden önce çalışır).
- Poly Haven (CC0): PBR dokular + sokak modelleri (API ile anahtar kelimeye göre seçilir)
- three.js örnek modelleri (MIT): iskeletli insan modeli (Idle/Walk/Run)
- Google Fonts (OFL): arayüz yazı tipleri
Bir kaynak inmezse oyun prosedürel yedeklerle çalışır; manifest.json neyin indiğini söyler.
"""
import json, os, sys, urllib.request, urllib.error

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets')
UA = {'User-Agent': 'NeonGolgeler-Build/1.0 (github.com/hllakbnr/neon-golgeler)'}
manifest = {'tex': {}, 'models': {}, 'chars': {}, 'fonts': {}}


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
    best = None
    for aid, a in assets.items():
        text = (aid + ' ' + ' '.join(a.get('tags', [])) + ' ' + ' '.join(a.get('categories', []))).lower()
        if any(k in aid.lower() for k in keywords) and not any(x in text for x in exclude):
            score = a.get('download_count', 0)
            if best is None or score > best[1]:
                best = (aid, score)
    return best[0] if best else None


def polyhaven():
    try:
        textures = get('https://api.polyhaven.com/assets?t=textures', False)
        models = get('https://api.polyhaven.com/assets?t=models', False)
    except Exception as e:
        print('Poly Haven erişilemedi:', e)
        return
    want_tex = {
        'asphalt': (['asphalt', 'road'], ()),
        'sidewalk': (['paving', 'pavement', 'sidewalk', 'concrete_tiles'], ()),
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
        'bin': ['trash', 'bin', 'garbage'],
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


def fonts():
    for key, url in {
        'display': 'https://github.com/google/fonts/raw/main/ofl/bebasneue/BebasNeue-Regular.ttf',
        'ui': 'https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf',
    }.items():
        if try_dl(url, os.path.join(ROOT, 'fonts', key + '.ttf')):
            manifest['fonts'][key] = 'res://assets/fonts/%s.ttf' % key


if __name__ == '__main__':
    polyhaven()
    characters()
    fonts()
    with open(os.path.join(ROOT, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
